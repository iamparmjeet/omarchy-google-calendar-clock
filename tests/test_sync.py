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
    print(json.dumps({"items": [
        {"id": "t1", "title": "Due today", "status": "needsAction",
         "due": "2026-08-20T00:00:00.000Z"},
        {"id": "t2", "title": "Done", "status": "completed",
         "completed": "2026-08-19T10:00:00.000Z"},
    ]}))
    sys.exit(0)

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
        # Cancelled event dropped; duplicate e2 deduped; completed task dropped.
        self.assertEqual([e["id"] for e in state["events"]], ["e1", "e2"])
        self.assertEqual([t["id"] for t in state["tasks"]], ["t1"])
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


if __name__ == "__main__":
    unittest.main()
