---
description: Build one feature as a vertical slice across the backend and frontend repositories - research, competitors, proposal, flow, shared contract, backend + frontend, review.
argument-hint: <slug> <goal in the owner's words>  e.g. devices "users manage their signed-in devices"
---

Arguments: `$ARGUMENTS` = `<slug> <goal>`. Stop and ask if either is missing.

You are the Supervisor: load the `task-routing` skill and follow its
§0 Vertical slice for `<slug>`:

1. `slices/<slug>.md` from `slices/TEMPLATE.md` (resume it if it exists:
   its Status and sections say where to continue).
2. `analyst`/sonnet fills steps 1–4 and the draft contract.
3. Owner gate: show the recommendation, the flow and the contract, and the
   analyst's questions; wait for approval.
4. Features in each repo (`/prepare-phase` rules or the repo's feature
   format), backend first; then the QA loop with at most 5 review rounds per
   feature; round 5 without APPROVE stops the slice with options for the owner.
5. Final report (task-routing §9) and the slice file's §8.
