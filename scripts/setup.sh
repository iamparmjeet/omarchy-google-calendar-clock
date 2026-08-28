#!/usr/bin/env bash
#
# Set up the parm.clock Google Calendar/Tasks plugin.
#
# Does, in order:
#   1. verify gcloud + gws are installed (prompts before installing; gcloud is
#      google-cloud-cli AUR via yay, gws is googleworkspace/cli via npm/cargo,
#      NOT the pacman 'gws' git-workspace helper)
#   2. gws auth setup --project <project>   (enable Calendar+Tasks APIs, OAuth client)
#   3. gws auth login --services calendar,tasks   (ONE browser consent)
#   4. gws auth status -> assert authenticated
#   5. write ~/.config/parm.clock/config.json
#   6. run the first sync
#   7. install + enable the systemd user timer
#
# The single browser consent (step 3) is the only manual step. Everything else
# is scripted. Safe to re-run; existing state is never overwritten destructively.
#
# Usage: ./setup.sh [--project <gcp-project-id>] [--timezone <tz>] [--dry-run] [--yes] [--allow-aur] [--allow-cargo] [--trust-existing-gws]

set -euo pipefail

# npm's registry integrity value is published with the exact CLI release. The
# package is downloaded and checked before its lifecycle script is allowed to
# run; installing by version alone would not provide that guarantee.
NPM_GWS_PACKAGE="@googleworkspace/cli@0.22.5"
NPM_GWS_INTEGRITY="sha512-Cej4nnkjphwRF+i7KWx4esp0p41yZ7Rv7A+P9hmFQrMStcngTASZBpeN/Lptk58oXxnSHvEcvM69S0e0y/GlvA=="

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_DIR="$REPO/sync"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/parm.clock"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/parm.clock"
CONFIG_FILE="$CONFIG_DIR/config.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

if [[ -n "${PARM_CLOCK_PROJECT:-}" ]]; then
  PROJECT="$PARM_CLOCK_PROJECT"
else
  # GCP project ids are globally unique; the previous default "omarchy-clock"
  # is already taken, so every new user hit PERMISSION_DENIED on
  # `gcloud services enable` with a misleading IAM error. Generate a unique
  # default that still hints at the owner (6-30 chars, lowercase, hyphens).
  _suffix="$(head -c4 /dev/urandom 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n' | head -c8)"
  if [[ -z "$_suffix" && -r /proc/sys/kernel/random/uuid ]]; then
    _suffix="$(tr -d '-' < /proc/sys/kernel/random/uuid | head -c8)"
  fi
  if [[ -z "$_suffix" ]]; then
    printf 'could not generate a unique project suffix\n' >&2
    exit 1
  fi
  PROJECT="omarchy-clock-${_suffix,,}"
  unset _suffix
fi
TIMEZONE="${PARM_CLOCK_TIMEZONE:-}"
DRY_RUN=false
AUTO_YES=false
ALLOW_AUR=false
ALLOW_CARGO=false
TRUST_EXISTING_GWS=false
GWS_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?--project requires a value}"; shift 2 ;;
    --timezone) TIMEZONE="${2:?--timezone requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) AUTO_YES=true; shift ;;
    --allow-aur) ALLOW_AUR=true; shift ;;
    --allow-cargo) ALLOW_CARGO=true; shift ;;
    --trust-existing-gws) TRUST_EXISTING_GWS=true; shift ;;
    -h | --help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ----------------------------------------------------------------- plumbing

info() { printf '\033[36m::\033[0m %s\n' "$1"; }
ok() { printf '\033[32m ✓\033[0m %s\n' "$1"; }
warn() { printf '\033[33m !\033[0m %s\n' "$1" >&2; }
die() { printf '\033[31m ✗\033[0m %s\n' "$1" >&2; exit 1; }

run() {
  if $DRY_RUN; then
    printf '   would run: %s\n' "$*"
  else
    "$@"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_correct_gws() {
  local gws_bin="${1:-$(command -v gws 2>/dev/null || true)}"
  # Correct gws is googleworkspace/cli; wrong gws is StreakyCobra/git-workspace (pacman package).
  # Wrong binary prints "Not in a workspace" and help contains "Manage workspaces which contain git".
  if [[ -z "$gws_bin" || ! -x "$gws_bin" ]]; then return 1; fi
  if "$gws_bin" --help 2>&1 | grep -q "Manage workspaces which contain git"; then return 1; fi
  if "$gws_bin" --help 2>&1 | grep -q "Not in a workspace"; then
    # Could be either, but correct gws never says "Not in a workspace" without args
    # so also check for auth subcommand
    if ! "$gws_bin" auth --help 2>&1 | grep -q "auth"; then return 1; fi
  fi
  # Correct gws has `gws auth status` and `gws calendar` subcommands
  if "$gws_bin" --help 2>&1 | grep -q "Google Workspace"; then return 0; fi
  if "$gws_bin" auth --help 2>&1 | grep -q "calendar\|tasks"; then return 0; fi
  # Fallback: check version string contains google-workspace or gws
  if "$gws_bin" --version 2>&1 | grep -qi "google"; then return 0; fi
  # If we have a binary but can't tell, assume wrong if --help lacks "auth setup"
  if "$gws_bin" --help 2>&1 | grep -q "auth setup"; then return 0; fi
  # Last resort: try `gws auth status` help
  if "$gws_bin" auth status --help 2>&1 | grep -q "auth"; then return 0; fi
  return 1
}

ask() {
  local prompt="$1"
  if $AUTO_YES || $DRY_RUN; then
    # In --dry-run we show what would be asked but don't block
    if $DRY_RUN; then echo "   would ask: $prompt [Y/n] -> Y (dry-run)"; fi
    return 0
  fi
  # Never approve package or privileged actions implicitly in a pipeline.
  if [[ ! -t 0 ]]; then
    warn "Non-interactive setup requires --yes to approve: $prompt"
    return 1
  fi
  local ans
  read -r -p "$prompt [Y/n] " ans </dev/tty || return 1
  ans="${ans:-Y}"
  [[ "$ans" =~ ^[Yy] ]] || [[ "$ans" == "" ]]
}

install_correct_gws() {
  info "Installing correct gws (googleworkspace/cli)…"
  info "  This is NOT the pacman package 'gws' (git-workspace helper)."
  info "  Source: https://github.com/googleworkspace/cli"
  if $DRY_RUN; then
    echo "   would run: verify npm tarball integrity, then install ${NPM_GWS_PACKAGE}"
    echo "   would run: cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked (fallback)"
    return 0
  fi
  # Remove wrong pacman gws if present (-Qi: -Q prints only "name version",
  # never the description the grep looks for)
  if pacman -Qi gws 2>/dev/null | grep -q "Colorful KISS helper"; then
    warn "Removing wrong pacman package 'gws' (StreakingCobra/git-workspace)…"
    if ask "Remove wrong pacman package 'gws' (StreakingCobra/git-workspace) with sudo?"; then
      sudo pacman -Rns gws 2>/dev/null || true
    else
      warn "Keeping wrong pacman package 'gws'; it may shadow the Google Workspace CLI."
    fi
    hash -r 2>/dev/null || true
  fi
  # Try npm first (preferred, prebuilt Rust binaries). Pinned to v0.22.5 so the
  # release is reproducible. Verify the immutable registry integrity value and
  # install the verified local tarball so a second fetch cannot change bytes.
  if command_exists npm; then
    local npm_tmp npm_tarball
    npm_tmp="$(mktemp -d)"
    npm pack --ignore-scripts --silent --pack-destination "$npm_tmp" "$NPM_GWS_PACKAGE" >/dev/null 2>&1 || true
    npm_tarball="$npm_tmp/googleworkspace-cli-0.22.5.tgz"
    if [[ -f "$npm_tarball" ]] && \
       python3 - "$npm_tarball" "$NPM_GWS_INTEGRITY" <<'PY'
import base64
import hashlib
import sys

path, expected = sys.argv[1:]
digest = hashlib.sha512(open(path, "rb").read()).digest()
raise SystemExit(0 if "sha512-" + base64.b64encode(digest).decode() == expected else 1)
PY
    then
      info "Verified npm tarball integrity for ${NPM_GWS_PACKAGE}."
      info "Trying: npm install -g verified local tarball"
    else
      warn "npm tarball integrity verification failed — refusing npm install."
      rm -rf -- "$npm_tmp"
      npm_tarball=""
    fi
    if [[ -n "$npm_tarball" ]] && npm install -g "$npm_tarball"; then
      rm -rf -- "$npm_tmp"
      hash -r 2>/dev/null || true
      if is_correct_gws "$(readlink -f -- "$(command -v gws)")"; then
        GWS_PATH="$(readlink -f -- "$(command -v gws)")"
        ok "gws installed via npm."; return 0
      fi
      warn "npm install succeeded but gws still not correct — trying fallback."
    else
      rm -rf -- "$npm_tmp"
      warn "npm install failed (check network/npm PATH) — trying fallback."
    fi
  else
    warn "npm not found — trying cargo."
  fi
  # Try cargo (pinned to v0.22.5 for reproducible marketplace review)
  if command_exists cargo && $ALLOW_CARGO; then
    info "Trying: cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked  (v0.22.5)"
    if cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked; then
      hash -r 2>/dev/null || true
      if is_correct_gws "$(readlink -f -- "$(command -v gws)")"; then
        GWS_PATH="$(readlink -f -- "$(command -v gws)")"
        ok "gws installed via cargo."; return 0
      fi
    fi
  fi
  die "gws install failed. Install manually from the signed release at https://github.com/googleworkspace/cli/releases/tag/v0.22.5, verify its .sha256 file, then rerun with --trust-existing-gws; or explicitly permit the pinned Cargo fallback with --allow-cargo."
}

# ----------------------------------------------------------------- step 1: deps

ensure_deps() {
  info "Checking dependencies (gcloud, gws, python3)…"
  info "Environment: PATH=$PATH"
  info "  node=$(command_exists node && node --version 2>/dev/null || echo 'missing')  npm=$(command_exists npm && npm --version 2>/dev/null || echo 'missing')  cargo=$(command_exists cargo && cargo --version 2>/dev/null | head -1 || echo 'missing')"
  info "  pacman=$(command_exists pacman && echo yes || echo no)  yay=$(command_exists yay && echo yes || echo no)  python3=$(command_exists python3 && python3 --version 2>/dev/null || echo 'missing')"

  # python3 is hard requirement
  command_exists python3 || die "python3 is required but not found. Install python3 and re-run."

  # gcloud — google-cloud-cli is AUR (yay), not extra
  if ! command_exists gcloud; then
    warn "gcloud not found. It provides 'gcloud' for GCP project setup (google-cloud-cli AUR, ~313MiB)."
    if ask "Install google-cloud-cli via yay/pacman (needs sudo)?"; then
      if $DRY_RUN; then
        info "Would install google-cloud-cli (yay -S or pacman -S)"
      elif command_exists yay; then
        if ! $ALLOW_AUR; then
          die "google-cloud-cli is supplied through the AUR. Refusing automatic AUR code execution; install it manually with 'yay -S google-cloud-cli' after reviewing the PKGBUILD, or rerun with --allow-aur."
        fi
        warn "AUR PKGBUILD execution is not independently verified by this plugin. Review it before continuing."
        info "Installing google-cloud-cli via yay…"
        yay -S --needed google-cloud-cli || \
          die "gcloud install via yay failed; try: yay -S google-cloud-cli  or  https://cloud.google.com/sdk/docs/install"
        ok "gcloud installed via yay."
      elif command_exists pacman && pacman -Si google-cloud-cli >/dev/null 2>&1; then
        info "Installing google-cloud-cli via pacman…"
        sudo pacman -S --needed google-cloud-cli || \
          die "gcloud install failed; install it manually (https://cloud.google.com/sdk/docs/install) and re-run."
        ok "gcloud installed via pacman."
      elif command_exists pacman; then
        # AUR but yay not installed — try pacman anyway, else instruct yay
        warn "google-cloud-cli is AUR — yay is recommended (pacman alone won't find it)."
        info "Trying pacman (will fail if not in extra, then try manual)…"
        if sudo pacman -S --needed google-cloud-cli 2>/dev/null; then
          ok "gcloud installed via pacman."
        else
          die "gcloud not in pacman repos. Install yay (https://github.com/Jguer/yay) then: yay -S google-cloud-cli  — or use https://cloud.google.com/sdk/docs/install"
        fi
      else
        die "gcloud not found and no AUR helper. Install yay then: yay -S google-cloud-cli  or  https://cloud.google.com/sdk/docs/install"
      fi
    else
      die "gcloud is required. Install via: yay -S google-cloud-cli  and re-run setup.sh."
    fi
  fi

  # gws — check both missing and wrong binary
  if ! command_exists gws; then
    warn "gws (Google Workspace CLI) not found. It owns OAuth and Calendar/Tasks API calls."
    warn "  Package: @googleworkspace/cli from https://github.com/googleworkspace/cli"
    if ask "Install gws (googleworkspace/cli) now?"; then
      install_correct_gws
    else
      die "gws is required. Install via: npm install -g @googleworkspace/cli  and re-run."
    fi
  else
    local existing_gws
    existing_gws="$(readlink -f -- "$(command -v gws)")"
    if [[ "$TRUST_EXISTING_GWS" != true ]]; then
      warn "An existing gws was found, but setup will not authenticate through an unpinned PATH executable."
      if ! install_correct_gws; then
        die "Install a verified gws release, then rerun with --trust-existing-gws after reviewing its checksum."
      fi
    elif ! is_correct_gws "$existing_gws"; then
      warn "Existing gws does not pass the Google Workspace CLI compatibility check."
      install_correct_gws
    else
      GWS_PATH="$existing_gws"
    fi
  fi

  if [[ -z "$GWS_PATH" ]]; then
    GWS_PATH="$(readlink -f -- "$(command -v gws)")"
  fi
  if ! is_correct_gws "$GWS_PATH"; then
    warn "Found wrong 'gws' binary at $(command -v gws) — this is the git-workspace helper (StreakyCobra/gws), not Google Workspace CLI."
    warn "  Wrong binary help: $("$GWS_PATH" --help 2>&1 | head -1)"
    warn "  Correct binary should support: gws auth setup, gws auth login, gws calendar calendarList list"
    die "Selected gws failed verification. Install the signed Google Workspace CLI release and rerun with --trust-existing-gws."
  fi

  command_exists python3 || die "python3 is required but not found."
  ok "gcloud $(gcloud --version 2>/dev/null | head -1 | awk '{print $NF}' || echo 'unknown')"
  # Show which gws we have
  if is_correct_gws "$GWS_PATH"; then
    ok "gws $("$GWS_PATH" --version 2>&1 | head -1) [googleworkspace/cli] at $GWS_PATH"
  else
    warn "gws at $(command -v gws) does not look like googleworkspace/cli — will fail at auth. Re-run setup.sh --yes to fix."
  fi
}

# ----------------------------------------------------------------- step 2-4: auth

ensure_auth() {
  # If already authenticated, skip `gws auth setup` — it requires manual OAuth client
  # creation and fails (400) when the project already has a client or when the
  # user has a valid token. The setup step is only needed on first run.
  if ! $DRY_RUN && "$GWS_PATH" auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
    ok "already authenticated via OAuth2 — skipping gws auth setup."
    return 0
  fi

  info "Configuring the GCP project + OAuth client (gws auth setup)…"
  if $DRY_RUN; then
    echo "   would run: $GWS_PATH auth setup --project $PROJECT"
  else
    # Don't die on setup failure — it may require manual console steps but auth may already be ok.
    _setup_out="$(mktemp)"
    trap 'rm -f -- "${_setup_out:-}"' EXIT
    if ! "$GWS_PATH" auth setup --project "$PROJECT" 2>&1 | tee "$_setup_out"; then
      # GCP project ids are globally unique. gcloud reports a missing project and
      # an inaccessible (already-taken) project with the same PERMISSION_DENIED,
      # which users misread as an IAM issue. Detect that case explicitly.
      if grep -qiE "already in use|already exists|does not have permission to access projects instance|PERMISSION_DENIED.*$PROJECT" "$_setup_out"; then
        warn "Project id '$PROJECT' is already taken globally (or you lack access to it)."
        warn "GCP project ids must be globally unique — 'omarchy-clock' is already registered."
        die "Try a unique id: ./scripts/setup.sh --project omarchy-clock-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' ' | head -c6)  or  PARM_CLOCK_PROJECT=my-unique-id ./scripts/setup.sh"
      fi
      warn "gws auth setup failed (see above). If you already have a client_secret.json or OAuth token, this is expected — continuing to auth check."
      if "$GWS_PATH" auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
        ok "already authenticated via OAuth2 — continuing."
        rm -f "$_setup_out"
        return 0
      fi
    fi
    rm -f "$_setup_out"
  fi

  info "Checking authentication state…"
  if $DRY_RUN; then
    echo "   would run: $GWS_PATH auth status"
  elif "$GWS_PATH" auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
    ok "already authenticated via OAuth2."
  else
    warn "Not authenticated — a browser window will open ONCE for Google consent."
    warn "Accept the consent. (If the app is in Testing mode, your account must"
    warn "be listed as an OAuth test user in the GCP console.)"
    run "$GWS_PATH" auth login --services calendar,tasks
    "$GWS_PATH" auth status 2>/dev/null | grep -q '"auth_method": "oauth2"' \
      || die "Authentication did not complete. Run 'gws auth login --services calendar,tasks' manually."
    ok "authenticated via OAuth2."
  fi
}

# ----------------------------------------------------------------- step 5: config

write_config() {
  if [[ -z "$TIMEZONE" ]]; then
    # Prefer system timezone; fall back to the plan default.
    if [[ -r /etc/timezone && -s /etc/timezone ]]; then
      TIMEZONE="$(cat /etc/timezone)"
    elif [[ -L /etc/localtime ]]; then
      TIMEZONE="$(readlink -f /etc/localtime | sed 's|^.*/zoneinfo/||')"
    else
      TIMEZONE="UTC"
    fi
  fi

  local gws_path
  gws_path="$GWS_PATH"
  [[ -x "$gws_path" && -f "$gws_path" ]] || die "gws path is not a regular executable: $gws_path"

  # Validate the zone name before it is baked into JSON: a weird /etc/timezone
  # (multiline, quotes) would otherwise write a config.json that load_config
  # silently ignores, quietly reverting the user to the auto-detected zone.
  if ! python3 -c 'import sys, zoneinfo; zoneinfo.ZoneInfo(sys.argv[1])' "$TIMEZONE" >/dev/null 2>&1; then
    die "timezone '$TIMEZONE' is not a valid IANA zone — pass --timezone <zone>"
  fi

  local gws_sha256
  gws_sha256="$(sha256sum -- "$gws_path" | cut -d' ' -f1)"
  if [[ -f "$CONFIG_FILE" ]] && python3 - "$CONFIG_FILE" "$gws_path" "$gws_sha256" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as stream:
        config = json.load(stream)
except (OSError, ValueError):
    raise SystemExit(1)
raise SystemExit(0 if isinstance(config, dict)
                 and config.get("gwsPath") == sys.argv[2]
                 and config.get("gwsSha256") == sys.argv[3] else 1)
PY
  then
    info "config.json already exists and its gws pin is current — leaving it in place."
    ok "config: $CONFIG_FILE"
    return
  fi

  info "Writing $CONFIG_FILE"
  if $DRY_RUN; then
    echo "   would write: $CONFIG_FILE"
    return
  fi
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  # umask 077 in the subshell -> config.json is created 0600 (it names the
  # user's calendars/tasklists); the chmod also tightens any older 0644 file.
  local tmp_config
  tmp_config="$(mktemp "$CONFIG_DIR/.config.json.XXXXXX")"
  if ! ( umask 077
    python3 - "$CONFIG_FILE" "$TIMEZONE" "$gws_path" "$gws_sha256" > "$tmp_config" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as stream:
        config = json.load(stream)
except (OSError, ValueError):
    config = {}
if not isinstance(config, dict):
    config = {}
config.update({"timezone": sys.argv[2], "gwsPath": sys.argv[3], "gwsSha256": sys.argv[4]})
config.setdefault("pastDays", 7)
config.setdefault("futureDays", 60)
config.setdefault("syncIntervalMin", 15)
config.setdefault("tasklistIds", [])
json.dump(config, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
  ); then
    rm -f -- "$tmp_config"
    die "could not write $CONFIG_FILE"
  fi
  chmod 600 "$tmp_config"
  mv -f -- "$tmp_config" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  ok "config written (timezone=$TIMEZONE, gws=$gws_path)"
}

# ----------------------------------------------------------------- step 6: first sync

first_sync() {
  info "Running the first sync…"
  if $DRY_RUN; then
    echo "   would run: python3 $SYNC_DIR/sync.py"
    return
  fi
  python3 "$SYNC_DIR/sync.py" && ok "first sync OK" \
    || warn "first sync exited non-zero (see above). Check 'gws auth status' and network."
}

# ----------------------------------------------------------------- step 7: systemd

install_systemd() {
  info "Installing systemd user units…"

  local python_bin
  python_bin="$(command -v python3)"
  local sync_path="$SYNC_DIR/sync.py"

  if [[ "$python_bin$sync_path" == *$'\n'* || "$python_bin$sync_path" == *%* ]]; then
    die "python or plugin path contains a newline or '%'; choose a simpler install path"
  fi

  systemd_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
  }

  # Render the units with this machine's absolute paths. The committed templates
  # carry placeholder-free text but hardcode the dev machine; we rewrite them so
  # setup is portable.
  local service_src="$SYSTEMD_USER_DIR/parm.clock-sync.service"
  local timer_src="$SYSTEMD_USER_DIR/parm.clock-sync.timer"

  if $DRY_RUN; then
    echo "   would install: $SYSTEMD_USER_DIR/parm.clock-sync.{service,timer}"
    echo "   would run: systemctl --user daemon-reload"
    echo "   would run: systemctl --user enable --now parm.clock-sync.timer"
    return
  fi

  mkdir -p "$SYSTEMD_USER_DIR"

  cat > "$service_src" <<EOF
[Unit]
Description=Sync Google Calendar and Tasks for parm.clock (gws)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
# A single gws call may take up to its 120s adapter timeout; a slow network can
# stack several, so the whole sync gets 10 minutes before systemd reaps it.
# (The state file stays last-good either way — writes are atomic.)
ExecStart=$(systemd_quote "$python_bin") $(systemd_quote "$sync_path")
TimeoutStartSec=600
Nice=10
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=%h/.local/state/parm.clock %h/.config/parm.clock %h/.config/gws
WorkingDirectory=/

[Install]
WantedBy=default.target
EOF

  cat > "$timer_src" <<EOF
[Unit]
Description=Sync Google Calendar and Tasks for parm.clock every 15 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  if command_exists systemd-analyze && ! systemd-analyze verify "$service_src" "$timer_src"; then
    die "generated systemd units failed validation"
  fi
  systemctl --user enable --now parm.clock-sync.timer
  ok "timer enabled and started (sync every 15 min)."
}

# ----------------------------------------------------------------- main

main() {
  ensure_deps
  ensure_auth
  write_config
  first_sync
  install_systemd
  echo
  ok "parm.clock setup complete. The clock in your bar should show events shortly."
  info "If the widget is not already in your bar, run:"
  echo "     omarchy plugin enable parm.clock center"
}

main "$@"
