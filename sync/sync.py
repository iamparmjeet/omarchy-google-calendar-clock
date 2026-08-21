"""Sync engine for parm.clock — fetch Google Calendar + Tasks and atomically
write ``~/.local/state/parm.clock/state.json``.

Pipeline:

    load+validate config
    -> verify gws exists
    -> auth check (gws auth status)
    -> calendarList.list -> filter calendars
    -> tasklists.list
    -> window (pastDays / futureDays)
    -> events.list per calendar (singleEvents=true, orderBy=startTime)
    -> tasks.list per list (due window)
    -> normalize -> dedupe -> sort -> validate
    -> merge syncStatus
    -> atomic write (tmp -> fsync -> rename)

Exit codes: 0 ok, 2 auth, 3 api, 4 config, 5 io. On any failure a previously
valid ``state.json`` is preserved.
"""

from __future__ import annotations

import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from itertools import count
from pathlib import Path
from typing import Optional
from zoneinfo import ZoneInfo

# Unique-per-process counter for atomic_write temp names (see atomic_write).
_TMP_COUNTER = count()

# Allow running both as ``python3 sync/sync.py`` (systemd) and as a package
# module (``python3 -m sync.sync`` or tests importing ``sync.sync``).
if __package__ in (None, ""):
    _ROOT = Path(__file__).resolve().parent.parent
    if str(_ROOT) not in sys.path:
        sys.path.insert(0, str(_ROOT))
    from sync import gws_adapter
    from sync.config import DEFAULT_CONFIG, load_config, validate_config
    from sync.schema import empty_state, normalize_event, normalize_task, utc_now, validate_state
else:
    from . import gws_adapter
    from .config import DEFAULT_CONFIG, load_config, validate_config
    from .schema import empty_state, normalize_event, normalize_task, utc_now, validate_state
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", "~/.local/state")).expanduser() / "parm.clock"
STATE_PATH = STATE_DIR / "state.json"


def now_iso() -> str:
    return utc_now().isoformat().replace("+00:00", "Z")


def compute_window(cfg: dict, tz_name: str) -> tuple[str, str]:
    """Return (timeMin, timeMax) RFC3339 bounds for the sync window.

    timeMin is the lower bound on an event's *end*; timeMax the upper bound on
    its *start* (per the Calendar API). We widen by pastDays/futureDays from
    today, using the local timezone so the window aligns to local days.
    """
    tz = ZoneInfo(tz_name)
    today = datetime.now(tz).date()
    start = datetime.combine(today - timedelta(days=int(cfg.get("pastDays", 7))), datetime.min.time(), tzinfo=tz)
    end = datetime.combine(today + timedelta(days=int(cfg.get("futureDays", 60)) + 1), datetime.min.time(), tzinfo=tz)
    return start.isoformat(), end.isoformat()


def filter_calendars(calendars: list[dict], cfg: dict) -> list[dict]:
    """Drop calendars Google itself marks hidden.

    The plugin's own ``hiddenCalendars`` UI setting (shell.json) is applied at
    display time by the panel; it must NOT be applied here, or a hidden
    calendar vanishes from state.json and can never be re-toggled in settings.
    """
    return [cal for cal in calendars if not cal.get("hidden")]


def filter_tasklists(tasklists: list[dict], cfg: dict) -> list[dict]:
    allow = set(cfg.get("tasklistIds", []))
    if not allow:
        return tasklists
    return [tl for tl in tasklists if tl.get("id") in allow]


def dedupe(events: list[dict]) -> list[dict]:
    """Remove duplicate events (same id in multiple calendars), keep first."""
    seen: set[str] = set()
    out: list[dict] = []
    for ev in events:
        key = ev.get("id")
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(ev)
    return out


def sort_events(events: list[dict]) -> list[dict]:
    def key(ev: dict):
        return (ev.get("dateKey") or "", ev.get("start") or "")
    return sorted(events, key=key)


def sort_tasks(tasks: list[dict]) -> list[dict]:
    def key(t: dict):
        return (t.get("due") or "9999-99-99", t.get("title") or "")
    return sorted(tasks, key=key)


def atomic_write(path: Path, data: str) -> None:
    """Write ``data`` to ``path`` atomically (tmp -> fsync -> rename).

    The temp file is unique per writer (pid + counter) so that two concurrent
    syncs — e.g. the systemd timer firing while a post-write refresh is still
    writing — never share a tmp path and interleave into a corrupt rename.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.tmp.{os.getpid()}.{next(_TMP_COUNTER)}")
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        tmp.replace(path)
    finally:
        if tmp.exists():
            tmp.unlink()


def load_last_good(target: Optional[Path] = None) -> Optional[dict]:
    """Return the current state.json if it validates, else None."""
    path = target or STATE_PATH
    try:
        raw = path.read_text(encoding="utf-8")
        state = json.loads(raw)
    except (OSError, ValueError):
        return None
    if validate_state(state):
        return None
    return state


def build_state(
    calendars: list[dict],
    events: list[dict],
    tasklists: list[dict],
    tasks: list[dict],
    timezone: str,
    sync_state: str,
    message: str,
    last_ok: Optional[str],
) -> dict:
    return {
        "version": 1,
        "syncedAt": now_iso(),
        "source": "google",
        "timezone": timezone,
        "calendars": [
            {
                "id": c.get("id", ""),
                "name": c.get("summary") or c.get("summaryOverride") or c.get("name") or c.get("id", ""),
                "color": c.get("backgroundColor") or c.get("color") or "",
                "visible": True,
                "primary": bool(c.get("primary")),
            }
            for c in calendars
        ],
        "events": events,
        "tasklists": [{"id": t.get("id", ""), "title": t.get("title") or ""} for t in tasklists],
        "tasks": tasks,
        "syncStatus": {"state": sync_state, "message": message, "lastOk": last_ok},
    }


def run_sync(
    cfg: Optional[dict] = None,
    *,
    gws_path: Optional[str] = None,
    state_path: Optional[Path] = None,
    fetch: bool = True,
    check_auth: bool = True,
    reuse_discovery: bool = False,
) -> int:
    """Run one full sync. Returns a process exit code.

    ``fetch=False`` performs validation + atomic write of an empty state only
    (used in tests and pre-auth bootstrap). ``check_auth=False`` skips the
    explicit ``gws auth status`` probe (which costs ~3s decrypting the keyring);
    real API calls still fail with an AuthError if the token is invalid.
    ``reuse_discovery=True`` skips calendar/tasklist discovery and reuses the
    lists from the last-good state (fast post-write refresh).
    """
    global STATE_PATH
    target = state_path or STATE_PATH

    if cfg is None:
        cfg = load_config()
    else:
        # Merge over defaults so partial configs (e.g. from tests) validate.
        cfg = {**DEFAULT_CONFIG, **cfg}

    config_errors = validate_config(cfg)
    if config_errors:
        _preserve_or_emit_failure(target, cfg, "error", "; ".join(config_errors))
        return 4

    timezone = cfg.get("timezone") or DEFAULT_CONFIG["timezone"]

    # Locate gws.
    try:
        exe = gws_adapter._find_gws(gws_path or cfg.get("gwsPath"))
    except gws_adapter.GwsNotFound as e:
        _preserve_or_emit_failure(target, cfg, "error", str(e))
        return 5

    if not fetch:
        state = empty_state(timezone, "never", "not yet synced")
        atomic_write(target, json.dumps(state, indent=2, ensure_ascii=False) + "\n")
        return 0

    try:
        # Auth check: any auth failure raises AuthError and we stop.
        if check_auth:
            auth = gws_adapter.auth_status(exe)
            if auth.get("auth_method") in (None, "none"):
                raise gws_adapter.AuthError("not authenticated — run `gws auth login`")

        if reuse_discovery:
            prior = load_last_good(target)
            if prior is None:
                # No prior state to lean on — fall back to full discovery.
                reuse_discovery = False
            else:
                calendars = prior.get("calendars", [])
                tasklists = prior.get("tasklists", [])

        if not reuse_discovery:
            raw_calendars = gws_adapter.list_calendars(exe)
            calendars = filter_calendars(raw_calendars, cfg)
            raw_tasklists = gws_adapter.list_tasklists(exe)
            tasklists = filter_tasklists(raw_tasklists, cfg)

        calendar_ids = [c["id"] for c in calendars]
        tasklist_ids = [t["id"] for t in tasklists]

        time_min, time_max = compute_window(cfg, timezone)

        events: list[dict] = []

        def _fetch_events(cal_id: str) -> list[dict]:
            out: list[dict] = []
            try:
                for raw in gws_adapter.list_events(cal_id, time_min, time_max, gws_path=exe):
                    if raw.get("status") == "cancelled":
                        continue
                    out.append(normalize_event(raw, cal_id, timezone))
            except (gws_adapter.AuthError, gws_adapter.ApiError):
                # Auth/API failures must NOT be swallowed: swallowing them here
                # would let an expired token (check_auth=False refresh) write an
                # empty "ok" state over the last-good state. Re-raise so the
                # outer handler preserves last-good.
                raise
            except gws_adapter.GwsError:
                # One calendar failing transiently (timeout, discovery) should
                # not abort the whole sync; that calendar is skipped.
                pass
            return out

        def _fetch_tasks(tl_id: str) -> list[dict]:
            out: list[dict] = []
            try:
                for raw in gws_adapter.list_tasks(tl_id, due_max=time_max, show_completed=True, gws_path=exe):
                    normalized = normalize_task(raw, tl_id)
                    # Recent-only filter for completed tasks: keep completed only if
                    # completed within last 30 days, to avoid syncing hundreds of
                    # historical tasks while still showing recent completions mixed
                    # with open tasks. Undated completed without timestamp is kept
                    # if due is undated (user just completed it).
                    if normalized.get("status") == "completed":
                        comp = normalized.get("completed") or ""
                        if comp:
                            try:
                                from sync.schema import parse_datetime
                                dt = parse_datetime(comp)
                                if dt is not None:
                                    age_days = (utc_now() - dt).total_seconds() / 86400
                                    if age_days > 30:
                                        continue
                            except Exception:
                                pass
                    out.append(normalized)
            except (gws_adapter.AuthError, gws_adapter.ApiError):
                raise
            except gws_adapter.GwsError:
                pass
            return out

        with ThreadPoolExecutor(max_workers=6) as pool:
            event_futures = {pool.submit(_fetch_events, c): "event" for c in calendar_ids}
            task_futures = {pool.submit(_fetch_tasks, t["id"]): "task" for t in tasklists}

            events = []
            tasks = []
            for fut in as_completed(list(event_futures) + list(task_futures)):
                kind = event_futures.get(fut) or task_futures.get(fut)
                if kind == "event":
                    events.extend(fut.result())
                else:
                    tasks.extend(fut.result())

        events = sort_events(dedupe(events))
        tasks = sort_tasks(tasks)

        state = build_state(
            calendars, events, tasklists, tasks,
            timezone, "ok", "", now_iso(),
        )

        errors = validate_state(state)
        if errors:
            # Do NOT overwrite good state with an invalid document.
            _preserve_or_emit_failure(target, cfg, "error", "invalid state: " + "; ".join(errors))
            return 3

        atomic_write(target, json.dumps(state, indent=2, ensure_ascii=False) + "\n")
        return 0

    except gws_adapter.AuthError as e:
        _preserve_or_emit_failure(target, cfg, "auth", str(e))
        return 2
    except gws_adapter.ApiError as e:
        _preserve_or_emit_failure(target, cfg, "error", str(e))
        return 3
    except gws_adapter.GwsError as e:
        # Validation/discovery/timeout/internal gws failures. Not auth and not
        # a Google API rejection, but still not success — preserve last-good.
        _preserve_or_emit_failure(target, cfg, "error", str(e))
        return 3
    except gws_adapter.GwsNotFound as e:
        _preserve_or_emit_failure(target, cfg, "error", str(e))
        return 5
    except OSError as e:
        _preserve_or_emit_failure(target, cfg, "error", f"io error: {e}")
        return 5


def _preserve_or_emit_failure(target: Path, cfg: dict, sync_state: str, message: str) -> None:
    """Preserve last-good state; if none exists, write a valid error state."""
    if load_last_good(target) is not None:
        # A valid prior state exists; leave it untouched (syncStatus stays as
        # it was last time). We surface the failure via stderr only.
        print(f"sync failed ({sync_state}): {message}", file=sys.stderr)
        return
    # No good state yet — emit a valid empty document marked with the failure,
    # so the UI still has something schema-valid to render.
    state = empty_state(cfg.get("timezone") or DEFAULT_CONFIG["timezone"], sync_state, message)
    try:
        atomic_write(target, json.dumps(state, indent=2, ensure_ascii=False) + "\n")
    except OSError:
        pass


def main(argv: Optional[list[str]] = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    gws_path = None
    if "--gws" in args:
        gws_path = args[args.index("--gws") + 1]
    return run_sync(gws_path=gws_path)


if __name__ == "__main__":
    sys.exit(main())
