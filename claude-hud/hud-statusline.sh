#!/bin/bash
# claude-hud wrapper: bars stay while context + usage fit one row; dropped when they would wrap.
# Usage: hud-statusline.sh [columns]   (columns overrides stty, for testing)
# No /dev/tty under Claude Code's statusline, so read the size from the parent's terminal.
tty=$(ps -o tty= -p $PPID | tr -d ' ')
cols=${1:-$(stty size 2>/dev/null <"/dev/$tty" | awk '{print $2}')}
cols=${cols:-${COLUMNS:-120}}
export COLUMNS=$(( cols > 4 ? cols - 4 : 1 ))
plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ '{ print $(NF-1) "\t" $(0) }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)

"/opt/homebrew/bin/node" "${plugin_dir}dist/index.js" | awk '
  function nobar(s) { gsub(/\033\[[0-9;]*m(█)*\033\[2m(░)*\033\[0m /, "", s); return s }
  function flush() { if (held != "") print held; held = ""; joined = 0 }
  /\033\[2mContext/ && !/\033\[2mUsage/ { flush(); held = $0; next }
  held != "" && /\033\[2mUsage/ { held = nobar(held) " │ " nobar($0); joined = 1; next }
  joined && /\033\[2mWeekly/ { held = held " | " nobar($0); next }
  { flush(); print }
  END { flush() }
' | sed -E 's/[(]resets in ([^)]*)[)]/\1/g; s/.[[]2m(Context|Usage|Weekly) *.[[]0m //g'
