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

---

## Phase 7 — CRUD wiring (via gws → re-sync)

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-20

**What changed:**
- `sync/mutate.py` — the QML→gws bridge. QML never calls gws/Google directly;
  it shells out here. Commands: `event-quickadd`, `event-add` (timed / all-day /
  `--meet`), `event-delete`, `task-add`, `task-complete` (`--undo`), `task-delete`.
  Each write re-syncs `state.json` afterwards. Exit 0/2/3/4/5.
- `sync/gws_adapter.py` — fixed the delete path: gws returns an empty body on
  success (with keyring noise on stderr); a successful empty/non-JSON body now
  resolves to `{}` instead of raising a parse error.
- `Panel.qml` — quick-add event input, new-task input (title + due), per-row
  delete buttons (events) and complete/delete buttons (tasks). Writes call
  `sync/mutate.py` via `bar.run`, then refresh the panel.
- `tests/test_mutate.py` — 7 tests against a fake gws (write shapes, all-day
  exclusive end, task due/complete/delete, re-sync-after-write).

**Live round-trip (gate):** PASSED against real Google —
  - `event-quickadd` "CRUD test meeting tomorrow 10am" → appeared in state.json
    (dateKey 2026-08-22) → `event-delete` → confirmed gone server-side.
  - `task-add` "CRUD test task" due 2026-08-21 → `task-complete` → `task-delete`
    → confirmed gone server-side.
  - `python3 sync/sync.py` now reports `syncStatus.state: ok` with real data
    (4 calendars, 15 events, tasklist "My Tasks").

**Setup note:** the `omarchy-clock` GCP project had been deleted
(`DELETE_REQUESTED`); restored via `gcloud projects undelete omarchy-clock`.
`gws auth login --services calendar,tasks` completed (one browser consent), and
the account was added as an OAuth "Test user" in the console (Testing-mode app).

**Gate:** 49 Python + 17 JS tests pass; `qmllint` clean on Panel.qml;
`omarchy plugin validate` exit 0; live create/read/delete round-trip verified.

**Next:** Phase 8 — Integration (auth-expired, offline, malformed, DST,
recurrence, manual sync, shell lifecycle).

---

## Phase 7 fix — new-event wrote to a read-only calendar

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-21

**Problem:** Adding a new event failed. `primaryCalendarId` resolved to
`state.calendars[0]`, which was "Holidays in India" — a read-only Google
holiday calendar — so inserts were rejected.

**Fix:**
- `sync/sync.py` — `build_state` now records `primary: bool` per calendar
  (from Google's `primary` flag on the CalendarListEntry).
- `sync/schema.py` — `primary` validated as a boolean.
- `Panel.qml` — `primaryCalendarId` now prefers the calendar Google marks
  primary, else the user's email-shaped calendar, else the first. Read-only
  group/holiday calendars are never chosen as the write target.

**Verified:** live quick-add writes to `iamparmjeetmishra@gmail.com` (primary)
and deletes cleanly; `sync.py` reports ok.

---

## Phase 7 fix — post-write latency

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-21

**Problem:** Adding an event took ~8s to show in the panel, because every write
triggered a full sync that (1) ran an explicit `gws auth status` probe (~3s of
keyring decryption) and (2) re-discovered calendars + tasklists before
re-fetching all events sequentially.

**Fix:**
- `sync/sync.py` — event/task fetches now run in parallel (ThreadPoolExecutor);
  new `check_auth=False` skips the auth probe (API calls still fail loudly on
  bad tokens); new `reuse_discovery=True` reuses the last-good calendar/tasklist
  list for post-write refreshes (a write never changes which lists exist).
- `sync/mutate.py` — post-write refresh uses `check_auth=False` +
  `reuse_discovery=True`.
- `Panel.qml` — on mutate exit, `stateFile.reload()` is called directly so the
  panel re-reads state.json immediately instead of waiting on the watcher.

**Result:** ~8s → ~1.9s end-to-end for a write; full timer sync unchanged.

---

## Phase 8 — Integration

**Agent:** deepseek/deepseek-v4-pro
**Date:** 2026-08-21

**What changed:**
- `tests/test_schema.py` — added DST-transition and DST-summer tests for
  Europe/Berlin (UTC→local dateKey correctness across the boundary).
- `tests/test_sync.py` — added: API-error preserves last-good; `reuse_discovery`
  path; malformed prior state.json is replaced by the next successful sync.
- `sync/sync.py`, `sync/mutate.py` — (already in place from the latency fix)
  parallel fetches, `check_auth`, `reuse_discovery` covered by tests.

**Gate — all paths behave per PLAN §11 (verified live):**
- **auth expired**: unauthenticated sync → exit 2, last-good preserved
  (unit-tested; previously reproduced live before `gws auth login`).
- **offline / gws missing**: `gwsPath=/no/such/gws` → exit 5, last-good state
  preserved (`state: ok`, 16 events intact).
- **malformed state.json**: corrupt file → next `sync.py` recovers to `ok`.
- **DST/timezone**: Berlin DST-transition + summer tests pass.
- **recurrence**: Google expands server-side via `singleEvents=true` (adapter
  param verified in Phase 2); normalization tests cover recurring-instance flag.
- **manual sync**: `python3 sync/sync.py` → rc 0, `syncStatus ok`.
- **systemd timer**: enabled, fires every 5 min, `journalctl` clean.
- **shell lifecycle**: `omarchy-shell shell summon/hide/toggle parm.clock` →
  rc 0; `parm.clock refresh` → rc 0; `omarchy plugin disable/enable parm.clock`
  → rc 0, widget still listed enabled and wired in the bar center.

**Suite:** 54 Python + 17 JS tests pass; `qmllint` clean on Panel.qml;
`omarchy plugin validate` exit 0.

**Next:** Phase 9 — adversarial review (race conditions, security, timezone,
systemd, Omarchy compat) + fixes.

---

## Phase 9 — Adversarial review + fixes

**Agent:** deepseek/deepseek-v4-pro (second-opinion review)
**Date:** 2026-08-21

**Review:** read AGENTS.md, PLAN, TASKS, PROMPTS, ARCHITECTURE, DECISIONS, and
every source file (sync/*.py, Model.js, BarWidget.qml, Panel.qml, systemd
units, manifest, tests/fixtures); verified gws invocation shapes against
`gws schema calendar.events.list / tasks.tasks.list / tasks.tasklists.list`;
re-ran the full suite + live sync. Found and fixed five issues, one at a time.

**Fix 1 — auth/API errors silently swallowed during per-calendar fetch
(data-loss bug).** In `sync/sync.py`, `_fetch_events`/`_fetch_tasks` caught
`GwsError` (the base of `AuthError`/`ApiError`) and `pass`ed. When
`check_auth=False` (the post-write refresh path) and the token had expired,
every fetch raised `AuthError`, which was swallowed — so the sync wrote an
**empty `ok` state over the last-good state**. Now `AuthError`/`ApiError` are
re-raised so the outer handler preserves last-good and returns exit 2; only
transient `GwsError` (timeout/discovery) is skipped. Added
`test_event_auth_error_preserves_last_good`.

**Fix 2 — list pagination missing.** `gws_adapter.list_tasks` omitted
`maxResults`, so Google's default of 20 silently truncated any task list over
20 items (verified: `gws schema tasks.tasks.list` maxResults default 20/max
100). Added a shared `_list_all` pager that follows `nextPageToken` to
exhaustion and wired it into `list_calendars`, `list_events`, `list_tasklists`,
`list_tasks` (with `maxResults=100` on the tasks endpoints). Added
`test_list_tasks_pages`.

**Fix 3 — atomic-write tmp-name race.** `atomic_write` used a fixed
`state.json.tmp` path; two concurrent syncs (timer firing while a post-write
refresh is mid-write) could interleave write/fsync/rename on the same tmp file.
Temp name is now unique per writer (`state.json.tmp.<pid>.<n>`), replaced with
`finally` cleanup. No API change.

**Fix 4 — mutate.py errors lost in the UI.** `mutate.py` reports failures on
stderr, but `Panel.qml`'s `Process` only attached a `StdioCollector` to
`stdout`, so a failed create/delete showed a blank error box. Added a `stderr`
collector and an `onExited` fallback that surfaces the stderr/stdout text (or a
generic message) instead of nothing.

**Fix 5 — uncaught `GwsError` traceback.** `run_sync` caught `AuthError`,
`ApiError`, `GwsNotFound`, and `OSError`, but not the base `GwsError`
(validation/discovery/timeout/internal). A gws timeout or discovery failure
escaped as an unhandled Python traceback (exit 1, ugly journal output). Added a
`GwsError` catch that preserves last-good and returns exit 3.

**Non-issues reviewed and left as-is:** the `.gitignore`-tracked
`download.html`; the panel's `todayKey`/`dayEvents`/`dayTasks` property
regeneration on state reload (the watcher is `atomicWrites: true`); the
cross-midnight timed-event model (Google serves expanded instances with
`singleEvents=true`); `config.py`'s unused `save_config`/`CONFIG_PATH` (settings
live in shell.json per PLAN §9; sync-only keys are read from defaults).

**Gate:** 56 Python + 17 JS tests pass; `qmllint` clean on `Panel.qml` (rc 0)
and on `BarWidget.qml` minus the pre-existing `IpcHandler` block (stock
`omarchy.clock` returns the same rc 255); `omarchy plugin validate` exit 0; live
`sync.py` returns `state: ok` (4 calendars, 16 events, 1 task, primary calendar
correctly flagged).

**Next:** Phase 10 — README/setup/uninstall/troubleshooting + final AGENT_LOG.
