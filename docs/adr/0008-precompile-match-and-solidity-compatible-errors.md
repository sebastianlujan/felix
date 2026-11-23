# ADR-0008: Precompile results through `match`, and Solidity-compatible custom errors with revert on failure

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The Fe std wrappers for the precompiles (`ec_add`, `ec_mul`, `ec_pairing`, `modexp`) return a `Result`.
- Taking a default on failure, `unwrap_or(default: 0)`, would let the computation continue with a silent 0. In a verifier that is a soundness bug.
- The upstream Barretenberg reference reverts on a bad proof, with custom errors defined in its `Errors.sol`.
- The Fe verifier is meant to be a drop-in for the reference behind the same ABI, `verify(bytes,bytes32[])`.
- The negative tests compare revert selectors with the reference (ADR-0009).

## Decision

Two rules.

**Precompile results.** Always `match` on the `Result`. `Err` reverts. Never `unwrap_or(default: 0)`. The code follows the `expect_word` / `expect_pair` / `expect_bool` pattern of `crates/fe/tests/fixtures/fe_test/precompile_wrappers.fe` in the Fe repository.

**Verifier failure.** The verifier contract reverts with the same custom errors as the reference, declared as `#[error]` structs and raised with `revert_error`. It does not return `false` for a bad proof.

| Item | Value in the original non-ZK plan | ZK target |
|---|---|---|
| Error set | `SumcheckFailed`, `ShpleminiFailed`, `ProofLengthWrongWithLogN`, `PublicInputsLengthWrong`, `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder`, `InvertOfZero` | **[ZK: TBC]** |
| Check order | Proof length, limbs, coordinates and scalars in proof order, public-input count, public-input range, sumcheck, Shplemini | **[ZK: TBC]** |

The check order must match the reference, or a given bad input reverts with a different selector.

## Options Considered

### Option A: `match` on precompiles, revert with the reference's custom errors (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | One `#[error]` struct per error; checks ordered as in the reference |
| Soundness | A precompile failure can never become a value |
| Drop-in compatibility | Same ABI and same revert selectors as the reference |
| Testability | Each tamper case has one expected selector |
| Fit with Fe 26.6.0 | Uses `#[error]` structs and `revert_error` |

**Pros:** A caller written for the reference works unchanged. Failures say which check failed.  
**Cons:** The check order becomes part of the contract's behaviour.

### Option B: Return `false` on any failure

| Dimension | Assessment |
|-----------|------------|
| Complexity | Lowest: no error types, no ordering constraint |
| Soundness | Sound if every failure path really returns `false` |
| Drop-in compatibility | Not a drop-in: the reference reverts |
| Testability | A test cannot tell which check rejected the proof |
| Fit with Fe 26.6.0 | No obstacle |

**Pros:** Simple. Callers need no revert handling.  
**Cons:** Behaviour differs from the reference, and negative tests lose their precision.

### Option C: `unwrap_or(default: 0)` on precompile results

| Dimension | Assessment |
|-----------|------------|
| Complexity | Shortest code at each call site |
| Soundness | Broken: a failed precompile yields 0 and verification continues |
| Drop-in compatibility | Not applicable |
| Testability | The failure is invisible |
| Fit with Fe 26.6.0 | Available on `Result`, which is why the rule is written down |

**Pros:** None that survive the soundness problem.  
**Cons:** Rejected outright by the plan.

## Trade-off Analysis

Option C is unsafe. Between A and B, the project wants a verifier that can replace the reference without changing its callers, and tests that can name the failing check. Both follow from reverting with the reference's errors. The price is that the order of checks must be copied exactly.

## Consequences

- Easier: negative tests assert one selector per tamper case, captured from the reference.
- Easier: the vault treats a revert or a `false` result the same way, as a failed claim (ADR-0010).
- Harder: the check order and the error set are flavor-specific, and for the ZK contract they are **[ZK: TBC]**.
- Harder: `inv(0)` must be caught before `modexp`, which would return 0 silently (ADR-0006).
- Revisit: the layer at which the revert is raised. The plan's sketches give the library functions a `bool` result, and the plan does not say where the contract turns a failed check into the matching error.

## Action Items

1. [ ] Stage 0b: read the error set and the check order from the generated ZK contract.
2. [ ] Stage 2: declare the errors and implement the length, limb, coordinate and scalar checks in the reference's order; test the reverts on scalar ≥ P and coordinate ≥ Q.
3. [ ] Stage 6: wrap `ec_add`, `ec_mul`, `ec_pairing` and `modexp` with the `expect_*` match pattern.
4. [ ] Stage 7: negative Fe tests assert, for each tamper case, the same selector as the reference.
