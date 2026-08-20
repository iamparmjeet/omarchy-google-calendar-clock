#!/usr/bin/env bash
#
# Set up the parm.clock Google Calendar/Tasks plugin.
#
# Does, in order (see docs/PLAN.md §7):
#   1. verify gcloud + gws are installed (install on Arch via pacman/AUR if not)
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
# Usage: ./setup.sh [--project <gcp-project-id>] [--timezone <tz>] [--dry-run]

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:?--project requires a value}"; shift 2 ;;
    --timezone) TIMEZONE="${2:?--timezone requires a value}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
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

# ----------------------------------------------------------------- step 1: deps

ensure_deps() {
  info "Checking dependencies (gcloud, gws, python3)…"

  if ! command_exists gcloud; then
    if command_exists pacman; then
      info "gcloud not found — installing google-cloud-cli (needs sudo)…"
      $DRY_RUN || sudo pacman -S --needed --noconfirm google-cloud-cli || \
        die "gcloud install failed; install it manually and re-run."
    else
      die "gcloud not found. Install the Google Cloud SDK and re-run."
    fi
  fi

  if ! command_exists gws; then
    if command_exists pacman; then
      info "gws not found — attempting to install it…"
      if $DRY_RUN; then
        echo "   would run: sudo pacman -S --needed --noconfirm gws"
      elif sudo pacman -S --needed --noconfirm gws 2>/dev/null; then
        ok "gws installed."
      else
        die "gws install failed. Install it manually (https://github.com/StreakingJellyfish/gws — or your AUR helper's 'gws' package) and re-run."
      fi
    else
      die "gws not found. Install it from https://github.com/StreakingJellyfish/gws and re-run."
    fi
  fi

  command_exists python3 || die "python3 is required but not found."
  ok "gcloud $(command_exists gcloud && gcloud --version 2>/dev/null | head -1 | awk '{print $NF}')"
  ok "gws $(gws --version 2>/dev/null | head -1)"
}

# ----------------------------------------------------------------- step 2-4: auth

ensure_auth() {
  info "Configuring the GCP project + OAuth client (gws auth setup)…"
  run gws auth setup --project "$PROJECT"

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
      TIMEZONE="Asia/Kolkata"
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
  cat > "$CONFIG_FILE" <<EOF
{
  "timezone": "$TIMEZONE",
  "pastDays": 7,
  "futureDays": 60,
  "gwsPath": "$gws_path",
  "syncIntervalMin": 5,
  "hiddenCalendars": [],
  "tasklistIds": []
}
EOF
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
