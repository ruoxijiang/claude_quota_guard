#!/usr/bin/env bash
# UserPromptSubmit hook: runs locally before the prompt is sent to Claude, reads only the
# cached quota state written by statusline.sh, and blocks (exit 2) if quota is exhausted.
# This adds no API calls of its own.

source "$HOME/.claude/quota-guard/lib.sh"

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
prompt=$(printf '%s' "$input" | jq -r '.user_prompt // empty' 2>/dev/null)
trimmed=$(printf '%s' "$prompt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# Never block slash commands. They're local CLI operations (not free-form model turns),
# and this is also what keeps '/quota-guard skip ...' itself always reachable even when
# quota is exhausted — don't narrow this to just "/quota-guard", a lockout here means the
# user has no way back in from inside the chat at all.
case "$trimmed" in
  /*) exit 0 ;;
esac

if reason=$(qg_check "$session_id" "$cwd"); then
  exit 0
fi

{
  echo "$reason"
  echo
  echo "To bypass: '/quota-guard skip session' or '/quota-guard skip project'."
  echo "If that ever doesn't work, run this in a plain terminal (no Claude involved):"
  echo "  ~/.claude/quota-guard/bin/quota-guard skip-project"
} >&2
exit 2
