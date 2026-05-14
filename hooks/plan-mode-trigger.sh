#!/bin/bash
# Claude Code hook — triggers PRPing menu bar app when permission_mode == "plan".
# Reads hook payload from stdin (JSON) and touches the trigger file.

payload="$(cat 2>/dev/null || true)"

mode="$(printf '%s' "$payload" | /usr/bin/python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get("permission_mode", ""))
' 2>/dev/null)"

if [ "$mode" = "plan" ]; then
    trigger_dir="$HOME/.claude-pr-ping"
    mkdir -p "$trigger_dir"
    /usr/bin/touch "$trigger_dir/trigger"
fi

exit 0
