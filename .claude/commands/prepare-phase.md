---
description: Plan phase N in one workspace repository or all of them, by running each repository's own /prepare-phase.
argument-hint: <repo-key|all> <phase-number>  e.g. all 1
---

Arguments: `$ARGUMENTS` = `<repo-key|all> <N>`; keys and folders are in
`.claude/orchestra.json`. Stop and ask if either is missing.

For each repository, read `<repo>/.claude/commands/prepare-phase.md` and
follow it with `$ARGUMENTS` replaced by `<N>`, treating `<repo>/` as the
repository root: relative paths are inside it, git runs as `git -C <repo>`,
scripts as `bash <repo>/scripts/…`.

With `all`:

- plan the backend first, so its feature ids exist when the frontend is
  planned;
- every frontend feature that calls an endpoint names the backend feature that
  delivers it (`<backend-repo> feat-N`) and the contract it expects;
- one approval step covers every plan and the cross-repo dependencies; then
  write and commit each repository separately.
