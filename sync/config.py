"""Plugin configuration for parm.clock.

Loads and validates the user's settings. Config lives in two places:

- ``shell.json`` (Omarchy) under the ``parm.clock`` entry — the QML-facing keys
  (badge, layout, calendar visibility) that the shell already persists.
- A small JSON file at ``~/.config/parm.clock/config.json`` for the sync-only
  keys (window, interval, timezone, gws path override) that QML never needs.

The sync engine only reads what it needs and always falls back to sane defaults
so a missing config file is not a failure.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Optional

from .schema import SYNC_STATES  # noqa: F401  (re-export convenience)

def _detect_system_timezone() -> str:
    """Best-effort detection of the host's IANA timezone.

    Mirrors the logic in scripts/setup.sh so a user who installs via
    the marketplace but never runs setup.sh still gets a correct local
    timezone instead of a hardcoded fallback.
    """
    try:
        tz_path = Path("/etc/timezone")
        if tz_path.is_file():
            text = tz_path.read_text(encoding="utf-8").strip()
            if text:
                return text
    except (OSError, ValueError):
        pass
    try:
        localtime = Path("/etc/localtime")
        if localtime.is_symlink():
            target = str(localtime.resolve())
            if "/zoneinfo/" in target:
                return target.split("/zoneinfo/", 1)[1]
        elif localtime.exists():
            # Fallback: ask the system via datetime
            from datetime import datetime as _dt

            tzname = _dt.now().astimezone().tzinfo
            if tzname is not None:
                key = getattr(tzname, "key", None)
                if key:
                    return str(key)
    except (OSError, ValueError, AttributeError):
        pass
    return "Asia/Kolkata"


DEFAULT_CONFIG = {
    "timezone": _detect_system_timezone(),
    "pastDays": 7,
    "futureDays": 60,
    "gwsPath": "/usr/bin/gws",
    "syncIntervalMin": 5,
    "hiddenCalendars": [],
    "tasklistIds": [],  # empty = all tasklists
}

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser() / "parm.clock"
CONFIG_PATH = CONFIG_DIR / "config.json"


def load_config(path: Optional[Path] = None) -> dict:
    """Load the sync config, merged over defaults. Never raises.

    A missing or malformed file returns the defaults (with auto-detected timezone).
    """
    cfg = dict(DEFAULT_CONFIG)
    target = Path(path) if path else CONFIG_PATH
    try:
        raw = json.loads(target.read_text(encoding="utf-8"))
        if isinstance(raw, dict):
            cfg.update({k: v for k, v in raw.items() if k in DEFAULT_CONFIG})
    except (OSError, ValueError):
        pass
    return cfg


def validate_config(cfg: dict) -> list[str]:
    """Return a list of config errors (empty = valid)."""
    errors: list[str] = []

    tz = cfg.get("timezone")
    if not isinstance(tz, str) or not tz:
        errors.append("timezone must be a non-empty string")

    for key in ("pastDays", "futureDays", "syncIntervalMin"):
        v = cfg.get(key)
        if not isinstance(v, int) or isinstance(v, bool) or v < 0:
            errors.append(f"{key} must be a non-negative integer")

    gws = cfg.get("gwsPath")
    if not isinstance(gws, str) or not gws:
        errors.append("gwsPath must be a non-empty string")

    if not isinstance(cfg.get("hiddenCalendars"), list):
        errors.append("hiddenCalendars must be a list")

    if not isinstance(cfg.get("tasklistIds"), list):
        errors.append("tasklistIds must be a list")

    return errors


def save_config(cfg: dict, path: Optional[Path] = None) -> None:
    """Atomically write the config file."""
    target = Path(path) if path else CONFIG_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(cfg, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(target)
