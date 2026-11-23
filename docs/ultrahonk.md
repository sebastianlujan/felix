# UltraHonk verification in Fe: plan and outcome

This project verifies UltraHonk proofs natively in Fe, in packages under `ultrahonk/` and `honk-toy/`: Noir proofs verified natively in Fe. It has three deliverables, and all three are built and tested: a port of Barretenberg's zero-knowledge (ZK) UltraHonk verifier (BN254, Keccak transcript), a vault contract that takes a Noir + Barretenberg proof through that verifier, and a hand-sized toy Honk verifier over F_17. The repository holds Fe, one Noir circuit, shell scripts and the toy's Python reference. It tracks no Solidity: the Solidity verifier that Barretenberg generates is a local, uncommitted reference oracle, and every committed test is a Fe test that compares against values captured from that oracle on a real Noir proof. The work is a contest entry due **Nov 24, 2026 23:59 UTC**.

> **Status (2026-11-23).** Every stage is done. `fe test` passes in the five ingots: 176 tests in `lib`, 2 in `relations`, 16 in `verifier`, 11 in `vault`, 70 in `toy`.
>
> - `HonkVerifier` accepts the pinned proof and rejects every recorded invalid call. A test flips the low bit of each of the 142 proof words, and none is accepted.
> - A claim succeeds through `Vault` in front of `HonkVerifier`.
> - The tests do not show that every proof the reference rejects is rejected.
> - Two planned items were not written: `scripts/check.sh` and a script that enforces the code-size limit. Sizes were measured by hand (see [Measured results](#measured-results)).
>
> **How to read this document.** It was written as the plan and now also records the outcome. Where a planned detail changed, the text states what was built. The exact proof layout, transcript, formulas and error selectors are in [`ultrahonk/docs/zk-verifier-reference.md`](../ultrahonk/docs/zk-verifier-reference.md). Test coverage and measurements are in [`ultrahonk/README.md`](../ultrahonk/README.md).

## Quick path

A reader needs only `fe` 26.6.0. Nothing below needs `bb`, `nargo`, Python or Foundry.

1. Run the tests of each ingot.

   ```sh
   cd ultrahonk
   (cd lib && fe test)        # 176 tests
   (cd relations && fe test)  # 2
   (cd verifier && fe test)   # 16
   (cd vault && fe test)      # 11
   (cd ../honk-toy && fe test) # 70
   ```

2. Read the result. In `verifier`, `test_the_valid_proof_is_accepted` shows the Fe verifier accepting the pinned proof. In `vault`, `test_the_real_verifier_accepts_a_claim_from_the_address_the_proof_was_made_for` shows a claim through the vault in front of it.

To run one group of tests, filter by name: for example `fe test -f transcript` inside `ultrahonk/lib`.

Regenerating inputs is optional and is not needed to verify: see [Verification](#verification).

| If you are | Read |
|---|---|
| The repository owner, reviewing stage by stage | [Stages](#stages), [Porting hazards](#porting-hazards-real-verifier), [Workflow](#workflow) |
| A contest judge | [Purpose and context](#purpose-and-context), [Reference oracle and expected values](#reference-oracle-and-expected-values), [Verification](#verification), [Assumptions, risks, out of scope](#assumptions-risks-out-of-scope) |
| Looking for the reason behind a choice | [Decisions](#decisions) and the [ADR index](adr/README.md) |

## Deliverables

| # | Deliverable | Package | What it is | Status |
|---|---|---|---|---|
| 1 | Real verifier | `ultrahonk/lib`, `ultrahonk/relations`, `ultrahonk/verifier` | Port of Barretenberg's ZK UltraHonk verifier (BN254, Keccak transcript with zero-knowledge), as two contracts: `HonkVerifier` and `HonkRelations` | Done. Accepts the pinned proof and rejects every recorded invalid call |
| 2 | Integration contract | `ultrahonk/vault` | A Fe application contract that takes a Noir + Barretenberg proof through the verifier (the teaching page's vault) | Done. A claim succeeds in front of the real verifier. No payout, by decision |
| 3 | Toy verifier | `honk-toy` | The teaching page's hand-sized Honk over F_17 with KZG over F_101, ported to Fe, including the page's sumcheck mask | Done. Its verdict equals the reference's in all 15 scenarios |

## Purpose and context

### Why this is being built

The goal is UltraHonk verification written natively in Fe, built gradually in new packages of this repository, the same way the root library and `calculator` pair was built. The project's teaching page ("UltraHonk by hand", its sections on practice and on integration with Fe) sketches the modules, the milestones and a vault application. None of the page's Fe sketches had been compiled.

The research behind the plan established:

| Finding | Detail |
|---|---|
| Not done in Fe | `fe-lang/rosetta/examples/verifier` has Groth16, a gnark Plonk and a Halo2 skeleton, and no Honk. No Fe UltraHonk verifier was found on GitHub. Another contest entry, `0xitsss/fe-zk`, covers Groth16/PLONK/halo2/FRI, not Honk. |
| Already solved on the EVM as a product | Barretenberg emits an audited Solidity verifier that Fe can call. The value of this work is as a contest entry and as a readable reference. |

### Scope: Noir proofs verified natively in Fe

| It means | It does not mean |
|---|---|
| A Noir circuit, proved by Barretenberg, with the proof verified on the EVM by code written in Fe. | Anything running on the Aztec network. Aztec network contracts are Noir and verify by recursion, so no Fe contract runs there. The teaching page says the same. |

`ultrahonk/README.md` states the same scope. See [ADR-0013](adr/0013-scope-noir-barretenberg-on-evm.md).

### Two decisions that shaped the work

The project owner made both on 2026-11-22, during stage 0, when the real verifier was still a skeleton.

| Area | Decision | ADR |
|---|---|---|
| Flavor of the real verifier | ZK only (`bb -t evm`). A first draft of the plan named the other flavor; it was dropped because a vault that hides its secret needs ZK. | [0001](adr/0001-port-bb-6-zk-verifier.md) |
| Repository contents and tests | No Solidity in the repository and no Solidity code in the documentation. The generated verifier is a local, untracked reference. Every committed test is a Fe test. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |

Why the ZK flavor:

| Reason | Detail |
|---|---|
| The vault hides a secret | A proof without zero-knowledge leaks witness evaluations, so a vault that hides its secret needs ZK. |
| Standard target | `-t evm` is `bb`'s standard EVM target. |
| Same flavor as Aztec | It is the flavor Aztec's own L1 verifier uses. |
| Cost | More protocol steps: Libra masking, a small-subgroup consistency check, a Gemini masking polynomial. All of them are ported. |

### Deadline and judging

| Item | Value |
|---|---|
| Submission deadline | Nov 24, 2026 23:59 UTC (about 48 hours away when the plan was written) |
| Feature freeze | Nov 24, 2026 14:00 UTC |
| Contest brief | Open-ended: "proof verification… bring test vectors, explicit assumptions, reusable abstractions" |
| Delivery model | The Fe code was written stage by stage, and the repository owner can review each stage. All stages were done by 2026-11-23. |

| Judging criterion | Weight |
|---|---|
| Technical quality | 30 |
| Fe-specific value | 25 |
| Originality | 20 |
| Usefulness | 15 |
| Docs / demo | 10 |

**Outcome wanted:** coherent, tested, honestly labelled packages under `ultrahonk/` and `honk-toy/`, with the real verifier checked value by value against Barretenberg's own verifier on a real Noir proof. [What the Fe tests assert](#what-the-fe-tests-assert) states how far the tests go.

## Decisions

Each row links to the Architecture Decision Record that holds the context, the options considered, the consequences and the outcome.

| Topic | Decision | ADR |
|---|---|---|
| Source of truth (real) | The Solidity verifier that `bb` 6.0.0 generates with `-t evm`: Keccak transcript with zero-knowledge (upstream `BaseZKHonkVerifier.sol` + `ZKTranscript.sol` at `aztec-packages@b225653`, template `honk_zk_contract.hpp`). Only the ZK flavor is built. | [0001](adr/0001-port-bb-6-zk-verifier.md) |
| Tooling | Project-local `bb` 6.0.0 and `nargo` 1.0.0 in `ultrahonk/.tools/`. The installed `bb` 0.84.0 / `nargo` beta.3 are too old and are left untouched. | [0002](adr/0002-project-local-bb-and-nargo.md) |
| Layout | Five sibling ingots with relative path dependencies, no workspace. | [0003](adr/0003-sibling-ingots-without-workspace.md) |
| Proof representation (real) | Keep the proof as `Bytes` and read words by index; no `Proof` struct. One `absorb` helper for the transcript: every round after the first hashes `prev ‖ one contiguous run of proof words`. | [0004](adr/0004-proof-as-bytes-read-by-offset.md) |
| Sizes (real) | Runtime `log_n` with fixed maximum-size arrays, like the upstream reference: `MAX_LOG_N = 25`, `MAX_SLOTS = 67`. No const generics. | [0005](adr/0005-runtime-log-n-fixed-max-arrays.md) |
| Field | Plain functions on `u256`, no operator-overloaded type (`sonatina#232`). | [0006](adr/0006-field-arithmetic-plain-u256-functions.md) |
| Hashing | The std `Packed` builder for the transcript rounds, the pairing input and the calldata sent to the relations contract. `keccak_words` for a single-word rehash and for the eight-word recursion separator. | [0007](adr/0007-hashing-with-std-packed-builder.md) |
| Precompiles | Always `match` on `Result`. Never `unwrap_or(default: 0)`: a silent 0 would be a soundness bug. | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Failure | The verifier contract reverts on a bad proof with the same custom errors as the upstream reference, so its ABI is a drop-in. Negative tests assert the selector the reference returned. See [Failure behaviour](#failure-behaviour) for the recorded differences. | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Reference oracle | Barretenberg's generated Solidity verifier is the reference oracle and is not committed. It lives in the local, untracked `ultrahonk/.oracle/` and is regenerated by `scripts/vectors.sh`. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Repository contents | Fe, a Noir circuit, shell scripts and the toy's Python reference. No Solidity, no JavaScript, no Foundry project, and no Solidity code in the documentation. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Tests and vectors | Every committed test is a Fe test run with `fe test`. Expected values and the revert of each invalid call are captured from the local oracle and committed as Fe constants with their provenance stated. Toy vectors are generated with Python 3 and committed. Tests need no `bb`, `nargo`, Python or Foundry. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Circuit | The teaching page's vault circuit (shown in [Design: vault](#design-vault-integration-contract)). | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Vault ↔ verifier | A static call through the standard ABI `verify(bytes,bytes32[])`, not library linking. The vault stays small and is not tied to one verifier implementation. | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Source of truth (toy) | A Python port of the teaching page's math block, function by function (`honk-toy/reference/honk.py`). A generator runs it and writes the vectors. Challenges are inputs. The toy includes the page's sumcheck mask. | [0011](adr/0011-toy-verifier-vectors-from-reference.md) |
| Code size | The relations are a second contract, `HonkRelations`, asked with a static call. Sizes are measured with `fe build` at `-O 1`, `-O 2` and `-O s`. No script enforces the limit. | [0012](adr/0012-code-size-strategy.md) |
| Scope and framing | Noir proofs verified natively in Fe, on the EVM. Not the Aztec network. | [0013](adr/0013-scope-noir-barretenberg-on-evm.md) |
| Delivery | Stages, incremental commits, and parallel lines in separate worktrees. | [0014](adr/0014-staged-delivery-incremental-commits.md) |
| `fe-lang/rosetta` | Structure only. It targets the 26.1 std and does not compile on 26.6.0. It has no licence, so nothing is copied from it. | [0001](adr/0001-port-bb-6-zk-verifier.md) |

## Package layout

The work lives under `ultrahonk/`, `honk-toy/` and `docs/`. Its commits do not change the root library or `calculator/`. The toy was first built inside `ultrahonk/`; it was moved to the top level on 2026-11-23, because it shares no code with the real verifier.

```
docs/
  ultrahonk.md         this document
  adr/                 decision records 0001 to 0014
honk-toy/              ingot "honk_toy": Honk over F_17 (library); README.md
  src/lib.fe f17.fe relations.fe sumcheck.fe curve.fe shplemini.fe libra.fe verifier.fe
      vectors.fe                generated
  reference/honk.py gen_vectors.py   Python 3, standard library only
ultrahonk/
  README.md            status, test coverage, measurements, how to regenerate
  docs/zk-verifier-reference.md   proof layout, transcript, formulas, errors
  lib/                 ingot "ultrahonk" (library)
    src/lib.fe abi.fe errors.fe fr.fe types.fe wire.fe
        proof.fe transcript.fe sumcheck.fe relations.fe
        shplemini.fe consistency.fe opening.fe
        std_assumptions.fe        tests that pin std precompile and Keccak behaviour
        vectors.fe                pinned proof and key (generated), then captured values
        test_address_vectors.fe   second pinned proof (generated)
        relations_vectors.fe opening_vectors.fe expected.fe   captured from the oracle
  relations/           ingot "ultrahonk_relations": contract HonkRelations
  verifier/            ingot "ultrahonk_verifier": contract HonkVerifier
  vault/               ingot "ultrahonk_vault": contract Vault; README.md
  circuit/             Nargo.toml, Prover.toml, Prover_test_address.toml, src/main.nr
  vectors/             proof, public_inputs, vk, vk_hash (raw bb output); test_address/
  scripts/vectors.sh       regenerates vectors/ and the local oracle
  scripts/proof_to_fe.sh   prints the proofs and the key as Fe constants; --check compares
  .tools/              not committed: bb and nargo binaries
  .oracle/             not committed: Barretenberg's generated Solidity verifier
```

| Rule | Detail |
|---|---|
| Shared ABI | `lib/src/abi.fe` holds the `msg` for `verify(bytes,bytes32[])`, shared by the verifier (which receives it) and the vault (which sends it). |
| Verification key | The constant `VK` in `lib/src/vectors.fe`, printed from `vectors/vk` by `scripts/proof_to_fe.sh`. There is no per-circuit `vk.fe`. |
| No Solidity | The repository tracks no Solidity file, no JavaScript file, no Foundry project and no forge-std. |
| Local oracle | `ultrahonk/.oracle/` is a local, untracked reference tool. `scripts/vectors.sh` regenerates the verifier in it. |
| Tests | Every committed test is a Fe test, run with `fe test` in its ingot. |
| Build outputs | `out/` and `circuit/target/` are ignored by git. |

## Project-local tooling

The installed `bb` 0.84.0 and `nargo` beta.3 are too old. The project downloads `bb` 6.0.0 and `nargo` 1.0.0 into `ultrahonk/.tools/` instead of replacing them ([ADR-0002](adr/0002-project-local-bb-and-nargo.md)). The asset names below were verified for Darwin arm64.

```sh
cd ultrahonk && mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
.tools/bb/bb --version && .tools/nargo/bin/nargo --version   # expect 6.0.0 and 1.0.0
```

This downloads and runs two official release binaries. `~/.bb` and `~/.nargo` are not touched. The tools are needed only to regenerate the proofs, the verification key and the local oracle, not to run the tests.

## Reference oracle and expected values

Barretenberg's generated Solidity verifier is the reference oracle. It is not committed. Tests are written in Fe against expected values captured from it ([ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md)).

### Pipeline (`scripts/vectors.sh`)

```sh
(cd circuit && nargo execute)
(cd circuit && nargo execute --prover-name Prover_test_address test_address)
bb write_vk -b circuit/target/vault.json -o vectors -t evm
bb prove    -b circuit/target/vault.json -w circuit/target/vault.gz -k vectors/vk -o vectors -t evm
bb prove    -b circuit/target/vault.json -w circuit/target/test_address.gz -k vectors/vk -o vectors/test_address -t evm
bb write_solidity_verifier -k vectors/vk -o .oracle/src/HonkVerifier.sol -t evm   # local, untracked
bb verify   -k vectors/vk -p vectors/proof -i vectors/public_inputs -t evm
bb verify   -k vectors/vk -p vectors/test_address/proof -i vectors/test_address/public_inputs -t evm
```

The script calls the project-local binaries by path and exits unless they report `bb` 6.0.0 and `nargo` 1.0.0. ZK proving is randomized, so a run overwrites the two pinned proofs with different valid ones. `ultrahonk/README.md` (section "Regenerate the vector") says how to return to the pinned proofs.

### How expected values reach the tests

1. `scripts/vectors.sh` regenerates the proofs, the verification key and the oracle's source.
2. Foundry tests kept locally in `.oracle/test/` run the oracle and log its intermediate values and the revert data of each invalid call.
3. The values are committed as Fe constants. Each file states its provenance at the top: tool, versions, and how the values were captured.
4. Fe tests compare the Fe verifier against those constants.

The local Foundry tests are not in the repository, and `scripts/vectors.sh` does not write them. The captured values therefore cannot be regenerated from the repository alone, which is why their provenance is written down.

### Test-vector provenance

| Artifact | Produced by | Committed |
|---|---|---|
| `circuit/src/main.nr` | The teaching page's vault circuit | Yes |
| `vectors/proof`, `vectors/public_inputs`, `vectors/vk`, `vectors/vk_hash` | `bb` 6.0.0 (`write_vk`, `prove`) with `-t evm` | Yes, raw `bb` output |
| `vectors/test_address/proof`, `vectors/test_address/public_inputs` | The same, from `circuit/Prover_test_address.toml` and the same key | Yes, raw `bb` output |
| `.oracle/src/HonkVerifier.sol` | `bb write_solidity_verifier`, regenerated by `scripts/vectors.sh` | No: local, untracked reference |
| `lib/src/vectors.fe`, first part: proof, public inputs, verification key | `scripts/proof_to_fe.sh` from `vectors/` | Yes. `scripts/proof_to_fe.sh --check` compares |
| `lib/src/vectors.fe`, second part: challenges, public-input delta, round targets, partial pow | Captured from the local oracle | Yes, with provenance |
| `lib/src/relations_vectors.fe` | Inputs and outputs of the oracle's relations, for the pinned proof and for a synthetic input that makes all 31 subrelations non-zero | Yes, with provenance |
| `lib/src/opening_vectors.fe` | The oracle's Shplemini scalars, consistency-check terms, pairing points and aggregation values | Yes, with provenance |
| `lib/src/expected.fe` | The oracle's reverts on invalid calls, and what its sumcheck alone does with them | Yes, with provenance |
| `lib/src/test_address_vectors.fe` | `scripts/proof_to_fe.sh --test-address` from `vectors/test_address/` | Yes. `--check` compares |
| `honk-toy/reference/honk.py` | Python port of the teaching page's math block | Yes |
| `honk-toy/src/vectors.fe` | `honk-toy/reference/gen_vectors.py` (Python 3, standard library only) | Yes. `gen_vectors.py --check` compares |

### What the Fe tests assert

| Area | Assertion |
|---|---|
| Intermediate values | For the pinned proof: every challenge, the public-input delta, each round target, the partial pow, the 31 subrelations and their batched value, the Shplemini scalars, the consistency-check terms and the two points of the pairing equal the captured values. |
| Accept | `HonkVerifier` accepts the pinned proof: 142 words, 82 + 12·log N with log N = 5. |
| Recorded invalid calls | For each one, the Fe verifier reverts with the selector the reference returned. For wrong proof lengths the whole revert data is compared. One case differs: see [Failure behaviour](#failure-behaviour). |
| Every proof word | The low bit of each of the 142 words flipped, one at a time: none is accepted. These flips were not all recorded from the reference, so the test asserts rejection only. |
| Vault | The claim flow against stand-in verifiers, and a claim in front of `HonkVerifier` (see [Design: vault](#design-vault-integration-contract)). |
| Code size | Not a test. Sizes are measured with `fe build` (see [Measured results](#measured-results)). |

The tests do not show that every proof the reference rejects is rejected. There is no fuzzed differential test against the reference verifier: the fixed list of cases replaces it ([ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md)).

### Reuse and licences

This table is the project's record of what was reused and what was only read.

| Source | Licence position | What the project does |
|---|---|---|
| Barretenberg's generated Solidity verifier | — | Used locally as the reference oracle. Not committed. |
| Fe repository fixtures | Apache-2.0 | The `expect_*` test helpers in `lib/src/std_assumptions.fe` follow `precompile_wrappers.fe`, with the attribution in the file. |
| `fe-lang/rosetta` | No licence | Learn from it, copy nothing. |
| Upstream negative test base (`NegativeTestBase.sol`) | Marked `UNLICENSED` | Nothing is copied from it. The invalid calls the tests use are listed in `lib/src/expected.fe`, with how each was captured. |
| Other contest entries | — | Nothing is taken from them. |

## Design: real verifier

Upstream Solidity file and function names in this section are the upstream Barretenberg reference being ported. They are not project code.

### The ZK verifier in numbers

| Quantity | Value |
|---|---|
| Proof size in words (L = log N) | 82 + 12·L: 142 for this circuit |
| Values per sumcheck round | 9 |
| Evaluations in the proof | 42: the masking polynomial, then the 41 entities the relations read (37 unshifted, 5 shifted) |
| Subrelations | 31, in ten relations |
| Slots of the multi-scalar multiplication | 42 + L |
| ZK-specific steps | Libra masking of sumcheck (initial target and last comparison), the row-disabling factor of the last comparison, the Gemini masking polynomial (evaluation 0, slot 1), a consistency check over a subgroup of 256 elements |
| Upstream sources | `BaseZKHonkVerifier.sol` + `ZKTranscript.sol`, with the relations and commitment-scheme helpers they use, at commit `b225653` |

The proof word layout, the hashed range of each transcript round and the table of slots are in [`ultrahonk/docs/zk-verifier-reference.md`](../ultrahonk/docs/zk-verifier-reference.md). Every layout row and every transcript row there was checked against the reference on the pinned proof.

### Modules and entry points

All modules are in `ultrahonk/lib/src/`.

| Module | Entry points | Ports (upstream reference) |
|---|---|---|
| `abi.fe` | `VerifierMsg::Verify { proof: Bytes, public_inputs: Vec<Bytes32> } -> bool`, with the selector of `verify(bytes,bytes32[])` | `IVerifier.verify` |
| `fr.fe` | `add`, `sub`, `mul`, `neg`, `inv`; the constants `P` and `Q` | `FrLib` |
| `proof.fe` | `validate(proof, log_n)`, `word(proof, index)`, one function per offset | The length check and the range checks of `loadProof` |
| `transcript.fe` | `absorb(prev, proof, start, count)`, `generate(vk, proof, public_inputs) -> Transcript` | `ZKTranscriptLib.generateTranscript` |
| `sumcheck.fe` | `public_input_delta`, `rounds`, `final_check`, `verify`, `verify_with_relations_at` | `computePublicInputDelta`, `verifySumcheck`, `computeNextTargetSum` |
| `relations.fe`, `wire.fe` | The ten relations, `batch`, `accumulate`; the message `RelationsMsg::Accumulate`; the entity indices | `RelationsLib` |
| `shplemini.fe` | `scalars`, `commitment`, `slots` | The scalar part of `verifyShplemini`, `computeSquares`, `computeFoldPosEvaluations` |
| `consistency.fe` | `check`, `evaluate`, `evaluate_sparse` | `checkEvalsConsistency` |
| `opening.fe` | `msm`, `negate`, `pairing_points`, `pairing`, `verify` | `batchMul`, `negateInplace`, the pairing-point aggregation, `pairing` |

Plain parameters view the caller's value in place, with no copy. Outputs that are arrays go through `mut` parameters.

`HonkVerifier` (`verifier/src/lib.fe`) runs `validate`, the public-input count check, `generate`, `public_input_delta`, `verify_with_relations_at` and `opening::verify`, in that order. `HonkRelations` (`relations/src/lib.fe`) answers `RelationsMsg::Accumulate` with `accumulate`. The verifier takes the address of the relations contract as its constructor argument.

### Failure behaviour

The Fe verifier reverts with the custom errors of the upstream reference, declared as `#[error]` structs in `lib/src/errors.fe` and raised with `revert_error`, so its ABI is a drop-in for the upstream verifier ([ADR-0008](adr/0008-precompile-match-and-solidity-compatible-errors.md)). A test asserts that each of the 13 selectors equals the selector of the reference's declaration.

The checks run in the order of the reference. The order decides which error a call that breaks two rules reverts with.

| # | Check | Error |
|---|---|---|
| 1 | Proof length | `ProofLengthWrongWithLogN(logN, actual, expected)` |
| 2 | Each proof word, in order: limbs, point coordinates, scalars | `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder` |
| 3 | Number of public inputs | `PublicInputsLengthWrong` |
| 4 | Each public input below `P` | `ValueGeFieldOrder` |
| 5 | Sumcheck: the round checks, then the last comparison | `SumcheckFailed` |
| 6 | Shplemini scalars | `InvertOfZero` on a zero denominator |
| 7 | Consistency check | `GeminiChallengeInSubgroup`, `ConsistencyCheckFailed` |
| 8 | Multi-scalar multiplication | `ShpleminiFailed` |
| 9 | Pairing-point aggregation, only when a limb is non-zero | `ValueGeGroupOrder`, `PointAtInfinity`, `ShpleminiFailed` |
| 10 | Pairing | `ShpleminiFailed` |

Where the revert is raised: the library reverts for checks 1, 2 and 4, for a sumcheck round that does not hold and for checks 6 to 9. Check 3 is in the contract. The library returns a `bool` for the last sumcheck comparison and for the pairing, and the contract turns `false` into `SumcheckFailed` or `ShpleminiFailed`. The contract never returns `false`.

Recorded differences from the reference:

| Case | Reference | Fe | Tested |
|---|---|---|---|
| Proof word 138 with its low bit flipped: `shplonkQ` is off the curve, so the first multiplication of the multi-scalar multiplication fails | Goes on after the failed precompile call, which takes all the gas it was given, runs out of gas and reverts without data | Reverts with `ShpleminiFailed()` at the first failed call | Yes, in `verifier` and `lib` |
| A carried pairing point off the curve | Reverts without data, according to the comment in `lib/src/opening.fe` | Reverts with `ShpleminiFailed()` | The Fe side, in `lib` |
| The `modexp` precompile call itself fails | Reverts with the four raw bytes `0xf8d61709` | `fr::inv` reverts with `ModExpFailed()` (`0x1f7ec5f0`) | No test triggers it |

`NotPowerOfTwo` is declared and never raised: `consistency.fe` computes `r^256` by eight squarings instead of the reference's `pow`.

Precompile results are matched in place (`mul_point`, `add_points` and `pairing` in `opening.fe`, `inv` in `fr.fe`). A failed `ec_add` or `ec_mul` reverts with `ShpleminiFailed`. A failed pairing call counts as a pairing that does not hold, as in the reference.

### Std functions used

From the Fe repository at tag `v26.6.0`:

| Module or use | Items |
|---|---|
| `ingots/std/src/evm/crypto.fe` | `addmod`, `mulmod`, `modexp`, `ec_add`, `ec_mul`, `ec_pairing`, `keccak_words` |
| `ingots/std/src/evm/packed.fe` | The `Packed` builder: `with_capacity(bytes:)`, `u256`, `u32`, `append_span`, `keccak256`, `span` |
| `std::evm` | `staticcall_decode` for the call to the relations contract |
| Test-input helpers | `std::abi::bytes_from_words`, `dyn_array_from` |

`lib/src/std_assumptions.fe` holds seven tests that pin the behaviour the port depends on: `ec_add` and `ec_mul` agree on the generator, `ec_add` rejects a point off the curve, the pairing of the generator with its negation holds, and `Packed` and `keccak_words` give known hashes.

## Design: vault (integration contract)

The vault follows the teaching page's sketch. Its storage is `{ y, verifier, claimed, winner }`. It is deployed with `y` and the address of the verifier, and answers `claim(bytes proof) -> bool`, `claimed()` and `winner()`. A claimant proves knowledge of a secret `x` with this circuit:

```noir
fn main(x: Field, y: pub Field, recipient: pub Field) {
    assert(x * x == y);
    assert(recipient != 0);
}
```

`claim` does four things:

1. Return `false` if already claimed, without asking the verifier.
2. Build the public inputs itself: `[y, caller]`. The claimant never supplies them, so a proof copied from the mempool is useless to anyone else.
3. Ask `verifier.verify(proof, public_inputs)` through `VerifierMsg`, in a static call. If the verifier answers `false`, `claim` returns `false`. If it reverts, `claim` reverts with the same data.
4. Set `claimed` and `winner`.

| Aspect | Detail |
|---|---|
| Why ZK | `x` is the secret. A proof without zero-knowledge leaks witness evaluations. |
| Payout | Not implemented, by decision. The contract records the claim and the claimant only. |
| Tests | 11 Fe tests. Nine put a stand-in behind the vault: a valid claim, a replay, another caller, a wrong proof, a verifier that reverts, a verifier address without code, a verifier that writes storage, the calldata the verifier receives, and the fixed address of the test contract. Two put the vault in front of `HonkVerifier`. |
| Caller in tests | A Fe test cannot choose the caller of a call. A caller is a `Claimer` contract that forwards `claim`, or the test contract itself, whose address is always `0xbd770416a3345f91e4b34576cb804a576fa48eb1` with `fe` 26.6.0. |
| Real claim | The second pinned proof is made for that test address, so a test claims through the vault in front of the real verifier. The first pinned proof, made for `0xc0ffe`, cannot be claimed from a Fe test. |

Details and measurements: [`ultrahonk/vault/README.md`](../ultrahonk/vault/README.md).

## Design: toy verifier

A port of the teaching page's `verify(vk, proof, pis, ch)`: 4 rows, 3 wires, 23 evaluations, 7 subrelations, 2 sumcheck rounds of 6 values, and 10 challenges passed in as inputs (the toy is interactive, as on the page). See [ADR-0011](adr/0011-toy-verifier-vectors-from-reference.md).

The toy also verifies proofs whose sumcheck is masked, the one part of the ZK flavor that the page computes. A masked toy proof is still not zero-knowledge: the 23 evaluations travel unmasked.

| Module | Content |
|---|---|
| `f17.fe` | Arithmetic mod 17. |
| `relations.fe`, `sumcheck.fe` | The 7 subrelations and their batching; public-input delta, round checks, Lagrange evaluation, partial pow, final check. |
| `curve.fe` | F_101, F_101², the curve y² = x³ + 3, G1 and G2 arithmetic, Miller-loop Tate pairing (no precompile exists for this curve). |
| `shplemini.fe` | Batched evaluation, fold evaluations, scalars, MSM, P0 and P1, pairing check. |
| `libra.fe` | The sumcheck mask: KZG check of the two mask openings, initial target, final term. |
| `verifier.fe` | `verify`, `verify_masked`. |
| `reference/honk.py` | The reference: a Python port of the page's math block. |
| `reference/gen_vectors.py` | Runs the reference on 15 scenarios and writes `src/vectors.fe`: 8 of the page's scenarios, 2 more honest runs and 5 masked ones. |

The Fe verdict equals the reference verdict in every scenario, including the "lucky dice" cheat that both accept. Limits, among them that the toy is not secure: [`honk-toy/README.md`](../honk-toy/README.md).

## Stages

All stages are done. The table keeps the plan's stage numbers and states what each one produced.

### Main line (branch `feature/ultrahonk-verifier`)

"Ports:" names the upstream Barretenberg reference functions a stage ports. They are references, not project code.

| # | Work | Outcome |
|---|---|---|
| 0 | Tooling, Noir circuit, `vectors.sh`, the ZK vector, the recorded reference reverts, ingot skeletons, checks of the std | Done. The pipeline ends with `bb verify` accepting both proofs. |
| 1 | `abi.fe` and the `Vault` contract, with Fe tests | Done. 11 tests. A valid claim returns `true`; a replay and another caller fail. |
| 2 | `fr`, `types`, `proof`, `transcript`. Ports: `FrLib`, the checks of `loadProof`, the transcript | Done. Every challenge equals the oracle's value. A scalar ≥ P and a coordinate ≥ Q revert as in the reference. |
| 3–5 | Sumcheck: public-input delta, round checks, the ten relations, the last comparison. Ports: `computePublicInputDelta`, `verifySumcheck`, `computeNextTargetSum`, the ten relations, `scaleAndBatchSubrelations` | Done. The delta, every round target and the partial pow match. The 31 subrelations match one by one, for the pinned proof and for a synthetic input that makes all 31 non-zero. The relations are the contract `HonkRelations`. |
| 6 | The opening: Shplemini scalars, Libra consistency check, multi-scalar multiplication, pairing-point aggregation, pairing. Ports: `computeSquares`, `computeFoldPosEvaluations`, `checkEvalsConsistency`, `batchMul`, the aggregation, `pairing` | Done. The scalars match slot by slot, and the two pairing points match. The aggregation matches the reference on limbs put in place of the zeros, because no proof of this circuit carries pairing points. |
| 7 | `HonkVerifier` accepting proofs, negative tests over the recorded invalid calls, the vault in front of the Fe verifier, size and gas | Done, except the code-size script: size and gas were measured by hand. |
| 8 | README, reproduce steps, `scripts/check.sh` | README and reproduce steps are done. `scripts/check.sh` was not written. |

The plan gave each stage an estimate and a cut line, so that a run stopped by the deadline would still leave a coherent result ([ADR-0014](adr/0014-staged-delivery-incremental-commits.md)). Every stage was reached, so they are not repeated here.

### Toy line (branch `feature/honk-toy`, merged)

| # | Work | Outcome |
|---|---|---|
| T1 | The reference and the generator; `f17`, `sumcheck`, `relations` | Done. For the honest run, the delta, round targets, pow, the 7 subrelations and the final check equal the reference. Each cheating scenario fails at the same check as in the reference. |
| T2 | `curve` (with the Miller-loop pairing), `shplemini`, `verifier` | Done. The batched evaluation, the scalars, P0, P1 and both pairing values equal the reference. `verify` gives the reference's verdict in every scenario. |
| Later step | The sumcheck mask | Done: `libra.fe` and `verify_masked`, with 5 masked vectors. |
| Later step | Reference and generator in Python | Done on 2026-11-23. The first version ran the page's JavaScript. The Python generator reproduced the committed vectors byte for byte before the JavaScript was removed. |

### Stage 0 spikes and what became of them

The plan started with six small experiments. Each one answered a question.

| # | Question | Answer |
|---|---|---|
| 1 | Does a `msg` with `Bytes` + `Vec<Bytes32>` work for `verify(bytes,bytes32[])`? | Yes: `VerifierMsg` in `lib/src/abi.fe`, used by `HonkVerifier`, `Vault` and their tests. |
| 2 | Can a Fe contract call another one, and take constructor arguments? | Yes: `Vault` calls the verifier with the typed message, `HonkVerifier` calls `HonkRelations` with `staticcall_decode`, and both take constructor arguments. |
| 3 | How are precompile `Result`s handled? | `match`, as in the tests of `lib/src/fr.fe` and `lib/src/std_assumptions.fe`. |
| 4 | Does the hash helper give a known hash? | Yes: the `Packed` and `keccak_words` tests of `lib/src/std_assumptions.fe`, and the `absorb` tests of `lib/src/transcript.fe`. |
| 5 | Can Foundry deploy a Fe `.bin`? | Dropped. No committed test uses Foundry. |
| 6 | Which flags and output names does `bb` 6.0.0 use? | Settled in `scripts/vectors.sh`. |

## Measured results

With `fe` 26.6.0. The figures are the ones in [`ultrahonk/README.md`](../ultrahonk/README.md) and [`ultrahonk/vault/README.md`](../ultrahonk/vault/README.md), which state the method and its caveats.

| | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| Runtime size of `HonkVerifier`, bytes | 16,446 | 16,274 | 16,174 |
| Runtime size of `HonkRelations`, bytes | 8,527 | 6,336 | 6,343 |
| Runtime size of `Vault`, bytes | 655 | 647 | 651 |
| Gas of `verify` on the pinned proof, accepted | 2,108,994 | 2,106,426 | 2,124,076 |
| Gas of a vault claim in front of `HonkVerifier` | 2,120,252 | 2,117,762 | 2,133,741 |

| Reference (Solidity verifier, solc 0.8.34) | |
|---|---|
| Runtime size | `HonkVerifier` 16,946 bytes, plus the linked libraries `RelationsLib` 8,211 and `ZKTranscriptLib` 6,008 |
| Gas of a valid `verify` | 2,654,961 (forge gas report) |

The limit for one contract is 24,576 bytes (EIP-170). `fe test` cannot catch it: its revm allows 1 MiB. A size is read from the build: `fe build --contract <Name> -O <level>` writes `out/<Name>.runtime.bin` as hex text, and the size is half its length. The nine sizes in the table were measured again this way on 2026-11-23. The gas figures were not measured again: the tests that measured them are not committed.

The relations are a contract of their own, as the reference keeps them in a linked library ([ADR-0012](adr/0012-code-size-strategy.md)). The two Fe runtimes add up to 24,973 bytes at `-O 1`, 22,610 at `-O 2` and 22,517 at `-O s`. The repository records no size for a single Fe contract holding everything, so these sums only indicate what it would weigh.

## Porting hazards (real verifier)

The implementer's checklist, restated for the ZK verifier. Every item is handled in the code named. "The reference" is the upstream Barretenberg verifier.

**Orderings and offsets**

- [x] 1. Three orderings. Proof order: masking commitment, w1, w2, w3, lookupReadCounts, lookupReadTags, w4, lookupInverses, zPerm. Order of the multi-scalar multiplication (slots 30–37): w1, w2, w3, w4, zPerm, lookupInverses, lookupReadCounts, lookupReadTags. Verification-key order: `vectors/vk` already lists its points in the order of slots 2–29. Handled by `shplemini::commitment`; a test compares the commitment of every slot.
- [x] 2. Shplemini slots: slot 0 is `shplonkQ` with scalar 1 and slot 1 the masking polynomial; the shifted wires are slots 30–34 and take evaluations 37–41; the ρ power is not reset between the unshifted and the shifted sum. Handled by `shplemini::scalars`; tests compare every scalar.
- [x] 15. Length checks first: `proof.len() == (82 + 12L)·32`, then the range of each word, then `public_inputs.len() == num_public_inputs − 8`. Handled by `proof::validate` and `verifier/src/lib.fe`.

**Field arithmetic**

- [x] 3. `sub(a, b)` needs `b ≤ P`. `neg(0)` is `P` in the reference and 0 in Fe; the two are equal after reduction, so raw values are never compared.
- [x] 4. `inv(0)` reverts with `InvertOfZero`; `modexp` would return 0 silently.

**Transcript**

- [x] 5. `eta`: the VK hash first, then each public input (checked `< P`), then proof words 0–15: the 8 pairing limbs, the masking commitment, w1, w2, w3. `num_public_inputs` counts the 8 limbs.
- [x] 6. All challenges are full `keccak % P`. Gate challenges are successive squares of the first one. `alphas[i] = alpha^(i+1)`. The Fe `Transcript` keeps the seeds, and the consumers multiply as they go.

**Sumcheck and relations**

- [x] 7. Sumcheck: the initial target is `libraChallenge · libraSum`; the nine barycentric denominators are copied verbatim; the pow update is `pow · (1 + u·(g − 1))`. The last comparison multiplies the relations by the row-disabling factor and adds `libraEvaluation · libraChallenge`.
- [x] 8. Relations: slots are not in call order (arithmetic 6–7, permutation 0–2); slots 4 and 21 are not multiplied by the domain separator; batching is `evals[0] + Σ evals[i]·alpha^i`.
- [x] 9. Public-input delta: the numerator starts at `gamma + beta·(2^28 + 5)`, the denominator at `gamma − beta·6`; real inputs first, then the 8 limbs.

**Shplemini, consistency check, MSM and pairing**

- [x] 10. The fold evaluations are computed from round L down to 1. The ν power starts at ν² and multiplies by ν² each step.
- [x] 11. MSM: the accumulator starts at `(0, 0)` explicitly (the reference relies on zeroed memory); the generator `(1, 2)` is slot 40 + L and `kzgQuotient`, with scalar `z`, slot 41 + L; a failed precompile call rejects.
- [x] 12. `kzgQuotient` is negated on a copy (the reference negates in place after the MSM); the negation is mod Q and skips `y = 0`.
- [x] 13. Pairing-point aggregation runs only if a limb is non-zero; coordinates are `lo | (hi << 136)`. The pinned proofs have all limbs at zero, so they exercise only the branch that skips it. The aggregation is tested in `lib` against values the reference computed with limbs put in place of the zeros.
- [x] 14. Pairing input order: (P0, the G2 generator), (P1, the G2 point of the key); the eight G2 words are copied verbatim.
- [x] 16. Consistency check: every scalar is computed before it and no curve operation runs before it, so a proof that fails both it and the MSM reverts with `ConsistencyCheckFailed`. `r^256 = 1` reverts with `GeminiChallengeInSubgroup`.

## Workflow

See [ADR-0014](adr/0014-staged-delivery-incremental-commits.md).

| Topic | Rule |
|---|---|
| Branches | Feature branches off `develop` (gitflow). `feature/ultrahonk-verifier` is the main line. `feature/honk-toy`, `feature/ultrahonk-relations`, `feature/ultrahonk-opening`, `feature/ultrahonk-integration` and `feature/ultrahonk-docs` each had their own git worktree and are merged into it. |
| Parallelism | The plan allowed one parallel line, the toy. The relations, the opening, the integration of the opening into the verifier, and the documents also had lines of their own. |
| Incremental commits | Owner's rule of 2026-11-22: commit each working unit as soon as its tests pass, several per stage, not one commit per stage. |
| Commit hygiene | Conventional commits, no tool-attribution trailers, explicit pathspecs only. No push unless asked. |
| Review | Stages do not wait for review. Each stage is a self-contained run of commits, so review can happen at any time. |
| Boundaries | No changes to global tools, the root library or `calculator/`. |

## Verification

A reader needs only `fe`.

| Level | How |
|---|---|
| Per ingot | `fe test` inside the ingot. `fe check` type-checks it. |
| One group of tests | `fe test -f <name>` in the ingot. |
| Committed proofs and key against the raw `bb` output | `scripts/proof_to_fe.sh --check`. Needs bash, `xxd` and `shasum`. |
| Regeneration (proofs, key, oracle source) | `scripts/vectors.sh`. Proving is randomized, so it writes different valid proofs; the README pins the committed ones. Needs the [project-local tools](#project-local-tooling). |
| Regeneration (captured values) | Not possible from the repository alone: it needs the local Foundry tests to be recreated. Their documented provenance stands in for it. |
| Regeneration (toy) | `python3 honk-toy/reference/gen_vectors.py` reproduces `honk-toy/src/vectors.fe`; `--check` compares without writing. Needs Python 3. |
| End-to-end script | Not written. Run the five `fe test` commands of the [Quick path](#quick-path). |

What the Fe tests show:

- [x] The Fe verifier accepts the committed proof.
- [x] Every intermediate value captured from the reference oracle equals the value the Fe code computes.
- [x] The Fe verifier reverts with the reference's selector on each recorded invalid call. For proof word 138 the reference returned no data, and the Fe verifier reverts with `ShpleminiFailed()`.
- [x] No proof with the low bit of one word flipped is accepted.
- [x] A vault claim succeeds in front of the Fe verifier, and a replay is refused.
- [ ] Every proof the reference rejects is rejected. The tests do not show this.

Code size is within EIP-170 for each contract by measurement, not by a test.

## Assumptions, risks, out of scope

### Assumptions and limitations

- The project owner is registered for the contest (registration closed Nov 17).
- The pinned proofs exercise only the branch that skips pairing-point aggregation. The aggregation is tested at library level only.
- One circuit, with `LOG_N = 5`. No other circuit size is exercised.
- Committed expected values are trusted on their documented provenance, because the oracle and the local Foundry tests are not in the repository.
- The port is not audited.

### Risks and how they turned out

| Risk in the plan | Outcome |
|---|---|
| Fe compiler crash or code size on the relations | The relations compile. They are a contract of their own, 8,527 bytes at `-O 1`. |
| Cross-contract call or constructor arguments from Fe | Both work and are tested. |
| Reaching stage 7 by the deadline | Reached on 2026-11-23. |
| The ZK flavor adds protocol steps | All ported. |
| A fixed list of invalid calls replaces fuzzed differential testing | Still true. Accepted in [ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md). |

### Out of scope

- Anything running on the Aztec network.
- The non-ZK flavor of the real verifier (`-t evm-no-zk`): not built.
- Solidity in the repository, Foundry tests, and fuzzed differential testing against the reference verifier.
- Vault payout logic.
- Gas optimisation.
- A VK generator CLI.
- Multiple circuits.
- Any change to the teaching page.

### Not done

- `scripts/check.sh`, the end-to-end script.
- A script that checks each `.runtime.bin` against 24,576 bytes.
- A re-cut of the stage estimates for the ZK verifier. The stages were carried out in the plan's order instead.

What is missing to submit the entry and to rely on the code outside its tests is listed, in order, in [Gaps before shipping and before real use](ultrahonk-gaps.md).

### Questions the plan left open, and their answers

| Question | Answer |
|---|---|
| Which stage holds the ZK-specific steps? | The Libra terms of sumcheck are in stages 3–5. The consistency check and the masking slot are in stage 6. |
| Does one `absorb` per round fit the ZK transcript? | Yes. Only `eta` differs: it has no previous challenge and hashes the VK hash and the public inputs before the proof words. |
| How are expected values captured, and how is the key produced? | Each vectors file states its capture method at the top, and `ultrahonk/README.md` describes it. `scripts/proof_to_fe.sh` prints the key from `vectors/vk`. |
| Where does the list of invalid calls come from? | It is the list in `lib/src/expected.fe`. |
| How do Fe tests set the caller, and which verifier answers the vault? | Callers are `Claimer` contracts or the test contract. Nine tests put a stand-in behind the vault and two put `HonkVerifier` there. |
| Are size and gas shown next to the reference? | Yes, in `ultrahonk/README.md` and in [Measured results](#measured-results). |
| What does the externally linked transcript library mean for the oracle? | The local Foundry project builds and links it. Its runtime size is listed with the reference's. |
| Does the library return `bool` or revert? | Both, by step: see [Failure behaviour](#failure-behaviour). |

## References

Upstream Solidity files are listed as the reference being ported or consulted. None of them is in this repository.

| Reference | Location |
|---|---|
| Reference oracle | Generated locally into `ultrahonk/.oracle/src/HonkVerifier.sol` with `-t evm` (untracked). Upstream at `aztec-packages` commit `b225653c4d0521907559ae80baa626bbbff49e55`: template `honk_zk_contract.hpp`, sources `BaseZKHonkVerifier.sol` and `ZKTranscript.sol` |
| Teaching page | "UltraHonk by hand", `https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ`: its section on practice (the vault) and its section on integration with Fe (modules and milestones). Its first inline script block is the math that `honk-toy/reference/honk.py` ports. |
| Fe std at the installed version | A local checkout of the Fe repository at tag `v26.6.0`: `ingots/std/src/evm/crypto.fe`, `ingots/std/src/evm/packed.fe`, `ingots/core/src/ptr.fe`, `ingots/core/src/abi.fe`, `ingots/std/src/abi.fe`, `docs/language/accesses.md` |
| Msg and test idioms (same checkout) | `crates/fe/tests/evm_compiler_bench/merkle_verifier.fe`, `crates/fe/tests/fixtures/fe_test/abi_dynamic_payload.fe`, `crates/fe/tests/fixtures/fe_test/address_call_method.fe`, `crates/fe/tests/fixtures/fe_test/precompile_wrappers.fe` |
| Pattern to mirror | `calculator/src/lib.fe` and `calculator/fe.toml` in this repository |
| Upstream negative test base | `barretenberg/sol/test/honk/negative/NegativeTestBase.sol` (marked `UNLICENSED`; nothing is copied) |
| Structure only | `fe-lang/rosetta`: `examples/verifier/fe/src/{field,transcript,msm}.fe`, `shared/ec/fe/src/bn254.fe` |

## Related documents

- [Gaps before shipping and before real use](ultrahonk-gaps.md): the contest checklist, the ordered work, the test track and the known limits in real use.
- [Architecture Decision Records](adr/README.md): one record per decision in the [Decisions](#decisions) table.
- [`ultrahonk/README.md`](../ultrahonk/README.md): status, test coverage, measurements, how to regenerate the vectors.
- [`ultrahonk/docs/zk-verifier-reference.md`](../ultrahonk/docs/zk-verifier-reference.md): the proof layout, the transcript, the formulas and the errors.
