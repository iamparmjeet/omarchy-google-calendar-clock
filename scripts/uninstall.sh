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
#   --purge-data         also delete ~/.local/state/parm.clock (cached state.json)
#   --purge-plugin       also run `omarchy plugin remove parm.clock`
#   --purge-config       also remove the parm.clock entry from shell.json
#   --purge-credentials  also delete local OAuth credentials (~/.config/gws,
#                        gcloud auth revoke). Requires re-auth on next setup.
#                        Online revoke still needs myaccount.google.com/permissions.
#   --purge-packages     also remove installed packages (google-cloud-cli via
#                        pacman, @googleworkspace/cli via npm). Needs sudo.
#   --purge-all          shorthand for --purge-data --purge-plugin --purge-config
#                        --purge-credentials --purge-packages (full reset)
#   --dry-run            print what would happen without doing it
#   --yes                auto-approve package/credential removal (skip [Y/n])
#
# Usage: ./uninstall.sh [--purge-data] [--purge-plugin] [--purge-config] [--purge-credentials] [--purge-packages] [--purge-all] [--dry-run] [--yes]

set -euo pipefail

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/parm.clock"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/parm.clock"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
GWS_DIR="$HOME/.config/gws"
GCLOUD_DIR="$HOME/.config/gcloud"

PURGE_DATA=false
PURGE_PLUGIN=false
PURGE_CONFIG=false
PURGE_CREDENTIALS=false
PURGE_PACKAGES=false
DRY_RUN=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-data) PURGE_DATA=true; shift ;;
    --purge-plugin) PURGE_PLUGIN=true; shift ;;
    --purge-config) PURGE_CONFIG=true; shift ;;
    --purge-credentials) PURGE_CREDENTIALS=true; shift ;;
    --purge-packages) PURGE_PACKAGES=true; shift ;;
    --purge-all) PURGE_DATA=true; PURGE_PLUGIN=true; PURGE_CONFIG=true; PURGE_CREDENTIALS=true; PURGE_PACKAGES=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) AUTO_YES=true; shift ;;
    -h | --help)
      sed -n '2,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

ask() {
  local prompt="$1"
  if $AUTO_YES || $DRY_RUN; then
    if $DRY_RUN; then echo "   would ask: $prompt [Y/n] -> Y (dry-run)"; fi
    return 0
  fi
  if [[ ! -t 0 ]]; then return 0; fi
  local ans
  read -r -p "$prompt [Y/n] " ans </dev/tty || return 0
  ans="${ans:-Y}"
  [[ "$ans" =~ ^[Yy] ]] || [[ "$ans" == "" ]]
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

  if $PURGE_CREDENTIALS; then
    info "Purging local OAuth credentials…"
    # gws credentials (googleworkspace/cli) — owns Calendar/Tasks OAuth
    if [[ -d "$GWS_DIR" ]]; then
      if ask "Delete $GWS_DIR (gws client_secret + token cache)?"; then
        # Try graceful logout first (revokes local token, keeps client_secret for reuse)
        if command -v gws >/dev/null 2>&1; then
          run gws auth logout 2>/dev/null || true
        fi
        run rm -rf "$GWS_DIR"
        ok "removed $GWS_DIR"
      else
        info "kept $GWS_DIR"
      fi
    else
      info "no gws credentials at $GWS_DIR"
    fi
    # gcloud credentials — optional, only if gcloud is present
    if [[ -d "$GCLOUD_DIR" ]]; then
      if ask "Also revoke gcloud auth (gcloud auth revoke --all) and delete $GCLOUD_DIR?"; then
        if command -v gcloud >/dev/null 2>&1; then
          run gcloud auth revoke --all 2>/dev/null || true
        fi
        # Keep GCLOUD_DIR by default; only delete if user confirms second prompt
        info "gcloud config kept at $GCLOUD_DIR (remove manually with rm -rf $GCLOUD_DIR if needed)"
      fi
    fi
    warn "Online revoke still required: https://myaccount.google.com/permissions → remove 'gws CLI' / 'omarchy-clock' to force fresh consent."
    warn "If OAuth client was in Testing mode, also remove test user at https://console.cloud.google.com/apis/credentials/consent"
  else
    info "credentials kept (re-run with --purge-credentials to delete ~/.config/gws)."
  fi

  if $PURGE_PACKAGES; then
    info "Purging installed packages (needs confirmation)…"
    # google-cloud-cli via pacman
    if pacman -Q google-cloud-cli 2>/dev/null >/dev/null; then
      if ask "Remove google-cloud-cli (~313 MiB) via pacman (needs sudo)?"; then
        run sudo pacman -Rns --noconfirm google-cloud-cli || warn "pacman remove failed"
        ok "removed google-cloud-cli"
      else
        info "kept google-cloud-cli"
      fi
    else
      info "google-cloud-cli not installed"
    fi
    # wrong gws (StreakyCobra) via pacman
    if pacman -Q gws 2>/dev/null | grep -q "Colorful KISS helper"; then
      if ask "Remove wrong pacman package 'gws' (StreakyCobra/git-workspace)?"; then
        run sudo pacman -Rns --noconfirm gws || true
        ok "removed pacman gws"
      fi
    fi
    # correct gws via npm
    if npm list -g @googleworkspace/cli 2>/dev/null | grep -q "@googleworkspace/cli"; then
      if ask "Remove correct gws via npm (npm uninstall -g @googleworkspace/cli)?"; then
        run npm uninstall -g @googleworkspace/cli || warn "npm uninstall failed"
        run hash -r 2>/dev/null || true
        ok "removed @googleworkspace/cli"
      else
        info "kept @googleworkspace/cli"
      fi
    else
      info "@googleworkspace/cli not installed via npm"
    fi
    # cargo install fallback
    if command -v gws >/dev/null 2>&1 && [[ -x "$HOME/.cargo/bin/gws" ]]; then
      if ask "Remove cargo-installed gws (~/.cargo/bin/gws)?"; then
        run rm -f "$HOME/.cargo/bin/gws" || true
        ok "removed ~/.cargo/bin/gws"
      fi
    fi
  else
    info "packages kept (re-run with --purge-packages to remove google-cloud-cli + gws)."
  fi

  echo
  ok "parm.clock uninstalled. Google data (events/tasks) was never touched."
  if $PURGE_CREDENTIALS || $PURGE_PACKAGES; then
    info "Fresh start: re-install deps then re-auth:"
    echo "     omarchy plugin add https://github.com/iamparmjeet/omarchy-google-calendar-clock.git --enable"
    echo "     ~/.config/omarchy/plugins/parm.clock/scripts/setup.sh --yes"
  fi
}

main "$@"
