"""Tests for the CRUD entrypoint (sync/mutate.py) against a fake gws."""

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

# A fake gws that records every invocation so we can assert the exact write
# call, and replies like a real gws to the sync pipeline's reads.
FAKE_GWS = """#!/usr/bin/env python3
import json, os, sys
log = os.environ.get("GWS_LOG", "/tmp/gws_calls.jsonl")

args = sys.argv[1:]
with open(log, "a") as f:
    f.write(json.dumps(args) + "\\n")

if args[0] == "auth" and args[1] == "status":
    print(json.dumps({"auth_method": "oauth2", "token_cache_exists": True}))
    sys.exit(0)

service, resource, method = args[0], args[1], args[2]
params = {}
if "--params" in args:
    params = json.loads(args[args.index("--params") + 1])
body = None
if "--json" in args:
    body = json.loads(args[args.index("--json") + 1])

if resource == "calendarList" and method == "list":
    print(json.dumps({"items": [{"id": "primary", "summary": "me"}]}))
elif resource == "tasklists" and method == "list":
    print(json.dumps({"items": [{"id": "default", "title": "My Tasks"}]}))
elif resource == "events" and method == "list":
    print(json.dumps({"items": []}))
elif resource == "tasks" and method == "list":
    print(json.dumps({"items": []}))
elif method == "insert":
    print(json.dumps({"id": "created", **(body or {})}))
elif method == "patch":
    print(json.dumps({"id": params.get("eventId") or params.get("task"), **(body or {})}))
elif method == "delete":
    print(json.dumps({}))
elif method == "quickAdd":
    print(json.dumps({"id": "quick_created", "summary": params.get("text")}))
else:
    print(json.dumps({}))
sys.exit(0)
"""


class TestMutate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.dir = Path(cls._tmp.name)
        cls.fake = cls.dir / "gws"
        cls.fake.write_text(FAKE_GWS, encoding="utf-8")
        cls.fake.chmod(cls.fake.stat().st_mode | stat.S_IEXEC)
        cls.log = cls.dir / "calls.jsonl"
        cls.state_path = cls.dir / "state" / "state.json"

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def _env(self):
        e = dict(os.environ)
        e["GWS_LOG"] = str(self.log)
        e["XDG_STATE_HOME"] = str(self.dir / "xdg-state")
        # Point load_config() at a temp config naming the fake gws.
        cfg_dir = self.dir / "config" / "parm.clock"
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "config.json").write_text(
            json.dumps({"gwsPath": str(self.fake), "timezone": "Asia/Kolkata"}),
            encoding="utf-8",
        )
        e["XDG_CONFIG_HOME"] = str(self.dir / "config")
        return e

    def _run(self, *args):
        return subprocess.run(
            [sys.executable, str(ROOT / "sync" / "mutate.py"), *args],
            capture_output=True, text=True, env=self._env(), timeout=60,
        )

    def _calls(self):
        if not self.log.exists():
            return []
        return [json.loads(l) for l in self.log.read_text().splitlines()]

    def _method_calls(self, method):
        """Calls of the form [service, resource, method, ...]."""
        out = []
        for c in self._calls():
            if len(c) >= 3 and c[2] == method:
                out.append(c)
        return out

    def _write_state(self):
        # A valid prior state so re-sync has something to replace.
        from sync.sync import atomic_write
        from sync.schema import empty_state
        atomic_write(self.state_path, json.dumps(empty_state()) + "\n")

    def setUp(self):
        # Fresh call log per test.
        if self.log.exists():
            self.log.unlink()

    def test_quickadd(self):
        self._write_state()
        r = self._run("event-quickadd", "--calendar", "primary", "--text", "Lunch")
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self._method_calls("quickAdd")
        self.assertEqual(len(calls), 1)
        self.assertEqual(json.loads(calls[0][calls[0].index("--params") + 1])["calendarId"], "primary")

    def test_event_add_timed(self):
        self._write_state()
        r = self._run("event-add", "--calendar", "primary", "--title", "Meet",
                      "--date", "2026-08-21", "--start", "14:00")
        self.assertEqual(r.returncode, 0, r.stderr)
        inserts = self._method_calls("insert")
        self.assertEqual(len(inserts), 1)
        body = json.loads(inserts[0][inserts[0].index("--json") + 1])
        self.assertEqual(body["summary"], "Meet")
        self.assertEqual(body["start"]["dateTime"], "2026-08-21T14:00:00")
        self.assertEqual(body["end"]["dateTime"], "2026-08-21T15:00:00")

    def test_event_add_allday(self):
        self._write_state()
        r = self._run("event-add", "--calendar", "primary", "--title", "Holiday",
                      "--date", "2026-08-22")
        self.assertEqual(r.returncode, 0, r.stderr)
        inserts = self._method_calls("insert")
        body = json.loads(inserts[0][inserts[0].index("--json") + 1])
        self.assertEqual(body["start"], {"date": "2026-08-22"})
        self.assertEqual(body["end"], {"date": "2026-08-23"})  # exclusive

    def test_task_add(self):
        self._write_state()
        r = self._run("task-add", "--list", "default", "--title", "Reply", "--due", "2026-08-20")
        self.assertEqual(r.returncode, 0, r.stderr)
        inserts = self._method_calls("insert")
        body = json.loads(inserts[0][inserts[0].index("--json") + 1])
        self.assertEqual(body["title"], "Reply")
        self.assertIn("2026-08-20", body["due"])

    def test_task_complete(self):
        self._write_state()
        r = self._run("task-complete", "--list", "default", "--task", "t1")
        self.assertEqual(r.returncode, 0, r.stderr)
        patches = self._method_calls("patch")
        body = json.loads(patches[0][patches[0].index("--json") + 1])
        self.assertEqual(body["status"], "completed")

    def test_task_delete(self):
        self._write_state()
        r = self._run("task-delete", "--list", "default", "--task", "t1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self._method_calls("delete"))

    def test_event_add_late_start_end_clamped_same_day(self):
        # 23:30 + default 1h would cross midnight; end must clamp to 23:59
        # rather than wrap to 00:30 (which would precede the start).
        self._write_state()
        r = self._run("event-add", "--calendar", "primary", "--title", "Late",
                      "--date", "2026-08-21", "--start", "23:30")
        self.assertEqual(r.returncode, 0, r.stderr)
        inserts = self._method_calls("insert")
        body = json.loads(inserts[0][inserts[0].index("--json") + 1])
        self.assertEqual(body["end"]["dateTime"], "2026-08-21T23:59:00")

    def test_event_add_meet_request_id_unique(self):
        # Google requires a unique requestId per conference createRequest;
        # two same-title events must not collide.
        self._write_state()
        ids = []
        for _ in range(2):
            r = self._run("event-add", "--calendar", "primary", "--title", "Standup",
                          "--date", "2026-08-21", "--start", "09:00", "--meet")
            self.assertEqual(r.returncode, 0, r.stderr)
            inserts = self._method_calls("insert")
            body = json.loads(inserts[-1][inserts[-1].index("--json") + 1])
            ids.append(body["conferenceData"]["createRequest"]["requestId"])
        self.assertNotEqual(ids[0], ids[1])
        self.assertTrue(ids[0].startswith("parm.clock-"))

    def test_re_syncs_state_after_write(self):
        self._write_state()
        r = self._run("event-quickadd", "--calendar", "primary", "--text", "X")
        self.assertEqual(r.returncode, 0, r.stderr)
        # run_sync wrote a fresh state.json in the fake XDG_STATE_HOME.
        state_file = self.dir / "xdg-state" / "parm.clock" / "state.json"
        self.assertTrue(state_file.exists())


if __name__ == "__main__":
    unittest.main()
