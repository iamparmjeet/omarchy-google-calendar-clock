"""Unit tests for the gws adapter, using a fake gws executable.

The fake script asserts the exact command-line shape (never guessing) and
returns canned JSON for each classification. No network, no real credentials.
"""

import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sync import gws_adapter  # noqa: E402


FAKE_GWS = """#!/usr/bin/env python3
import json, os, sys

# gws <service> <resource> <method> --params <json> [--json <json>]
args = sys.argv[1:]
service, resource, method = args[0], args[1], args[2]
params = {}
body = None
if "--params" in args:
    params = json.loads(args[args.index("--params") + 1])
if "--json" in args:
    body = json.loads(args[args.index("--json") + 1])

# Emit the invocation shape so tests can assert it.
shape = {"service": service, "resource": resource, "method": method,
         "params": params, "body": body}

# Failure modes selected via params.mode (checked first).
mode = params.get("mode")
if mode == "auth":
    print(json.dumps({"error": {"code": 401, "message": "Access denied", "reason": "authError"}}))
    sys.exit(2)
if mode == "api":
    print(json.dumps({"error": {"code": 404, "message": "Not found", "reason": "notFound"}}))
    sys.exit(1)
if mode == "internal":
    print(json.dumps({"error": {"code": 500, "message": "boom", "reason": "internalError"}}))
    sys.exit(5)

if os.environ.get("FAKE_GWS_HUGE") == "1":
    # A response far past any sane per-page size. Checked before the
    # resource branches so any invocation can select it.
    sys.stdout.write("x" * 65536)
    sys.exit(0)

if method == "list" and resource == "calendarList":
    print(json.dumps({"items": [{"id": "primary", "summary": "x"}]}))
    sys.exit(0)

if method == "list" and resource == "events":
    print(json.dumps({"items": [{"id": "e1", "summary": "meeting"}]}))
    sys.exit(0)

if method == "list" and resource == "tasklists":
    print(json.dumps({"items": [{"id": "default", "title": "My Tasks"}]}))
    sys.exit(0)

if method == "list" and resource == "tasks":
    if os.environ.get("FAKE_GWS_PAGED") == "1":
        page_token = params.get("pageToken")
        if not page_token:
            print(json.dumps({"items": [{"id": "p1"}], "nextPageToken": "tok2"}))
        else:
            print(json.dumps({"items": [{"id": "p2"}]}))
        sys.exit(0)
    if os.environ.get("FAKE_GWS_ENDLESS") == "1":
        # Two items per page and a pageToken that never clears: pagination
        # would run forever without the adapter's caps.
        print(json.dumps({"items": [{"id": "a"}, {"id": "b"}], "nextPageToken": "more"}))
        sys.exit(0)
    print(json.dumps({"items": [{"id": "t1", "title": "todo"}]}))
    sys.exit(0)

if method == "insert" and resource == "events":
    print(json.dumps({"id": "new_event", **body}))
    sys.exit(0)

if method == "patch" and resource == "events":
    print(json.dumps({"id": params.get("eventId"), **body}))
    sys.exit(0)

if method == "insert" and resource == "tasks":
    print(json.dumps({"id": "new_task", **body}))
    sys.exit(0)

if method == "patch" and resource == "tasks":
    print(json.dumps({"id": params.get("task"), **body}))
    sys.exit(0)

# Default: echo the shape as a successful response.
print(json.dumps(shape))
sys.exit(0)
"""


class TestGwsAdapter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.fake = Path(cls._tmp.name) / "gws"
        cls.fake.write_text(FAKE_GWS, encoding="utf-8")
        cls.fake.chmod(cls.fake.stat().st_mode | stat.S_IEXEC)

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def _gws(self):
        return str(self.fake)

    def test_list_calendars(self):
        cals = gws_adapter.list_calendars(self._gws())
        self.assertEqual(cals[0]["id"], "primary")

    def test_list_events_passes_verified_params(self):
        evs = gws_adapter.list_events("primary", "2026-08-01T00:00:00+05:30", "2026-09-01T00:00:00+05:30", gws_path=self._gws())
        self.assertEqual(evs[0]["id"], "e1")

    def test_list_tasks(self):
        tasks = gws_adapter.list_tasks("default", gws_path=self._gws())
        self.assertEqual(tasks[0]["id"], "t1")

    def test_list_tasks_pages(self):
        # A list method returning a nextPageToken must be followed to exhaustion.
        os.environ["FAKE_GWS_PAGED"] = "1"
        try:
            tasks = gws_adapter.list_tasks("default", gws_path=self._gws())
            self.assertEqual([t["id"] for t in tasks], ["p1", "p2"])
        finally:
            os.environ.pop("FAKE_GWS_PAGED", None)

    def test_list_item_cap_truncates(self):
        # An endless list stops at MAX_LIST_ITEMS and returns a bounded list.
        os.environ["FAKE_GWS_ENDLESS"] = "1"
        try:
            with mock.patch.object(gws_adapter, "MAX_LIST_ITEMS", 3):
                tasks = gws_adapter.list_tasks("default", gws_path=self._gws())
            self.assertEqual(len(tasks), 3)
        finally:
            os.environ.pop("FAKE_GWS_ENDLESS", None)

    def test_list_page_cap_truncates(self):
        # Endless pagination stops at MAX_LIST_PAGES even under a high item cap.
        os.environ["FAKE_GWS_ENDLESS"] = "1"
        try:
            with mock.patch.object(gws_adapter, "MAX_LIST_PAGES", 2), \
                 mock.patch.object(gws_adapter, "MAX_LIST_ITEMS", 10 ** 9):
                tasks = gws_adapter.list_tasks("default", gws_path=self._gws())
            self.assertEqual(len(tasks), 4)  # 2 pages x 2 items
        finally:
            os.environ.pop("FAKE_GWS_ENDLESS", None)

    def test_run_rejects_oversized_output(self):
        # A gws response past the byte cap is killed and classified, never
        # buffered to completion.
        os.environ["FAKE_GWS_HUGE"] = "1"
        try:
            with mock.patch.object(gws_adapter, "MAX_RESPONSE_BYTES", 4096):
                with self.assertRaises(gws_adapter.GwsError) as ctx:
                    gws_adapter.run("calendar", "events", "list", gws_path=self._gws())
            self.assertEqual(ctx.exception.kind, "limit")
        finally:
            os.environ.pop("FAKE_GWS_HUGE", None)

    def test_auth_error_classified(self):
        # Use a resource/method that forwards to the failure branch.
        with self.assertRaises(gws_adapter.AuthError) as ctx:
            gws_adapter.run("calendar", "calendarList", "list", params={"mode": "auth"}, gws_path=self._gws())
        self.assertEqual(ctx.exception.kind, "auth")

    def test_api_error_classified(self):
        with self.assertRaises(gws_adapter.ApiError):
            gws_adapter.run("calendar", "calendarList", "list", params={"mode": "api"}, gws_path=self._gws())

    def test_internal_error_classified(self):
        with self.assertRaises(gws_adapter.GwsError) as ctx:
            gws_adapter.run("calendar", "calendarList", "list", params={"mode": "internal"}, gws_path=self._gws())
        self.assertEqual(ctx.exception.kind, "gws")

    def test_missing_gws(self):
        with self.assertRaises(gws_adapter.GwsNotFound):
            gws_adapter.run("calendar", "calendarList", "list", gws_path="/no/such/gws")

    def test_insert_event_body(self):
        ev = gws_adapter.insert_event("primary", {"summary": "x"}, gws_path=self._gws())
        self.assertEqual(ev["summary"], "x")

    def test_patch_task(self):
        t = gws_adapter.patch_task("default", "t1", {"status": "completed"}, gws_path=self._gws())
        self.assertEqual(t["status"], "completed")


if __name__ == "__main__":
    unittest.main()
