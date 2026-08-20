# Google Calendar Clock (`parm.clock`) — Build Plan

Source of truth for the build. A builder model reads this + `AGENTS.md` first,
implements one phase at a time per `docs/TASKS.md` and `docs/PROMPTS.md`, stops
at each gate, and logs to `docs/AGENT_LOG.md`.

## 1. Mission

Replace khal/vdirsyncer with a **gws-powered** Google Calendar + Tasks clock for
the Omarchy bar:

- clock + **task badge (`☑ N` = tasks due today)**
- popup **compact by default ⇄ expanded two-pane** (month grid | agenda + tasks)
- **full CRUD** for events & tasks via gws
- synced by a **systemd user timer**
- **offline-first** from a cached JSON state

Built end-to-end by **`google/gemini-3.7-flash`**.

## 2. Verified environment (builder does not re-derive)

- `gws` v0.22.5 at `/usr/bin/gws`. `calendar.events`: `list/insert/patch/delete/instances/quickAdd`; `+insert --meet`; `tasks.tasks`: `list/insert/patch/delete/clear`. Discovery cached at `~/.config/gws/cache/{calendar_v3,tasks_v1}.json`.
- `gcloud` 581.0.0 at `/usr/bin/gcloud`, authed `iamparmjeetmishra@gmail.com`, project `omarchy-clock`. OAuth client exists (`~/.config/gws/client_secret.json`); **no token yet** → one `gws auth login` browser step required.
- Plugin pattern: `Process` + `StdioCollector` reads JSON; `bar.run("...")` fires shell cmds. Stock clock = `BarWidget.qml` + `Panel.qml` + `Model.js`; `parm.clock` is the clone, wired as `centerAnchor`.
- Timezone: `Asia/Kolkata`.
- Official gates: `omarchy plugin validate <dir>` and `qmllint -I "$OMARCHY_PATH/shell" …`.

## 3. Architecture (hard boundary)

```
Google (Cal+Tasks) ←OAuth(gws owns)→ gws CLI
 → sync/sync.py (discover→window→normalize→tz→recurrence→dedupe→validate→ATOMIC write)
 → ~/.local/state/parm.clock/state.json
 → Model.js (pure) → BarWidget.qml + Panel.qml
 → writes: gws insert/patch/delete → re-sync → state.json
systemd user timer → sync.service (oneshot, abs paths, no overlap)
```

**QML never touches gws/Google/credentials — only reads `state.json`.**
No server, no DB, no OAuth code in the plugin.

## 4. Files

```
parm.clock/
├── AGENTS.md              # hard engineering rules
├── manifest.json          # bar-widget, clonedFrom omarchy.clock, license MIT, name "Google Calendar Clock"
├── BarWidget.qml          # stock clock + ☑N badge + popup host
├── Panel.qml              # compact ⇄ expanded 2-pane + settings + CRUD triggers
├── Model.js               # pure logic (ported month grid + new agenda/badge/next-event)
├── sync/{sync.py, gws_adapter.py, normalize.py, config.py}
├── scripts/{setup.sh, uninstall.sh}
├── systemd/{parm.clock-sync.service, parm.clock-sync.timer}
├── tests/ (+fixtures/)
└── docs/{PLAN, TASKS, PROMPTS, DECISIONS, ARCHITECTURE, AGENT_LOG}.md
```

## 5. `state.json` (v1)

```json
{
  "version": 1,
  "syncedAt": "RFC3339",
  "source": "google",
  "timezone": "Asia/Kolkata",
  "calendars": [{"id":"...","name":"...","color":"#...","visible":true}],
  "events": [{
    "id":"...","calendarId":"...","title":"...",
    "start":"RFC3339","end":"RFC3339","allDay":false,
    "dateKey":"YYYY-MM-DD (local)","location":"...",
    "description":"...","htmlLink":"...","meetUrl":"...",
    "recurring":true
  }],
  "tasklists": [{"id":"...","title":"..."}],
  "tasks": [{
    "id":"...","listId":"...","title":"...","notes":"...",
    "due":"YYYY-MM-DD or RFC3339","status":"needsAction|completed",
    "completed":"RFC3339|null"
  }],
  "syncStatus": {"state":"ok|auth|error|never","message":"...","lastOk":"RFC3339|null"}
}
```

Rules: `dateKey` is always local; all-day events get a `dateKey` per spanned
day in the UI model; task `due` is normalized to a local date.

## 6. Sync engine (`sync/sync.py`)

```
load+validate config
→ verify gws exists + absolute path
→ gws auth status
→ calendarList.list → filter calendars
→ tasklists.list
→ window (pastDays=7, futureDays=60, configurable)
→ events.list per calendar (singleEvents=true, orderBy=startTime, timeMin/timeMax)
→ tasks.list per list (due window; showCompleted handling)
→ normalize → timezone → dedupe → sort → validate
→ merge syncStatus
→ atomic write (tmp → fsync → rename)
```

Exit codes: `0` ok, `2` auth, `3` api, `4` config, `5` io. **Preserve last-good
on any non-zero.**

## 7. Setup automation (`scripts/setup.sh`)

```
1. ensure gcloud + gws (pacman/AUR if missing; verify presence first)
2. gws auth setup --project omarchy-clock   # enable Cal+Tasks APIs, ensure OAuth client
3. gws auth login --services calendar,tasks # ONE browser consent (unavoidable)
4. gws auth status → assert authenticated
5. python3 sync/sync.py                     # first sync
6. install systemd units → daemon-reload → enable --now parm.clock-sync.timer
```

Documented honestly: the browser consent (and possible "add yourself as a test
user" in Testing-mode sensitive scope) is the only manual step.

## 8. UI

- **BarWidget.qml**: stock clock + `☑ N` badge (N = tasks due today; shown when
  `showTaskBadge != false` and `N > 0`). Left-click → panel; badge-click → panel
  Tasks; right-click → format cycle (stock); middle-click → timezone (stock).
- **Compact (default)**: hero date, year/life bars (stock), month grid with
  event/task dots, today agenda strip.
- **Expanded (toggle)**: left month grid; right column = selected-day agenda
  (events: edit/delete, Meet/link) + tasks (checkbox complete/add/delete).
- **Header buttons**: Sync (manual), New event, New task, Settings, Expand/Compact.
- **Settings view** (persist to shell.json): `showTaskBadge`,
  `badgeCount(dueToday|overdue|all)`, `defaultView(compact|expanded)`,
  `hiddenCalendars[]`, `pastDays`, `futureDays`, `syncIntervalMin`, `weekStartDay`.
- **Footer**: sync status (`✓ Synced 2m` / `⚠ auth needed`). Styling reuses
  `Style.*`, `Color.accent`, `PanelActionButton`, `TextField` — matches the stock
  clock, no new design system.

## 9. Settings keys (shell.json under `parm.clock`)

Stock: `format, formatAlt, verticalFormat, verticalFormatAlt, weekStartDay,
birthYear, lifeExpectancy`.
New: `showTaskBadge=true, badgeCount="dueToday", defaultView="compact",
hiddenCalendars=[], pastDays=7, futureDays=60, syncIntervalMin=5`.

## 10. CRUD flows (all via gws → re-sync)

- Event: quick-add (`events.quickAdd`) or form → `events.insert`/`+insert`;
  edit → `events.patch`; delete → `events.delete`.
- Task: add → `tasks.insert`; complete → `tasks.patch status=completed`;
  delete → `tasks.delete`.
- Authoritative refresh always from re-sync.

## 11. Failure behavior

- gws missing → `syncStatus.state=error`, UI shows cached + "gws not installed".
- auth expired → `syncStatus.state=auth`, UI shows cached + "re-auth: gws auth login".
- API/network fail → keep last-good, `syncStatus.state=error`, retry next timer.
- malformed JSON → **do not write**, keep last-good.

## 12. Official contract & validation

- Manifest: `kinds: ["bar-widget"]`, `entryPoints.barWidget`,
  `omarchy.clonedFrom: "omarchy.clock"` (kept during dev), `license: "MIT"`, and
  a `LICENSE` file. The panel stays a nested `Panel.qml` loaded by `BarWidget.qml`
  (not a separate `panel` kind).
- Every phase that touches QML/manifest must pass
  `omarchy plugin validate <dir>` and `qmllint -I "$OMARCHY_PATH/shell" …`.
- Publishing ID (future): move `parm.clock` → `io.github.<you>.<name>` and drop
  `clonedFrom` only when publishing. Not a v1 blocker.

## 13. Phases + acceptance gates

See `docs/TASKS.md` for the full ticket list; each phase ends with its validator.

## 14. Model roles (cost-aware)

- **Builder (P0–P8, P10): `google/gemini-3.7-flash`** (0.75/3.75, intel 56).
- **Cheap tail (docs/fixtures/systemd, optional): `gpt-5.6-luna` / `meta/muse-spark-1.2`.**
- **P9 review (one pass, a *different* model): `zai-org/GLM-5.3`.** Don't review
  gemini with gemini.
- **Safety valve:** if gemini repeatedly fails a gate (esp. timezone/recurrence
  in P3), promote the build to `glm-5.3`. AGENTS.md/PLAN.md are model-agnostic,
  so a handoff is clean.
