#!/usr/bin/env python3
"""Delegation nudge hook (orchestrator delegation budget).

Counts direct tool calls per turn (reset on each user prompt). If a turn
passes NUDGE_AT direct calls with no subagent dispatch, injects a one-line
reminder the model sees via PostToolUse additionalContext. Never blocks.
"""
import fcntl
import json
import sys
import time
from pathlib import Path

NUDGE_AT = 5          # first nudge on this many direct calls in one turn
NUDGE_EVERY = 5       # then again every N further calls
DELEGATION_TOOLS = {"Agent", "Task", "Workflow", "SendMessage"}
STATE_DIR = Path.home() / ".claude" / "hooks" / "state"
STATE_MAX_AGE_S = 7 * 86400

NUDGE = (
    "Delegation nudge (automated, advisory only): {count} direct tool calls this turn "
    "with no subagent dispatch. If meaningful work remains, bundle the remainder into "
    "a subagent per the orchestrator delegation budget. If the turn is nearly done, you are "
    "a subagent yourself, or delegation doesn't fit, continue and ignore this."
)


def state_file(session_id: str) -> Path:
    safe = "".join(c for c in session_id if c.isalnum() or c in "-_")[:80]
    return STATE_DIR / f"budget-{safe or 'default'}.json"


def update(path: Path, fn) -> dict:
    """Atomically read-modify-write the state file under an exclusive lock,
    so parallel tool calls can't lose counts or clobber the delegated flag."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(path, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        try:
            state = json.loads(f.read())
        except Exception:
            state = {"count": 0, "delegated": False}
        state = fn(state)
        f.seek(0)
        f.truncate()
        f.write(json.dumps(state))
    return state


def cleanup_old() -> None:
    now = time.time()
    for f in STATE_DIR.glob("budget-*.json"):
        if now - f.stat().st_mtime > STATE_MAX_AGE_S:
            f.unlink(missing_ok=True)


def main() -> None:
    data = json.load(sys.stdin)
    event = data.get("hook_event_name", "")
    path = state_file(data.get("session_id", "default"))

    if event == "UserPromptSubmit":
        update(path, lambda s: {"count": 0, "delegated": False})
        cleanup_old()
        return

    if event != "PostToolUse":
        return

    tool = data.get("tool_name", "")
    if tool in DELEGATION_TOOLS:
        update(path, lambda s: {**s, "delegated": True})
        return

    state = update(path, lambda s: {**s, "count": s.get("count", 0) + 1})

    n = state["count"]
    if not state["delegated"] and n >= NUDGE_AT and (n - NUDGE_AT) % NUDGE_EVERY == 0:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": NUDGE.format(count=n),
            }
        }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # a nudge hook must never break a session
    sys.exit(0)
