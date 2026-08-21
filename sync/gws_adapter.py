"""Thin wrapper around the installed gws CLI.

Rules: never guess gws args — this module only uses the
invocation shapes verified against `gws schema` and `gws --help`:

- Invocation: ``gws <service> <resource> <method> --params '{json}' [--json '{json}']``
- Exit codes: 0 ok, 1 API error, 2 auth, 3 validation, 4 discovery, 5 internal.
- Errors are printed to BOTH stdout and stderr as a JSON ``{"error": {...}}``
  (plus a human line on stderr). We parse stdout first and fall back to stderr.

This module has no dependency on the UI and no credential handling — gws owns
tokens; we only invoke it and parse its JSON.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from typing import Any, Optional

# Verified exit codes (gws --help).
EXIT_OK = 0
EXIT_API = 1
EXIT_AUTH = 2
EXIT_VALIDATION = 3
EXIT_DISCOVERY = 4
EXIT_INTERNAL = 5


class GwsError(Exception):
    """Base class for gws adapter failures."""

    def __init__(self, message: str, kind: str, code: Optional[int] = None):
        super().__init__(message)
        self.kind = kind
        self.code = code


class AuthError(GwsError):
    """Authentication is missing or invalid."""

    def __init__(self, message: str, code: Optional[int] = None):
        super().__init__(message, "auth", code)


class ApiError(GwsError):
    """Google rejected the request (non-auth)."""

    def __init__(self, message: str, code: Optional[int] = None):
        super().__init__(message, "api", code)


class GwsNotFound(GwsError):
    """The gws binary is not installed."""

    def __init__(self, message: str):
        super().__init__(message, "missing")


def _find_gws(path_override: Optional[str] = None) -> str:
    """Locate the gws binary, honoring an explicit path override."""
    if path_override:
        return path_override
    found = shutil.which("gws")
    if not found:
        raise GwsNotFound("gws is not installed or not on PATH")
    return found


def _extract_error(raw: str) -> dict:
    """Pull the ``error`` object out of a raw gws output string."""
    try:
        data = json.loads(raw)
        if isinstance(data, dict) and "error" in data:
            return data["error"]
    except (ValueError, TypeError):
        pass
    return {}


def run(
    service: str,
    resource: str,
    method: str,
    params: Optional[dict] = None,
    body: Optional[dict] = None,
    *,
    gws_path: Optional[str] = None,
    timeout: float = 120.0,
) -> dict:
    """Invoke ``gws <service> <resource> <method>`` and return parsed JSON.

    Raises:
        AuthError     on exit code 2 or an ``authError`` reason.
        ApiError      on exit code 1 or any other Google error response.
        GwsError      on validation/discovery/internal failures.
        GwsNotFound   if gws is missing.
    """
    exe = _find_gws(gws_path)

    cmd = [exe, service, resource, method]
    if params:
        cmd += ["--params", json.dumps(params)]
    if body is not None:
        cmd += ["--json", json.dumps(body)]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        raise GwsNotFound(f"gws not found at {exe}")
    except subprocess.TimeoutExpired:
        raise GwsError(f"gws {service} {resource} {method} timed out", "timeout")

    stdout = proc.stdout.strip()
    stderr = proc.stderr.strip()

    # gws writes JSON to stdout; stderr carries human/log lines (e.g. "Using
    # keyring backend: keyring") plus a duplicated error line on failure. Parse
    # stdout first, falling back to stderr only when stdout is empty.
    payload = stdout or stderr

    if proc.returncode == EXIT_AUTH:
        err = _extract_error(stdout) or _extract_error(stderr)
        raise AuthError(err.get("message") or "gws authentication failed", err.get("code"))

    if proc.returncode == EXIT_OK:
        if not payload:
            return {}
        try:
            return json.loads(payload)
        except ValueError:
            # A successful call with a non-JSON body (e.g. a delete that returns
            # nothing) is fine — return an empty dict rather than erroring.
            if not _looks_like_json(stdout):
                return {}
            raise GwsError("gws returned non-JSON output", "parse")

    # Non-zero, non-auth exit.
    err = _extract_error(stdout) or _extract_error(stderr)
    reason = err.get("reason")
    message = err.get("message") or f"gws exited with code {proc.returncode}"

    if reason == "authError" or err.get("code") == 401:
        raise AuthError(message, err.get("code"))
    if proc.returncode == EXIT_API:
        raise ApiError(message, err.get("code"))
    raise GwsError(message, "gws", proc.returncode)


def _looks_like_json(text: str) -> bool:
    return text.startswith("{") or text.startswith("[")


# ---------------------------------------------------------------------------
# Typed helpers for the exact resources we use.
# ---------------------------------------------------------------------------

def auth_status(gws_path: Optional[str] = None) -> dict:
    """``gws auth status`` -> dict with ``auth_method`` (may be ``none``).

    Note: this is a two-word subcommand (``gws auth status``), not the usual
    ``<service> <resource> <method>`` shape, and it exits 0 even when
    unauthenticated — callers must inspect ``auth_method``.
    """
    exe = _find_gws(gws_path)
    proc = subprocess.run([exe, "auth", "status"], capture_output=True, text=True, timeout=30.0)
    payload = (proc.stdout or proc.stderr).strip()
    if proc.returncode != 0:
        err = _extract_error(proc.stdout) or _extract_error(proc.stderr)
        raise AuthError(err.get("message") or "gws auth status failed", err.get("code"))
    if not payload:
        return {}
    try:
        return json.loads(payload)
    except ValueError:
        return {}


def _list_all(
    service: str,
    resource: str,
    method: str,
    params: dict,
    *,
    gws_path: Optional[str] = None,
) -> list[dict]:
    """Page through a gws ``list`` method until ``nextPageToken`` is exhausted.

    All Google list endpoints cap the page size (tasks: 100, events: 2500,
    calendars/tasklists: a few hundred) and hand back a ``nextPageToken``. A
    single un-paged call would silently truncate a large account, so every list
    helper funnels through here.
    """
    items: list[dict] = []
    page_token: Optional[str] = None
    while True:
        p = dict(params)
        if page_token:
            p["pageToken"] = page_token
        data = run(service, resource, method, params=p, gws_path=gws_path)
        if not isinstance(data, dict):
            return items
        items.extend(data.get("items", []) or [])
        page_token = data.get("nextPageToken")
        if not page_token:
            return items


def list_calendars(gws_path: Optional[str] = None) -> list[dict]:
    """``gws calendar calendarList list`` -> list of CalendarListEntry dicts."""
    return _list_all("calendar", "calendarList", "list", {}, gws_path=gws_path)


def list_events(
    calendar_id: str,
    time_min: str,
    time_max: str,
    *,
    single_events: bool = True,
    order_by: str = "startTime",
    gws_path: Optional[str] = None,
) -> list[dict]:
    """``gws calendar events list`` within [timeMin, timeMax)."""
    params = {
        "calendarId": calendar_id,
        "timeMin": time_min,
        "timeMax": time_max,
        "singleEvents": single_events,
        "orderBy": order_by,
        "maxResults": 2500,
    }
    return _list_all("calendar", "events", "list", params, gws_path=gws_path)


def list_tasklists(gws_path: Optional[str] = None) -> list[dict]:
    """``gws tasks tasklists list`` -> list of TaskList dicts."""
    return _list_all("tasks", "tasklists", "list", {"maxResults": 100}, gws_path=gws_path)


def list_tasks(
    tasklist_id: str,
    *,
    due_min: Optional[str] = None,
    due_max: Optional[str] = None,
    show_completed: bool = False,
    gws_path: Optional[str] = None,
) -> list[dict]:
    """``gws tasks tasks list`` for one task list."""
    params: dict[str, Any] = {
        "tasklist": tasklist_id,
        "showCompleted": show_completed,
        "maxResults": 100,
    }
    if due_min:
        params["dueMin"] = due_min
    if due_max:
        params["dueMax"] = due_max
    return _list_all("tasks", "tasks", "list", params, gws_path=gws_path)


# Write operations (used by the CRUD wiring in a later phase).

def insert_event(calendar_id: str, event: dict, *, gws_path: Optional[str] = None) -> dict:
    """``gws calendar events insert``."""
    return run("calendar", "events", "insert", params={"calendarId": calendar_id}, body=event, gws_path=gws_path)


def patch_event(calendar_id: str, event_id: str, patch: dict, *, gws_path: Optional[str] = None) -> dict:
    """``gws calendar events patch``."""
    return run("calendar", "events", "patch", params={"calendarId": calendar_id, "eventId": event_id}, body=patch, gws_path=gws_path)


def delete_event(calendar_id: str, event_id: str, *, gws_path: Optional[str] = None) -> dict:
    """``gws calendar events delete``."""
    return run("calendar", "events", "delete", params={"calendarId": calendar_id, "eventId": event_id}, gws_path=gws_path)


def quick_add_event(calendar_id: str, text: str, *, gws_path: Optional[str] = None) -> dict:
    """``gws calendar events quickAdd``."""
    return run("calendar", "events", "quickAdd", params={"calendarId": calendar_id, "text": text}, gws_path=gws_path)


def insert_task(tasklist_id: str, task: dict, *, gws_path: Optional[str] = None) -> dict:
    """``gws tasks tasks insert``."""
    return run("tasks", "tasks", "insert", params={"tasklist": tasklist_id}, body=task, gws_path=gws_path)


def patch_task(tasklist_id: str, task_id: str, patch: dict, *, gws_path: Optional[str] = None) -> dict:
    """``gws tasks tasks patch``."""
    return run("tasks", "tasks", "patch", params={"tasklist": tasklist_id, "task": task_id}, body=patch, gws_path=gws_path)


def delete_task(tasklist_id: str, task_id: str, *, gws_path: Optional[str] = None) -> dict:
    """``gws tasks tasks delete``."""
    return run("tasks", "tasks", "delete", params={"tasklist": tasklist_id, "task": task_id}, gws_path=gws_path)
