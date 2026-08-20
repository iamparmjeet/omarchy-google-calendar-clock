#!/usr/bin/env bash
#
# Remove the parm.clock systemd sync units, and (optionally) its data and the
# plugin itself.
#
# By default this only stops + disables + removes the systemd user units and
# deletes the generated config. It does NOT touch your Google data (events and
# tasks live server-side) and does NOT remove the plugin from Omarchy, so a
# re-run of setup.sh brings everything back.
#
# Options:
#   --purge-data    also delete ~/.local/state/parm.clock (cached state.json)
#   --purge-plugin  also run `omarchy plugin remove parm.clock`
#   --purge-config  also remove the parm.clock entry from shell.json
#   --dry-run       print what would happen without doing it
#
# Usage: ./uninstall.sh [--purge-data] [--purge-plugin] [--purge-config] [--dry-run]

set -euo pipefail

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/parm.clock"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/parm.clock"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

PURGE_DATA=false
PURGE_PLUGIN=false
PURGE_CONFIG=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-data) PURGE_DATA=true; shift ;;
    --purge-plugin) PURGE_PLUGIN=true; shift ;;
    --purge-config) PURGE_CONFIG=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h | --help)
      sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

info() { printf '\033[36m::\033[0m %s\n' "$1"; }
ok() { printf '\033[32m ✓\033[0m %s\n' "$1"; }
warn() { printf '\033[33m !\033[0m %s\n' "$1" >&2; }

run() {
  if $DRY_RUN; then
    printf '   would run: %s\n' "$*"
  else
    "$@"
  fi
}

main() {
  info "Stopping and disabling the sync timer…"
  run systemctl --user disable --now parm.clock-sync.timer 2>/dev/null \
    || warn "parm.clock-sync.timer not active (already removed?)."
  run systemctl --user disable --now parm.clock-sync.service 2>/dev/null \
    || warn "parm.clock-sync.service not active."

  for unit in parm.clock-sync.service parm.clock-sync.timer; do
    if [[ -e "$SYSTEMD_USER_DIR/$unit" ]]; then
      run rm -f "$SYSTEMD_USER_DIR/$unit"
      ok "removed ~/.config/systemd/user/$unit"
    fi
  done
  run systemctl --user daemon-reload

  if [[ -d "$CONFIG_DIR" ]]; then
    run rm -rf "$CONFIG_DIR"
    ok "removed config (~/.config/parm.clock)"
  fi

  if $PURGE_DATA; then
    if [[ -d "$STATE_DIR" ]]; then
      run rm -rf "$STATE_DIR"
      ok "removed cached state (~/.local/state/parm.clock)"
    fi
  else
    info "cached state kept (re-run with --purge-data to remove it)."
  fi

  if $PURGE_PLUGIN; then
    info "Removing the parm.clock plugin from Omarchy…"
    run omarchy plugin remove parm.clock --yes
  fi

  if $PURGE_CONFIG && [[ -f "$SHELL_JSON" ]] && command -v jq >/dev/null 2>&1; then
    info "Removing the parm.clock entry from shell.json…"
    if $DRY_RUN; then
      echo "   would run: jq … (strip parm.clock from shell.json)"
    else
      local tmp
      tmp="$(mktemp "$SHELL_JSON.XXXXXX")"
      jq 'walk(if type == "object" and .id == "parm.clock" then empty else . end)
          | .bar.centerAnchor = (if .bar.centerAnchor == "parm.clock" then "" else .bar.centerAnchor end)' \
        "$SHELL_JSON" > "$tmp" 2>/dev/null \
        && jq -e . "$tmp" >/dev/null 2>&1 \
        && mv "$tmp" "$SHELL_JSON" \
        && ok "shell.json updated (backup: keep $tmp if mv failed)" \
        || { rm -f "$tmp"; warn "could not update shell.json; remove the parm.clock entry by hand."; }
    fi
  fi

  echo
  ok "parm.clock uninstalled. Google data (events/tasks) was never touched."
}

main "$@"
