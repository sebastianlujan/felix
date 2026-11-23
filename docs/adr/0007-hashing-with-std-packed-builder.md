# ADR-0007: Hashing with the standard `Packed` builder instead of a hand-rolled buffer

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- Each transcript round hashes a multi-word byte run: the previous challenge followed by proof words.
- The pairing check also needs a multi-word input buffer.
- The original plan built these buffers by hand on `MemBuffer` (`new`, `write_word`, `span`).
- After approval, the plan was amended under a reuse-first rule: use what the std already provides.
- The Fe std at tag `v26.6.0` has a `Packed` builder in `ingots/std/src/evm/packed.fe`.

## Decision

Use the std `Packed` builder for every multi-word hash and for the pairing input.

| Use | Tool |
|---|---|
| Multi-word hash | `Packed`: `with_capacity(bytes:)`, `u256`, `append_span`, `keccak256`, `span` |
| Pairing input | `Packed`, then `span` |
| Single-word rehash | `keccak_words([x]) % P` |

## Outcome (2026-11-23)

- Carried out. `Packed` builds every hash whose length depends on the circuit (the transcript rounds), the pairing input, and the calldata `HonkVerifier` sends to `HonkRelations`.
- `keccak_words` hashes the two inputs of fixed size: the single-word rehash and the eight-word recursion separator of the pairing-point aggregation.
- The ZK transcript needed no hash shape the builder does not cover.
- `lib/src/std_assumptions.fe` pins both against known hashes, so a std upgrade that changes them fails there first.

## Options Considered

### Option A: The std `Packed` builder (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Calls to an existing builder |
| Cost | No buffer code to write or test in this project |
| Risk | Depends on the std API at the pinned Fe version |
| Fit with Fe 26.6.0 | The builder exists at tag `v26.6.0` |

**Pros:** Less project code. One idiom for the transcript and the pairing input.  
**Cons:** The transcript's byte layout is expressed through someone else's API, so it must be checked against a known hash.

### Option B: A hand-rolled buffer on `MemBuffer` (the original plan)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Manual offsets and word writes for every hash |
| Cost | Buffer code to write and test |
| Risk | Offset mistakes in project code |
| Fit with Fe 26.6.0 | `MemBuffer` is available |

**Pros:** Full control over the byte layout.  
**Cons:** Repeats what the std already does.

## Trade-off Analysis

Both options produce the same bytes. Option A removes code the project would otherwise have to write and test under a 48-hour deadline, and the reuse-first rule asks for it.

## Consequences

- Easier: `absorb` (ADR-0004) is a short function over the builder.
- Easier: the pairing input uses the same idiom.
- Harder: the transcript's bytes now depend on the std API of the installed Fe version (26.6.0).
- Settled: the ZK transcript needs no hash shape the builder does not cover.

## Action Items

1. [x] Stage 2: implement `absorb` with `Packed` and test it against a known hash (the stage 0 spike 4 check). The tests are in `transcript.fe` and `std_assumptions.fe`.
2. [x] Stage 2: compare every transcript challenge with the reference value.
3. [x] Stage 6: build the pairing input with `Packed`.
