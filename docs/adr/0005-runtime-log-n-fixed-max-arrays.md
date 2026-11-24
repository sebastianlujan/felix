# ADR-0005: Runtime `log_n` with fixed maximum-size arrays instead of const generics

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The circuit size differs per circuit, and several verifier arrays grow with log N.
- The upstream Barretenberg reference uses fixed maximum-size arrays and a runtime log N.
- The verification key differs per circuit, and the library functions take it as a parameter.
- The port is compared with the reference value by value, so staying close to its shape helps review.

## Decision

`log_n` is a runtime value. Arrays have a fixed maximum size, like the reference. No const generics.

## Outcome (2026-11-23)

Carried out as decided. The sizes, read from the generated ZK verifier:

| Constant or type | Value | Where |
|---|---|---|
| `MAX_LOG_N` | 25, the reference's `CONST_PROOF_SIZE_LOG_N` | `key/src/lib.fe`, re-exported by `lib/src/types.fe` |
| Sumcheck challenges, powers of the Gemini challenge, fold evaluations | `[u256; MAX_LOG_N]` | `types.fe`, `shplemini.fe` |
| `MAX_SLOTS`, the scalars of the multi-scalar multiplication | 67 = 42 + `MAX_LOG_N` | `lib/src/shplemini.fe` |
| Evaluations the relations read | `[u256; 41]` | `lib/src/relations.fe` |
| Verification-key points | `[u256; 56]`: 28 points | `lib/src/types.fe` |

- The proof holds 42 evaluations: the masking polynomial, then the 41 entities. They are read from the proof by offset, so no 42-word array exists.
- The contracts are exercised at `LOG_N` 5, 15 and 20 (#43, #51), and the library tests also run 12 and 17, on proofs made by Garaga (`ultrahonk/README.md`, Other circuits). One library build serves every size: that is the point of this decision.
- The key is the constant `VK` in `lib/src/vk.fe`, which `HonkVerifier` imports. It was moved there from `lib/src/vectors.fe` on 2026-11-23, so the contract no longer imports from the file of test vectors.

## Options Considered

### Option A: Runtime `log_n` over fixed maximum-size arrays (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Loops bounded by a runtime value over fixed arrays |
| Cost | Arrays are sized for the maximum, whatever the circuit |
| Risk | An index past the used part is not caught by the type |
| Fit with Fe 26.6.0 | Fixed-size `u256` arrays; mirrors the reference's shape |

**Pros:** One library for every circuit. The port stays comparable with the reference, loop by loop.  
**Cons:** Unused array slots for small circuits. Bounds are a runtime concern.

### Option B: Const generics parameterised by log N

| Dimension | Assessment |
|-----------|------------|
| Complexity | Every function that touches a sized array becomes generic |
| Cost | Not evaluated in the plan |
| Risk | Unknown: the plan records no trial of const generics on Fe 26.6.0 |
| Fit with Fe 26.6.0 | Not evaluated |

**Pros:** Sizes checked by the compiler. No unused slots.  
**Cons:** Departs from the reference's shape. Untested here, with about 48 hours to the deadline.

## Trade-off Analysis

The plan chooses the shape the reference already has. It keeps the port mechanical and the comparison with reference values direct, and it avoids depending on a language feature the plan did not try.

## Consequences

- Easier: review against the reference.
- Easier: a new circuit needs a new `VerificationKey` constant and a contract that passes it, not new verifier functions. This is untested: the project has one circuit.
- Harder: array sizes are constants that must match the reference exactly, and they are flavor-specific.
- Revisit: const generics, after the deadline.

## Action Items

1. [x] Stage 0: read the maximum array sizes from the generated ZK contract.
2. [x] Stage 2: define the sized types in `types.fe`.
3. [x] Stage 6: check the Shplemini arrays index by index against the reference scalars.
