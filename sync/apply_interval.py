#!/usr/bin/env python3
"""Apply the chosen sync interval to the systemd user timer.

Called from Panel.qml when the user picks a new interval in Settings, or
manually:

    python3 sync/apply_interval.py 30
    python3 sync/apply_interval.py --from-config

The script:
  1. Resolves the interval (CLI arg wins, else --from-config reads
     sync/config.load_config(), else defaults to 15).
  2. Rewrites ~/.config/systemd/user/parm.clock-sync.timer with the new
     OnUnitActiveSec value.
  3. Runs `systemctl --user daemon-reload` and restarts the timer so the
     new cadence takes effect immediately.
  4. Persists the interval back to ~/.config/parm.clock/config.json (so
     `systemctl --user status` and future setup.sh runs stay consistent).

Exit 0 on success, 1 on bad argument, 2 on I/O failure. Never raises
unhandled.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Allow running as `python3 sync/apply_interval.py` (systemd) and as module.
if __package__ in (None, ""):
    _ROOT = Path(__file__).resolve().parent.parent
    if str(_ROOT) not in sys.path:
        sys.path.insert(0, str(_ROOT))
    from sync.config import DEFAULT_CONFIG, load_config, save_config
else:
    from .config import DEFAULT_CONFIG, load_config, save_config

TIMER_PATH = Path.home() / ".config" / "systemd" / "user" / "parm.clock-sync.timer"
ALLOWED = {5, 15, 30, 60, 120, 240}


def _parse_interval_arg(argv: list[str]) -> int | None:
    if not argv:
        return None
    if argv[0] == "--from-config":
        cfg = load_config()
        n = int(cfg.get("syncIntervalMin", DEFAULT_CONFIG["syncIntervalMin"]))
        return n if n in ALLOWED else DEFAULT_CONFIG["syncIntervalMin"]
    try:
        n = int(argv[0])
    except ValueError:
        print(f"error: interval must be one of {sorted(ALLOWED)}", file=sys.stderr)
        sys.exit(1)
    if n not in ALLOWED:
        print(f"error: interval {n} not allowed; choose one of {sorted(ALLOWED)}", file=sys.stderr)
        sys.exit(1)
    return n


def _timer_content(interval_min: int) -> str:
    return (
        "[Unit]\n"
        f"Description=Sync Google Calendar and Tasks for parm.clock every {interval_min} minutes\n"
        "\n"
        "[Timer]\n"
        "OnBootSec=2min\n"
        f"OnUnitActiveSec={interval_min}min\n"
        "Persistent=true\n"
        "\n"
        "[Install]\n"
        "WantedBy=timers.target\n"
    )


def _write_timer(interval_min: int) -> None:
    TIMER_PATH.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{TIMER_PATH.name}.", suffix=".tmp", dir=TIMER_PATH.parent)
    tmp = Path(tmp_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(_timer_content(interval_min))
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, TIMER_PATH)
    finally:
        if tmp.exists():
            tmp.unlink()


def _reload_timer() -> None:
    # Best-effort: if systemctl is not available (tests, non-systemd env), skip.
    for cmd in (
        ["systemctl", "--user", "daemon-reload"],
        ["systemctl", "--user", "enable", "--now", "parm.clock-sync.timer"],
    ):
        try:
            subprocess.run(cmd, check=False, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pass


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    interval = _parse_interval_arg(args)
    if interval is None:
        # No arg and no --from-config: read current effective config.
        cfg = load_config()
        interval = int(cfg.get("syncIntervalMin", DEFAULT_CONFIG["syncIntervalMin"]))
        if interval not in ALLOWED:
            interval = DEFAULT_CONFIG["syncIntervalMin"]
    try:
        _write_timer(interval)
    except OSError as e:
        print(f"error: could not write timer: {e}", file=sys.stderr)
        return 2
    # Persist back to config.json so setup.sh and load_config stay consistent.
    try:
        cfg = load_config()
        if cfg.get("syncIntervalMin") != interval:
            cfg["syncIntervalMin"] = interval
            save_config(cfg)
    except OSError:
        pass
    _reload_timer()
    print(f"sync interval set to {interval} min ({TIMER_PATH})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
