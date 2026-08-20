#!/bin/bash
# Block in-process Claude Code subagents inside Herdr; redirect to herdr tabs.
# Grill-settled 2026-08-20: all subagents run as claude sessions in labeled tabs.
[ "${HERDR_ENV:-}" = "1" ] || exit 0
cat >/dev/null
cat >&2 <<'MSG'
In-process subagents are disabled inside Herdr. Do NOT retry this tool and do NOT do the work yourself.
Instead, immediately re-issue this exact delegation as a Bash tool call:
  python3 ~/.claude/skills/herdr/scripts/claude_pane.py delegate --prompt '<the same task prompt>' [--agent-type <subagent_type>] [--model <m>]
This spawns the delegate as a claude session in its own Herdr tab and prints one JSON line.
For several delegates: add --no-wait to each, then harvest each with
  python3 ~/.claude/skills/herdr/scripts/claude_pane.py collect --name <agent_name>
On success the JSON contains the delegate's full report and its tab is auto-closed.
MSG
exit 2
