# ADR-0003: Sibling ingots without a workspace

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The work is added gradually in new packages, the same way the root library and `calculator` pair of this repository was built. `calculator/src/lib.fe` and `calculator/fe.toml` are the pattern to mirror.
- The root library, `calculator/` and the root `README.md` must not be modified.
- Four Fe packages are needed: a verifier library, a verifier contract, a vault contract and a toy verifier.
- The verifier and the vault share one message definition for `verify(bytes,bytes32[])`.

## Decision

Four sibling ingots under `ultrahonk/`, joined by relative path dependencies. No workspace.

| Ingot | Path | Kind |
|---|---|---|
| `ultrahonk` | `ultrahonk/lib` | Pure library |
| `ultrahonk_verifier` | `ultrahonk/verifier` | Contract `HonkVerifier`, with a per-circuit `vk.fe` |
| `ultrahonk_vault` | `ultrahonk/vault` | Contract `Vault` |
| `honk_toy` | `ultrahonk/toy` | Pure library, Honk over F_17 |

`lib/src/abi.fe` holds the shared `msg`: the verifier receives it and the vault sends it.

## Options Considered

### Option A: Sibling ingots with relative path dependencies (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One `fe.toml` per ingot, each with a path dependency where needed |
| Cost | Commands run per ingot (`fe check`, `fe fmt --check`, `fe test` in each) |
| Risk | Low: it is the pattern `calculator/` already uses in this repository |
| Fit with Fe 26.6.0 | Mirrors a package pair that already exists here |

**Pros:** Follows an existing, known pattern. Each ingot builds and tests alone. The toy line can be developed in a separate worktree without touching the others.
**Cons:** No single command covers all ingots; `scripts/check.sh` has to loop over them.

### Option B: A Fe workspace

| Dimension | Assessment |
|-----------|------------|
| Complexity | Not evaluated in the plan |
| Cost | Not evaluated in the plan |
| Risk | Unknown: the plan records no trial of a workspace on Fe 26.6.0 |
| Fit with Fe 26.6.0 | Not evaluated |

**Pros:** Could give one entry point for all packages.
**Cons:** Untested here, with about 48 hours to the deadline.

## Trade-off Analysis

With about 48 hours available, the plan prefers the pattern that already exists in the repository over an untested one. The cost is running commands per ingot, which a script covers.

## Consequences

- Easier: each ingot is a self-contained unit for review, and a stage can be reverted alone.
- Easier: the two implementation lines touch disjoint directories (ADR-0014).
- Harder: dependency paths are relative, so moving an ingot means editing its dependants.
- Harder: an end-to-end run needs a script.
- Revisit: a workspace, once the deadline has passed.

## Action Items

1. [ ] Stage 0b: keep one `fe.toml` per ingot, with relative path dependencies, while the skeletons are switched to the ZK target.
2. [ ] Stage 1: add `lib/src/abi.fe` with the shared `VerifierMsg`.
3. [ ] Stage T1: create `ultrahonk/toy` as its own ingot on the toy line.
4. [ ] Stage 8: make `scripts/check.sh` run the checks in every ingot.
