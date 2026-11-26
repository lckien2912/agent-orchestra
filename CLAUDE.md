# <Project> workspace

This folder holds independent git repositories, each with its own harness
(see [harness-template](https://github.com/lckien2912/harness-template)), and
the shared design documents. The repositories are listed in
`.claude/orchestra.json`; keep this table in step with it:

| Key   | Repo        | What                          | Contract              |
| ----- | ----------- | ----------------------------- | --------------------- |
| `api` | `backend/`  | <backend stack, one line>     | `backend/AGENTS.md`   |
| `ui`  | `frontend/` | <frontend stack, one line>    | `frontend/AGENTS.md`  |

Design: <design documents at the root, e.g. `docs/system-design.md`>; owner
plans in `<repo>/docs/plans/` (phase plans in `<repo>/docs/phases/`).
Market for competitor research (slice step 2): <e.g. online learning in
Vietnam>.

`<workspace>` in agent prompts and briefs is the absolute path of this folder;
the Supervisor writes it out in every brief (workers run in worktrees).

## Rules

- This folder's own git, if any, tracks only the orchestra files (`.claude/`,
  `slices/`, `owner-decisions.md`, docs); the repositories are ignored.
- Before touching a repo, read its `AGENTS.md` and `progress.md`; they apply
  in full. Run its gates with `bash <repo>/init.sh`.
- Git per repo: `git -C <repo> …`. Worktrees: run
  `bash scripts/new-worktree.sh …` from inside the repo.
- Hooks here forward each call to the guard and post-edit hooks of the repo it
  touches (`.claude/hooks/dispatch.sh`); rules live only in `<repo>/.harness/`.
- This folder coordinates and owns cross-repo contracts; implementation goes
  to the agents `backend-worker` and `frontend-worker` (`.claude/agents/`,
  project knowledge in their prompts, craft skills preloaded), or to a session
  opened in the repo folder. Backend first when a frontend task needs a new
  endpoint; pass the shipped contract from the `backend-worker` report to
  `frontend-worker`.
- Craft skills live in the repos (`<repo>/.claude/skills/`) and are linked
  here (`ln -s ../../<repo>/.claude/skills/<name> .claude/skills/<name>`);
  only `task-routing` (orchestration) lives in `.claude/skills/`.

## Orchestra

The main session here is the Supervisor (subagents: this does not apply to
you). A task from the owner is the Supervisor's to run end to end: it splits,
orders and delegates without asking, and asks only when the flow, business
rules, scope or an approved contract would change, or the decision is the
owner's (`task-routing` §7). Every owner decision or request goes into
`owner-decisions.md` when it is made; repeats become harness rules at
`/cleanup-sprint` (§10). Before delegating engineering work, load the
`task-routing` skill and follow it: score complexity, pass an explicit `model`
on every Agent call, brief workers so they do not re-explore, QA every change,
ask the owner before HIGH plans and Protected Decisions.

| Agent                                | Model                     | Role                                                   |
| ------------------------------------ | ------------------------- | ------------------------------------------------------ |
| `analyst`                            | sonnet                    | slice steps 1–4: business, competitors, proposal, flow |
| `researcher`                         | haiku                     | read-only file map, trace logic                        |
| `backend-worker` / `frontend-worker` | sonnet                    | implement in the backend / frontend repo               |
| `architect`                          | opus                      | HIGH: trade-offs, risks, plan; read-only               |
| `reviewer`                           | sonnet (opus if security) | diff review, APPROVE / REQUEST_CHANGES                 |
| `debugger`                           | sonnet → opus             | reproduce, root cause, minimal fix                     |

Helpers: `node .claude/scripts/feature.mjs <repo-key> [--list | <feat-id>]`
(never read `feature_list.json` whole), `bash .claude/scripts/gate.sh <path>
[--integration]` (gates, summary only), `node .claude/scripts/usage-report.mjs`
(measured tokens per delegation).

## Vertical slices

Every new user-facing feature is one slice through both repos:
business research → competitors → proposal → flow design → **owner
approval** → backend and frontend on one shared contract → review.
`/slice <slug> <goal>` runs it; the record is `slices/<slug>.md`; steps in
`task-routing` §0. A feature still REQUEST_CHANGES after **5 review rounds**
stops: the Supervisor brings the owner the open findings and 2–3 options and
waits.

## Cross-repo API work

1. The backend feature fixes the contract first: route, request/response
   shape, error codes, auth/scope. It is part of its acceptance criteria.
2. The frontend feature depends on it by name (`<backend-repo> feat-N`) and
   stays `blocked` until that feature is `pass`, or builds against a typed
   mock of the same contract, said in its criteria.
3. The frontend maps API types in its feature mapper; a contract change edits
   the backend feature, then the mapper.

## Commands

`/slice <slug> <goal>` (workspace only, see Vertical slices),
`/prepare-phase <repo-key|all> <N>`, `/feature <repo-key> <feat-id>`,
`/cleanup-sprint <repo-key> [next]`: run the repo's own command of that name.

## CodeGraph

No index at this level on purpose (it would inject context into every
prompt). Query a repo on demand: `codegraph_explore` with `projectPath` set to
the repo's absolute path, or `codegraph explore "…"` from inside the repo.
