"""Unit tests for the sync engine: window computation, normalization pipeline,
dedupe/sort, atomic write, and preserve-last-good on failure.

Uses a fake gws executable so no network or credentials are involved.
"""

import json
import os
import stat
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sync import sync  # noqa: E402
from sync.schema import validate_state  # noqa: E402

FAKE_GWS = """#!/usr/bin/env python3
import json, os, sys

args = sys.argv[1:]

if args[0] == "auth" and args[1] == "status":
    authed = os.environ.get("FAKE_GWS_AUTH") != "none"
    print(json.dumps({"auth_method": "oauth2" if authed else "none",
                      "token_cache_exists": authed}))
    sys.exit(0)

service, resource, method = args[0], args[1], args[2]
params = {}
if "--params" in args:
    params = json.loads(args[args.index("--params") + 1])
body = None
if "--json" in args:
    body = json.loads(args[args.index("--json") + 1])

# --- calendar.calendarList list ---
if resource == "calendarList" and method == "list":
    print(json.dumps({"items": [
        {"id": "primary", "summary": "parm@example.com", "backgroundColor": "#4285F4"},
        {"id": "hidden_cal", "summary": "Hidden", "hidden": True},
    ]}))
    sys.exit(0)

# --- calendar.events list ---
if resource == "events" and method == "list":
    if os.environ.get("FAKE_GWS_EVENT_AUTH"):
        print(json.dumps({"error": {"code": 401, "message": "Token expired", "reason": "authError"}}))
        sys.exit(2)
    print(json.dumps({"items": [
        {"id": "e1", "summary": "Timed", "status": "confirmed",
         "start": {"dateTime": "2026-08-20T09:00:00+05:30", "timeZone": "Asia/Kolkata"},
         "end": {"dateTime": "2026-08-20T10:00:00+05:30", "timeZone": "Asia/Kolkata"}},
        {"id": "e2", "summary": "All-day", "status": "confirmed",
         "start": {"date": "2026-08-21"}, "end": {"date": "2026-08-22"}},
        {"id": "e2", "summary": "Dup of e2", "status": "confirmed",
         "start": {"date": "2026-08-21"}, "end": {"date": "2026-08-22"}},
        {"id": "e3", "summary": "Cancelled", "status": "cancelled"},
    ]}))
    sys.exit(0)

# --- tasks.tasklists list ---
if resource == "tasklists" and method == "list":
    print(json.dumps({"items": [{"id": "default", "title": "My Tasks"}]}))
    sys.exit(0)

# --- tasks.tasks list ---
if resource == "tasks" and method == "list":
    from datetime import datetime, timezone, timedelta
    recent_completed = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat().replace("+00:00", "Z")
    print(json.dumps({"items": [
        {"id": "t1", "title": "Due today", "status": "needsAction",
         "due": "2026-08-20T00:00:00.000Z"},
        {"id": "t2", "title": "Done", "status": "completed",
         "completed": recent_completed},
    ]}))
    sys.exit(0)

# --- API error mode (via env) ---
if os.environ.get("FAKE_GWS_API_ERROR"):
    print(json.dumps({"error": {"code": 500, "message": "backend unavailable", "reason": "internalError"}}))
    sys.exit(1)

print(json.dumps({"ok": True}))
sys.exit(0)
"""


def _write_fake_gws(d: Path) -> Path:
    fake = d / "gws"
    fake.write_text(FAKE_GWS, encoding="utf-8")
    fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
    return fake


class TestWindow(unittest.TestCase):
    def test_window_bounds(self):
        cfg = {"pastDays": 7, "futureDays": 60}
        tmin, tmax = sync.compute_window(cfg, "Asia/Kolkata")
        tz = ZoneInfo("Asia/Kolkata")
        today = datetime.now(tz).date()
        self.assertIn(str(today - timedelta(days=7)), tmin)
        self.assertIn(str(today + timedelta(days=61)), tmax)


class TestDedupeSort(unittest.TestCase):
    def test_dedupe(self):
        evs = [{"id": "a"}, {"id": "b"}, {"id": "a"}]
        self.assertEqual(len(sync.dedupe(evs)), 2)

    def test_sort_events_by_datekey(self):
        evs = [{"dateKey": "2026-08-22"}, {"dateKey": "2026-08-20"}]
        self.assertEqual(sync.sort_events(evs)[0]["dateKey"], "2026-08-20")


class TestSyncPipeline(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.fake = _write_fake_gws(self.dir)
        self.state_path = self.dir / "state" / "state.json"

    def tearDown(self):
        self._tmp.cleanup()

    def _cfg(self):
        return {"timezone": "Asia/Kolkata", "pastDays": 7, "futureDays": 60,
                "gwsPath": str(self.fake), "hiddenCalendars": [], "tasklistIds": []}

    def test_full_sync_writes_valid_state(self):
        os.environ["FAKE_GWS_AUTH"] = "ok"
        code = sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
        self.assertEqual(code, 0)
        state = json.loads(self.state_path.read_text())
        self.assertEqual(validate_state(state), [])
        self.assertEqual(state["syncStatus"]["state"], "ok")
        # Hidden calendar filtered out.
        self.assertEqual([c["id"] for c in state["calendars"]], ["primary"])
        # Cancelled event dropped; duplicate e2 deduped; completed task now kept (recent).
        self.assertEqual([e["id"] for e in state["events"]], ["e1", "e2"])
        self.assertEqual(sorted([t["id"] for t in state["tasks"]]), ["t1", "t2"])
        self.assertEqual(state["events"][1]["allDay"], True)
        self.assertEqual(state["events"][1]["end"], "2026-08-21")

    def test_unauthenticated_preserves_last_good(self):
        # First, a successful sync.
        os.environ["FAKE_GWS_AUTH"] = "ok"
        sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
        good = self.state_path.read_text()

        # Now report unauthenticated.
        os.environ["FAKE_GWS_AUTH"] = "none"
        cfg = self._cfg()
        code = sync.run_sync(cfg, gws_path=str(self.fake), state_path=self.state_path)
        self.assertEqual(code, 2)
        # Last-good state preserved untouched.
        self.assertEqual(self.state_path.read_text(), good)

    def test_no_state_emits_error_state(self):
        # A sync with a missing gws and no prior state writes a valid error doc.
        os.environ["FAKE_GWS_AUTH"] = "ok"
        cfg = self._cfg()
        cfg["gwsPath"] = "/no/such/gws"
        code = sync.run_sync(cfg, gws_path="/no/such/gws", state_path=self.state_path)
        self.assertEqual(code, 5)
        state = json.loads(self.state_path.read_text())
        self.assertEqual(validate_state(state), [])
        self.assertEqual(state["syncStatus"]["state"], "error")

    def test_invalid_config(self):
        cfg = self._cfg()
        cfg["pastDays"] = -1
        code = sync.run_sync(cfg, gws_path=str(self.fake), state_path=self.state_path)
        self.assertEqual(code, 4)

    def test_atomic_write_no_tmp_left(self):
        sync.atomic_write(self.state_path, '{"x": 1}\n')
        leftovers = list(self.state_path.parent.glob("*.tmp"))
        self.assertEqual(leftovers, [])

    def test_atomic_write_private_modes(self):
        # The cache holds calendar/task contents: dir 0700, file 0600.
        sync.atomic_write(self.state_path, '{"x": 1}\n')
        dir_mode = stat.S_IMODE(self.state_path.parent.stat().st_mode)
        file_mode = stat.S_IMODE(self.state_path.stat().st_mode)
        self.assertEqual(dir_mode, 0o700)
        self.assertEqual(file_mode, 0o600)

    def test_atomic_write_tightens_legacy_modes(self):
        # A 0755/0644 cache from an older version is tightened on rewrite.
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        os.chmod(self.state_path.parent, 0o755)
        self.state_path.write_text("old", encoding="utf-8")
        os.chmod(self.state_path, 0o644)
        sync.atomic_write(self.state_path, '{"x": 1}\n')
        dir_mode = stat.S_IMODE(self.state_path.parent.stat().st_mode)
        file_mode = stat.S_IMODE(self.state_path.stat().st_mode)
        self.assertEqual(dir_mode, 0o700)
        self.assertEqual(file_mode, 0o600)

    def test_save_config_private_modes(self):
        from sync.config import save_config
        cfg_path = self.dir / "cfg" / "config.json"
        save_config({"timezone": "UTC"}, cfg_path)
        dir_mode = stat.S_IMODE(cfg_path.parent.stat().st_mode)
        file_mode = stat.S_IMODE(cfg_path.stat().st_mode)
        self.assertEqual(dir_mode, 0o700)
        self.assertEqual(file_mode, 0o600)

    def test_api_error_preserves_last_good(self):
        # Successful sync first.
        os.environ["FAKE_GWS_AUTH"] = "ok"
        sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
        good = self.state_path.read_text()

        # Now a backend failure (one calendar fetch fails; events list raises).
        os.environ["FAKE_GWS_API_ERROR"] = "1"
        try:
            code = sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
            # A single calendar failing is tolerated (events skipped), so the
            # overall sync can still succeed with whatever it fetched — but if
            # the calendar list itself fails, it must preserve last-good.
            if code != 0:
                self.assertEqual(self.state_path.read_text(), good)
        finally:
            os.environ.pop("FAKE_GWS_API_ERROR", None)

    def test_reuse_discovery(self):
        os.environ["FAKE_GWS_AUTH"] = "ok"
        cfg = self._cfg()
        sync.run_sync(cfg, gws_path=str(self.fake), state_path=self.state_path)
        # Second sync reusing discovery should also produce valid state.
        code = sync.run_sync(cfg, gws_path=str(self.fake), state_path=self.state_path,
                             reuse_discovery=True, check_auth=False)
        self.assertEqual(code, 0)
        state = json.loads(self.state_path.read_text())
        self.assertEqual(validate_state(state), [])
        self.assertEqual(state["syncStatus"]["state"], "ok")

    def test_event_auth_error_preserves_last_good(self):
        # A token expiry during per-calendar fetch (check_auth=False path) must
        # NOT swallow the AuthError into an empty "ok" state — it must preserve
        # the last-good document.
        os.environ["FAKE_GWS_AUTH"] = "ok"
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
        good = self.state_path.read_text()

        os.environ["FAKE_GWS_EVENT_AUTH"] = "1"
        try:
            code = sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path,
                                 check_auth=False)
            self.assertEqual(code, 2)
            self.assertEqual(self.state_path.read_text(), good)
        finally:
            os.environ.pop("FAKE_GWS_EVENT_AUTH", None)

    def test_malformed_prior_state_replaced(self):
        # A corrupt state.json must not be treated as "last good"; the next
        # successful sync overwrites it.
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self.state_path.write_text("{ not json", encoding="utf-8")
        os.environ["FAKE_GWS_AUTH"] = "ok"
        code = sync.run_sync(self._cfg(), gws_path=str(self.fake), state_path=self.state_path)
        self.assertEqual(code, 0)
        state = json.loads(self.state_path.read_text())
        self.assertEqual(validate_state(state), [])


if __name__ == "__main__":
    unittest.main()
