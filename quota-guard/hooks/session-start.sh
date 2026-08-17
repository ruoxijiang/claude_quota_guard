#!/usr/bin/env bash
# SessionStart hook: informational only (SessionStart hooks can't block). Warns immediately
# if quota is already exhausted, instead of letting the first prompt get silently blocked.

source "$HOME/.claude/quota-guard/lib.sh"

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

if reason=$(qg_check "$session_id" "$cwd"); then
  exit 0
fi

echo "quota-guard: $reason" >&2
echo "Prompts in this session will be blocked until it resets. Run '/quota-guard skip session' to override." >&2
exit 2
