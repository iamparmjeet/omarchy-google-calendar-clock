# AGENT_LOG.md — what each agent changed, per phase

Append an entry here after every phase, before moving on.

---

## Phase 0 — Hard cut (khal/vdirsyncer → gws)

**Agent:** deepseek/deepseek-v4-pro (bootstrap session)
**Date:** 2026-08-20

**What changed:**

- Wrote `AGENTS.md` (hard engineering rules).
- Wrote `docs/PLAN.md`, `docs/TASKS.md`, `docs/PROMPTS.md`,
  `docs/DECISIONS.md`, `docs/ARCHITECTURE.md` (source of truth; the prior
  planning session was read-only and never wrote these to disk).
- Created `docs/AGENT_LOG.md` (this file).

**Hard cut (khal/vdirsyncer removal):**

- Disabled + stopped `vdirsyncer-sync.timer` and `vdirsyncer-sync.service`;
  removed both unit files from `~/.config/systemd/user/`.
- Deleted `~/.config/vdirsyncer/config` and `~/.config/khal/config` (and the
  now-empty dirs), plus `~/.local/share/calendars/` and
  `~/.local/state/vdirsyncer/` (the local CalDAV mirror + status).
- Deleted `scripts/fetch_events.py` and `scripts/setup_google_calendar.sh`.
- Discarded the uncommitted `Panel.qml` icon tweak (3 glyph changes) via
  `git checkout -- Panel.qml`, then re-stripped the khal/vdirsyncer event wiring
  from `Panel.qml` (removed the `Process`/`fetchScript` block, the `events`/
  `agenda`/`eventsError` state + `applyEvents`/`refreshEvents`/`eventsOn`/
  `monthAgenda`/`openNewEvent`/`openInteractive` functions, the grid event-dot
  Repeater, and the agenda/Sync/New/Calendar buttons), leaving a clean
  stock-clock clone with an "EVENTS / No events yet." placeholder. The event UI
  is re-wired in Phase 6 from `state.json`.
- Updated `manifest.json` description ("gws-powered", no khal/vdirsyncer).
- Rewrote `README.md` to describe the gws architecture (no khal/vdirsyncer).

**Acceptance gate:** PASSED — no `khal`/`vdirsyncer` references remain in
active plugin files (`*.qml/*.js/*.json/*.py/*.sh`); vdirsyncer timer gone from
`systemctl --user list-timers`; `qmllint` clean on both QML files;
`omarchy plugin validate` exit 0.

**Next:** Phase 1 — schema v1 + fixtures + validation tests.

---

## Phase 1 — Schema v1 + config + fixtures + validation tests

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `sync/schema.py` — v1 data contract, validation, and Google→internal
  normalization (timed/all-day/multi-day/cross-midnight/recurring/meet URL;
  task due/status/completed). All-day exclusive end collapsed to inclusive.
- `sync/config.py` — sync config (`timezone`, `pastDays`, `futureDays`,
  `gwsPath`, `syncIntervalMin`, `hiddenCalendars`, `tasklistIds`) with defaults,
  validation, atomic save.
- `sync/__init__.py`.
- `tests/fixtures/{events,tasks,state.golden}.json`.
- `tests/test_schema.py` — 25 tests: RFC3339/date parsing (naive rejected),
  UTC→Kolkata, all-day multi-day inclusive end, recurring flag, meet URL, and
  full state validation.

**Gate:** `python3 -m unittest discover -s tests` → 25/25 pass.

## Phase 2 — gws adapter

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `sync/gws_adapter.py` — wraps the verified gws CLI contract (invocation
  shape, exit codes 0/1/2/3/4/5, JSON error bodies on stdout+stderr). Typed
  helpers for calendarList/events/tasklists/tasks list + insert/patch/delete/
  quickAdd for events and tasks. Classifies `AuthError`/`ApiError`/`GwsError`/
  `GwsNotFound`. `auth_status()` for the two-word `gws auth status` subcommand.
- `tests/test_gws_adapter.py` — 9 tests against a fake gws asserting exact CLI
  shape and failure classification.

**Gate:** 34/34 tests pass (schema + adapter).

## Phase 3 — Sync engine

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `sync/sync.py` — full pipeline: config→gws path→auth check→calendarList→
  tasklists→window(past7/future60)→events(singleEvents, orderBy=startTime)→
  tasks→normalize→dedupe→sort→validate→atomic write. Exit 0/2/3/4/5; preserves
  last-good on failure; emits a valid error state when none exists. Runs both
  as `python3 sync/sync.py` (systemd) and as a package module.
- `tests/test_sync.py` — 8 tests: window bounds, dedupe/sort, full sync writes
  valid state, unauthenticated preserves last-good byte-for-byte, no-prior-state
  emits error state, invalid config, no stray tmp files.

**Gate:** 42/42 tests pass. `python3 sync/sync.py` classifies the current
`auth_method: none` as auth (exit 2) and emits a valid `auth` state.

## Phase 4 — systemd service + timer

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `systemd/parm.clock-sync.service` — Type=oneshot, absolute python3 path,
  TimeoutStartSec=120, Nice=10.
- `systemd/parm.clock-sync.timer` — OnBootSec=2min, OnUnitActiveSec=5min,
  Persistent=true.
- Installed both into `~/.config/systemd/user/`, `daemon-reload`, enabled+started
  the timer.

**Gate:** `systemctl --user list-timers` shows `parm.clock-sync.timer`; the
service runs cleanly (no tracebacks) and correctly reports the pending
`gws auth login` as exit 2 / auth state. First real sync will succeed once
setup.sh completes the one browser consent (Phase 10).

---

## Phase 5 — Model.js (calendar-state logic)

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `Model.js` — added provider-independent calendar-state functions:
  `eventIndex` (date-keyed, expands multi-day/all-day), `eventsForDate`
  (sorted, all-day first), `taskDueDate`, `tasksForDate`, `badgeCount`
  (dueToday|overdue|all), `nextEvent`, `countdown` ("in 18m"), `isStale`.
  All pure, locale/Qt-free, Node-testable.
- `sync/schema.py` — `normalize_task` now truncates `due` to a local
  `YYYY-MM-DD` date (Google's RFC3339 due has a meaningless time part).
- `tests/test_model.js` — 12 tests (grouping, badge modes, next-event,
  countdown, stale detection).
- `tests/test_schema.py` — tightened task-due assertion to the normalized date.

**Gate:** `node tests/test_model.js` → 12/12 pass; `python3 -m unittest
discover -s tests` → 42/42 pass; `qmllint` clean on both QML files.

**Next:** Phase 6 — QML (BarWidget badge + Panel compact/expanded + settings).

---

## Phase 6 — QML (badge + compact/expanded panel + settings)

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `Model.js` — added `parseState` (safe JSON->state, never throws),
  `calendarColor`, `syncStatusLabel` (human "Synced Nm ago").
- `BarWidget.qml` — reads `~/.local/state/parm.clock/state.json` via a
  `FileView` watcher; appends a `☑ N` badge (N = tasks due today) to the label
  when `showTaskBadge` is on and N > 0; badge count mode from `badgeCount`
  setting (dueToday|overdue|all).
- `Panel.qml` — full rebuild:
  - month grid with event/task dots (calendar-colored, capped at 4) and
    click-to-select day;
  - compact (hero + year/life rails + month grid + today agenda strip) and
    expanded (two-pane: grid | selected-day agenda + tasks) views via a toggle;
  - header buttons: Sync (runs sync.py), New event / New task (Phase 7 stubs),
    Settings, Expand/Compact;
  - settings view (Toggle + Dropdown + calendar-visibility toggles) persisting
    to shell.json (`showTaskBadge`, `badgeCount`, `defaultView`,
    `hiddenCalendars`);
  - sync status footer (`✓ Synced Nm ago` / `⚠ …`) from `syncStatus`.
- `tests/test_model.js` — +5 tests (parseState, calendarColor, syncStatusLabel).

**Gate:** `qmllint` clean on `Panel.qml` (rc 0) and on `BarWidget.qml` minus the
pre-existing `IpcHandler` block (the stock `omarchy.clock` BarWidget returns the
same qmllint rc 255 for that block — a known qmllint/Quickshell limitation, not
a regression); `omarchy plugin validate` exit 0; 17 JS + 42 Python tests pass.

**Next:** Phase 7 — CRUD wiring (create/edit/delete event & task via gws).
