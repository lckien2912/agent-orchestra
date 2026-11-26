---
description: Close the current milestone of a workspace repository by running that repository's /cleanup-sprint, then promote repeated owner decisions into the harness.
argument-hint: <repo-key> [next-milestone]  e.g. api p2-accounts
---

Arguments: `$ARGUMENTS` = `<repo-key> [next-milestone]`; the key maps to a
folder in `.claude/orchestra.json`. Stop and ask if the repository is missing.

Read `<repo>/.claude/commands/cleanup-sprint.md` and follow it with
`$ARGUMENTS` replaced by `[next-milestone]`, treating `<repo>/` as the
repository root (git as `git -C <repo>`, scripts as `bash <repo>/scripts/…`).

Then, before the commit step, review `owner-decisions.md` (task-routing §10):
list the rows with `Repeats ≥ 2` or a "from now on" request whose `Harness`
is still `not yet`, propose for each the rule text and where it goes (this
repo's `AGENTS.md`, an agent prompt, a skill, `task-routing`), apply the ones
the owner accepts (rules in `.harness/` or gates are Protected Decisions:
ask), and fill the `Harness` column. Report what was promoted and what was
left.
