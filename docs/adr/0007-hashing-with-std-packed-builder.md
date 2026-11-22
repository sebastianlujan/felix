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
- Revisit: whether the ZK transcript needs any hash shape the builder does not cover.

## Action Items

1. [ ] Stage 2: implement `absorb` with `Packed` and test that absorbing 32 zero bytes equals `keccak(0x00…00) % P` (the stage 0 spike 4 check).
2. [ ] Stage 2: compare every transcript challenge with the reference value.
3. [ ] Stage 6: build the pairing input with `Packed`.
