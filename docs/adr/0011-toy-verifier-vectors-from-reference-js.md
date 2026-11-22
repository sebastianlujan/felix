# ADR-0011: Toy verifier: vectors from the teaching page's reference JavaScript, challenges as inputs

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The third deliverable is the teaching page's hand-sized Honk over F_17, ported to Fe.
- The page's math block is a DOM-free script that already exports for Node.
- On the page the toy is interactive: the verifier's challenges are given, not derived from a transcript.
- The page runs scenarios: an honest run, cheating scenarios, and nine non-ZK scenarios in total, including a "lucky dice" cheat that the verifier accepts. It also has optional ZK sumcheck-mask scenarios.
- No precompile exists for the toy's curve, y² = x³ + 3 over F_101.
- The real verifier now targets the ZK flavor (ADR-0001). That change does not reach the toy.

## Decision

| Aspect | Decision |
|---|---|
| Source of truth | The page's math block, extracted verbatim into `toy/reference/honk.js` |
| Vectors | `toy/reference/gen_vectors.js` runs the page's scenarios under Node 24 and writes `toy/src/vectors.fe`, which is committed |
| What is ported | The page's `verify(vk, proof, pis, ch)`: 4 rows, 3 wires, 23 evaluations, 7 subrelations, 2 sumcheck rounds of 6 values |
| Challenges | The 10 challenges are passed in as inputs |
| Protocol | The toy stays the non-ZK toy protocol of the teaching page |
| ZK mask scenarios | Optional. They may be added as a later step and are not part of T1 or T2. |
| Pairing | Written in Fe (Miller loop) |

## Options Considered

### Option A: Generated vectors from the page's JavaScript, challenges as inputs, non-ZK protocol (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Extraction of one script plus a small generator |
| Cost | Estimated at 5.5 h for T1 and T2 together |
| Risk | The generator must run the page's code unmodified |
| Fidelity to the teaching page | Exact: same code, same scenarios, same verdicts |

**Pros:** The Fe toy can be compared value by value with the page. Vectors are reproducible with one command.
**Cons:** A JavaScript reference lives in the repository, and Node 24 is needed to regenerate.

### Option B: Derive the challenges inside the toy with a Fiat–Shamir transcript

| Dimension | Assessment |
|-----------|------------|
| Complexity | Adds a transcript to the toy |
| Cost | Not estimated in the plan |
| Risk | The toy's values would no longer match the page's |
| Fidelity to the teaching page | Departs from it: the page's toy is interactive |

**Pros:** A non-interactive toy.
**Cons:** Loses the direct comparison with the page.

### Option C: Hand-written vectors transcribed from the page

| Dimension | Assessment |
|-----------|------------|
| Complexity | No generator |
| Cost | Manual transcription of every value |
| Risk | Transcription errors, and no way to regenerate |
| Fidelity to the teaching page | Depends on the transcription |

**Pros:** No Node dependency at all.
**Cons:** Not reproducible.

### Option D: Include the ZK sumcheck-mask scenarios now

| Dimension | Assessment |
|-----------|------------|
| Complexity | More scenarios and the mask logic |
| Cost | Outside the T1 and T2 estimates |
| Risk | Competes for time with the main line |
| Fidelity to the teaching page | Higher: covers the optional scenarios too |

**Pros:** A more complete toy.
**Cons:** Deferred: it may be added as a later step.

## Trade-off Analysis

The toy exists to mirror the teaching page, so the page's own code is the right oracle, and keeping the challenges as inputs keeps the comparison exact. The ZK mask scenarios are optional on the page and are left for later, because the order of sacrifice puts the toy line behind the main line (ADR-0014).

## Consequences

- Easier: `node toy/reference/gen_vectors.js` reproduces `toy/src/vectors.fe`.
- Easier: running the toy's tests needs no Node, because the vectors are committed.
- Harder: the toy and the real verifier differ in flavor. The toy is non-ZK and interactive; the real verifier is ZK and non-interactive. The README should say so.
- Harder: the toy needs its own field, curve and pairing code, since no precompile applies.
- Revisit: the ZK sumcheck-mask scenarios, as a later step.

## Action Items

1. [ ] Stage T1: extract `reference/honk.js` verbatim, write `reference/gen_vectors.js`, port `f17`, `sumcheck` and `relations`. For the honest run, delta, round targets, pow, the 7 subrelations and the final check equal the reference; each cheating scenario fails at the same check as on the page.
2. [ ] Stage T2: port `curve` (including the Miller-loop pairing), `shplemini` and `verifier`. `verify` gives the page's verdict for all nine non-ZK scenarios, including the accepted "lucky dice" cheat.
3. [ ] Later step, optional: add the ZK sumcheck-mask scenarios.
