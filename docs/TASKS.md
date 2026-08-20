# TASKS.md — Phase tickets, models, acceptance gates

Each phase is a hard stop. Implement ONLY the current phase, pass its gate,
then append to `docs/AGENT_LOG.md` before continuing. Builder model is
`google/gemini-3.7-flash` unless a ticket says otherwise.

| # | Task | Model | Acceptance gate |
|---|------|-------|-----------------|
| 0 | **Hard cut**: disable+remove vdirsyncer timer/service; delete khal/vdirsyncer configs; drop `scripts/fetch_events.py` + `scripts/setup_google_calendar.sh`; discard uncommitted icon tweak | gemini-3.7-flash | No khal/vdirsyncer references remain; timer gone; `git status` clean; README updated to gws |
| 1 | Schema v1 + config + fixtures + validation tests (no UI, no auth) | gemini-3.7-flash | Schema validation + unit tests pass |
| 2 | `gws_adapter.py` (schema-verified, error classify auth vs api vs network) + tests | gemini-3.7-flash | Adapter unit tests pass on fixtures |
| 3 | `sync.py` engine + atomic write + preserve-last-good + tests | gemini-3.7-flash | Produces valid `state.json` from fixtures; failure keeps old state |
| 4 | systemd service + timer + install | gemini-3.7-flash | `systemctl --user list-timers` shows it; `journalctl --user` clean |
| 5 | Model.js logic (grouping, next event, badge count, stale detection) + JS tests | gemini-3.7-flash | JS unit tests pass |
| 6 | QML — BarWidget badge + Panel compact/expanded + settings (no CRUD yet) | gemini-3.7-flash | `omarchy plugin validate` + `qmllint` pass; hot-reload renders; badge toggles; expand works |
| 7 | Wire CRUD via gws + re-sync | gemini-3.7-flash | Live round-trip create/edit/delete event & add/complete/delete task |
| 8 | Integration: auth-expired, offline, malformed, DST, recurrence, manual sync, click/Escape, `omarchy-shell shell summon/hide parm.clock`, disable/re-enable, shell restart, removal | gemini-3.7-flash | All paths behave per PLAN §11 |
| 9 | Adversarial review + fixes (race conditions, security, timezone, systemd, Omarchy compat) | **`zai-org/GLM-5.3`** | Issues found + fixed one at a time |
| 10 | README/setup/uninstall/troubleshooting + AGENT_LOG final | gemini-3.7-flash | Docs complete |

## Gate commands (run at the end of each relevant phase)

- QML/manifest phases (6+): `omarchy plugin validate ~/.config/omarchy/plugins/parm.clock`
  and `qmllint -I "$OMARCHY_PATH/shell" <file>.qml`
- Python phases (1–3): `python3 -m pytest tests/ -q` (or the repo's test runner)
- JS phase (5): `node tests/*.test.js`
- systemd phase (4): `systemctl --user list-timers` + `journalctl --user -u parm.clock-sync -n 20`

## Model-role notes

- Cheap tail (`gpt-5.6-luna` / `meta/muse-spark-1.2`) may only do docs, fixtures,
  systemd boilerplate, and AGENT_LOG entries — never `sync.py`, `normalize.py`,
  timezone/recurrence code, or QML state wiring.
- Phase 9 review uses a **different** model than the builder for a genuine
  second opinion.
