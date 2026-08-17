#!/usr/bin/env bash
# quota-guard shared library. Sourced by statusline.sh, hooks/*.sh, bin/claude-guarded.
# Everything here reads local, already-cached data — it never calls the Anthropic API,
# so sourcing/running this never consumes plan quota.

QG_DIR="$HOME/.claude/quota-guard"
QG_STATE="$QG_DIR/state.json"
QG_CONFIG="$QG_DIR/config.json"
QG_SKIP_DIR="$QG_DIR/skip"

mkdir -p "$QG_SKIP_DIR" 2>/dev/null

# Stable key for a project directory, used to scope "skip" markers.
qg_project_key() {
  local cwd="${1:-$PWD}"
  cwd="$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")"
  printf '%s' "$cwd" | shasum -a 256 | cut -d' ' -f1
}

# 0 (true) if the check should be bypassed for this session/project.
qg_is_skipped() {
  local session_id="$1" cwd="$2"
  [[ -n "$QUOTA_GUARD_SKIP" ]] && return 0
  [[ -n "$session_id" && -f "$QG_SKIP_DIR/session-$session_id" ]] && return 0
  local pkey
  pkey=$(qg_project_key "$cwd")
  [[ -f "$QG_SKIP_DIR/project-$pkey" ]] && return 0
  return 1
}

qg_fmt_duration() {
  local secs="$1"
  (( secs < 0 )) && secs=0
  local h=$(( secs / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  if (( h > 0 )); then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Prints a human reason and returns 1 if a new Claude call should be blocked right now.
# Returns 0 (with no output) if it's fine to proceed.
qg_check() {
  local session_id="$1" cwd="$2"

  local enabled
  enabled=$(jq -r '.enabled // true' "$QG_CONFIG" 2>/dev/null)
  [[ "$enabled" == "false" ]] && return 0

  qg_is_skipped "$session_id" "$cwd" && return 0

  [[ -f "$QG_STATE" ]] || return 0

  local threshold now
  threshold=$(jq -r '.block_threshold_percent // 100' "$QG_CONFIG" 2>/dev/null)
  now=$(date +%s)

  local window label used resets
  for window in five_hour seven_day; do
    used=$(jq -r ".${window}.used_percentage // empty" "$QG_STATE" 2>/dev/null)
    resets=$(jq -r ".${window}.resets_at // empty" "$QG_STATE" 2>/dev/null)
    [[ -z "$used" || -z "$resets" ]] && continue

    # Reset time already passed: quota has come back, nothing to report.
    (( now >= resets )) && continue

    if awk -v u="$used" -v t="$threshold" 'BEGIN{exit !(u+0>=t+0)}'; then
      label="5-hour session"
      [[ "$window" == "seven_day" ]] && label="7-day (weekly)"
      local wait=$(( resets - now ))
      local resets_str
      resets_str=$(date -r "$resets" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || date -d "@$resets" '+%Y-%m-%d %H:%M %Z' 2>/dev/null)
      printf 'Claude %s quota is exhausted (%s%% used). Resets in %s (%s).' \
        "$label" "$used" "$(qg_fmt_duration "$wait")" "$resets_str"
      return 1
    fi
  done

  return 0
}
