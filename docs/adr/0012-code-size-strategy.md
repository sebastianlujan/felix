# ADR-0012: Code-size strategy: measure early, optimisation levels first, then split the relations

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- EIP-170 limits a contract's runtime code to 24,576 bytes.
- `fe test` cannot catch the limit: its revm allows 1 MiB.
- The plan's size concern is the relations. The largest in the upstream reference is `accumulateMemoryRelation`, at 169 lines.
- The plan lists "Fe compiler crash or code size on the relations" as a risk.
- The upstream reference keeps its relations in a separate library, `RelationsLib`.
- The ZK flavor (ADR-0001) adds protocol steps on top of the shared relations. Their effect on size is unmeasured.
- No size has been recorded in the project documents yet.

## Decision

| Step | Detail |
|---|---|
| Measure early | Stage 3 is a risk spike: compile the largest relation and record the `runtime.bin` size at `-O 1`, `-O 2` and `-O s` |
| Project | Stage 3's number × ~4.5 projects the size of the relations |
| Enforce | A script checks the built `.runtime.bin` against 24,576 bytes (ADR-0009) |
| Fallback 1 | `-O 2` / `-O s` |
| Fallback 2 | A second contract, `HonkRelations`, staticcalled by the verifier |

Work pauses after stage 3 for the decision between a single contract and a split.

## Options Considered

### Option A: Measure early, optimisation levels first, then split (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One contract unless the measurement says otherwise |
| Cost | A 1.5 h spike at stage 3 |
| Risk | The projection is an estimate; the ZK steps are unmeasured |
| Deadline fit | The decision is made before most of the relations are written |

**Pros:** The split is paid for only if needed. The risk is known at stage 3, not at stage 7.
**Cons:** A pause for a decision in the middle of the main line.

### Option B: Split the relations into a second contract from the start

| Dimension | Assessment |
|-----------|------------|
| Complexity | Two contracts and a cross-contract call from the first relation onwards |
| Cost | Paid whether or not the size requires it |
| Risk | Removes most of the size risk early |
| Deadline fit | Not evaluated in the plan as an upfront choice |

**Pros:** Mirrors what the upstream reference does with `RelationsLib`.
**Cons:** Extra structure that may turn out to be unnecessary.

### Option C: Measure only when the contract is complete

| Dimension | Assessment |
|-----------|------------|
| Complexity | None until the end |
| Cost | None until the end |
| Risk | A size problem appears at stage 7, with the least time left to restructure |
| Deadline fit | Poor |

**Pros:** No spike.
**Cons:** Finds the problem at the worst moment.

## Trade-off Analysis

The spike costs little and moves the answer to the point where it can still change the design. Splitting from the start buys certainty with structure that may not be needed, so it stays the second fallback, after the optimisation levels.

## Consequences

- Easier: the single-contract-or-split decision rests on a measured number.
- Easier: the limit is enforced mechanically by a script.
- Harder: the main line has a decision point after stage 3.
- Harder: if the split is needed, the verifier gains a second deployment and a `staticcall`.
- Revisit: the × ~4.5 projection once the ZK-specific steps have been sized.

## Action Items

1. [ ] Stage 3: port `accumulateMemoryRelation`, check that it compiles and that slots 14–19 match the reference, and record the `runtime.bin` size at `-O 1`, `-O 2` and `-O s`.
2. [ ] After stage 3: decide single contract or split, and record the measured sizes in this ADR.
3. [ ] Stage 7: add the script that checks `.runtime.bin` against 24,576 bytes.
4. [ ] Stage 8: run that script from `scripts/check.sh`.
