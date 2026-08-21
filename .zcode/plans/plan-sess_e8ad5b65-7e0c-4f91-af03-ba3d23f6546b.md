Fix 5 correctness bugs found in review of parm.clock plugin:

**1. Meet `requestId` collision** — `sync/mutate.py:128`: `f"parm.clock-{args.title}"` → make unique per request using `int(time.time()*1000)` (plus a short random suffix to be safe against rapid double-submits).

**2. `_plus_hour` midnight wrap** — `sync/mutate.py:173-179`: when start+60min crosses 24:00, return `"24:00"`-style handling is wrong; correct fix: if the computed end is on the next day (total >= 1440), set end to `23:59` on the same date (simple, keeps same-day `--date` semantics, Google accepts it). Add a unit test for 23:30 → 23:59.

**3. Hardcoded `Asia/Kolkata` in failure paths** —
- `sync/sync.py:362` `_preserve_or_emit_failure`: use `cfg.get("timezone") or DEFAULT_CONFIG["timezone"]` instead of literal.
- `sync/schema.py:317` `empty_state`: change signature default to `timezone: str = ""` and fall back to a local `_detect_system_timezone()`-equivalent import from `sync.config` — but schema.py must stay dependency-light, so instead: give `empty_state` a required-ish default of `"UTC"` and have both callers (sync.py already passes timezone; setup doesn't call it) pass the detected zone. Simplest: default `UTC` in schema, sync.py always passes explicit timezone (it already does at line 223 and via `_preserve_or_emit_failure` after fix).
- Update the stale comment in `scripts/setup.sh` fallback? No — setup.sh writes detected tz already; only Python defaults change.

**4. Duplicate `hiddenCalendars` semantics** — remove the sync-time filter so the panel's shell.json `hiddenCalendars` is the single source of truth:
- `sync/sync.py`: delete `filter_calendars()` usage — fetch all non-`hidden` (Google's own hidden flag) calendars so they stay visible/toggleable in the panel settings UI.
- `sync/config.py`: drop `hiddenCalendars` from `DEFAULT_CONFIG` (keep accepting-and-ignoring it in `load_config` so old config.json files don't break).
- `scripts/setup.sh`: stop writing `"hiddenCalendars": []` into config.json.
- Panel already filters dots/chips via `isHidden()` — no QML change needed.
- Update README Settings section accordingly.
- Update tests (`tests/test_sync.py` filter_calendars tests) to match.

**5. `dateKey` fallback invalid state** — `sync/schema.py:273`: `dk or start_raw or ""` → fall back to `""` only (never a full RFC3339 string), so one bad event can't fail validation of the whole state document. Add a test: timed event with unparseable dateTime gets `dateKey: ""`.

**Verification**: run `python3 -m unittest discover -s tests` and `node tests/test_model.js` — all must pass, including new tests added for fixes 2 and 5.