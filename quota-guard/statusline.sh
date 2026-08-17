#!/usr/bin/env bash
# Claude Code statusLine script. Claude Code invokes this on every render and feeds it
# the rate_limits it already fetched for its own UI (five_hour/seven_day windows) — this
# is the only channel that exposes plan quota without an extra API call. We cache
# whatever we're handed and print a compact status line.

source "$HOME/.claude/quota-guard/lib.sh"

input=$(cat)

rl=$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [[ -n "$rl" && "$rl" != "null" ]]; then
  jq -n --argjson rl "$rl" --arg ts "$(date +%s)" '{updated_at: ($ts | tonumber)} + $rl' \
    > "$QG_STATE.tmp" 2>/dev/null && mv "$QG_STATE.tmp" "$QG_STATE"
fi

display=$(jq -r '.statusline_display // true' "$QG_CONFIG" 2>/dev/null)
[[ "$display" == "false" ]] && exit 0

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
dir=$(basename "$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty' 2>/dev/null)")
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

line="[$model] ${dir:-.}"
[[ -n "$ctx" ]] && line="$line | ctx ${ctx%%.*}%"
[[ -n "$five" ]] && line="$line | 5h ${five%%.*}%"
[[ -n "$week" ]] && line="$line | wk ${week%%.*}%"

printf '%s\n' "$line"
