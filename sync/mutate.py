"""CRUD entrypoint for parm.clock.

The QML panel never talks to gws or Google directly — it shells out to this
script, which performs the write via gws and then re-syncs so the panel's
`state.json` reflects the change.

Usage:
    python3 mutate.py <command> [args...]

Commands:
    event-quickadd --calendar <id> --text "Lunch tomorrow 1pm"
    event-add --calendar <id> --title <t> [--date YYYY-MM-DD]
              [--start HH:MM] [--end HH:MM] [--location <s>] [--meet]
    event-delete --calendar <id> --event <eventId>
    task-add --list <id> --title <t> [--due YYYY-MM-DD]
    task-complete --list <id> --task <taskId> [--undo]
    task-delete --list <id> --task <taskId>

After a successful write it runs the sync engine to refresh state.json. Exit
codes mirror gws/sync: 0 ok, 2 auth, 3 api, 4 usage, 5 io.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

_THIS = Path(__file__).resolve().parent
_ROOT = _THIS.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from sync import gws_adapter  # noqa: E402
from sync.config import load_config  # noqa: E402
from sync.schema import parse_date  # noqa: E402
from sync.sync import run_sync  # noqa: E402


def _tz() -> str:
    return load_config().get("timezone", "Asia/Kolkata")


def _fail(kind: str, msg: str) -> int:
    print(f"error: {msg}", file=sys.stderr)
    return {"auth": 2, "api": 3, "usage": 4, "io": 5}.get(kind, 5)


def _event_datetime(date_str: str, time_str: str | None) -> dict:
    """Build a Google EventDateTime from a date + optional time."""
    if time_str:
        tz = _tz()
        return {"dateTime": f"{date_str}T{time_str}:00", "timeZone": tz}
    return {"date": date_str}


def _all_day_end(date_str: str) -> str:
    """All-day events are exclusive-ended; add one day."""
    d = parse_date(date_str)
    if d is None:
        return date_str
    from datetime import timedelta
    return (d + timedelta(days=1)).isoformat()


def _main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="mutate.py")
    sub = parser.add_subparsers(dest="command", required=True)

    qa = sub.add_parser("event-quickadd")
    qa.add_argument("--calendar", required=True)
    qa.add_argument("--text", required=True)

    ea = sub.add_parser("event-add")
    ea.add_argument("--calendar", required=True)
    ea.add_argument("--title", required=True)
    ea.add_argument("--date", required=True)
    ea.add_argument("--start")
    ea.add_argument("--end")
    ea.add_argument("--location", default="")
    ea.add_argument("--meet", action="store_true")

    ed = sub.add_parser("event-delete")
    ed.add_argument("--calendar", required=True)
    ed.add_argument("--event", required=True)

    ta = sub.add_parser("task-add")
    ta.add_argument("--list", required=True)
    ta.add_argument("--title", required=True)
    ta.add_argument("--due")

    tc = sub.add_parser("task-complete")
    tc.add_argument("--list", required=True)
    tc.add_argument("--task", required=True)
    tc.add_argument("--undo", action="store_true")

    td = sub.add_parser("task-delete")
    td.add_argument("--list", required=True)
    td.add_argument("--task", required=True)

    args = parser.parse_args(argv)
    cfg = load_config()
    gws_path = cfg.get("gwsPath")

    try:
        if args.command == "event-quickadd":
            gws_adapter.quick_add_event(args.calendar, args.text, gws_path=gws_path)

        elif args.command == "event-add":
            body = {
                "summary": args.title,
                "start": _event_datetime(args.date, args.start),
            }
            if args.start:
                # Timed event: end required, fall back to start + 1h.
                end_time = args.end or _plus_hour(args.start)
                body["end"] = _event_datetime(args.date, end_time)
            else:
                # All-day: exclusive end.
                body["end"] = {"date": _all_day_end(args.date)}
            if args.location:
                body["location"] = args.location
            if args.meet:
                body["conferenceData"] = {
                    "createRequest": {
                        "requestId": f"parm.clock-{args.title}",
                        "conferenceSolutionKey": {"type": "hangoutsMeet"},
                    }
                }
            gws_adapter.insert_event(args.calendar, body, gws_path=gws_path)

        elif args.command == "event-delete":
            gws_adapter.delete_event(args.calendar, args.event, gws_path=gws_path)

        elif args.command == "task-add":
            body = {"title": args.title}
            if args.due:
                body["due"] = f"{args.due}T00:00:00.000Z"
            gws_adapter.insert_task(args.list, body, gws_path=gws_path)

        elif args.command == "task-complete":
            gws_adapter.patch_task(
                args.list, args.task,
                {"status": "needsAction" if args.undo else "completed"},
                gws_path=gws_path,
            )

        elif args.command == "task-delete":
            gws_adapter.delete_task(args.list, args.task, gws_path=gws_path)

        else:
            return _fail("usage", f"unknown command {args.command}")

    except gws_adapter.AuthError as e:
        return _fail("auth", str(e))
    except gws_adapter.ApiError as e:
        return _fail("api", str(e))
    except gws_adapter.GwsNotFound as e:
        return _fail("io", str(e))
    except gws_adapter.GwsError as e:
        return _fail("api", str(e))

    # Refresh the cached state so the panel reflects the write immediately.
    # Skip the ~3s auth probe (the API calls above already proved the token is
    # valid) and reuse the last-good calendar/tasklist discovery (a write never
    # changes which lists exist) so the refresh is just a parallel event+task
    # re-fetch.
    return run_sync(cfg, gws_path=gws_path, check_auth=False, reuse_discovery=True)


def _plus_hour(hhmm: str) -> str:
    try:
        h, m = int(hhmm[:2]), int(hhmm[3:5])
        total = h * 60 + m + 60
        return f"{total // 60 % 24:02d}:{total % 60:02d}"
    except (ValueError, IndexError):
        return hhmm


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
