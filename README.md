# Google Calendar Clock

An [Omarchy](https://omarchy.org/) bar widget: a clock whose calendar popup
shows **your Google Calendar events** as dots on the month grid plus an agenda
list, and can create/edit them — without any OAuth dance.

It is a clone of the built-in `omarchy.clock` (the same date/time label,
calendar popup, month stepping, week-start toggle, and memento-mori bar), with
Google Calendar layered on top.

## How it works

No Google Cloud project, no OAuth consent screen, no token files. It rides on
two well-known CalDAV tools:

- **`vdirsyncer`** — syncs your Google Calendar to local `.ics` files using a
  Google **App Password** (Basic auth over CalDAV).
- **`khal`** — a command-line calendar that reads those files and edits them
  (write-back is synced to Google by vdirsyncer).

The widget shell's out to a bundled helper (`scripts/fetch_events.py`) that
reads the khal database and emits one JSON line per event. The panel renders
dots and an agenda from that, and its buttons drop into `khal` / `ikhal` to
create or edit events.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-google-calendar-clock --enable
```

This replaces the stock `omarchy.clock` (the manifest carries
`clonedFrom: omarchy.clock`). Remove it to get the plain clock back:

```bash
omarchy plugin remove parm.clock
```

## Set up Google Calendar sync (once)

You need `khal` and `vdirsyncer` installed (Arch: `sudo pacman -S khal vdirsyncer`).

1. **Create a Google App Password** (Google requires 2-Step Verification first):
   - https://myaccount.google.com/security → turn on **2-Step Verification**
   - https://myaccount.google.com/apppasswords → **Create** (name it `omarchy`),
     copy the 16-character password.

2. Run the bundled setup, passing your Gmail address and the app password
   (spaces are fine):

   ```bash
   ~/.config/omarchy/plugins/parm.clock/scripts/setup_google_calendar.sh you@gmail.com "abcd efgh ijkl mnop"
   ```

   This writes `~/.config/vdirsyncer/config` and `~/.config/khal/config`,
   discovers collections, and runs the first sync.

3. (Optional) Auto-sync every 15 minutes:

   ```bash
   systemctl --user enable --now vdirsyncer-sync.timer
   ```

   A `vdirsyncer-sync.service` / `.timer` pair is included in the repo; copy
   them to `~/.config/systemd/user/` and put the `vdirsyncer-sync` script on
   your `PATH`.

## What you get

- **Dots** on the month grid for every day that has events (multi-day events
  dot each day they span).
- **Agenda** under the grid listing the viewed month's events (time, or "all
  day", then title).
- **Buttons**: Sync (runs `vdirsyncer sync`), New (opens `khal new` in a
  terminal), Calendar (opens `ikhal`).
- Everything the stock clock did: label format cycling (right-click), calendar
  popup, timezone picker (middle-click), month stepping, ISO week numbers,
  week-start toggle, and the year/life progress bars.

## Settings

The widget keeps the stock clock's `format`, `formatAlt`, `weekStartDay`,
`birthYear`, and `lifeExpectancy` keys in `~/.config/omarchy/shell.json`
(see the stock clock docs). No new settings are required.

## Dependencies

- Omarchy 4 (Quickshell shell)
- `khal` and `vdirsyncer` on `PATH` (for the popup's event view and buttons)
- A Google App Password for write access

## License

MIT. `BarWidget.qml`, `Panel.qml`, and `Model.js` derive from the stock
`omarchy.clock` plugin (Omarchy, MIT).
