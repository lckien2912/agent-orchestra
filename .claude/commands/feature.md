---
description: Implement one feature of a workspace repository by running that repository's /feature.
argument-hint: <repo-key> <feat-id>  e.g. api feat-3
---

Arguments: `$ARGUMENTS` = `<repo-key> <feat-id>`; the key maps to a folder in
`.claude/orchestra.json` (`repos.<key>.dir`). Stop and ask if either is
missing or the key is unknown.

Prefer running it in a session opened in the repository folder (its own
settings, hooks and commands load natively). If it runs here, you are the
Supervisor: load the `task-routing` skill, score `<feat-id>`
(`node .claude/scripts/feature.mjs <repo-key> <feat-id>`), and delegate it to
the repo's worker (`repos.<key>.worker`) with a brief that says to follow
`<repo>/.claude/commands/feature.md` for `<feat-id>` (worktree via
`cd <repo> && bash scripts/new-worktree.sh …`). Then run the QA loop and
report.

A frontend feature that depends on a backend feature (`<backend-repo> feat-N`)
starts only when that one is `pass` in the backend's `feature_list.json`,
unless its criteria say it builds against a typed mock.
