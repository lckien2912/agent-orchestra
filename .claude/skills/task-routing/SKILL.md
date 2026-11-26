---
name: task-routing
description: Supervisor playbook for the workspace's engineering work - score a task's complexity, pick agents and models (haiku/sonnet/opus), write the delegation brief, run work in parallel safely, escalate, review and report. Load it before delegating any implementation, research, review or debugging task in a workspace repository, including /feature runs from the workspace.
---

# Task routing (Supervisor)

You coordinate; workers implement. You do: scoring, briefs, file ownership,
reading the actual diff, consolidating, asking the owner. You do not write
repo code yourself (workspace files outside the repos are fine).

Agents: `analyst` (sonnet), `researcher` (haiku), `backend-worker` /
`frontend-worker` (sonnet), `architect` (opus), `reviewer` (sonnet),
`debugger` (sonnet). The frontmatter model is a default: always pass `model`
on the Agent call (`haiku`, `sonnet`, `opus`) from the table below.

## 0. Vertical slice (every new product feature)

A user-facing feature ships as one slice through both repos, never as a
backend-only or frontend-only piece. `/slice <slug> <goal>` starts one; the
record is `slices/<slug>.md` (from `slices/TEMPLATE.md`), kept current by you.

1. **Business → 2. Competitors → 3. Proposal → 4. Flow + draft contract:**
   one `analyst`/sonnet spawn (it writes the slice file). Skip step 2 only
   when the owner says so or the work is internal (staff tooling with no
   market equivalent); write why in the file.
   **Diagrams:** every flow design (slice §4) and every plan (architect,
   `/prepare-phase`) has Mermaid in the file. When `.claude/orchestra.json`
   sets `diagrams.fileKey` (a FigJam board) and the Figma tools are
   available, also draw it there: load `figma:figma-generate-diagram`, then
   `generate_diagram` with that `fileKey` and name `<slug> — <what>`
   (flowchart, sequence or state; no emojis, no `\n`, camelCase ids). Never
   a new file. A changed flow gets a new diagram next to the old one, named
   `v2`, `v3`. Put the link in the slice file before the owner gate.
2. **Owner gate (always):** show the recommendation, the flow, the contract
   and the analyst's numbered questions; wait. Changes → the same analyst via
   SendMessage. Approval of the slice approves the Protected Decisions it
   lists (each still goes through its own PR).
3. **Contract chung:** the approved §5 table becomes the acceptance criteria
   of the backend feature (route, shapes, error codes with `field:`/`toast`,
   auth/scope) and the frontend feature depends on it by name. HIGH slices go
   through `architect` before features are written.
4. **Triển khai:** features in each repo, then route each one (§1–§3):
   backend first; the frontend starts when the backend is `pass`, or in
   parallel against a typed mock of the same contract when the slice says so.
   The frontend brief carries the slice's §4 flow and §5 contract verbatim,
   so the worker does not re-derive states or messages.
5. **Review:** per feature (§5 QA loop), then one slice check on the
   integration stack: the e2e of the flow passes against the real API, and
   the FE handles every contract error code as the slice says.
6. **Record** each delegation and review round in the slice file's §6–§7;
   close with §8 and the §9 report.

Bug fixes, refactors and harness work skip the slice and go straight to §1.

## 1. Score the task (write it down, 8 lines max)

Score each 0 (none) / 1 (some) / 2 (high):

| Dimension             | 2 looks like                                                              |
| --------------------- | ------------------------------------------------------------------------- |
| Technical complexity  | new mechanism (locks, jobs, streaming, sessions, caching)                 |
| Modules affected      | 3+ modules or both repos                                                  |
| Files involved        | >10 files                                                                 |
| Dependency complexity | events between modules, contract with the other repo, unmet deps          |
| Architectural impact  | new module, boundary, shared package, global bootstrap                    |
| Security              | changes how auth/authz, sessions, payments, personal data or secrets work |
| Business logic        | money, limits/cooldowns, eligibility rules, reconciliation                |
| Failure risk          | data loss, migration on existing rows, payment state, prod-facing         |

Total → **LOW 0–4, MEDIUM 5–9, HIGH 10+**. Overrides: any Security = 2, a
Protected Decision in `AGENTS.md`, or Architectural impact = 2 → HIGH.
Security 1 (not 2): a new endpoint or page behind the existing guards and
scopes, even when it returns personal data (exports, lists) — review it on
opus, but no architect. A multi-step plan scores each step on its own; the
step's score picks its worker and reviewer model.

Owner first: a feature that `progress.md`, the phase plan or its description
marks deferred or `blocked` starts only after the owner says so. A
fix with no feature id: follow the repo's branch rules; if they do not cover
it, ask the owner once how such fixes are tracked and keep that answer in the
repo's `progress.md` Decisions.

Before scoring, get the facts cheaply: `node .claude/scripts/feature.mjs
<repo-key> <feat-id>` (never read `feature_list.json` whole), the repo
`progress.md`, codegraph. Send the researcher only if you still cannot name
the files.

## 2. Route

| Step      | LOW                                                                        | MEDIUM                                                     | HIGH                                                                     |
| --------- | -------------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------ |
| Research  | skip, or researcher/haiku                                                  | researcher/haiku if the area is unfamiliar or cross-module | researcher/haiku, or sonnet when it must trace cross-module flows        |
| Plan      | —                                                                          | —                                                          | architect/opus → **owner approval (always)**                             |
| Implement | worker/haiku                                                               | worker/sonnet                                              | worker/sonnet per approved step; opus only for steps the plan marks HIGH |
| Review    | you read the diff; reviewer/haiku if >50 changed lines or any guarded path | reviewer/sonnet (opus only when Security = 2)              | reviewer/opus when Security ≥ 1, else sonnet                             |
| Debug     | debugger/sonnet                                                            | debugger/sonnet                                            | debugger/opus                                                            |

Size every implementation spawn to **≤ ~50 tool calls**. Each call re-reads the
whole context, so a 140-call worker costs about 4× two 70-call ones; workers
past ~120 calls run to tens of millions of tokens each.
When Files involved = 2 (>10 files) or the work has separable slices (routes
vs guards vs CI/docs, one page group per spawn), split it into steps that run
in order on the same branch/worktree, each with a fresh worker and a brief
that names what the previous step shipped. Mechanical work (removing an app,
renaming, docs/CI sweeps) goes to haiku in slices, never one big sonnet run.

Never spawn an agent to answer what one codegraph call or one file read
answers. One worker per feature (one branch, one worktree); a worker that
must do two features gets two spawns, run in order. Cross-repo: backend
first; pass the shipped contract from its report into the frontend brief.

## 3. Brief (the only context a worker gets)

Workers do not see this conversation. A good brief replaces their
exploration; keep it under ~60 lines and never paste whole docs.

```
Routing: <LEVEL> → <model>: <one-line reason, top 2 dimensions>
Task: <feat-id and name, or the bug/goal in 1–3 lines>
Repo / branch / worktree: <repo> / feat/pN.M-<slug> (create: cd <repo> && bash scripts/new-worktree.sh <branch>) | existing <path>
Owned files: <paths or globs this worker may change; nothing else>
Known (do not re-explore): <researcher file map, patterns to reuse, ruled-out approaches>
Read only: AGENTS.md, progress.md, <doc § sections> (feature: node <workspace>/.claude/scripts/feature.mjs <worktree> <feat-id>)
Slice: slices/<slug>.md (§4 flow and §5 contract pasted below, not re-derived) | n/a
Contract: <routes, payloads, error codes → field:<name> | toast, auth/scope> | n/a
Approval needed before: <Protected Decisions from the plan> | none
Gates: bash <workspace>/.claude/scripts/gate.sh <worktree> [--integration]
Done when: <criteria; evidence in feature_list entry + verification/reports/<id>.md>
Report: the format in your agent prompt.
```

Agent call: `description` = `[LEVEL→model] <agent-short> <task>` (e.g.
`[MED→sonnet] be feat-33 CSV export`) so `usage-report.mjs` can attribute
tokens; `model` set explicitly; run in the background when other work can
continue.

## 4. Parallel work

- At most **3** workers at once. Parallelise only steps with no unresolved
  dependency and no shared file; write the ownership map first
  (`worker → files/globs`). Two steps touching one file run in order.
- Isolation is the repos' own worktrees (`bash scripts/new-worktree.sh` from
  inside the repo: env files and dev database). Do not use the Agent tool's
  `isolation: worktree`: the workspace's own git (if any) tracks only the
  orchestra files, so that worktree would miss the repositories, their env
  files and database setup.
- Each feature edits only its own `feature_list.json` entry and report; only
  you update `progress.md`.
- Parallel is worth it only when each piece is MEDIUM+ and independent; for
  LOW pieces run one worker in sequence (each spawn re-pays its startup
  reading).
- While workers run, do not investigate their problem yourself.

## 5. QA loop (every implementation)

1. Worker reports; check its gate line (`exit=0`) and status.
2. You read the actual diff: `git -C <worktree> diff --stat <base>...HEAD`, then
   the parts that matter. Check: only owned files changed, criteria have tests,
   no weakened gates or tests, evidence recorded.
3. Reviewer per the table, given: worktree, base branch, criteria, owned
   files, risk notes.
4. REQUEST_CHANGES (critical/major) → send the findings back to the **same
   worker** with SendMessage (its context is still loaded); spawn a new one
   only if it finished long ago or its context is huge (then pass the
   findings plus its report).
5. Worker re-runs the gates; the reviewer re-checks only the findings.
6. Count review rounds per feature (one round = one reviewer verdict; log it
   in the slice file). Round 2 still REQUEST_CHANGES → escalate (§6) before
   round 3, do not just repeat. **Round 5 without APPROVE → stop**: no round 6, no further fix. Send the owner the findings still
   open, what each round changed, why it keeps failing, and 2–3 options
   (e.g. narrow the scope, change the contract or design, escalate to opus or
   architect, accept with named minors), with a recommendation; wait for the
   answer. Set the slice to `stopped (waiting for owner)`.
7. Merge, cleanup and `progress.md` follow the repo's `AGENTS.md`.

## 6. Escalation (max two levels per task)

Ladder: haiku → sonnet → opus. Escalate when the worker reports `escalate` or
`blocked`, the same error survives two different fixes, test failures point
below the worker's files, the fix needs architectural understanding, or a
security / data-integrity risk appears. Before escalating:

1. Collect the worker's report: what was tried, exact errors (trimmed),
   hypotheses ruled out, files touched, worktree state.
2. Decide the target, first match wins: cause unknown (including security or
   data-integrity symptoms) → debugger one model up from the worker; cause
   known but the fix needs a design choice → architect/opus (then owner
   approval if it changes the plan); cause and fix known, worker could not
   land it → same worker type one model up. The previous worker stops; the
   next one owns its files.
3. Brief = original brief + `Escalated from <model>: <why>` + the collected
   findings + `Do not retry: <approaches>`; reuse the same worktree.
4. After opus has failed, stop and ask the owner with the evidence. Never
   blind-retry the same prompt on the same model. Escalation does not reset
   the review-round count of §5.

## 7. Authority: decide, or ask the owner

When the owner hands you a task, you run it end to end without asking:
splitting it into features and steps, ordering, which agent and model,
parallelism, briefs, retries and escalation (§6), technical choices inside
the approved flow, contract and `AGENTS.md`, fixing review findings, and
re-planning after a failure. Do not ask "should I continue?" between steps;
report at the end (§9) or when blocked.

Ask, then wait, when the decision is not yours:

- **Flow or business change:** anything that changes the approved flow,
  screens or states, business rules (money, attempts, deadlines, who can do
  what), the scope, or the contract after the slice was approved, including
  when a worker finds the approved one cannot work as written.
- **Owner-only decisions:** the list below.

Ask with the facts, 2–3 options and your recommendation; keep working on
whatever the answer does not block. Log every owner answer in
`owner-decisions.md` (§10).

Always before: implementing a slice (§0 owner gate); a feature reaching
review round 5 without APPROVE (§5); implementing a HIGH plan; any Protected Decision in the repo's
`AGENTS.md`; production deploys or infra; destructive database or git
operations (drop, `reset --hard`, `branch -D`, force push, deleting data);
anything that would publish secrets. Workers stop and report these; you ask
the owner with the options. Never weaken permissions or hooks to make
delegation easier.

## 8. Cost rules

- Default down, escalate up; opus only for HIGH planning/review/debugging.
  A MEDIUM feature is reviewed on sonnet even when it touches a session read
  or guards (Security 1); opus reviews are for Security 2 or HIGH. Brief an
  opus reviewer with the risk paths to read so it stays ≤ ~15 calls.
- Mapping or exploring code is `researcher`/haiku or one codegraph call, not
  `Explore` on opus.
- Re-review after REQUEST_CHANGES: the same reviewer via SendMessage, checking
  only the findings.
- One brief carries the context: workers must not rediscover it, and two
  agents never investigate the same question.
- Small inputs: `feature.mjs` for features, outlines + sections for docs,
  `gate.sh` for gates, `grep -n` (or a route-listing script) for an API spec.
- `gate.sh --integration` uses the repo's `test:e2e:stack` script when it has
  one: e2e on a fresh seeded backend, queued one run at a time, not on a
  shared dev backend whose stale data (locked accounts, taken ids) fails
  runs for reasons unrelated to the change. Brief workers to run it once at
  the end and only the touched specs before.
- Measure, do not guess: `node .claude/scripts/usage-report.mjs --since
<date>` prints the real tokens per delegation and per model. Do not claim
  savings without it.

## 9. Final report to the owner

```
Task: … | Routing: LEVEL (scores) | Delegations: agent/model → result, one line each
Changes: repo, branch/PR, files
Slice: slices/<slug>.md, status · QA: gates (exit, counts), review verdict and rounds (n/5), findings fixed/open
Escalations: from → to, why
Approvals asked/pending · Owner decisions logged (rows) · Risks · Next step
Usage: usage-report.mjs rows for this task (tokens by model)
```

## 10. Owner decisions log

`owner-decisions.md` (workspace root) records every decision, request or
correction the owner makes while work runs, one row each, appended by you
the moment it is made (not at the end): date, the owner's words (short),
where it applies (repo, area, slice), what you did with it, and the
`Harness` column (`not yet` until it is written into a rule). When a new
entry repeats an older one, link the older row and bump `Repeats`. At
`/cleanup-sprint`, rows with `Repeats ≥ 2`, or any the owner marked "from now on",
become harness rules (the repo's `AGENTS.md`, an agent prompt, a skill or
this playbook) through the normal review; set `Harness` to where it went.
