"""Unit tests for the v1 schema, validation, and normalization.

Run from the plugin root: ``python3 -m unittest discover -s tests -v``
"""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sync import schema  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def load_fixture(name):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class TestDateTimeParsing(unittest.TestCase):
    def test_parse_datetime_z(self):
        dt = schema.parse_datetime("2026-08-20T09:00:00Z")
        self.assertIsNotNone(dt)
        self.assertEqual(dt.utcoffset().total_seconds(), 0)

    def test_parse_datetime_offset(self):
        dt = schema.parse_datetime("2026-08-20T09:00:00+05:30")
        self.assertEqual(dt.utcoffset().total_seconds(), 5.5 * 3600)

    def test_parse_datetime_naive_rejected(self):
        self.assertIsNone(schema.parse_datetime("2026-08-20T09:00:00"))

    def test_parse_datetime_garbage(self):
        self.assertIsNone(schema.parse_datetime("not a date"))

    def test_parse_date(self):
        self.assertEqual(schema.parse_date("2026-08-20").isoformat(), "2026-08-20")

    def test_parse_date_rejects_time(self):
        self.assertIsNone(schema.parse_date("2026-08-20T09:00:00Z"))


class TestEventNormalization(unittest.TestCase):
    def test_timed_event(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["timed"], "primary", "Asia/Kolkata")
        self.assertFalse(ev["allDay"])
        self.assertEqual(ev["title"], "Team meeting")
        self.assertEqual(ev["dateKey"], "2026-08-20")
        self.assertEqual(ev["location"], "Room 4")
        self.assertFalse(ev["recurring"])

    def test_timed_utc_to_kolkata(self):
        # 2026-03-29T00:30:00Z = 06:00 IST (Kolkata is UTC+5:30, no DST).
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["timed_utc"], "primary", "Asia/Kolkata")
        self.assertEqual(ev["dateKey"], "2026-03-29")

    def test_allday(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["allday"], "primary", "Asia/Kolkata")
        self.assertTrue(ev["allDay"])
        self.assertEqual(ev["dateKey"], "2026-08-15")
        # Exclusive Google end (08-16) collapses to inclusive 08-15.
        self.assertEqual(ev["end"], "2026-08-15")

    def test_allday_multiday_inclusive_end(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["allday_multiday"], "primary", "Asia/Kolkata")
        self.assertTrue(ev["allDay"])
        self.assertEqual(ev["start"], "2026-08-18")
        self.assertEqual(ev["end"], "2026-08-20")  # exclusive 08-21 -> inclusive 08-20

    def test_cross_midnight(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["cross_midnight"], "primary", "Asia/Kolkata")
        self.assertEqual(ev["dateKey"], "2026-08-20")

    def test_recurring_instance_flagged(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["recurring_instance"], "primary", "Asia/Kolkata")
        self.assertTrue(ev["recurring"])

    def test_meet_url(self):
        fx = load_fixture("events.json")
        ev = schema.normalize_event(fx["with_meet"], "primary", "Asia/Kolkata")
        self.assertEqual(ev["meetUrl"], "https://meet.google.com/abc-defg-hij")


class TestTaskNormalization(unittest.TestCase):
    def test_task_due(self):
        fx = load_fixture("tasks.json")
        t = schema.normalize_task(fx["task_needs_action_due_today"], "default")
        self.assertEqual(t["status"], "needsAction")
        self.assertEqual(t["title"], "Reply to email")
        self.assertIn("2026-08-20", t["due"])

    def test_task_no_due(self):
        fx = load_fixture("tasks.json")
        t = schema.normalize_task(fx["task_needs_action_no_due"], "default")
        self.assertEqual(t["due"], "")

    def test_task_completed(self):
        fx = load_fixture("tasks.json")
        t = schema.normalize_task(fx["task_completed"], "default")
        self.assertEqual(t["status"], "completed")


class TestValidation(unittest.TestCase):
    def test_golden_state_valid(self):
        state = load_fixture("state.golden.json")
        self.assertEqual(schema.validate_state(state), [])

    def test_empty_state_valid(self):
        self.assertEqual(schema.validate_state(schema.empty_state()), [])

    def test_bad_version(self):
        state = load_fixture("state.golden.json")
        state["version"] = 99
        self.assertTrue(any("version" in e for e in schema.validate_state(state)))

    def test_missing_event_field(self):
        state = load_fixture("state.golden.json")
        del state["events"][0]["title"]
        self.assertTrue(any("title" in e for e in schema.validate_state(state)))

    def test_bad_sync_state(self):
        state = load_fixture("state.golden.json")
        state["syncStatus"]["state"] = "bogus"
        self.assertTrue(any("state" in e for e in schema.validate_state(state)))

    def test_bad_task_status(self):
        state = load_fixture("state.golden.json")
        state["tasks"][0]["status"] = "weird"
        self.assertTrue(any("status" in e for e in schema.validate_state(state)))

    def test_non_object_state(self):
        self.assertEqual(schema.validate_state(None), ["state must be an object"])


class TestConfig(unittest.TestCase):
    def test_defaults_valid(self):
        from sync import config
        self.assertEqual(config.validate_config(config.load_config(Path("/nonexistent"))), [])

    def test_bad_timezone(self):
        from sync import config
        cfg = dict(config.DEFAULT_CONFIG)
        cfg["timezone"] = ""
        self.assertTrue(any("timezone" in e for e in config.validate_config(cfg)))


if __name__ == "__main__":
    unittest.main()
