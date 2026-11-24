# ADR-0010: Vault calls the verifier through the standard ABI instead of linking it as a library

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The integration deliverable is the vault sketched on the project's teaching page: a contract that records a claim when the caller proves knowledge of a secret.
- The verifier is large. Staying under the 24,576-byte code-size limit is already a risk for the verifier alone (ADR-0012).
- The verifier's entry point is `verify(bytes,bytes32[])`, the same ABI as the upstream Barretenberg reference (ADR-0008).
- The Fe verifier contract only exists at stage 7. The vault is stage 1.

## Decision

The vault calls the verifier with an external call through the standard ABI. The message type `VerifierMsg` lives in `lib/src/abi.fe` and is shared by both contracts. The verifier is not linked into the vault as a library.

The circuit is the teaching page's vault circuit:

```noir
fn main(x: Field, y: pub Field, recipient: pub Field) {
    assert(x * x == y);
    assert(recipient != 0);
}
```

| Element | Design |
|---|---|
| Storage | `{ y, verifier, claimed, winner }` |
| Entry points | `init(y, verifier)`, `claim(bytes proof) -> bool`, `claimed()`, `winner()` |
| Public inputs | Built by the vault itself as `[y, caller]`. The claimant never supplies them, so a proof copied from the mempool is useless to anyone else. |
| Call | A static call with the typed message `VerifierMsg::Verify`. The verifier cannot change state or call back into a vault that could. |
| Failure | If the verifier answers `false`, `claim` returns `false`. If it reverts, `claim` reverts with the same data. Nothing is recorded in either case. |
| Payout | Not implemented, by decision. The contract records the claim and the claimant only. |

## Outcome (2026-11-23)

- Carried out. `Vault` is in `ultrahonk/vault`, with 13 Fe tests. Details and measurements are in `ultrahonk/vault/README.md`.
- A claim succeeds in front of the real `HonkVerifier`, with a second pinned proof made for the address of the Fe test contract.
- A Fe test cannot choose the caller of a call. A caller is a `Claimer` contract that forwards `claim`, or the test contract itself, whose address is fixed with `fe` 26.6.0.
- Eleven tests put a stand-in behind the vault (in one of them, an address without code). Two put `HonkVerifier` there.
- The decision named a storage of `{ y, verifier, claimed }` and one entry point. `winner` and the two read functions were added.
- The vault protects nothing, and the documents say so since 2026-11-23. The context above calls the witness a secret; anyone can compute a square root of the public `y` and prove for their own address. The public inputs carry no vault address and no chain id, and with a relayer the relayer is the caller. The vault shows how a Fe contract consumes a proof; it is not a puzzle.
- Since issue #5, `y` and `verifier` are immutable fields: set once in `init` and kept in the contract's code. Only `claimed` and `winner` are storage.

## Options Considered

### Option A: External call through `verify(bytes,bytes32[])` (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One shared `msg` and one external call |
| Code size | The vault holds only its own logic |
| Coupling | Any contract with that ABI can stand behind the vault, including the upstream verifier |
| Risk | Depends on cross-contract calls and constructor arguments working from Fe (stage 0, spike 2) |
| Fit with Fe 26.6.0 | Uses a `msg` with a `sol(...)` selector; the `Bytes` + `Vec<Bytes32>` shape was untested when the plan was written |

**Pros:** The vault stays small. The vault and the verifier can be built and replaced independently.  
**Cons:** Two deployments. The verifier address must be supplied at `init`.

### Option B: Link the verifier library into the vault

| Dimension | Assessment |
|-----------|------------|
| Complexity | No external call and no shared `msg` |
| Code size | The vault's bytecode would contain the verifier, which is already a code-size risk alone |
| Coupling | One verifier implementation, fixed at compile time |
| Risk | Exceeding the code-size limit |
| Fit with Fe 26.6.0 | Not evaluated in the plan |

**Pros:** One contract to deploy.  
**Cons:** Ties the vault to the verifier's size and to the verifier library being finished.

## Trade-off Analysis

The verifier's size is a known risk (ADR-0012), so adding it to the vault's bytecode would make the integration deliverable depend on that risk. An external call keeps the vault small and decoupled, at the cost of a second deployment.

## Consequences

- Easier: the vault's code can be written at stage 1, before the Fe verifier exists.
- Easier: the vault works with any verifier that implements the ABI.
- Harder: under the Fe-only layout (ADR-0009) the vault is tested with Fe tests, so the tests need verifier contracts written in Fe. They are stand-ins declared in the test section of `vault/src/lib.fe`.
- Harder: the tests (valid claim, replay, different caller) cannot choose the caller. They use forwarding contracts (see Outcome).
- Harder: a real claim from a test needs a proof made for the caller. A proof made for a contract deployed with `create2` breaks when that contract's code changes, so the second pinned proof is made for the test contract's own address.
- Revisit: payout logic, which is out of scope.

## Action Items

1. [x] Stage 1: add `VerifierMsg` to `lib/src/abi.fe` and implement `Vault` with `init` and `claim`.
2. [x] Stage 1: Fe tests for a valid claim, a replay and a different caller; settle how the caller is set and which verifier answers.
3. [x] Stage 7: run the vault in front of the Fe verifier. Two tests do.
