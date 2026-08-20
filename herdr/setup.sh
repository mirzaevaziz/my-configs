#!/usr/bin/env bash
# Installs the herdr Claude Code + pi.dev subagent wiring from this repo
# into the live locations herdr/Claude Code expect. Copies (not symlinks),
# matching this repo's snapshot convention. Idempotent.
#
# Usage: ./herdr/setup.sh
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dest="$HOME/.agents/skills/herdr"
hooks_dest="$HOME/.claude/hooks"
settings_file="$HOME/.claude/settings.json"

mkdir -p "$skills_dest/scripts" "$hooks_dest"
cp "$repo_dir/skills/SKILL.md" "$skills_dest/SKILL.md"
cp "$repo_dir/skills/scripts/claude_pane.py" "$skills_dest/scripts/claude_pane.py"
cp "$repo_dir/skills/scripts/pi_pane.py" "$skills_dest/scripts/pi_pane.py"
cp "$repo_dir/hooks/herdr-subagent-redirect.sh" "$hooks_dest/herdr-subagent-redirect.sh"
cp "$repo_dir/hooks/herdr-agent-state.sh" "$hooks_dest/herdr-agent-state.sh"

# ~/.claude/skills/herdr must resolve to $skills_dest so Claude Code loads
# the skill (matches the live machine's layout).
mkdir -p "$HOME/.claude/skills"
ln -sfn "../../.agents/skills/herdr" "$HOME/.claude/skills/herdr"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found — install jq, then re-run to merge settings.json hooks." >&2
  exit 1
fi

[ -f "$settings_file" ] || echo '{}' > "$settings_file"

pretooluse_entry=$(jq -n --arg cmd "bash '$hooks_dest/herdr-subagent-redirect.sh'" '
  {matcher: "Task|Agent", hooks: [{type: "command", command: $cmd, timeout: 10}]}
')
sessionstart_entry=$(jq -n --arg cmd "bash '$hooks_dest/herdr-agent-state.sh' session" '
  {matcher: "*", hooks: [{type: "command", command: $cmd, timeout: 10}]}
')

jq \
  --argjson pretooluse "$pretooluse_entry" \
  --argjson sessionstart "$sessionstart_entry" \
  '
  .hooks.PreToolUse //= [] |
  .hooks.PreToolUse |=
    (if any(.[]; .matcher == "Task|Agent") then . else . + [$pretooluse] end) |
  .hooks.SessionStart //= [] |
  .hooks.SessionStart |=
    (if any(.[]; .hooks[0].command // "" | test("herdr-agent-state")) then . else . + [$sessionstart] end)
  ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"

echo "herdr subagent wiring installed."
