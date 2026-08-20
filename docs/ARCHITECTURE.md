# ARCHITECTURE.md — diagram, data contract, sync pipeline

## Diagram

```
                 Google (Calendar + Tasks APIs)
                          │  OAuth (gws owns tokens)
                          ▼
                        gws CLI
                          │  JSON
                          ▼
        sync/sync.py  (Python engine)
        discover calendars+tasklists → fetch window →
        normalize → timezone → expand recurrence →
        dedupe → validate → ATOMIC write
                          │
                          ▼
   ~/.local/state/parm.clock/state.json   (single source of truth)
                          │  FileView / Process watch
                          ▼
        Model.js (pure: grouping, next-event, badge count, month grid)
                          ▼
   BarWidget.qml (clock + ☑N badge)   Panel.qml (compact ⇄ expanded)
                          │  writes (create/edit/delete/complete)
                          ▼
        gws insert/patch/delete  →  re-sync  →  state.json
```

## Hard boundary

QML never talks to Google. QML reads `state.json`; writes go through gws then
trigger a re-sync. gws owns all credentials. No server, no DB, no OAuth code in
the plugin.

## Data contract — `~/.local/state/parm.clock/state.json` (v1)

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

- `dateKey` is always local `YYYY-MM-DD`.
- All-day events get a `dateKey` per spanned day in the UI model.
- Task `due` is normalized to a local date.

## Sync pipeline (`sync/sync.py`)

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

Exit codes: `0` ok, `2` auth, `3` api, `4` config, `5` io. Preserve last-good on
any non-zero.

## Failure behavior

| Condition | syncStatus.state | UI |
|---|---|---|
| gws missing | `error` | cached + "gws not installed" |
| auth expired | `auth` | cached + "re-auth: gws auth login" |
| API/network fail | `error` | keep last-good, retry next timer |
| malformed JSON | (no write) | keep last-good |

## systemd

- `parm.clock-sync.service`: `Type=oneshot`, absolute paths, `TimeoutStartSec=120`.
- `parm.clock-sync.timer`: `OnBootSec=2min`, `OnUnitActiveSec=5min`, `Persistent=true`.
- No overlap via oneshot + timer semantics.
