# claude-quota-guard

Stops Claude Code from spending prompts once your Claude.ai plan quota (5-hour session
window or 7-day/weekly window) is exhausted, and automatically starts allowing calls
again the moment the window resets — no daemon, no polling, no extra API calls of its
own.

## How it works

Claude Code's `statusLine` feature is fed a `rate_limits` object (`five_hour` /
`seven_day`, each with `used_percentage` and `resets_at`) after the first reply in a
session — this is the same data Claude Code's own UI uses, handed to your status line
script for free. This repo's `statusline.sh` caches that to
`~/.claude/quota-guard/state.json` on every render.

A `UserPromptSubmit` hook then reads that cache (no API call) before every prompt you
send. If a window is at 100% and its `resets_at` hasn't passed yet, it blocks the prompt
(exit 2, prompt never sent) with a message telling you when it resets. Once `resets_at`
passes, the same check auto-allows again — that's the "resume" trigger, it's just a fresh
read of the clock, checked on your next attempt.

A `SessionStart` hook does the same check purely to warn you immediately if a new session
opens already over quota, instead of letting you burn your first prompt finding out.

Slash commands (anything starting with `/`) are always exempt from the block — they're
local CLI operations, not free-form model turns, and this is also what keeps
`/quota-guard skip ...` itself reachable even while blocked.

For anywhere outside an interactive session — cron, `/loop`, `/schedule`, scripts — hooks
never fire, so `bin/claude-guarded` is a drop-in wrapper for the `claude` CLI that runs
the same cached check before deciding whether to launch `claude` at all.

## Install

```sh
git clone github:ruoxijiang/claude_quota_guard
cd claude_quota_guard
./install.sh
```

Requires `jq`. Installs into `~/.claude/quota-guard/` and
`~/.claude/skills/quota-guard/`, and merges a `statusLine` + two hooks into
`~/.claude/settings.json` (existing keys are preserved). Safe to re-run — it updates the
scripts but never overwrites an existing `config.json` or your `skip/` markers. Takes
effect in new Claude Code sessions.

## Usage

- `/quota-guard` — show current 5-hour / weekly usage and reset times, and whether a skip
  is active
- `/quota-guard skip session` — bypass the guard for just the current session
- `/quota-guard skip project` — bypass it for every session opened in the current
  directory
- `/quota-guard unskip session|project|all` — remove those bypasses
- `/quota-guard enable` / `disable` — toggle the guard globally (every project/session)

All of the above also work as a standalone CLI, independent of Claude Code entirely —
useful if a prompt-level lockout ever happens again, or for scripting:

```sh
~/.claude/quota-guard/bin/quota-guard status
~/.claude/quota-guard/bin/quota-guard skip-project
```

For scripted/background invocations, use the wrapper instead of `claude` directly:

```sh
~/.claude/quota-guard/bin/claude-guarded -p "..."
```

## Config

`~/.claude/quota-guard/config.json`:

```json
{
  "enabled": true,
  "block_threshold_percent": 100,
  "statusline_display": true
}
```

- `block_threshold_percent` — lower it (e.g. `95`) to leave a safety margin instead of
  blocking only at true exhaustion.
- `statusline_display` — set `false` to keep the background quota caching but hide the
  status line text.

## Limitations

- `rate_limits` only appears after the first reply of a session, so a fresh cache with no
  data yet fails open (allows).
- Only tracks Claude.ai subscription plan windows (Pro/Max), not API-key/pay-per-token
  usage.

## License

MIT
