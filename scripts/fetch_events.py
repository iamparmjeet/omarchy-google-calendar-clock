#!/usr/bin/env python3
"""Fetch calendar events for the Omarchy calendar panel as JSON.

Emits one JSON object per line. Each record is either a timed event
(startTime/endTime in HH:MM, local time) or an all-day event, always with
startDate/endDate in YYYY-MM-DD — independent of the user's khal display
formats. Recurring events are expanded by khal inside the query window.

The window is 60 days back and 120 days forward from today, so the panel can
step a few months around today and still have dots without a refetch.

Exit 0 with no output = no events. Exit 2 = no khal config (panel shows a
setup hint). Any other non-zero exit = fetch failed.
"""
import datetime as dt
import json
import sys

import khal.cli_utils
from khal.settings import get_config


def _iso(d):
    return d.strftime("%Y-%m-%d")


def main():
    try:
        conf = get_config()
        collection = khal.cli_utils.build_collection(conf, None)
    except Exception:
        sys.exit(2)

    today = dt.date.today()
    tz = conf["locale"]["local_timezone"]

    start_naive = dt.datetime.combine(today - dt.timedelta(days=60), dt.time.min)
    end_naive = dt.datetime.combine(today + dt.timedelta(days=120), dt.time.max)
    start_local = tz.localize(start_naive)
    end_local = tz.localize(end_naive)

    events = sorted(collection.get_localized(start_local, end_local))
    events += sorted(collection.get_floating(start_naive, end_naive))

    for event in events:
        if event.allday:
            s = event.start if isinstance(event.start, dt.date) else event.start.date()
            e = event.end if isinstance(event.end, dt.date) else event.end.date()
            if e and e > s:
                e = e - dt.timedelta(days=1)
            print(json.dumps({
                "allday": True,
                "startDate": _iso(s),
                "endDate": _iso(e or s),
                "title": str(event.summary),
                "calendar": str(event.calendar),
            }, ensure_ascii=False))
        else:
            s = event.start_local
            e = event.end_local
            print(json.dumps({
                "allday": False,
                "startDate": _iso(s),
                "endDate": _iso(e),
                "startTime": s.strftime("%H:%M"),
                "endTime": e.strftime("%H:%M"),
                "title": str(event.summary),
                "calendar": str(event.calendar),
            }, ensure_ascii=False))


if __name__ == "__main__":
    main()
