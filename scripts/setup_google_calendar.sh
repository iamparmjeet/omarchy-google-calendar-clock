#!/usr/bin/env bash
# Write vdirsyncer + khal configs for Google Calendar sync using an app
# password, then perform an initial sync.
#
# Usage: setup_google_calendar.sh <email> <app-password>
#
# The app password may contain spaces (Google displays it in 4 groups of 4).
# It is stored in vdirsyncer's config with the spaces kept — CalDAV Basic
# auth sends it exactly as written.

set -euo pipefail

EMAIL="${1:-}"
APP_PASSWORD="${2:-}"

if [[ -z "$EMAIL" || -z "$APP_PASSWORD" ]]; then
  echo "usage: $0 <email> <app-password>" >&2
  exit 1
fi

CAL_DIR="$HOME/.local/share/calendars/google"
VDIRSYNCER_CONFIG="$HOME/.config/vdirsyncer/config"
KHAL_CONFIG="$HOME/.config/khal/config"

mkdir -p "$HOME/.config/vdirsyncer" "$HOME/.config/khal" "$CAL_DIR"

cat > "$VDIRSYNCER_CONFIG" <<EOF
[general]
status_path = "$HOME/.local/state/vdirsyncer/status/"

[pair google]
a = "google_remote"
b = "google_local"
collections = ["from a", "from b"]
conflict_resolution = "a wins"
metadata = ["color"]

[storage google_remote]
type = "caldav"
url = "https://apidata.googleusercontent.com/caldav/v2/$EMAIL/events"
username = "$EMAIL"
password = "$APP_PASSWORD"

[storage google_local]
type = "filesystem"
path = "$CAL_DIR"
fileext = ".ics"
EOF

cat > "$KHAL_CONFIG" <<EOF
[calendars]

  [[google]]
    path = $CAL_DIR/
    color = light blue

[locale]
    timeformat = %H:%M
    dateformat = %Y-%m-%d
    longdateformat = %Y-%m-%d
    datetimeformat = %Y-%m-%d %H:%M
    longdatetimeformat = %Y-%m-%d %H:%M
    local_timezone = Asia/Kolkata
    default_timezone = Asia/Kolkata

[default]
    default_calendar = google
    timedelta = 2d
EOF

chmod 600 "$VDIRSYNCER_CONFIG"

echo "Config written. Discovering collections..."
vdirsyncer discover google
echo "Running initial sync..."
vdirsyncer sync
echo "Initial sync complete. Verifying khal can read it..."
khal list today 7d || true
echo "Done."
