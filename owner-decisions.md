# Owner decisions and requests

The Supervisor adds one row **the moment** the owner decides, asks for or
corrects something (in chat, at a slice approval, answering a question).
Rules: `task-routing` §10.

- **Repeats**: how many times the owner said the same thing (a new row says
  `see #N` and bumps `Repeats` on the original row).
- **Harness**: `not yet` | where it became a rule (`<repo>/AGENTS.md §…`,
  `.claude/agents/…`, `task-routing §…`) | `no` (one-off, with the reason).
- At `/cleanup-sprint`: rows with `Repeats ≥ 2`, or that the owner said "from
  now on", whose `Harness` is still `not yet` → into the harness through a
  normal review, then update the column.
- A feature's business decisions still go in the repo's `progress.md` ›
  Decisions; here, add one short row pointing to it.

| #   | Date | Owner said / decided | Applies to | Done | Repeats | Harness |
| --- | ---- | -------------------- | ---------- | ---- | ------- | ------- |
