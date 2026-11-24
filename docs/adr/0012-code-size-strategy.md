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
- The ZK flavor (ADR-0001) adds protocol steps on top of the shared relations. When this record was written, no size had been measured.

## Decision

| Step | Detail |
|---|---|
| Measure early | Stage 3 is a risk spike: compile the largest relation and record the `runtime.bin` size at `-O 1`, `-O 2` and `-O s` |
| Project | Stage 3's number × ~4.5 projects the size of the relations |
| Enforce | A script checks the built `.runtime.bin` against 24,576 bytes (ADR-0009) |
| Fallback 1 | `-O 2` / `-O s` |
| Fallback 2 | A second contract, `HonkRelations`, staticcalled by the verifier |

Work pauses after stage 3 for the decision between a single contract and a split.

## Outcome (2026-11-23)

The relations are a second contract, `HonkRelations`, which `HonkVerifier` asks with a static call. This is fallback 2, and it mirrors the reference's linked `RelationsLib`.

Measured with `fe` 26.6.0 (`fe build --contract <Name> -O <level>`; the size is half the length of the hex text in `out/<Name>.runtime.bin`):

| Runtime size, bytes | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| `HonkVerifier` | 16,710 | 16,637 | 16,504 |
| `HonkRelations` | 8,527 | 6,336 | 6,343 |
| Both together | 25,237 | 22,973 | 22,847 |

- The table was measured again on 2026-11-23, after issues #4 to #6 (`ultrahonk/README.md`). Before them `HonkVerifier` was 16,446, 16,274 and 16,174 bytes. It was measured once more after #42, which moved the steps of `verify` into the library function `verify_at`: before it `HonkVerifier` was 16,638, 16,476 and 16,346 bytes.
- Each contract is below the 24,576-byte limit at every level.
- The reference is a 16,946-byte contract plus two linked libraries of 8,211 and 6,008 bytes.
- The split was made when the relations were ported, on 2026-11-22. The repository records no size for a single Fe contract holding everything, and no use of the × ~4.5 projection. The sums in the last row only indicate what a single contract would weigh: above the limit at `-O 1`, below it at `-O 2` and `-O s`.
- The call between the two contracts sends hand-built calldata. The typed message made the verifier 2,103 bytes larger at `-O 1`, measured before the opening was ported (`ultrahonk/README.md`).
- Since 2026-11-23 `scripts/check.sh` builds the three contracts at the three optimisation levels and fails if a runtime exceeds the limit. Before that, sizes were read from the build by hand.

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

- Easier: the single-contract-or-split decision was meant to rest on a measured number. As built, the split came first and the measurements after (see Outcome).
- Reached on 2026-11-23: `scripts/check.sh` enforces the limit.
- Harder: the verifier has a second deployment and a static call. `HonkRelations` is deployed first, and its address is the constructor argument of `HonkVerifier`.
- Revisit: a single contract at `-O 2` or `-O s`, which the sums suggest might fit. The repository has no such build.

## Action Items

1. [x] Stage 3: port `accumulateMemoryRelation` and check that it compiles and that its slots match the reference. The memory relation was the first one ported. No size of it alone is recorded.
2. [x] After stage 3: decide single contract or split, and record the measured sizes in this ADR. The split was made; the sizes are in Outcome.
3. [x] Stage 7: add the script that checks `.runtime.bin` against 24,576 bytes. Done on 2026-11-23, as a step of `scripts/check.sh`.
4. [x] Stage 8: run that check from `scripts/check.sh`. Done on 2026-11-23.
