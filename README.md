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

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-google-calendar-clock --enable
```

This replaces the stock `omarchy.clock` (the manifest carries
`clonedFrom: omarchy.clock`). Remove it to get the plain clock back:

```bash
omarchy plugin remove parm.clock
```

## Set up Google (once)

Requirements: `gws` and `gcloud` on your `PATH` (a GCP project + OAuth client
are configured by the setup script).

```bash
~/.config/omarchy/plugins/parm.clock/scripts/setup.sh
```

This enables the Calendar + Tasks APIs, opens a **single browser consent** for
OAuth (the only manual step), runs the first sync, and installs + enables the
systemd sync timer.

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
`birthYear`, and `lifeExpectancy` keys in `~/.config/omarchy/shell.json`, plus
new keys: `showTaskBadge`, `badgeCount`, `defaultView`, `hiddenCalendars`,
`pastDays`, `futureDays`, `syncIntervalMin`.

## Dependencies

- Omarchy 4 (Quickshell shell)
- `gws` and `gcloud` on `PATH`

## License

MIT. `BarWidget.qml`, `Panel.qml`, and `Model.js` derive from the stock
`omarchy.clock` plugin (Omarchy, MIT).
