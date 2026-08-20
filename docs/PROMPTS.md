# PROMPTS.md — copy-paste per-phase prompts

For each phase, paste the matching prompt into the builder chat. After a phase
passes its gate, advance with:

```
Phase N passed its gate. Continue to Phase N+1 per docs/PROMPTS.md. Stop at its
gate and append what you changed to docs/AGENT_LOG.md.
```

## Phase 0 — Hard cut

Context: the plugin currently uses khal + vdirsyncer. We are moving to gws.
Read `AGENTS.md` and `docs/PLAN.md` first. Implement ONLY the hard cut:

- `systemctl --user disable --now vdirsyncer-sync.timer` and `.service`;
  remove both unit files from `~/.config/systemd/user/`.
- Delete `~/.config/vdirsyncer/config`, `~/.config/khal/config`,
  `~/.local/share/calendars/google`.
- Remove `scripts/fetch_events.py` and `scripts/setup_google_calendar.sh`.
- Discard the uncommitted `Panel.qml` icon tweak.
- Update `README.md` so it no longer references khal/vdirsyncer; describe the
  gws architecture briefly.

Stop conditions: do not create sync/, QML, or any new feature files yet.
Acceptance: `grep -ri 'khal\|vdirsyncer'` finds nothing outside docs/history;
`git status` clean; timer gone from `systemctl --user list-timers`.
Then append what you changed to `docs/AGENT_LOG.md`.

## Phase 1 — Schema + fixtures + validation tests

Context: define the v1 data contract before any code talks to Google. Read
`AGENTS.md` and `docs/PLAN.md §5` (and `docs/ARCHITECTURE.md`). Implement ONLY:
the normalized calendar/task schema, config schema, fixture data, validation,
and unit tests. Do not implement QML, auth, systemd, or the gws adapter.
Acceptance: schema validation + unit tests pass.

## Phase 2 — gws adapter

Context: wrap the installed gws CLI. Inspect `gws schema <service.resource.method>`
before every call — never guess args. Implement ONLY `sync/gws_adapter.py`:
run(args, json_body=None) → dict, `--format json`, classify auth vs api vs
network failures. Methods: list_calendars, list_events, list_tasklists, list_tasks,
insert_event, patch_event, delete_event, insert_task, complete_task, delete_task.
Do not implement sync.py or QML. Acceptance: adapter unit tests pass on fixtures.

## Phase 3 — Sync engine

Context: `sync/sync.py` pipeline per PLAN §6. Implement ONLY the engine:
config → gws abs path → auth status → calendarList.list → tasklists.list →
window(past7/future60) → events.list(singleEvents=true, orderBy=startTime) →
tasks.list → normalize → timezone → dedupe → sort → validate → syncStatus →
atomic write (tmp→fsync→rename). Exit 0/2auth/3api/4config/5io; preserve
last-good on any failure. Acceptance: valid `state.json` from fixtures; a forced
failure keeps the old state file intact.

## Phase 4 — systemd

Context: schedule the sync. Implement ONLY the systemd user units
`systemd/parm.clock-sync.{service,timer}`: Type=oneshot, absolute gws/python
paths, `TimeoutStartSec=120`, `OnBootSec=2min`, `OnUnitActiveSec=5min`,
`Persistent=true`, no overlap. Install + `daemon-reload` + `enable --now`.
Acceptance: `systemctl --user list-timers` shows it; `journalctl --user` clean.

## Phase 5 — Model.js

Context: provider-independent logic. Implement ONLY Model.js: monthGrid (port
from stock), eventsForDate, tasksForDate, tasksDueToday, badgeCount(dueToday|
overdue|all), nextEvent, countdown, isStale, all-day/multi-day grouping,
calendar visibility filter. Do not touch QML. Acceptance: JS unit tests pass.

## Phase 6 — QML

Context: UI using Model.js. Implement ONLY: BarWidget badge (`☑ N`), Panel
compact ⇄ expanded (grid | agenda+tasks), settings view (badge, badgeCount,
defaultView, hiddenCalendars, pastDays, futureDays, syncIntervalMin,
weekStartDay), sync status footer. No CRUD wiring yet. Follow stock clock
styling (`Style.*`, `Color.accent`, `PanelActionButton`, `TextField`).
Acceptance: `omarchy plugin validate` + `qmllint` pass; hot-reload renders;
badge toggles; expand works.

## Phase 7 — CRUD wiring

Context: writes through gws then re-sync. Implement ONLY: new event (quickAdd
or form), edit event (patch), delete event; new task, complete task, delete
task — each via gws then re-sync. Acceptance: live round-trip create/edit/delete
event and add/complete/delete task.

## Phase 8 — Integration

Context: exercise every failure and lifecycle path per PLAN §11. Verify:
auth-expired, offline/cached, malformed data, DST/timezone, recurrence, manual
sync, click/Escape, `omarchy-shell shell summon/hide parm.clock`,
disable/re-enable, shell restart, removal. Acceptance: all paths behave per §11.

## Phase 9 — Adversarial review (use `zai-org/GLM-5.3`)

Context: a second pair of eyes, different from the builder. Review the whole
repo as a senior Linux/Quickshell engineer. Do not rewrite. Find architectural
flaws, race conditions, security problems, timezone bugs, lifecycle problems,
incorrect gws assumptions, systemd issues, Omarchy compatibility issues. Fix one
at a time. Acceptance: issues found + fixed one at a time.

## Phase 10 — Polish + docs

Context: finish. Implement ONLY: README (install, uninstall, troubleshooting),
`scripts/setup.sh` + `scripts/uninstall.sh` per PLAN §7, and a final AGENT_LOG
summary. Acceptance: docs complete and accurate.
