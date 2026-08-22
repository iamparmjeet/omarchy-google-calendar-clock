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
# Usage: ./setup.sh [--project <gcp-project-id>] [--timezone <tz>] [--dry-run] [--yes]

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_DIR="$REPO/sync"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/parm.clock"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/parm.clock"
CONFIG_FILE="$CONFIG_DIR/config.json"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

PROJECT="${PARM_CLOCK_PROJECT:-omarchy-clock}"
TIMEZONE="${PARM_CLOCK_TIMEZONE:-}"
DRY_RUN=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?--project requires a value}"; shift 2 ;;
    --timezone) TIMEZONE="${2:?--timezone requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) AUTO_YES=true; shift ;;
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
  # Correct gws is googleworkspace/cli; wrong gws is StreakyCobra/git-workspace (pacman package).
  # Wrong binary prints "Not in a workspace" and help contains "Manage workspaces which contain git".
  if ! command_exists gws; then return 1; fi
  if gws --help 2>&1 | grep -q "Manage workspaces which contain git"; then return 1; fi
  if gws --help 2>&1 | grep -q "Not in a workspace"; then
    # Could be either, but correct gws never says "Not in a workspace" without args
    # so also check for auth subcommand
    if ! gws auth --help 2>&1 | grep -q "auth"; then return 1; fi
  fi
  # Correct gws has `gws auth status` and `gws calendar` subcommands
  if gws --help 2>&1 | grep -q "Google Workspace"; then return 0; fi
  if gws auth --help 2>&1 | grep -q "calendar\|tasks"; then return 0; fi
  # Fallback: check version string contains google-workspace or gws
  if gws --version 2>&1 | grep -qi "google"; then return 0; fi
  # If we have a binary but can't tell, assume wrong if --help lacks "auth setup"
  if gws --help 2>&1 | grep -q "auth setup"; then return 0; fi
  # Last resort: try `gws auth status` help
  if gws auth status --help 2>&1 | grep -q "auth"; then return 0; fi
  return 1
}

ask() {
  local prompt="$1"
  if $AUTO_YES || $DRY_RUN; then
    # In --dry-run we show what would be asked but don't block
    if $DRY_RUN; then echo "   would ask: $prompt [Y/n] -> Y (dry-run)"; fi
    return 0
  fi
  # Only prompt if stdin is a tty; otherwise auto-yes
  if [[ ! -t 0 ]]; then return 0; fi
  local ans
  read -r -p "$prompt [Y/n] " ans </dev/tty || return 0
  ans="${ans:-Y}"
  [[ "$ans" =~ ^[Yy] ]] || [[ "$ans" == "" ]]
}

install_correct_gws() {
  info "Installing correct gws (googleworkspace/cli)…"
  info "  This is NOT the pacman package 'gws' (git-workspace helper)."
  info "  Source: https://github.com/googleworkspace/cli"
  if $DRY_RUN; then
    echo "   would run: npm install -g @googleworkspace/cli@0.22.5  (or pinned cargo fallback)"
    return 0
  fi
  # Remove wrong pacman gws if present
  if pacman -Q gws 2>/dev/null | grep -q "Colorful KISS helper"; then
    warn "Removing wrong pacman package 'gws' (StreakingCobra/git-workspace)…"
    sudo pacman -Rns --noconfirm gws 2>/dev/null || true
    hash -r 2>/dev/null || true
  fi
  # Try npm first (preferred, prebuilt Rust binaries). Pinned to v0.22.5 so the
  # marketplace reviews the exact bytes that run, matching the cargo fallback.
  if command_exists npm; then
    info "Trying: npm install -g @googleworkspace/cli@0.22.5"
    if npm install -g @googleworkspace/cli@0.22.5; then
      hash -r 2>/dev/null || true
      if is_correct_gws; then ok "gws installed via npm."; return 0; fi
      warn "npm install succeeded but gws still not correct — trying fallback."
    else
      warn "npm install failed (check network/npm PATH) — trying fallback."
    fi
  else
    warn "npm not found — trying cargo."
  fi
  # Try cargo (pinned to v0.22.5 for reproducible marketplace review)
  if command_exists cargo; then
    info "Trying: cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked  (v0.22.5)"
    if cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked; then
      hash -r 2>/dev/null || true
      if is_correct_gws; then ok "gws installed via cargo."; return 0; fi
    fi
  fi
  die "gws install failed. Install manually: npm install -g @googleworkspace/cli@0.22.5  OR  cargo install --git https://github.com/googleworkspace/cli --rev 705fb0ecac6f4249679958f6325b809b63fdde17 --locked  OR  download from https://github.com/googleworkspace/cli/releases/tag/v0.22.5  and ensure 'gws auth --help' works, then re-run."
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
        info "Installing google-cloud-cli via yay…"
        yay -S --needed --noconfirm google-cloud-cli || \
          die "gcloud install via yay failed; try: yay -S google-cloud-cli  or  https://cloud.google.com/sdk/docs/install"
        ok "gcloud installed via yay."
      elif command_exists pacman && pacman -Si google-cloud-cli >/dev/null 2>&1; then
        info "Installing google-cloud-cli via pacman…"
        sudo pacman -S --needed --noconfirm google-cloud-cli || \
          die "gcloud install failed; install it manually (https://cloud.google.com/sdk/docs/install) and re-run."
        ok "gcloud installed via pacman."
      elif command_exists pacman; then
        # AUR but yay not installed — try pacman anyway, else instruct yay
        warn "google-cloud-cli is AUR — yay is recommended (pacman alone won't find it)."
        info "Trying pacman (will fail if not in extra, then try manual)…"
        if sudo pacman -S --needed --noconfirm google-cloud-cli 2>/dev/null; then
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
  elif ! is_correct_gws; then
    warn "Found wrong 'gws' binary at $(command -v gws) — this is the git-workspace helper (StreakyCobra/gws), not Google Workspace CLI."
    warn "  Wrong binary help: $(gws --help 2>&1 | head -1)"
    warn "  Correct binary should support: gws auth setup, gws auth login, gws calendar calendarList list"
    if ask "Replace it with the correct googleworkspace/cli binary?"; then
      install_correct_gws
    else
      die "Wrong gws binary in PATH. Remove it (sudo pacman -R gws) and install correct one: npm install -g @googleworkspace/cli"
    fi
  fi

  command_exists python3 || die "python3 is required but not found."
  ok "gcloud $(gcloud --version 2>/dev/null | head -1 | awk '{print $NF}' || echo 'unknown')"
  # Show which gws we have
  if is_correct_gws; then
    ok "gws $(gws --version 2>&1 | head -1) [googleworkspace/cli] at $(command -v gws)"
  else
    warn "gws at $(command -v gws) does not look like googleworkspace/cli — will fail at auth. Re-run setup.sh --yes to fix."
  fi
}

# ----------------------------------------------------------------- step 2-4: auth

ensure_auth() {
  # If already authenticated, skip `gws auth setup` — it requires manual OAuth client
  # creation and fails (400) when the project already has a client or when the
  # user has a valid token. The setup step is only needed on first run.
  if ! $DRY_RUN && gws auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
    ok "already authenticated via OAuth2 — skipping gws auth setup."
    return 0
  fi

  info "Configuring the GCP project + OAuth client (gws auth setup)…"
  if $DRY_RUN; then
    echo "   would run: gws auth setup --project $PROJECT"
  else
    # Don't die on setup failure — it may require manual console steps but auth may already be ok.
    if ! gws auth setup --project "$PROJECT"; then
      warn "gws auth setup failed (see above). If you already have a client_secret.json or OAuth token, this is expected — continuing to auth check."
      if gws auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
        ok "already authenticated via OAuth2 — continuing."
        return 0
      fi
    fi
  fi

  info "Checking authentication state…"
  if $DRY_RUN; then
    echo "   would run: gws auth status"
  elif gws auth status 2>/dev/null | grep -q '"auth_method": "oauth2"'; then
    ok "already authenticated via OAuth2."
  else
    warn "Not authenticated — a browser window will open ONCE for Google consent."
    warn "Accept the consent. (If the app is in Testing mode, your account must"
    warn "be listed as an OAuth test user in the GCP console.)"
    run gws auth login --services calendar,tasks
    gws auth status 2>/dev/null | grep -q '"auth_method": "oauth2"' \
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

  if [[ -f "$CONFIG_FILE" ]]; then
    info "config.json already exists — leaving it in place."
    ok "config: $CONFIG_FILE"
    return
  fi

  local gws_path
  gws_path="$(command -v gws)"

  info "Writing $CONFIG_FILE"
  if $DRY_RUN; then
    echo "   would write: $CONFIG_FILE"
    return
  fi
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  # umask 077 in the subshell -> config.json is created 0600 (it names the
  # user's calendars/tasklists); the chmod also tightens any older 0644 file.
  ( umask 077
    cat > "$CONFIG_FILE" <<EOF
{
  "timezone": "$TIMEZONE",
  "pastDays": 7,
  "futureDays": 60,
  "gwsPath": "$gws_path",
  "syncIntervalMin": 5,
  "tasklistIds": []
}
EOF
  )
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
ExecStart=$python_bin $SYNC_DIR/sync.py
TimeoutStartSec=120
Nice=10

[Install]
WantedBy=default.target
EOF

  cat > "$timer_src" <<EOF
[Unit]
Description=Sync Google Calendar and Tasks for parm.clock every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now parm.clock-sync.timer
  ok "timer enabled and started (sync every 5 min)."
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
