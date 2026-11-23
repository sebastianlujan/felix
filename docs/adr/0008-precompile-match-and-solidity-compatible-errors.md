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

| Item | ZK verifier |
|---|---|
| Error set | `ProofLengthWrongWithLogN`, `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder`, `PublicInputsLengthWrong`, `SumcheckFailed`, `ShpleminiFailed`, `ConsistencyCheckFailed`, `GeminiChallengeInSubgroup`, `PointAtInfinity`, `InvertOfZero`, `NotPowerOfTwo`, `ModExpFailed` |
| Check order | Proof length; each proof word in order (limbs, coordinates, scalars); public-input count; public-input range; sumcheck; Shplemini scalars; consistency check; multi-scalar multiplication; pairing-point aggregation; pairing |

The check order must match the reference, or a given bad input reverts with a different selector.

## Outcome (2026-11-23)

Carried out, with these details.

- **Precompiles.** No `unwrap_or` exists in the verifier code. Each call is matched where it is made: a failed `ec_mul` or `ec_add` reverts with `ShpleminiFailed` (`lib/src/opening.fe`), a failed `modexp`, or one whose answer is not the inverse, with `ModExpFailed` (`lib/src/fr.fe`). A failed pairing call counts as a pairing that does not hold, as in the reference, and the contract reverts with `ShpleminiFailed`. The `expect_*` helpers appear only in the tests of `lib/src/std_assumptions.fe`.
- **Where the revert is raised.** The library reverts for the range checks, a sumcheck round that does not hold, the consistency check and a failed curve operation. It returns a `bool` for the last sumcheck comparison and for the pairing. `HonkVerifier` turns `false` into `SumcheckFailed` or `ShpleminiFailed` and never returns `false`.
- **Selectors.** A test asserts that each of the 13 errors in `lib/src/errors.fe` has the selector of the reference's declaration. `NotPowerOfTwo` is declared and never raised: the port computes `r^256` by eight squarings.
- **Check order.** The order of the checks before any algebra was confirmed on the reference with calls that break two rules at once, and the Fe contract is tested with the same calls. The later steps follow the order of the reference's code. One recorded case shows it: a flipped fold commitment fails both the consistency check and the multi-scalar multiplication, and reverts with `ConsistencyCheckFailed` in both verifiers.
- **Tests.** For every recorded invalid call the contract reverts with the selector the reference returned, with the one exception below. The tests do not show that every proof the reference rejects is rejected.

Recorded differences from the reference:

| Case | Reference | Fe | Tested |
|---|---|---|---|
| Proof word 138 with its low bit flipped: `shplonkQ` is off the curve, so the first multiplication of the multi-scalar multiplication fails | Goes on after the failed precompile call, which takes all the gas it was given, runs out of gas and reverts without data | Reverts with `ShpleminiFailed()` at the first failed call | Yes |
| A carried pairing point off the curve | Reverts without data: captured from the reference (`lib/src/opening_vectors.fe`) | Reverts with `ShpleminiFailed()` | The Fe side only |
| The `modexp` precompile call itself fails | Reverts with the four raw bytes `0xf8d61709` | Reverts with `ModExpFailed()` (`0x1f7ec5f0`) | No test triggers it |
| The `modexp` precompile call succeeds and its answer is not the inverse | Uses the answer as returned | `fr::inv` reverts with `ModExpFailed()` unless `a * answer == 1` | The Fe side only: `inv(P)`, where the precompile answers 0. A chain with no code at 0x05 was read from the code, not run |

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
- Easier: no claim is recorded when the verifier reverts or answers `false`. The vault passes a revert on and returns `false` for `false` (ADR-0010).
- Harder: the check order and the error set are flavor-specific. For the ZK contract they are in the table above.
- Harder: `inv(0)` must be caught before `modexp`, which would return 0 silently (ADR-0006).
- Settled: the layer at which the revert is raised (see Outcome).

## Action Items

1. [x] Stage 0: read the error set and the check order from the generated ZK contract.
2. [x] Stage 2: declare the errors and implement the length, limb, coordinate and scalar checks in the reference's order; test the reverts on scalar ≥ P and coordinate ≥ Q.
3. [x] Stage 6: `match` the results of `ec_add`, `ec_mul`, `ec_pairing` and `modexp`.
4. [x] Stage 7: negative Fe tests assert, for each recorded invalid call, the selector the reference returned.
