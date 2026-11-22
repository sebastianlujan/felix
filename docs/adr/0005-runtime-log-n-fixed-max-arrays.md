# ADR-0005: Runtime `log_n` with fixed maximum-size arrays instead of const generics

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The circuit size differs per circuit, and several verifier arrays grow with log N.
- The upstream Barretenberg reference uses fixed maximum-size arrays and a runtime log N.
- The verification key is generated per circuit (`verifier/src/vk.fe`), and the library is meant to serve any of them.
- The port is compared with the reference value by value, so staying close to its shape helps review.

## Decision

`log_n` is a runtime value. Arrays have a fixed maximum size, like the reference. No const generics.

The original plan named `[u256; 25]` and `[u256; 63]` for the non-ZK contract. The sizes for the ZK contract are **[ZK: TBC]**. One known ZK size: 42 evaluated entities, so the evaluations array is `[u256; 42]`.

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
- Easier: a new circuit needs a new `vk.fe`, not a new library build.
- Harder: array sizes are constants that must match the reference exactly, and they are flavor-specific.
- Revisit: const generics, after the deadline.

## Action Items

1. [ ] Stage 0b: read the maximum array sizes from the generated ZK contract and replace the **[ZK: TBC]** values.
2. [ ] Stage 2: define the sized types in `types.fe`.
3. [ ] Stage 6: check the Shplemini arrays index by index against the reference scalars.
