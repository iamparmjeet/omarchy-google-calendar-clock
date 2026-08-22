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
import selectors
import shutil
import subprocess
import sys
import time
from typing import Any, Optional

# Verified exit codes (gws --help).
EXIT_OK = 0
EXIT_API = 1
EXIT_AUTH = 2
EXIT_VALIDATION = 3
EXIT_DISCOVERY = 4
EXIT_INTERNAL = 5

# Hard bounds so a runaway or hostile gws/Google response cannot exhaust
# memory: a byte cap per response, a page and item cap per list call.
MAX_RESPONSE_BYTES = 16 * 1024 * 1024
MAX_LIST_PAGES = 20
MAX_LIST_ITEMS = 5000


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


def _run_capped(cmd: list[str], *, timeout: float) -> tuple[int, str, str]:
    """Run ``cmd`` capturing both streams with a hard per-stream byte cap.

    ``subprocess.run(capture_output=True)`` buffers unbounded output. Here a
    stream past ``MAX_RESPONSE_BYTES`` kills the child and raises GwsError
    (kind="limit") instead of growing the buffer further.
    """
    deadline = time.monotonic() + timeout
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
    except FileNotFoundError:
        raise GwsNotFound(f"gws not found at {cmd[0]}") from None

    # bufsize=0 so each read() is one os.read: it returns whatever is ready
    # (select already said the fd is readable) and never blocks for more.
    chunks = {proc.stdout: bytearray(), proc.stderr: bytearray()}
    sel = selectors.DefaultSelector()
    try:
        for stream in chunks:
            sel.register(stream, selectors.EVENT_READ)
        open_streams = len(chunks)
        while open_streams:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(cmd, timeout)
            for key, _ in sel.select(timeout=remaining):
                chunk = key.fileobj.read(65536)
                if not chunk:
                    sel.unregister(key.fileobj)
                    open_streams -= 1
                    continue
                buf = chunks[key.fileobj]
                buf.extend(chunk)
                if len(buf) > MAX_RESPONSE_BYTES:
                    raise GwsError(
                        f"gws output exceeded {MAX_RESPONSE_BYTES} bytes (runaway response)",
                        "limit",
                    )
        proc.wait(timeout=max(0.0, deadline - time.monotonic()))
        return (
            proc.returncode,
            chunks[proc.stdout].decode("utf-8", "replace"),
            chunks[proc.stderr].decode("utf-8", "replace"),
        )
    except BaseException:
        # Any exit path that leaves the child alive must reap it.
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        raise
    finally:
        sel.close()
        # Popen leaves the pipe fds open until GC; close them deterministically
        # so capped reads don't leak fds / raise ResourceWarnings under -W error.
        for stream in chunks:
            stream.close()


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
        GwsError      on validation/discovery/internal/limit failures.
        GwsNotFound   if gws is missing.
    """
    exe = _find_gws(gws_path)

    cmd = [exe, service, resource, method]
    if params:
        cmd += ["--params", json.dumps(params)]
    if body is not None:
        cmd += ["--json", json.dumps(body)]

    try:
        proc_returncode, stdout_raw, stderr_raw = _run_capped(cmd, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise GwsError(f"gws {service} {resource} {method} timed out", "timeout") from None

    stdout = stdout_raw.strip()
    stderr = stderr_raw.strip()

    # gws writes JSON to stdout; stderr carries human/log lines (e.g. "Using
    # keyring backend: keyring") plus a duplicated error line on failure. Parse
    # stdout first, falling back to stderr only when stdout is empty.
    payload = stdout or stderr

    if proc_returncode == EXIT_AUTH:
        err = _extract_error(stdout) or _extract_error(stderr)
        raise AuthError(err.get("message") or "gws authentication failed", err.get("code"))

    if proc_returncode == EXIT_OK:
        if not payload:
            return {}
        try:
            return json.loads(payload)
        except ValueError:
            # A successful call with a non-JSON body (e.g. a delete that returns
            # nothing) is fine — return an empty dict rather than erroring.
            if not _looks_like_json(stdout):
                return {}
            raise GwsError("gws returned non-JSON output", "parse") from None

    # Non-zero, non-auth exit.
    err = _extract_error(stdout) or _extract_error(stderr)
    reason = err.get("reason")
    message = err.get("message") or f"gws exited with code {proc_returncode}"

    if reason == "authError" or err.get("code") == 401:
        raise AuthError(message, err.get("code"))
    if proc_returncode == EXIT_API:
        raise ApiError(message, err.get("code"))
    raise GwsError(message, "gws", proc_returncode)


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
    returncode, out, err_out = _run_capped([exe, "auth", "status"], timeout=30.0)
    payload = (out or err_out).strip()
    if returncode != 0:
        err = _extract_error(out) or _extract_error(err_out)
        raise AuthError(err.get("message") or "gws auth status failed", err.get("code"))
    if not payload:
        return {}
    try:
        return json.loads(payload)
    except ValueError:
        return {}


def _warn_truncated(what: str, limit: str) -> None:
    print(f"warning: {what} exceeded {limit}; results truncated", file=sys.stderr)


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
    helper funnels through here. Pagination itself is bounded by
    ``MAX_LIST_PAGES`` / ``MAX_LIST_ITEMS``: past a cap we stop and keep what
    we have (with a stderr warning) rather than let a runaway or hostile
    server grow the aggregate without limit.
    """
    items: list[dict] = []
    page_token: Optional[str] = None
    pages = 0
    while True:
        pages += 1
        p = dict(params)
        if page_token:
            p["pageToken"] = page_token
        data = run(service, resource, method, params=p, gws_path=gws_path)
        if not isinstance(data, dict):
            return items
        items.extend(data.get("items", []) or [])
        if len(items) >= MAX_LIST_ITEMS:
            _warn_truncated(f"{service}.{resource}.list", f"{MAX_LIST_ITEMS} items")
            return items[:MAX_LIST_ITEMS]
        page_token = data.get("nextPageToken")
        if not page_token:
            return items
        if pages >= MAX_LIST_PAGES:
            _warn_truncated(f"{service}.{resource}.list", f"{MAX_LIST_PAGES} pages")
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
