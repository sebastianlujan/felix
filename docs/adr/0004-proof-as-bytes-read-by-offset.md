# ADR-0004: Keep the proof as `Bytes` and read words by offset

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The proof arrives as `bytes` through `verify(bytes,bytes32[])`.
- The upstream Barretenberg reference first decodes the proof into a `Proof` struct (`loadProof`).
- In the reference's transcript, every Fiat–Shamir round after the first hashes `prev ‖ one contiguous run of proof words`.
- In Fe, a plain parameter views the caller's value in place, with no copy.
- The target is the ZK flavor (ADR-0001), whose proof is 82 + 12·log N words.

## Decision

Keep the proof as `Bytes` and read 32-byte words by offset (`Bytes.word_at` takes a byte offset). There is no `Proof` struct. The transcript is one `absorb` helper, called once per round over a contiguous run of proof words.

```fe
// lib/src/transcript.fe
pub fn absorb(prev: u256, _ proof: Bytes, start: usize, count: usize) -> u256
```

## Outcome (2026-11-23)

- Carried out as decided. `proof::word(proof, index)` reads a word by its index, and `proof.fe` has one function per offset that depends on log N.
- The design fits the ZK transcript. Every challenge is either `absorb` over one contiguous run or a rehash of the previous challenge. `eta` is the one exception: it has no previous challenge and hashes the VK hash and the public inputs before proof words 0–15.
- For the pinned proof, each of the 16 challenges equals the value captured from the reference, one test per challenge.
- The word layout and the hashed range of each round are in `ultrahonk/docs/zk-verifier-reference.md`.

## Options Considered

### Option A: `Bytes` plus offsets, one `absorb` per round (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One helper for the whole transcript; offsets computed from log N |
| Cost | No decoding pass and no copy of the proof |
| Risk | An offset error reads the wrong word; three different orderings exist (proof, commitment, VK) |
| Fit with Fe 26.6.0 | Uses `Bytes.word_at` and in-place parameter views |

**Pros:** Small code. The transcript mirrors what is hashed, byte for byte.  
**Cons:** No named fields. Every reader needs the layout table.

### Option B: Decode into a `Proof` struct, as the upstream reference does

| Dimension | Assessment |
|-----------|------------|
| Complexity | A struct with every proof element plus a loader |
| Cost | A decoding pass; the transcript then has to rebuild the hashed byte runs from the fields |
| Risk | Lower risk of offset mistakes after loading; the loader itself must still be right |
| Fit with Fe 26.6.0 | Not evaluated in the plan |

**Pros:** Named access. A line-by-line match with the reference's shape.  
**Cons:** More code, and the hashing has to rebuild byte runs that already exist in the proof.

## Trade-off Analysis

The transcript hashes runs of the proof exactly as they sit in the proof bytes, so keeping the bytes avoids decoding and re-encoding. The cost is that correctness depends on offsets, which the plan covers by comparing every challenge with the reference value (stage 2). The range checks the reference does while loading (scalars below P, coordinates below Q) still have to be done, in the reference's order (ADR-0008).

## Consequences

- Easier: the transcript is one helper and a list of ranges.
- Easier: no proof copy.
- Harder: the layout table is the only map of the proof, so it must be exact. It is in `ultrahonk/docs/zk-verifier-reference.md`, and every row was checked against the reference on the pinned proof.
- Harder: a round that does not hash one contiguous run needs a different shape. Only `eta` does (see Outcome).

## Action Items

1. [x] Stage 0: derive the ZK proof word layout and the hashed range of each transcript round from the generated ZK contract.
2. [x] Stage 0: confirm or adjust the one-`absorb`-per-round design for the ZK transcript and record the result here.
3. [x] Stage 2: implement `proof.fe` and `transcript.fe`; `fe test -f transcript` compares every challenge with the reference value.
