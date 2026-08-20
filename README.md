# Google Calendar Clock

An [Omarchy](https://omarchy.org/) bar widget: a clock whose calendar popup
shows **your Google Calendar events and Google Tasks** — dots on the month
grid, an agenda list, a task badge on the bar, and full create/edit/delete for
events and tasks.

It is a clone of the built-in `omarchy.clock` (the same date/time label,
calendar popup, month stepping, week-start toggle, and memento-mori bar), with
Google Calendar + Tasks layered on top.

## How it works

No khal, no vdirsyncer, no CalDAV. The plugin is powered by
[`gws`](https://github.com/StreakingJellyfish/gws) (Google Workspace CLI), which
owns OAuth and exposes Calendar + Tasks CRUD over JSON.

```
Google (Calendar + Tasks)  ← OAuth (gws owns tokens)
        │
        ▼
     gws CLI
        │ JSON
        ▼
  sync/sync.py  (Python sync engine — normalize/timezone/recurrence/atomic write)
        │
        ▼
  ~/.local/state/parm.clock/state.json   ← single source of truth
        │
        ▼
  Model.js + BarWidget.qml + Panel.qml   (QML reads state.json only)
```

The QML never talks to Google. It reads a cached JSON state file; writes go
through gws and trigger a re-sync. A systemd user timer runs the sync every few
minutes, so the widget stays up to date and works offline from cached data.

## Requirements

- Omarchy 4 (Quickshell shell)
- `gcloud` (Google Cloud SDK) and `gws` on `PATH`
- `python3` with the `zoneinfo`/`tzdata` module (Python 3.9+)
- A GCP project for the OAuth client (the setup script creates/uses one)

## Install

```bash
omarchy plugin add https://github.com/iamparmjeet/omarchy-google-calendar-clock.git --enable
```

This replaces the stock `omarchy.clock` in your bar (the manifest carries
`clonedFrom: omarchy.clock`). To put it back in the bar center if needed:

```bash
omarchy plugin enable parm.clock center
```

## Set up Google (once)

```bash
~/.config/omarchy/plugins/parm.clock/scripts/setup.sh
```

The script, in order:

1. verifies `gcloud` + `gws` are installed (installs via pacman on Arch if not);
2. runs `gws auth setup --project omarchy-clock` (enables the Calendar + Tasks
   APIs and ensures an OAuth client);
3. runs `gws auth login --services calendar,tasks` — **this is the one manual
   step**: a browser opens for a single Google consent screen;
4. verifies authentication, then writes `~/.config/parm.clock/config.json`
   (timezone, sync window, gws path);
5. runs the first sync;
6. installs and enables the systemd user timer (syncs every 5 minutes).

Options:

```bash
setup.sh --project my-gcp-project --timezone America/New_York
setup.sh --dry-run      # print what it would do
```

**Testing-mode app note:** if your OAuth client is in "Testing" mode in the GCP
console, add your account as a test user (APIs & Services → OAuth consent
screen → Test users), otherwise the browser consent will be rejected.

## What you get

- **Task badge** — `☑ N` next to the clock, counting tasks due today (toggleable
  in settings).
- **Dots** on the month grid for every day that has events or tasks.
- **Compact ⇄ expanded** popup — compact month grid by default; expand to a
  two-pane view (month grid | selected-day agenda + tasks).
- **Full CRUD** — create/edit/delete events, add/complete/delete tasks, all via
  gws.
- Everything the stock clock did: label format cycling (right-click), calendar
  popup, timezone picker (middle-click), month stepping, ISO week numbers,
  week-start toggle, and the year/life progress bars.

## Settings

The widget keeps the stock clock's `format`, `formatAlt`, `weekStartDay`,
`birthYear`, and `lifeExpectancy` keys, plus new keys — all stored on the
`parm.clock` entry in `~/.config/omarchy/shell.json`:

- `showTaskBadge` (bool, default `true`) — show the `☑ N` badge.
- `badgeCount` (`dueToday` | `overdue` | `all`, default `dueToday`).
- `defaultView` (`compact` | `expanded`, default `compact`).
- `hiddenCalendars` (array of calendar ids) — hide a calendar's dots.
- `weekStartDay` — first day of the week (stock key).

Sync-only keys live in `~/.config/parm.clock/config.json` and are written by the
setup script:

- `timezone` (e.g. `Asia/Kolkata`)
- `pastDays` / `futureDays` — sync window (default 7 / 60)
- `gwsPath` — absolute path to the gws binary
- `syncIntervalMin` — informational; the timer interval is fixed in the unit
- `hiddenCalendars` / `tasklistIds` — optional filters

## Uninstall

Remove the systemd units, config, and cached state (keeps your Google data and
the plugin itself):

```bash
~/.config/omarchy/plugins/parm.clock/scripts/uninstall.sh
```

Options:

```bash
uninstall.sh --purge-data      # also delete ~/.local/state/parm.clock
uninstall.sh --purge-plugin    # also `omarchy plugin remove parm.clock`
uninstall.sh --purge-config    # also remove the parm.clock entry from shell.json
uninstall.sh --dry-run
```

Or remove just the plugin with the shell:

```bash
omarchy plugin remove parm.clock
```

Your events and tasks always live server-side on Google — uninstalling never
deletes them.

## Troubleshooting

**The clock shows but the panel is empty / "Auth needed".**

Run the sync by hand and read the message:

```bash
python3 ~/.config/omarchy/plugins/parm.clock/sync/sync.py
```

- `gws not installed` → install gws and re-run `scripts/setup.sh`.
- `not authenticated` → `gws auth login --services calendar,tasks`.
- `sync failed (error): …` → check `gws auth status` and network.

**New events go to the wrong calendar.** The panel writes to the calendar Google
marks `primary` (never a read-only holiday calendar). Verify with
`gws calendar calendarList list --params '{}'`.

**Badge shows a stale count.** The timer syncs every 5 minutes; force one with
`systemctl --user start parm.clock-sync.service`, or click the sync button in
the panel header. Check the timer is active:

```bash
systemctl --user list-timers parm.clock-sync.timer
```

**Manual sync from a terminal works but the timer doesn't.** The service uses
absolute paths resolved by `scripts/setup.sh`. Re-run `scripts/setup.sh` (safe)
to regenerate them for this machine, then:

```bash
systemctl --user status parm.clock-sync.service
journalctl --user -u parm.clock-sync.service -n 30
```

**OAuth consent is rejected.** Your GCP OAuth client is in Testing mode and your
account is not a test user. Add it under GCP → APIs & Services → OAuth consent
screen → Test users.

**gws write fails with a keyring/dbus error.** gws stores tokens in the system
keyring; ensure a keyring daemon is running in your session (e.g. gnome-keyring)
before the first `gws auth login`.

## Running the tests

```bash
python3 -m unittest discover -s tests   # sync engine, schema, adapter, mutate
node tests/test_model.js                # QML model logic
```

## License

MIT — see `LICENSE`. `BarWidget.qml`, `Panel.qml`, and `Model.js` derive from
the stock `omarchy.clock` plugin (Omarchy, MIT).
