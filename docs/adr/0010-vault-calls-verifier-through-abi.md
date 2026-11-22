# ADR-0010: Vault calls the verifier through the standard ABI instead of linking it as a library

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The integration deliverable is the vault ("cofre") sketched on the project's teaching page: a contract that records a claim when the caller proves knowledge of a secret.
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
| Storage | `{ y, verifier, claimed }` |
| Entry points | `init(y, verifier)`, `claim(bytes proof) -> bool` |
| Public inputs | Built by the vault itself as `[y, caller]`. The claimant never supplies them, so a proof copied from the mempool is useless to anyone else. |
| Failure | A revert or a `false` result from the verifier fails the claim |
| Payout | Not implemented. The contract records the claim only. |

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
- Harder: under the Fe-only layout (ADR-0009) the vault is tested with Fe tests. Which verifier answers the vault in those tests before stage 7 is not stated, and the original stage 1 cut line, which relied on the Solidity verifier, needs restating.
- Harder: the tests (valid claim, replay, different caller) need the Fe test harness to choose the caller, which the original plan treated as unconfirmed.
- Revisit: payout logic, which is out of scope.

## Action Items

1. [ ] Stage 1: add `VerifierMsg` to `lib/src/abi.fe` and implement `Vault` with `init` and `claim`.
2. [ ] Stage 1: Fe tests for a valid claim, a replay and a different caller; settle how the caller is set and which verifier answers.
3. [ ] Stage 7: run the vault tests against the Fe verifier.
