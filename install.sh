#!/usr/bin/env bash
# Installs quota-guard into ~/.claude/. Safe to re-run: overwrites the scripts/skill
# (the code), but never touches quota-guard/config.json, state.json, or skip/ markers
# if they already exist (your local settings and skip state).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
QG_DIR="$CLAUDE_DIR/quota-guard"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq >/dev/null || { echo "install.sh requires jq" >&2; exit 1; }

mkdir -p "$QG_DIR/hooks" "$QG_DIR/bin" "$QG_DIR/skip" "$CLAUDE_DIR/skills/quota-guard"

cp "$REPO_DIR/quota-guard/lib.sh" "$QG_DIR/lib.sh"
cp "$REPO_DIR/quota-guard/statusline.sh" "$QG_DIR/statusline.sh"
cp "$REPO_DIR/quota-guard/hooks/user-prompt-submit.sh" "$QG_DIR/hooks/user-prompt-submit.sh"
cp "$REPO_DIR/quota-guard/hooks/session-start.sh" "$QG_DIR/hooks/session-start.sh"
cp "$REPO_DIR/quota-guard/bin/claude-guarded" "$QG_DIR/bin/claude-guarded"
cp "$REPO_DIR/quota-guard/bin/quota-guard" "$QG_DIR/bin/quota-guard"
cp "$REPO_DIR/skills/quota-guard/SKILL.md" "$CLAUDE_DIR/skills/quota-guard/SKILL.md"

[[ -f "$QG_DIR/config.json" ]] || cp "$REPO_DIR/quota-guard/config.json" "$QG_DIR/config.json"

chmod +x "$QG_DIR/lib.sh" "$QG_DIR/statusline.sh" "$QG_DIR/hooks/"*.sh "$QG_DIR/bin/"*

[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

tmp=$(mktemp)
jq --arg statusline "$QG_DIR/statusline.sh" \
   --arg sessionstart "$QG_DIR/hooks/session-start.sh" \
   --arg promptsubmit "$QG_DIR/hooks/user-prompt-submit.sh" '
  .statusLine = {"type": "command", "command": $statusline}
  | .hooks = (.hooks // {})
  | .hooks.SessionStart = (
      ((.hooks.SessionStart // []) + [{
        "matcher": "*",
        "hooks": [{"type": "command", "command": $sessionstart, "timeout": 5}]
      }]) | unique_by(.hooks[0].command)
    )
  | .hooks.UserPromptSubmit = (
      ((.hooks.UserPromptSubmit // []) + [{
        "matcher": "*",
        "hooks": [{"type": "command", "command": $promptsubmit, "timeout": 5}]
      }]) | unique_by(.hooks[0].command)
    )
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "quota-guard installed."
echo "  scripts:  $QG_DIR"
echo "  skill:    $CLAUDE_DIR/skills/quota-guard"
echo "  settings: $SETTINGS (statusLine + SessionStart/UserPromptSubmit hooks)"
echo
echo "Takes effect in new Claude Code sessions. Try '/quota-guard status' or run"
echo "  $QG_DIR/bin/quota-guard status"
echo "directly in a terminal any time."
