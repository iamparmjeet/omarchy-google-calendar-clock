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
