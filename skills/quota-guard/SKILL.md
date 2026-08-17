---
name: quota-guard
description: Check cached Claude plan quota (5-hour session / weekly windows) and manage the pre-call quota guard — skip it for this session or this project, or turn it back on.
---

Handle `/quota-guard $ARGUMENTS` by shelling out to the standalone CLI at
`~/.claude/quota-guard/bin/quota-guard` — don't reimplement its logic, don't call any
Anthropic API, and don't invoke the `claude` CLI. Just map arguments to the subcommand and
run it, then relay its output tersely (a line or two, not a report).

Mapping from `$ARGUMENTS` (case-insensitive, trim whitespace):
- (empty) / "status" → `quota-guard status`
- "skip session" → `quota-guard skip-session`
- "skip project" → `quota-guard skip-project`
- "unskip session" → `quota-guard unskip-session`
- "unskip project" → `quota-guard unskip-project`
- "unskip" / "unskip all" → `quota-guard unskip-all`
- "on" / "enable" → `quota-guard enable`
- "off" / "disable" → `quota-guard disable` — first warn this disables the guard
  everywhere (every project/session), and confirm the user wants that rather than a
  scoped `skip session`/`skip project`, unless they were already explicit about it.
- anything else → print the usage line the CLI itself prints for an unknown subcommand.

If this whole prompt gets blocked before you ever see it (the `UserPromptSubmit` hook
should never do that for a `/`-prefixed prompt, but if it somehow does), the user still
has a way out that doesn't touch this skill or that hook at all: running
`~/.claude/quota-guard/bin/quota-guard skip-project` directly in a plain terminal. Mention
that once if they bring up ever getting stuck; otherwise no need to bring it up.
