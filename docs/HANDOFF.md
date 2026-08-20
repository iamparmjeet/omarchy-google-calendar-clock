# Handoff — Google Calendar Clock (`parm.clock`) — COMPLETE

**Repo:** `~/.config/omarchy/plugins/parm.clock/` (git, branch `master`, pushed to `origin`)
**Remote:** `https://github.com/iamparmjeet/omarchy-google-calendar-clock.git`

## What this is

An Omarchy bar widget (clone of stock `omarchy.clock`) that shows Google
Calendar events + Google Tasks: task badge on the clock, month grid with event
dots, compact ⇄ expanded two-pane popup, full CRUD. **gws-powered** (no
khal/vdirsyncer). QML never calls gws/Google — it reads
`~/.local/state/parm.clock/state.json`, written atomically by the Python sync
engine.

## Status: ALL PHASES 0–10 DONE and pushed.

Final commits:

- `10ee194` — Phase 9 (adversarial review, 5 fixes)
- `9c28ac4` — Phase 10 (docs/setup/uninstall/LICENSE)

Read these first (source of truth):

- `AGENTS.md` — hard rules
- `docs/PLAN.md` — full plan
- `docs/TASKS.md` — phase list + gates
- `docs/PROMPTS.md` — per-phase prompts
- `docs/AGENT_LOG.md` — what was done each phase

## Files

```
AGENTS.md  BarWidget.qml  Panel.qml  Model.js  manifest.json  README.md  LICENSE
sync/{schema,config,gws_adapter,sync,mutate}.py
scripts/{setup.sh,uninstall.sh}
systemd/parm.clock-sync.{service,timer}   (installed + enabled, 5-min timer)
tests/{test_schema,test_gws_adapter,test_sync,test_mutate}.py + test_model.js + fixtures/
docs/{PLAN,TASKS,PROMPTS,DECISIONS,ARCHITECTURE,AGENT_LOG}.md
```

## Current state

- **Live & working**: OAuth done, project `omarchy-clock`, account added as
  OAuth test user. `sync.py` → `state: ok` with 4 calendars, 16 events, 1 task
  ("My Tasks").
- **Tests**: `python3 -m unittest discover -s tests` → 56 pass;
  `node tests/test_model.js` → 17 pass.
- **Validation**: `omarchy plugin validate .` exit 0;
  `qmllint -I "$OMARCHY_PATH/shell" Panel.qml` rc 0. `BarWidget.qml` rc 255 is a
  **pre-existing** `IpcHandler` limitation (stock clock fails identically) — not
  a regression.

## Environment facts (don't re-derive)

- `gws` v0.22.5 `/usr/bin/gws`, `gcloud` 581, authed
  `iamparmjeetmishra@gmail.com`, project `omarchy-clock`.
- Timezone `Asia/Kolkata`. Python3
  `/home/parm/.local/share/mise/installs/python/latest/bin/python3`.
- gws invocation: `gws <service> <resource> <method> --params '{json}'
  [--json '{json}']`; exit codes 0/1(api)/2(auth)/3(validation)/4/5. Empty
  success body on deletes. `gws auth status` is a 2-word subcommand;
  `gws auth setup --project X`; `gws auth login --services calendar,tasks`.
- Calendar write target: the Google-`primary` calendar (never read-only holiday
  calendars — bit us once).

## Bootstrap prompt for a fresh chat

```
Read AGENTS.md and docs/PLAN.md in ~/.config/omarchy/plugins/parm.clock first —
source of truth. Then docs/TASKS.md and docs/PROMPTS.md.

This is the "Google Calendar Clock" Omarchy plugin (gws-powered). All phases 0-10
are complete and pushed. QML never calls gws/Google; it only reads
~/.local/state/parm.clock/state.json. Never guess gws args — run `gws schema ...` first.

No pending phase work. Propose any new work as a change to the plan docs before implementing.
```

---

Note: the build is finished, so there's no "next phase" — any new work should be
scoped fresh against the plan docs.
