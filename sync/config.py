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
from zoneinfo import ZoneInfoNotFoundError

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
    return "UTC"


DEFAULT_CONFIG = {
    "timezone": _detect_system_timezone(),
    "pastDays": 7,
    "futureDays": 60,
    "gwsPath": "/usr/bin/gws",
    "syncIntervalMin": 5,
    "tasklistIds": [],  # empty = all tasklists
}

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", "~/.config")).expanduser() / "parm.clock"
CONFIG_PATH = CONFIG_DIR / "config.json"

# config.json is user-writable; a file past this size is foreign or corrupt and
# is treated as malformed (defaults) rather than materialized.
MAX_CONFIG_BYTES = 64 * 1024


def load_config(path: Optional[Path] = None) -> dict:
    """Load the sync config, merged over defaults. Never raises.

    A missing, malformed, or oversized file returns the defaults (with
    auto-detected timezone).
    """
    cfg = dict(DEFAULT_CONFIG)
    target = Path(path) if path else CONFIG_PATH
    try:
        # Bounded single-open read; see MAX_CONFIG_BYTES above.
        with target.open("rb") as f:
            raw_bytes = f.read(MAX_CONFIG_BYTES + 1)
        if len(raw_bytes) > MAX_CONFIG_BYTES:
            raise ValueError("config.json exceeds size ceiling")
        raw = json.loads(raw_bytes.decode("utf-8"))
        if isinstance(raw, dict):
            cfg.update({k: v for k, v in raw.items() if k in DEFAULT_CONFIG})
    except (OSError, ValueError):
        pass
    return cfg


def _is_valid_timezone(tz: str) -> bool:
    """True if ``tz`` names a zone the system's zoneinfo can construct.

    Guards ``compute_window`` — ``ZoneInfo`` raises ``ZoneInfoNotFoundError``
    (a ``KeyError``) for unknown names, which no sync handler catches.
    """
    from zoneinfo import ZoneInfo

    try:
        ZoneInfo(tz)
    except (ZoneInfoNotFoundError, ValueError, OSError):
        return False
    return True


def validate_config(cfg: dict) -> list[str]:
    """Return a list of config errors (empty = valid)."""
    errors: list[str] = []

    tz = cfg.get("timezone")
    if not isinstance(tz, str) or not tz:
        errors.append("timezone must be a non-empty string")
    elif not _is_valid_timezone(tz):
        errors.append(f"timezone is not a known IANA zone: {tz!r}")

    # Upper bounds keep the window math inside date/timedelta range; without
    # them an absurd value raises OverflowError out of run_sync.
    caps = {"pastDays": 3650, "futureDays": 3650, "syncIntervalMin": 10080}
    for key, cap in caps.items():
        v = cfg.get(key)
        if not isinstance(v, int) or isinstance(v, bool) or v < 0:
            errors.append(f"{key} must be a non-negative integer")
        elif v > cap:
            errors.append(f"{key} must be at most {cap}")

    gws = cfg.get("gwsPath")
    if not isinstance(gws, str) or not gws:
        errors.append("gwsPath must be a non-empty string")

    if not isinstance(cfg.get("tasklistIds"), list):
        errors.append("tasklistIds must be a list")

    return errors


def save_config(cfg: dict, path: Optional[Path] = None) -> None:
    """Atomically write the config file.

    Like the state cache, the config is private: directory 0700, file 0600
    (re-asserted each write so older 0755/0644 files are tightened).
    """
    target = Path(path) if path else CONFIG_PATH
    target.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(target.parent, 0o700)
    tmp = target.with_suffix(".json.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(json.dumps(cfg, indent=2, sort_keys=True) + "\n")
            f.flush()
            os.fsync(f.fileno())
        tmp.replace(target)
    finally:
        if tmp.exists():
            tmp.unlink()
