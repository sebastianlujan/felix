# ADR-0014: Staged delivery with cut lines, incremental commits and one parallel worktree for the toy line

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The submission deadline is Nov 24, 2026 23:59 UTC, about 48 hours away when the plan was written.
- The original estimates are 25 h for the main line and 5.5 h for the toy line.
- Reaching stage 7 by the deadline is not guaranteed. The switch to the ZK flavor (ADR-0001) raises that risk.
- The repository owner reviews each stage. Whichever stages pass by the deadline are submitted.
- The owner's rule of 2026-11-22 is to use incremental commits always.
- The real verifier and the toy verifier live in disjoint directories.

## Decision

| Topic | Rule |
|---|---|
| Stages | Main line: stages 0 to 8, with a stage 0b for the switch to the ZK flavor and the Fe-only layout (the plan now counts it inside stage 0). Toy line: T1 and T2. Each stage has an acceptance test and a cut line ("if the deadline hits here"). |
| Feature freeze | Nov 24, 2026 14:00 UTC. Feature work stops and the docs stage starts. |
| Status | The status table in `ultrahonk/README.md` is updated at the end of every stage. |
| Commits | Each working unit is committed as soon as its tests pass: several commits per stage, not one per stage. |
| Commit hygiene | Conventional commits, no tool-attribution trailers, explicit `ultrahonk/` pathspecs only. No push unless asked. |
| Branches | Two branches off `develop` (gitflow): `feature/ultrahonk-verifier` in the main checkout, `feature/honk-toy` in a separate git worktree. |
| Parallelism | One parallel implementation writer, the toy line, in its own worktree. One writer per stage on each line. A coordinator reports each stage's test output. |
| Review | Stages do not wait for review. Work pauses only for a real decision, for example single contract or split after stage 3. |
| Order of sacrifice | T2 first, then vault extras, never the main-line stage in progress. |
| Boundaries | No changes to global tools, the root library or `calculator/`. |

## Outcome (2026-11-23)

- Every stage of both lines was done by 2026-11-23, before the feature freeze. No cut line was used, and nothing in the order of sacrifice was given up. The toy also got its later step, the sumcheck mask.
- **More parallel lines than decided.** Besides the toy, the relations, the opening, the integration of the opening into the verifier, and the documents each had a branch and a git worktree: `feature/ultrahonk-relations`, `feature/ultrahonk-opening`, `feature/ultrahonk-integration`, `feature/ultrahonk-docs`. All are merged into `feature/ultrahonk-verifier`.
- Commits were incremental: one per working unit, with conventional messages.
- The status table in `ultrahonk/README.md` was updated as stages landed.
- The stage estimates were not re-cut after the switch to the ZK flavor. The stages were carried out in the plan's order, with the ZK-specific steps inside stages 3–5 and 6.
- The relations went into a second contract as they were ported. The repository records no pause for that decision (ADR-0012).
- Two items of stage 8 were not written: `scripts/check.sh` and the code-size script.

## Options Considered

### Option A: Stages with cut lines, incremental commits, one parallel worktree (chosen)

| Dimension | Assessment |
|-----------|------------|
| Deadline risk | Every stage boundary is a valid stopping point |
| Reviewability | Small commits; a stage can be reviewed at any time |
| Revertability | A stage can be reverted alone |
| Coordination cost | Two lines to track, kept apart by directory |

**Pros:** Something coherent exists at every cut point. The toy line advances in parallel instead of waiting for the main line.  
**Cons:** More commits and a status table to keep current.

### Option B: One delivery at the end

| Dimension | Assessment |
|-----------|------------|
| Deadline risk | If the last step is not reached, nothing coherent is ready |
| Reviewability | One large change to review at the end |
| Revertability | All or nothing |
| Coordination cost | Lowest |

**Pros:** No intermediate bookkeeping.  
**Cons:** Unsuitable when reaching the last stage is not guaranteed.

### Option C: One commit per stage

| Dimension | Assessment |
|-----------|------------|
| Deadline risk | Work inside an unfinished stage is uncommitted when the deadline hits |
| Reviewability | Stage-sized commits, up to 5 h of work each |
| Revertability | Per stage |
| Coordination cost | Low |

**Pros:** A tidy history, one entry per stage.  
**Cons:** Contradicts the owner's rule of incremental commits.

### Option D: A single serial line, no parallel worktree

| Dimension | Assessment |
|-----------|------------|
| Deadline risk | The toy would wait for the main line, or delay it |
| Reviewability | One line to follow |
| Revertability | Unchanged |
| Coordination cost | Lowest |

**Pros:** Simplest to coordinate.  
**Cons:** Leaves the toy deliverable competing with the main line for the same hours.

## Trade-off Analysis

The plan cannot promise the last stage, so it makes every earlier stage a legitimate result. Incremental commits narrow the loss at the deadline to one working unit. The parallel worktree is safe here because the two lines touch disjoint directories, and it is limited to one extra writer.

The plan's workflow text says both that each stage "is its own commit" and that there are several commits per stage. This record follows the dated owner's rule: a stage is a run of several commits, and it is that run which can be reviewed or reverted alone.

## Consequences

- Easier: the submission at the deadline is whatever stages have passed, each labelled honestly.
- Easier: review can lag behind implementation without blocking it.
- Harder: stage boundaries must stay visible in the commit history.
- Harder: the stage table needs maintenance when scope changes. The estimates predate the switch to the ZK flavor and were never re-cut.

## Action Items

1. [ ] Stage 0b: finish the switch to the ZK flavor and the Fe-only layout (done), then re-cut stages 1–8 and their estimates for the ZK target (not done: the stages were carried out in the plan's order).
2. [x] Every stage: commit each working unit when its tests pass, and update the README status table at the end of the stage.
3. [ ] After stage 3: pause for the single-contract-or-split decision (ADR-0012). No pause is recorded: the relations were split as they were ported.
4. [x] Nov 24, 2026 14:00 UTC: stop feature work and start stage 8. The documentation stage started on 2026-11-23, ahead of the freeze.
