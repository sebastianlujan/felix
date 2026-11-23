# ADR-0011: Toy verifier: vectors generated from an independent reference, challenges as inputs

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The third deliverable is the teaching page's hand-sized Honk over F_17, ported to Fe.
- The page's math block is a script without DOM access, so it can run outside a browser.
- On the page the toy is interactive: the verifier's challenges are given, not derived from a transcript.
- The page runs scenarios: an honest run and cheating scenarios, including a "lucky dice" cheat that the verifier accepts. It also has sumcheck-mask scenarios in its ZK section.
- No precompile exists for the toy's curve, y² = x³ + 3 over F_101.
- The real verifier is the ZK flavor (ADR-0001). That choice does not reach the toy.

## Decision

| Aspect | Decision |
|---|---|
| Source of truth | A reference implementation of the page's math block, kept in `toy/reference/`. It is independent of the Fe code. |
| Vectors | A generator runs the reference on the page's scenarios and writes `toy/src/vectors.fe`, which is committed. Vectors are never written by hand. |
| What is ported | The page's `verify(vk, proof, pis, ch)`: 4 rows, 3 wires, 23 evaluations, 7 subrelations, 2 sumcheck rounds of 6 values |
| Challenges | The 10 challenges are passed in as inputs |
| Protocol | The toy protocol of the teaching page |
| Sumcheck-mask scenarios | Optional, as a later step after T1 and T2 |
| Pairing | Written in Fe (Miller loop) |

## Outcome (2026-11-23)

- Carried out. The toy is the ingot `honk_toy` in `ultrahonk/toy`, with 70 Fe tests.
- **The reference is Python.** `toy/reference/honk.py` is a function-by-function port of the page's math block, and `toy/reference/gen_vectors.py` is the generator. Both use Python 3 with the standard library only. The first version ran the page's JavaScript; it was replaced on 2026-11-23, after the Python generator reproduced the committed vectors byte for byte. The repository tracks no JavaScript.
- `python3 reference/gen_vectors.py --check` exits with an error if `src/vectors.fe` is out of date.
- **The sumcheck mask is included.** `libra.fe` and `verify_masked` verify proofs whose sumcheck is masked, with 5 masked vectors. A masked toy proof is still not zero-knowledge: the 23 evaluations travel unmasked.
- The vectors cover 15 scenarios: 8 of the page's, 2 more honest runs and 5 masked ones. The Fe verdict equals the reference verdict in each, including the accepted "lucky dice" cheat.
- `ultrahonk/toy/README.md` states the limits: the toy is interactive and is not secure.

## Options Considered

### Option A: Generated vectors from a reference implementation of the page's math, challenges as inputs (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One reference implementation plus a small generator |
| Cost | Estimated at 5.5 h for T1 and T2 together |
| Risk | The reference must stay faithful to the page's code |
| Fidelity to the teaching page | Same functions, same scenarios, same verdicts |

**Pros:** The Fe toy can be compared value by value with the reference. Vectors are reproducible with one command.  
**Cons:** A reference in a second language lives in the repository, and that language is needed to regenerate.

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

**Pros:** No second language at all.  
**Cons:** Not reproducible.

### Option D: Include the sumcheck-mask scenarios from the start

| Dimension | Assessment |
|-----------|------------|
| Complexity | More scenarios and the mask logic |
| Cost | Outside the T1 and T2 estimates |
| Risk | Competes for time with the main line |
| Fidelity to the teaching page | Higher: covers the mask scenarios too |

**Pros:** A more complete toy.  
**Cons:** Deferred to a later step, which was then carried out (see Outcome).

## Trade-off Analysis

The toy exists to mirror the teaching page, so a reference that follows the page's own code is the right oracle, and keeping the challenges as inputs keeps the comparison exact. The mask scenarios were left for a later step, because the order of sacrifice puts the toy line behind the main line (ADR-0014).

## Consequences

- Easier: `python3 toy/reference/gen_vectors.py` reproduces `toy/src/vectors.fe`.
- Easier: running the toy's tests needs no Python, because the vectors are committed.
- Harder: the toy and the real verifier differ. The toy is interactive and not zero-knowledge; the real verifier is ZK and non-interactive. `ultrahonk/toy/README.md` says so.
- Harder: the toy needs its own field, curve and pairing code, since no precompile applies.
- Harder: the Python reference is a port, so its fidelity to the page rests on the byte-for-byte reproduction of the earlier vectors.

## Action Items

1. [x] Stage T1: write the reference and the generator, port `f17`, `sumcheck` and `relations`. For the honest run, delta, round targets, pow, the 7 subrelations and the final check equal the reference; each cheating scenario fails at the same check as in the reference.
2. [x] Stage T2: port `curve` (including the Miller-loop pairing), `shplemini` and `verifier`. `verify` gives the reference's verdict in every scenario, including the accepted "lucky dice" cheat.
3. [x] Later step: add the sumcheck-mask scenarios.
