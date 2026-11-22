# ADR-0013: Scope and framing: Noir + Barretenberg proofs verified on the EVM, not the Aztec network

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The work is described as an "Aztec integration". That phrase can be read two ways.
- Aztec network contracts are written in Noir and verify by recursion, so no Fe contract runs there. The project's teaching page says the same.
- As a product, verifying these proofs on the EVM is already solved: Barretenberg emits an audited Solidity verifier that Fe can call.
- No Fe UltraHonk verifier was found. `fe-lang/rosetta` has Groth16, a gnark Plonk and a Halo2 skeleton. Another contest entry covers Groth16/PLONK/halo2/FRI.
- The contest brief is open-ended: "proof verification… bring test vectors, explicit assumptions, reusable abstractions".

| Judging criterion | Weight |
|---|---|
| Technical quality | 30 |
| Fe-specific value | 25 |
| Originality | 20 |
| Usefulness | 15 |
| Docs / demo | 10 |

## Decision

The integration is with Aztec's proving stack: a Noir circuit, proved by Barretenberg, verified on the EVM by a verifier written in Fe. `ultrahonk/README.md` states exactly that.

| In scope | Out of scope |
|---|---|
| A native Fe port of the ZK UltraHonk verifier (`-t evm`, the flavor Aztec's own L1 verifier uses) | Anything running on the Aztec network |
| A Fe vault contract that consumes a proof through that verifier | The non-ZK flavor of the real verifier |
| A toy Honk verifier over F_17 | Vault payout logic, gas optimisation, a VK generator CLI, multiple circuits |
| Committed expected values and stated assumptions | Any change to the teaching page |

The work is presented as a contest entry and a readable reference, not as a replacement for the audited verifier.

## Options Considered

### Option A: Noir + Barretenberg proofs verified on the EVM by Fe (chosen)

| Dimension | Assessment |
|-----------|------------|
| Feasibility | Fe targets the EVM, where these proofs can be verified |
| Contest value | Native Fe code for a proof system with no Fe verifier found |
| Cost | The staged port described in the plan |
| Accuracy of the claim | States what the code does |

**Pros:** Achievable and original. The claim can be checked by a reader.
**Cons:** Does not touch the Aztec network.

### Option B: Target the Aztec network itself

| Dimension | Assessment |
|-----------|------------|
| Feasibility | None: Aztec network contracts are Noir and verify by recursion |
| Contest value | Not applicable |
| Cost | Not applicable |
| Accuracy of the claim | A claim of network integration would be false |

**Pros:** None available to a Fe contract.
**Cons:** Not possible.

### Option C: Call Barretenberg's Solidity verifier from Fe, without a port

| Dimension | Assessment |
|-----------|------------|
| Feasibility | Works today: the audited verifier exists and Fe can call it |
| Contest value | Little Fe-specific value or originality |
| Cost | Lowest |
| Accuracy of the claim | Accurate, but the verification itself would not be in Fe |

**Pros:** Uses audited code. Smallest effort.
**Cons:** Nothing new in Fe, and it conflicts with a Fe-only repository (ADR-0009).

## Trade-off Analysis

Option B is not available. Option C is the sensible product choice and the weakest contest entry: 45 of the 100 judging points are for Fe-specific value and originality. Option A is the only one that produces a native Fe verifier, and its framing is narrow enough to be true.

## Consequences

- Easier: judges can see at once what is claimed and what is not.
- Easier: scope arguments during the 48 hours are settled by the out-of-scope list.
- Harder: the README has to carry the framing carefully, since "Aztec integration" invites the wider reading.
- Harder: the port is unaudited code next to an audited reference, and the documentation must not suggest otherwise.
- Revisit: the out-of-scope items after the contest.

## Action Items

1. [ ] Stage 8: state the framing in `ultrahonk/README.md`: proving stack, not network.
2. [ ] Stage 8: list assumptions and out-of-scope items in the README, including which branch of pairing-point aggregation the test circuit exercises.
3. [ ] Stage 8: add the "reused from / learned from" table to the README.
