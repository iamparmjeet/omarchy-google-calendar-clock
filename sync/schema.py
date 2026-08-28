"""Normalized calendar/task schema and validation for parm.clock.

Defines the v1 data contract that ``~/.local/state/parm.clock/state.json`` must
satisfy, plus pure helpers to coerce raw Google shapes into it. This module is
imported by both the sync engine and the unit tests, and must stay free of any
gws/network/QML dependency so it can be tested in isolation.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timezone
from typing import Any, Optional

SCHEMA_VERSION = 1

# RFC3339 with a mandatory offset, e.g. 2026-08-20T10:30:00+05:30 or ...Z
RFC3339_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)

# Local date only, e.g. 2026-08-20
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

SYNC_STATES = ("ok", "auth", "error", "never")
TASK_STATUSES = ("needsAction", "completed")

# Per-field length caps applied at normalization. Item-count limits alone do
# not bound a document: a single event description can carry megabytes. These
# caps bound every free-text field an event or task contributes to state.json,
# so the aggregate is a function of item count, not of remote content size.
MAX_TITLE_CHARS = 512
MAX_NOTES_CHARS = 4096
MAX_URL_CHARS = 2048
MAX_SYNC_MESSAGE_CHARS = 2048
MAX_EVENT_SPAN_DAYS = 90
MAX_ID_CHARS = 512


def clip(value: Any, limit: int) -> str:
    """Coerce to str and truncate to ``limit`` characters."""
    if not isinstance(value, str):
        value = "" if value is None else str(value)
    return value[:limit]

#: Fields required on every normalized event record.
EVENT_REQUIRED = {"id", "calendarId", "title", "start", "end", "allDay", "dateKey"}
#: Fields required on every normalized task record.
TASK_REQUIRED = {"id", "listId", "title", "status"}


def local_date_key(d: date) -> str:
    """Return the local ``YYYY-MM-DD`` identity for a ``datetime.date``."""
    return d.strftime("%Y-%m-%d")


def _clamped_end_date(start: date, end: date) -> date:
    """Keep an event end within the display expansion window without overflow."""
    limit = start.toordinal() + MAX_EVENT_SPAN_DAYS - 1
    return date.fromordinal(min(end.toordinal(), limit, date.max.toordinal()))


def parse_datetime(value: Any) -> Optional[datetime]:
    """Parse an RFC3339 string into a timezone-aware ``datetime``, else ``None``.

    Accepts both ``Z`` and ``+HH:MM`` offsets. Naive values (no offset) are
    rejected so callers never guess a timezone.
    """
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None
    # Reject naive timestamps: every timestamp we accept carries an offset.
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        return None
    return parsed


def parse_date(value: Any) -> Optional[date]:
    """Parse a ``YYYY-MM-DD`` string into a ``date``, else ``None``."""
    if not isinstance(value, str) or not DATE_RE.match(value):
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def _missing(obj: dict, field: str) -> bool:
    return obj.get(field) is None or obj.get(field) == ""


def valid_id(value: Any) -> bool:
    return isinstance(value, str) and 0 < len(value) <= MAX_ID_CHARS


def validate_state(state: Any) -> list[str]:
    """Validate a state document against the v1 schema.

    Returns a list of human-readable error strings. An empty list means the
    document is valid.
    """
    errors: list[str] = []
    if not isinstance(state, dict):
        return ["state must be an object"]

    if state.get("version") != SCHEMA_VERSION:
        errors.append(f"version must be {SCHEMA_VERSION}")

    if not isinstance(state.get("syncedAt"), str) or not RFC3339_RE.match(str(state.get("syncedAt")) or ""):
        errors.append("syncedAt must be an RFC3339 timestamp")

    if state.get("source") != "google":
        errors.append('source must be "google"')

    if not isinstance(state.get("timezone"), str) or not state.get("timezone"):
        errors.append("timezone must be a non-empty string")

    if not isinstance(state.get("calendars"), list):
        errors.append("calendars must be a list")
    else:
        for i, cal in enumerate(state["calendars"]):
            errors.extend(f"calendars[{i}] {e}" for e in validate_calendar(cal))

    if not isinstance(state.get("events"), list):
        errors.append("events must be a list")
    else:
        for i, ev in enumerate(state["events"]):
            errors.extend(f"events[{i}] {e}" for e in validate_event(ev))

    if not isinstance(state.get("tasklists"), list):
        errors.append("tasklists must be a list")
    else:
        for i, tl in enumerate(state["tasklists"]):
            errors.extend(f"tasklists[{i}] {e}" for e in validate_tasklist(tl))

    if not isinstance(state.get("tasks"), list):
        errors.append("tasks must be a list")
    else:
        for i, task in enumerate(state["tasks"]):
            errors.extend(f"tasks[{i}] {e}" for e in validate_task(task))

    errors.extend(f"syncStatus {e}" for e in validate_sync_status(state.get("syncStatus")))

    return errors


def validate_calendar(cal: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(cal, dict):
        return ["must be an object"]
    if not valid_id(cal.get("id")):
        errors.append("id must be a non-empty string within the length limit")
    if not cal.get("name"):
        errors.append("missing name")
    if "visible" in cal and not isinstance(cal.get("visible"), bool):
        errors.append("visible must be a boolean")
    if "primary" in cal and not isinstance(cal.get("primary"), bool):
        errors.append("primary must be a boolean")
    return errors


def validate_event(ev: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(ev, dict):
        return ["must be an object"]

    for field in EVENT_REQUIRED:
        if field not in ev:
            errors.append(f"missing required field '{field}'")

    for field in ("id", "calendarId"):
        if field in ev and not valid_id(ev.get(field)):
            errors.append(f"{field} must be a non-empty string within the length limit")

    if "allDay" in ev and not isinstance(ev.get("allDay"), bool):
        errors.append("allDay must be a boolean")

    if "start" in ev and not isinstance(ev.get("start"), str):
        errors.append("start must be a string")

    if "end" in ev and not isinstance(ev.get("end"), str):
        errors.append("end must be a string")

    if "dateKey" in ev:
        dk = ev.get("dateKey")
        # "" means "local day unknown" (unparseable start) — tolerated so one
        # bad event can't invalidate the whole state document.
        if not isinstance(dk, str) or (dk != "" and not DATE_RE.match(dk)):
            errors.append("dateKey must be YYYY-MM-DD")

    if "recurring" in ev and not isinstance(ev.get("recurring"), bool):
        errors.append("recurring must be a boolean")

    return errors


def validate_tasklist(tl: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(tl, dict):
        return ["must be an object"]
    if not valid_id(tl.get("id")):
        errors.append("id must be a non-empty string within the length limit")
    if not tl.get("title"):
        errors.append("missing title")
    return errors


def validate_task(task: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(task, dict):
        return ["must be an object"]

    for field in TASK_REQUIRED:
        if field not in task:
            errors.append(f"missing required field '{field}'")

    for field in ("id", "listId"):
        if field in task and not valid_id(task.get(field)):
            errors.append(f"{field} must be a non-empty string within the length limit")

    if "status" in task and task.get("status") not in TASK_STATUSES:
        errors.append(f"status must be one of {TASK_STATUSES}")

    if "due" in task and task.get("due") not in (None, ""):
        due = task.get("due")
        if not isinstance(due, str) or not (DATE_RE.match(due) or RFC3339_RE.match(due)):
            errors.append("due must be YYYY-MM-DD or RFC3339")

    if "completed" in task and task.get("completed") not in (None, ""):
        if not isinstance(task.get("completed"), str) or not RFC3339_RE.match(task.get("completed")):
            errors.append("completed must be an RFC3339 timestamp or null")

    return errors


def validate_sync_status(ss: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(ss, dict):
        return ["must be an object"]

    if ss.get("state") not in SYNC_STATES:
        errors.append(f"state must be one of {SYNC_STATES}")

    if "message" in ss:
        if not isinstance(ss.get("message"), str):
            errors.append("message must be a string")
        elif len(ss["message"]) > MAX_SYNC_MESSAGE_CHARS:
            errors.append(f"message must be at most {MAX_SYNC_MESSAGE_CHARS} characters")

    if "lastOk" in ss and ss.get("lastOk") is not None:
        if not isinstance(ss.get("lastOk"), str) or not RFC3339_RE.match(ss.get("lastOk")):
            errors.append("lastOk must be an RFC3339 timestamp or null")

    return errors


# ---------------------------------------------------------------------------
# Normalization of raw Google shapes -> internal schema
# ---------------------------------------------------------------------------

def normalize_event(raw: dict, calendar_id: str, timezone: str) -> dict:
    """Normalize a raw Google Calendar event into the v1 event record.

    Uses the EventDateTime shape from ``gws schema calendar.Event``: ``start``
    and ``end`` are objects with either ``dateTime`` (RFC3339) or ``date``
    (``YYYY-MM-DD`` for all-day). Recurring instances carry ``recurringEventId``.
    """
    if not isinstance(raw, dict):
        raw = {}
    start = raw.get("start") if isinstance(raw.get("start"), dict) else {}
    end = raw.get("end") if isinstance(raw.get("end"), dict) else {}

    all_day = "date" in start and "dateTime" not in start
    start_raw = start.get("dateTime") if not all_day else start.get("date")
    end_raw = end.get("dateTime") if not all_day else end.get("date")
    if not isinstance(start_raw, str):
        start_raw = ""
    if not isinstance(end_raw, str):
        end_raw = ""

    if all_day:
        start_date = parse_date(start_raw)
        dk = local_date_key(start_date) if start_date is not None else ""
        # Google all-day end is exclusive; collapse it to the inclusive end
        # date so the UI model can span multi-day events without off-by-one.
        end_date = parse_date(end_raw)
        if start_date is None:
            end_raw = ""
        elif end_date is not None and end_date > start_date:
            inclusive_end = end_date - _timedelta_days(1)
            end_raw = local_date_key(_clamped_end_date(start_date, inclusive_end))
        else:
            end_raw = dk
    else:
        dt = parse_datetime(start_raw)
        dk = ""
        if dt is not None:
            try:
                from zoneinfo import ZoneInfo
                local = dt.astimezone(ZoneInfo(timezone))
                dk = local_date_key(local.date())
            except Exception:
                dk = ""

    # The last local day the event occupies. Emitted here rather than derived in
    # the UI, because the local day of an RFC3339 end is a timezone question and
    # slicing the first ten characters answers it with the organizer's offset
    # instead of the viewer's.
    if all_day:
        edk = end_raw or dk
    else:
        edk = dk
        end_dt = parse_datetime(end_raw)
        if end_dt is not None:
            try:
                from zoneinfo import ZoneInfo
                end_local = end_dt.astimezone(ZoneInfo(timezone))
                # An event ending at exactly midnight belongs to the day that
                # just closed, not to the one starting — 22:00-00:00 is one
                # evening, not two days.
                if end_local.hour == 0 and end_local.minute == 0:
                    end_local = end_local - _timedelta_days(1)
                edk = local_date_key(end_local.date())
            except Exception:
                edk = dk
        if edk < dk:
            edk = dk

    if dk and edk:
        start_date = parse_date(dk)
        end_date = parse_date(edk)
        if start_date is not None and end_date is not None:
            edk = local_date_key(_clamped_end_date(start_date, end_date))
    elif not dk:
        edk = ""

    return {
        "id": raw.get("id", ""),
        "calendarId": calendar_id,
        "title": clip(raw.get("summary") or "", MAX_TITLE_CHARS),
        "start": start_raw or "",
        "end": end_raw or "",
        "allDay": all_day,
        "dateKey": dk,
        "endDateKey": edk,
        "location": clip(raw.get("location") or "", MAX_TITLE_CHARS),
        "description": clip(raw.get("description") or "", MAX_NOTES_CHARS),
        "htmlLink": clip(raw.get("htmlLink") or "", MAX_URL_CHARS),
        "meetUrl": clip(_meet_url(raw), MAX_URL_CHARS),
        "recurring": bool(raw.get("recurringEventId") or raw.get("recurrence")),
    }


def _timedelta_days(n: int):
    import datetime as _dt
    return _dt.timedelta(days=n)


def _meet_url(raw: dict) -> str:
    conference = raw.get("conferenceData") if isinstance(raw, dict) else {}
    conference = conference if isinstance(conference, dict) else {}
    points = conference.get("entryPoints") or []
    if not isinstance(points, list):
        points = []
    for p in points:
        if isinstance(p, dict) and p.get("entryPointType") == "video" and p.get("uri"):
            return p["uri"]
    return (raw.get("hangoutLink") or "") if isinstance(raw, dict) else ""


def normalize_task(raw: dict, list_id: str) -> dict:
    """Normalize a raw Google Task into the v1 task record.

    ``due`` is normalized to a local ``YYYY-MM-DD`` date (Google stores it as an
    RFC3339 timestamp whose time-of-day is meaningless).
    """
    if not isinstance(raw, dict):
        raw = {}
    due = raw.get("due") or ""
    if not isinstance(due, str):
        due = ""
    parsed = parse_datetime(due)
    if parsed is not None:
        due = parsed.date().isoformat()
    return {
        "id": raw.get("id", ""),
        "listId": list_id,
        "title": clip(raw.get("title") or "", MAX_TITLE_CHARS),
        "notes": clip(raw.get("notes") or "", MAX_NOTES_CHARS),
        "due": due,
        "status": raw.get("status") if isinstance(raw.get("status"), str) and raw.get("status") in TASK_STATUSES else "needsAction",
        "completed": raw.get("completed") if isinstance(raw.get("completed"), str) else "",
    }


def empty_state(timezone: str = "UTC", sync_state: str = "never", message: str = "") -> dict:
    """Return a minimal, valid v1 state document (used before the first sync).

    ``timezone`` should be the detected local zone; callers that have one must
    pass it explicitly (the "UTC" default is only a last resort).
    """
    return {
        "version": SCHEMA_VERSION,
        "syncedAt": utc_now().isoformat().replace("+00:00", "Z"),
        "source": "google",
        "timezone": timezone,
        "calendars": [],
        "events": [],
        "tasklists": [],
        "tasks": [],
        "syncStatus": {"state": sync_state, "message": message, "lastOk": None},
    }
