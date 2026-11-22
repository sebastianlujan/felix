# UltraHonk verification in Fe: project plan

This project adds UltraHonk proof verification written natively in Fe, as new packages under `ultrahonk/`. It has three deliverables: a port of Barretenberg's zero-knowledge (ZK) UltraHonk verifier (BN254, Keccak transcript), a vault contract that consumes a Noir + Barretenberg proof through that verifier, and a hand-sized toy Honk verifier over F_17. The repository is pure Fe plus a Noir circuit and scripts: the Solidity verifier that Barretenberg generates serves as a local, uncommitted reference oracle, and every committed test is a Fe test that compares against expected values captured from that oracle on a real Noir proof. The work is a contest entry due **Nov 24, 2026 23:59 UTC** and is delivered in stages, so that whatever passes by the deadline is coherent, tested and honestly labelled.

> **Status (2026-11-22).** Stage 0 was completed on 2026-11-22 for the original non-ZK target (pipeline, oracle tests, Fe skeleton). Two scope changes by the project owner followed: the real verifier targets the ZK flavor ([ADR-0001](adr/0001-port-bb-6-zk-verifier.md)), and the repository contains no Solidity ([ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md)). Stage 0b, which switches the stage 0 artifacts to ZK and moves them to the Fe-only layout, is in progress. Every later stage is planned, and no other result is reported in this document.
>
> **Reading the numbers.** The original plan was written against the non-ZK contract. A value tagged **[ZK: TBC]** comes from that plan and is to be confirmed from the generated ZK contract (stage 0b, in progress). Code blocks labelled "sketch" have not been compiled.

## Quick path

These are the **intended** commands. A reader of the repository needs only `fe`; no `forge` command is needed. The commands work once the stages that create their targets have landed (see [Stages](#stages)): `scripts/check.sh` is stage 8 work.

1. Check, format-check and test each ingot.

   ```sh
   cd ultrahonk/lib        # likewise ultrahonk/verifier, ultrahonk/vault, ultrahonk/toy
   fe check
   fe fmt --check
   fe test
   ```

2. Run the end-to-end script.

   ```sh
   cd ultrahonk
   scripts/check.sh
   ```

3. Read the result. The intended outcome: the Fe verifier accepts the committed proof, it reverts with the reference selector on every tamper case, the vault claim works, and each contract's runtime code is within 24,576 bytes.

To check one stage, run its acceptance command from the stage tables, for example `fe test -f transcript` inside `ultrahonk/lib`.

Regenerating inputs is optional and is not needed to verify: see [Verification](#verification).

| If you are | Read |
|---|---|
| The repository owner, reviewing stage by stage | [Stages](#stages), [Porting hazards](#porting-hazards-real-verifier), [Workflow](#workflow) |
| A contest judge | [Purpose and context](#purpose-and-context), [Reference oracle and expected values](#reference-oracle-and-expected-values), [Verification](#verification), [Assumptions, risks, out of scope](#assumptions-risks-out-of-scope) |
| Looking for the reason behind a choice | [Decisions](#decisions) and the [ADR index](adr/README.md) |

## Deliverables

| # | Deliverable | Package | What it is | Status |
|---|---|---|---|---|
| 1 | Real verifier | `ultrahonk/lib`, `ultrahonk/verifier` | Port of Barretenberg's ZK UltraHonk verifier (BN254, Keccak transcript with zero-knowledge) | Stage 0 done for the non-ZK target; stage 0b in progress; later stages planned |
| 2 | Integration contract | `ultrahonk/vault` | A Fe application contract that consumes a Noir + Barretenberg proof through the verifier (the teaching page's vault, "cofre") | Planned |
| 3 | Toy verifier | `ultrahonk/toy` | The teaching page's hand-sized Honk over F_17 (the page's non-ZK toy protocol), ported to Fe | Planned |

## Purpose and context

### Why this is being built

The goal is UltraHonk verification written natively in Fe, built gradually in new packages of this repository, the same way the root library and `calculator` pair was built. The project's teaching page ("UltraHonk a mano", sections "En la práctica" and "Integración con Fe") sketches the modules, the milestones and a vault application, but nothing in it was ever compiled.

The research behind the plan established:

| Finding | Detail |
|---|---|
| Not done in Fe | `fe-lang/rosetta/examples/verifier` has Groth16, a gnark Plonk and a Halo2 skeleton, and no Honk. No Fe UltraHonk verifier was found on GitHub. Another contest entry, `0xitsss/fe-zk`, covers Groth16/PLONK/halo2/FRI, not Honk. |
| Already solved on the EVM as a product | Barretenberg emits an audited Solidity verifier that Fe can call. The value of this work is as a contest entry and as a readable reference. |

### What "Aztec integration" means

| It means | It does not mean |
|---|---|
| Integration with Aztec's proving stack: a Noir circuit, proved by Barretenberg, verified on the EVM by Fe. | Anything running on the Aztec network. Aztec network contracts are Noir and verify by recursion, so no Fe contract runs there. The teaching page says the same. |

`ultrahonk/README.md` will state exactly this. See [ADR-0013](adr/0013-scope-noir-barretenberg-on-evm.md).

### Scope changes after the plan was approved

Both changes were decided by the project owner. They are applied throughout this document.

| Area | Original plan | Now | ADR |
|---|---|---|---|
| Flavor of the real verifier | Non-ZK (`-t evm-no-zk`) | ZK (`-t evm`). The non-ZK flavor is dropped, not built alongside. | [0001](adr/0001-port-bb-6-zk-verifier.md) |
| Repository contents and tests | A tracked Foundry project holding the generated Solidity verifier and Solidity tests | No Solidity in the repository and no Solidity code in the documentation. The generated verifier is a local, untracked reference. Every committed test is a Fe test. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |

Why the ZK flavor:

| Reason | Detail |
|---|---|
| The vault hides a secret | A non-ZK proof leaks witness evaluations, so a vault that hides its secret needs ZK. |
| Standard target | `-t evm` is `bb`'s standard EVM target. |
| Same flavor as Aztec | It is the flavor Aztec's own L1 verifier uses. |
| Cost | More protocol steps (Libra masking, a small-subgroup consistency check, a Gemini masking polynomial), so the risk of not reaching the final pairing check by the deadline is higher. |

### Deadline and judging

| Item | Value |
|---|---|
| Submission deadline | Nov 24, 2026 23:59 UTC (about 48 hours away when the plan was written) |
| Feature freeze | Nov 24, 2026 14:00 UTC: feature work stops and the docs stage starts |
| Contest brief | Open-ended: "proof verification… bring test vectors, explicit assumptions, reusable abstractions" |
| Delivery model | The Fe code is written stage by stage and the repository owner reviews each stage. Whichever stages pass by the deadline are submitted. |

| Judging criterion | Weight |
|---|---|
| Technical quality | 30 |
| Fe-specific value | 25 |
| Originality | 20 |
| Usefulness | 15 |
| Docs / demo | 10 |

**Outcome wanted:** at any cut point, coherent, tested, honestly-labelled packages under `ultrahonk/`, with the real verifier checked bit-for-bit against values taken from Barretenberg's own verifier on a real Noir proof.

## Decisions

Each row links to the Architecture Decision Record that holds the context, the options considered and the consequences.

| Topic | Decision | ADR |
|---|---|---|
| Source of truth (real) | The Solidity verifier that `bb` 6.0.0 generates with `-t evm`: Keccak transcript with zero-knowledge (upstream `BaseZKHonkVerifier.sol` + `ZKTranscript.sol` at `aztec-packages@b225653`, template `honk_zk_contract.hpp`). The non-ZK flavor is dropped. | [0001](adr/0001-port-bb-6-zk-verifier.md) |
| Tooling | Project-local `bb` 6.0.0 and `nargo` 1.0.0 in `ultrahonk/.tools/`. The installed `bb` 0.84.0 / `nargo` beta.3 are too old and are left untouched. | [0002](adr/0002-project-local-bb-and-nargo.md) |
| Layout | Sibling ingots with relative path dependencies, no workspace. | [0003](adr/0003-sibling-ingots-without-workspace.md) |
| Proof representation (real) | Keep the proof as `Bytes` and read words by offset; no `Proof` struct. One `absorb` helper per transcript round, designed around each Fiat–Shamir round hashing `prev ‖ one contiguous run of proof words`. That contiguous-absorb design is being re-validated for the ZK transcript. | [0004](adr/0004-proof-as-bytes-read-by-offset.md) |
| Sizes (real) | Runtime `log_n` with fixed maximum-size arrays, like the upstream reference. No const generics. The sizes in the original plan (`[u256; 25]`, `[u256; 63]`) are **[ZK: TBC]**. | [0005](adr/0005-runtime-log-n-fixed-max-arrays.md) |
| Field | Plain functions on `u256`, no operator-overloaded type (`sonatina#232`). | [0006](adr/0006-field-arithmetic-plain-u256-functions.md) |
| Hashing | The std `Packed` builder for every multi-word hash and for the pairing input, instead of a hand-rolled buffer. Single-word rehash: `keccak_words([x]) % P`. | [0007](adr/0007-hashing-with-std-packed-builder.md) |
| Precompiles | Always `match` on `Result`; `Err` reverts. Never `unwrap_or(default: 0)` (a silent 0 would be a soundness bug). | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Failure | The verifier contract reverts on a bad proof with the same custom errors as the upstream reference (`Errors.sol`), so its ABI is a drop-in. Negative tests assert the same revert selector as the reference. The error set and check order of the ZK contract are **[ZK: TBC]**. | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Reference oracle | Barretenberg's generated Solidity verifier is the reference oracle but is not committed. It lives in the local, untracked `ultrahonk/.oracle/` and is regenerated by `scripts/vectors.sh`. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Repository contents | Pure Fe plus a Noir circuit and scripts. No Solidity in the repository, no Foundry project, no forge-std, and no Solidity code in the documentation. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Tests and vectors | Every committed test is a Fe test run with `fe test`. Expected values and the revert selector of each tamper case are captured from the local oracle and committed as Fe constants with their provenance stated. Toy vectors are generated with Node and committed. Tests need no `bb`, `nargo`, Node or Foundry. | [0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |
| Circuit | The teaching page's vault circuit (shown in [Design: vault](#design-vault-integration-contract)). | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Vault ↔ verifier | External call through the standard ABI `verify(bytes,bytes32[])`, not library linking. The vault stays small and is not tied to one verifier implementation. | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Source of truth (toy) | The math block of the teaching page (a DOM-free script that already exports for Node), extracted verbatim and run under Node 24 to generate vectors. Challenges are inputs. The toy stays the page's non-ZK toy protocol; its optional ZK sumcheck-mask scenarios may be added as a later step. | [0011](adr/0011-toy-verifier-vectors-from-reference-js.md) |
| Code size | Measure early (stage 3), try optimisation levels first, then split the relations into a second contract. The limit is checked by a script on the built `.runtime.bin`. | [0012](adr/0012-code-size-strategy.md) |
| Scope and framing | ZK Noir + Barretenberg proofs verified on the EVM by Fe, not the Aztec network. | [0013](adr/0013-scope-noir-barretenberg-on-evm.md) |
| Delivery | Stages with cut lines (stage 0b added for the scope changes), incremental commits, and one parallel worktree for the toy line. | [0014](adr/0014-staged-delivery-incremental-commits.md) |
| `fe-lang/rosetta` | Structure only. It targets the 26.1 std and does not compile on 26.6.0. It has no licence, so nothing is copied from it. | [0001](adr/0001-port-bb-6-zk-verifier.md) |

## Package layout

Everything is new. The root library, `calculator/` and the root `README.md` are not modified.

```
ultrahonk/
  README.md
  lib/                 ingot "ultrahonk" (pure library)
    src/lib.fe abi.fe fr.fe types.fe proof.fe transcript.fe sumcheck.fe
        relations.fe shplemini.fe verifier.fe
        vectors.fe     expected values captured from the local oracle (Fe constants)
  verifier/            ingot "ultrahonk_verifier": contract HonkVerifier
    src/lib.fe  src/vk.fe (per circuit)
  vault/               ingot "ultrahonk_vault": contract Vault (the teaching page's "cofre")
    src/lib.fe
  toy/                 ingot "honk_toy": Honk over F_17, pure library
    src/lib.fe f17.fe curve.fe sumcheck.fe relations.fe shplemini.fe verifier.fe
        vectors.fe     GENERATED
    reference/honk.js  the teaching page's math block, verbatim
    reference/gen_vectors.js
    README.md
  circuit/             Nargo.toml, Prover.toml, src/main.nr
  vectors/             proof, public_inputs, vk (raw bb output, committed)
  scripts/vectors.sh  scripts/check.sh
  .tools/              bb + nargo binaries (ignored by the root `.*` rule)
  .oracle/             local and untracked: Barretenberg's generated Solidity verifier
```

| Rule | Detail |
|---|---|
| Shared ABI | `lib/src/abi.fe` holds the `msg` for `verify(bytes,bytes32[])`, shared by the verifier (which receives it) and the vault (which sends it). |
| No Solidity | The repository tracks no Solidity file, no Foundry project and no forge-std. |
| Local oracle | `ultrahonk/.oracle/` is a local, untracked reference tool, regenerated by `scripts/vectors.sh`. |
| Tests | Every committed test is a Fe test, run with `fe test` in its ingot. |
| Build outputs | `out/` and `circuit/target/` are never staged. |

The move to this layout is stage 0b work and is in progress.

## Project-local tooling

The installed `bb` 0.84.0 and `nargo` beta.3 are too old. The project downloads `bb` 6.0.0 and `nargo` 1.0.0 into `ultrahonk/.tools/` instead of replacing them ([ADR-0002](adr/0002-project-local-bb-and-nargo.md)). The asset names below were verified for Darwin arm64.

```sh
cd ultrahonk && mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
.tools/bb/bb --version && .tools/nargo/bin/nargo --version   # expect 6.0.0 and 1.0.0
```

This downloads and runs two official release binaries. `~/.bb` and `~/.nargo` are not touched. The tools are needed only to regenerate the proof, the verification key and the local oracle, not to run the tests.

## Reference oracle and expected values

Barretenberg's generated Solidity verifier is the reference oracle. It is not committed. Tests are written in Fe against expected values captured from it ([ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md)).

### Pipeline (`scripts/vectors.sh`)

Intended shape after stage 0b:

```sh
(cd circuit && nargo execute)
bb write_vk -b circuit/target/vault.json -o vectors -t evm
bb prove    -b circuit/target/vault.json -w circuit/target/vault.gz -o vectors -t evm
bb verify   -k vectors/vk -p vectors/proof -i vectors/public_inputs -t evm
bb write_solidity_verifier -k vectors/vk -o .oracle/HonkVerifier.sol -t evm   # local, untracked
```

The pipeline was built in stage 0 with `-t evm-no-zk`. Switching it to `-t evm` and to the untracked `.oracle/` directory is stage 0b work, in progress. Flags, output file names and the file name inside `.oracle/` are **[ZK: TBC]**.

### How expected values reach the tests

1. `scripts/vectors.sh` regenerates the proof, the verification key and the local oracle.
2. Expected values, and the revert selector for each tamper case, are captured from the local oracle.
3. They are committed as Fe constants, with their provenance stated: tool, version, and how they were captured.
4. Fe tests compare the Fe verifier against those constants.

The harness that captures intermediate values from the oracle is local and is not in the repository. The intermediate expected values therefore cannot be regenerated from the repository alone without recreating that harness, which is why their provenance must be documented.

### Test-vector provenance

| Artifact | Produced by | Committed |
|---|---|---|
| `circuit/src/main.nr` | The teaching page's vault circuit | Yes |
| `vectors/proof`, `vectors/public_inputs`, `vectors/vk` | `bb` 6.0.0 (`write_vk`, `prove`) with `-t evm` | Yes, raw `bb` output |
| Generated Solidity verifier in `.oracle/` | `bb write_solidity_verifier`, regenerated by `scripts/vectors.sh` | No: local, untracked reference |
| `lib/src/vectors.fe` | Captured from the local oracle: challenges, round targets, subrelation values, scalars, the points of the final pairing | Yes, as Fe constants with provenance |
| Revert selector of each tamper case | Captured from the local oracle | Yes, as Fe constants with provenance |
| `verifier/src/vk.fe` | Per circuit, from the verification key. How it is produced under the Fe-only layout is not stated (see [open points](#open-points)). | Yes |
| `toy/reference/honk.js` | The teaching page's math block, verbatim | Yes |
| `toy/src/vectors.fe` | `toy/reference/gen_vectors.js` under Node 24 | Yes |

The original plan also listed the proof words, the public inputs, the public-input delta, the pow value and the grand sum among the captured values, and `N`, `LOG_N`, `NUM_PUBLIC_INPUTS`, `VK_HASH` and `VK_POINTS: [u256; 56]` (in commitment order) as the content of `vk.fe`. The values added by the ZK protocol steps and the `VK_POINTS` size are **[ZK: TBC]**.

### What the Fe tests assert

| Area | Assertion |
|---|---|
| Intermediate values | Challenges, round targets, subrelation values, scalars and the points of the final pairing equal the committed expected values. |
| Accept | The Fe verifier accepts the committed proof. The proof length is 82 + 12·log N words for the ZK flavor. |
| Negative | For each case in a fixed list of tamper cases, the Fe verifier reverts with the same selector as the reference. |
| Vault | Fe tests of the claim flow (see [Design: vault](#design-vault-integration-contract)). |
| Code size | Not a Fe test: a script checks the built `.runtime.bin` against 24,576 bytes. |

In-EVM fuzzed differential testing against the Solidity verifier, which the original plan included, is given up in favour of the fixed list of tamper cases.

### Reuse and licences

| Source | Licence position | What the project does |
|---|---|---|
| Barretenberg's generated Solidity verifier | — | Used locally as the reference oracle. Not committed. |
| Fe repository fixtures | Apache-2.0 | Idioms may be copied with attribution. |
| `fe-lang/rosetta` | No licence | Learn from it, copy nothing. |
| Upstream negative test base (`NegativeTestBase.sol`) | Marked `UNLICENSED` | Copy nothing. The original plan followed its case list (34 expectations, read for the non-ZK contract). Whether the fixed tamper list still follows it is not restated. |
| Other contest entries | — | Nothing is taken from them. |

`ultrahonk/README.md` gets a "reused from / learned from" table.

## Design: real verifier

Upstream Solidity file and function names in this section are the upstream Barretenberg reference being ported. They are not project code.

### What changes with the ZK flavor

| Quantity | Original non-ZK plan | ZK target |
|---|---|---|
| Proof size in words (L = log N) | 67 + 11·L | 82 + 12·L |
| Values per sumcheck round | 8 | 9 |
| Evaluated entities | 41 | 42 (37 unshifted) |
| Subrelations | 31 | 31, the same ones, in the shared relations code |
| Flavor-specific upstream files | `BaseHonkVerifier.sol` | `BaseZKHonkVerifier.sol` + `ZKTranscript.sol` (621 + 371 lines) |
| Transcript library | — | Linked externally by the generated contract |
| Extra protocol steps | — | Libra masking, a small-subgroup consistency check, a Gemini masking polynomial |
| Word offset of each proof element | Table below | **[ZK: TBC]** |
| Hashed range of each transcript round | Table below | **[ZK: TBC]** |
| Shplemini array sizes and slot indices | Hazards 2 and 11 | **[ZK: TBC]** |
| Check order and error set | [Failure behaviour](#failure-behaviour) | **[ZK: TBC]** |

The ZK column is read from the upstream source at commit `b225653`.

What stays: the proof is kept as `Bytes`, the transcript uses one `absorb` helper per round, and the relation functions write into one shared array. The contiguous-absorb design is being re-validated for the ZK transcript.

### Proof word layout (non-ZK, superseded)

<details>
<summary>Layout from the original non-ZK plan. It is not valid for the ZK target and is kept only as the starting point for the ZK layout.</summary>

L = log N. `Bytes.word_at` takes a byte offset.

| Words | Content | Hashed for |
|---|---|---|
| 0–7 | pairing limbs | eta |
| 8–13 | w1, w2, w3 | eta = H(vkHash ‖ publicInputs ‖ words 0..13) |
| 14–19 | lookupReadCounts, lookupReadTags, w4 | beta (gamma = H(beta)) |
| 20–23 | lookupInverses, zPerm | alpha |
| 24+8i … +7 | sumcheck univariate, round i | u_i |
| 24+8L … +40 | 41 evaluations | rho |
| 65+8L … | 2(L−1) fold-commitment words | geminiR |
| 63+10L … | L gemini evaluations | shplonkNu |
| 63+11L, 64+11L | shplonkQ | shplonkZ |
| 65+11L, 66+11L | kzgQuotient | (not hashed) |

</details>

### Key signatures (sketch)

Uncompiled sketches in Fe 26.6.0 syntax, written for the original plan. They show intent, not final code. The entity count is the ZK one; the `absorb` shape is the part being re-validated.

```fe
// abi.fe
pub msg VerifierMsg {
    #[selector = sol("verify(bytes,bytes32[])")]
    Verify { proof: Bytes, public_inputs: Vec<Bytes32> } -> bool,
}

// fr.fe
pub const P: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495617
pub const Q: u256 = 21888242871839275222246405745257275088696311157297823662689037894645226208583
pub fn add(_ a: u256, _ b: u256) -> u256 { addmod(a, b, P) }
pub fn sub(_ a: u256, _ b: u256) -> u256 { addmod(a, P - b, P) }
pub fn mul(_ a: u256, _ b: u256) -> u256 { mulmod(a, b, P) }
pub fn inv(_ a: u256) -> u256            // a != 0 required (reverts otherwise); match modexp(base: a, exp: P - 2, modulus: P)

// transcript.fe
fn absorb(prev: u256, _ proof: Bytes, start: usize, n: usize) -> u256   // std Packed: prev, then n proof words from start; keccak256 % P
pub fn generate(vk: VerificationKey, _ proof: Bytes, _ public_inputs: Vec<Bytes32>) -> Transcript

// sumcheck.fe / relations.fe / shplemini.fe / verifier.fe
pub fn verify(vk: VerificationKey, _ proof: Bytes, t: Transcript) -> bool          // sumcheck, shplemini
pub fn accumulate(_ p: [u256; 42], t: Transcript, pow: u256) -> u256                // relations; 42 evaluated entities (ZK)
pub fn verify(vk: VerificationKey, _ proof: Bytes, _ public_inputs: Vec<Bytes32>) -> bool
```

| Convention | Rule |
|---|---|
| Parameters | Plain parameters view the caller's value in place (no copy). Outputs go through `mut` parameters. |
| Arity | Every function keeps six parameters or fewer. |

### Failure behaviour

The Fe verifier reverts with the same custom errors as the upstream reference (`Errors.sol`), declared as `#[error]` structs and raised with `revert_error`, so its ABI is a drop-in for the upstream verifier ([ADR-0008](adr/0008-precompile-match-and-solidity-compatible-errors.md)). The negative tests assert that each tamper case reverts with the same selector as the reference.

Errors listed in the original plan for the non-ZK contract: `SumcheckFailed`, `ShpleminiFailed`, `ProofLengthWrongWithLogN`, `PublicInputsLengthWrong`, `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder`, `InvertOfZero`. The error set of the ZK contract is **[ZK: TBC]**.

The check order must match the reference, or the selectors differ. The order below is the non-ZK one from the original plan; the ZK order is **[ZK: TBC]**.

1. Proof length.
2. Limbs.
3. Coordinates and scalars, in proof order.
4. Public-input count.
5. Public-input range.
6. Sumcheck.
7. Shplemini.

Precompile results follow the `expect_word` / `expect_pair` / `expect_bool` match pattern of `crates/fe/tests/fixtures/fe_test/precompile_wrappers.fe` in the Fe repository.

### Std functions to reuse

From the Fe repository at tag `v26.6.0`:

| Module or use | Items |
|---|---|
| `ingots/std/src/evm/crypto.fe` | `addmod`, `mulmod`, `keccak256(MemSpan)`, `ec_add`, `ec_mul`, `ec_pairing(MemSpan)`, `modexp` |
| `ingots/std/src/evm/packed.fe` | The `Packed` builder: `with_capacity(bytes:)`, `u256`, `append_span`, `keccak256`, `span` |
| Single-word rehash | `keccak_words([x]) % P` |
| Test-input helpers | `std::abi::bytes_from_words`, `dyn_array_from` |

## Design: vault (integration contract)

The vault follows the teaching page's sketch: storage `{ y, verifier, claimed }`, `init(y, verifier)` and `claim(bytes proof) -> bool`. It proves knowledge of a secret `x` with this circuit:

```noir
fn main(x: Field, y: pub Field, recipient: pub Field) {
    assert(x * x == y);
    assert(recipient != 0);
}
```

`claim` does four things:

1. Reject if already claimed.
2. Build the public inputs itself: `[y, caller]`. The claimant never supplies them, so a proof copied from the mempool is useless to anyone else.
3. Call `verifier.verify(proof, public_inputs)` through `VerifierMsg`. A revert or `false` fails the claim.
4. Set `claimed`.

| Aspect | Detail |
|---|---|
| Why ZK | `x` is the secret. A non-ZK proof leaks witness evaluations, so a vault that hides its secret needs the ZK flavor. |
| Payout | Not implemented. The contract records the claim only. |
| Tests | Fe tests. The cases from the plan: a valid claim by the recipient the proof was made for succeeds, a replay fails, a different caller fails. |
| Caller in tests | These cases need the Fe test harness to choose the caller. The original plan treated that as unconfirmed (see [open points](#open-points)). |

## Design: toy verifier

A port of the teaching page's `verify(vk, proof, pis, ch)`: 4 rows, 3 wires, 23 evaluations, 7 subrelations, 2 sumcheck rounds of 6 values, and 10 challenges passed in as inputs (the toy is interactive, as on the page). See [ADR-0011](adr/0011-toy-verifier-vectors-from-reference-js.md).

The toy stays the non-ZK toy protocol of the teaching page, independent of the real verifier's switch to ZK. Its optional ZK sumcheck-mask scenarios may be added as a later step; they are not part of T1 or T2.

| Module | Content |
|---|---|
| `f17.fe` | Arithmetic mod 17. |
| `curve.fe` | F_101, F_101², the curve y² = x³ + 3, G1/G2 addition and scalar multiplication, Miller-loop pairing (no precompile exists for this curve). |
| `sumcheck.fe`, `relations.fe` | Public-input delta, round checks, Lagrange evaluation, partial pow, the 7 subrelations, final check `pow·A + l1 == target`. |
| `shplemini.fe` | Batched evaluation, fold evaluations, MSM over the 22 unshifted commitments plus `[Q]`, `[A₁]`, `[1]`, then `e(P0, G2)·e(P1, τG2) == 1`. |
| `reference/gen_vectors.js` | Runs the page's scenarios and writes `src/vectors.fe`. |

## Stages

Hard rule: at **Nov 24, 2026 14:00 UTC** feature work stops and the docs stage starts. The status table in `ultrahonk/README.md` is updated at the end of every stage.

The Status column reflects 2026-11-22. Only stage 0 is recorded as complete, and only for the original non-ZK target.

### Main line (branch `feature/ultrahonk-verifier`)

How to read this table:

- "Ports:" names the upstream Barretenberg reference functions a stage ports. They are references, not project code.
- Rows 1–8 and all estimates (25 h in total, stage 0 included) come from the original plan. Their test wording is restated here for Fe tests, but the stages have not been re-cut: names, counts and slot numbers are **[ZK: TBC]**, and the ZK-specific steps (Libra masking, the small-subgroup consistency check, the Gemini masking polynomial) are not yet assigned to a stage or estimated.

| # | Work | Acceptance | Est. | If the deadline hits here | Status |
|---|---|---|---|---|---|
| 0 | Tooling, Noir circuit, `vectors.sh`, oracle tests, ingot skeletons, spikes | Pipeline ends with bb verify OK; oracle tests pass; `fe test` green | 3 h | Reproducible oracle pipeline + skeleton | Done on 2026-11-22 for the original non-ZK target |
| 0b | Switch the stage 0 artifacts to the ZK flavor (`-t evm`) and to the Fe-only layout: generated verifier in the untracked `.oracle/`, no tracked Solidity, expected values and tamper-case selectors as Fe constants | Not stated in the scope changes | — | — | In progress |
| 1 | `abi.fe` + `Vault` contract, with Fe tests | `fe test`: valid claim true; replay and wrong caller fail | 2 h | To be restated: the original cut line ("A Fe contract that verifies Noir proofs", through the Solidity verifier) relied on the tracked oracle | Planned |
| 2 | `fr`, `types`, `proof`, `transcript`; transcript challenges captured from the local oracle. Ports: `FrLib`, `loadProof` checks, all `generate*Challenge` | `fe test -f transcript`: every challenge equals the oracle value; reverts on scalar ≥ P and coordinate ≥ Q | 2.5 h | + bit-exact UltraHonk transcript in Fe | Planned |
| 3 | Risk spike. Ports: `accumulateMemoryRelation` (largest, 169 lines) | Compiles; slots 14–19 match; record `runtime.bin` size at `-O 1/2/s` | 1.5 h | Decides single contract vs split | Planned |
| 4 | `sumcheck` without relations. Ports: `computePublicInputDelta`, `checkSum`, `computeNextTargetSum`, `partiallyEvaluatePOW` | delta, every round target and final pow match | 1.5 h | + sumcheck reduction | Planned |
| 5 | Other nine relations; finish `sumcheck::verify`. Ports: the nine relations, `scaleAndBatchSubrelations` | 31 slots match one by one; grand sum equals target; tampered evaluation → false | 5 h | "Full sumcheck verifier in Fe; no opening proof" | Planned |
| 6 | `shplemini`. Ports: `computeSquares`, `computeFoldPosEvaluations`, scalars, `batchMul`, pairing-point aggregation, `pairing` | scalars match by index; P0, P1 match; `verifier::verify` returns true | 4 h | Complete verifier library | Planned |
| 7 | `HonkVerifier` Fe contract, negative Fe tests over the fixed tamper list, vault tests against the Fe verifier, code-size script, gas | the Fe verifier accepts the proof and reverts with the reference selector on every tamper case; vault claim passes with the Fe verifier; runtime ≤ 24,576 bytes | 2.5 h | Full submission | Planned |
| 8 | README, `scripts/check.sh`, reproduce steps | fresh clone passes `scripts/check.sh` with only `fe` | 3 h | — | Planned |

### Stage 0 spikes

The original plan's spikes, each kept as real code or as a test. They belong to stage 0, which is recorded as completed for the non-ZK target (pipeline, oracle tests, Fe skeleton). This document does not record individual spike outcomes.

| # | Spike | Why | Under the Fe-only layout |
|---|---|---|---|
| 1 | Contract skeleton with `verify(bytes,bytes32[])` that checks lengths then always reverts, called from a Fe test and from Foundry with ABI-encoded calldata | Settles the untested `Bytes` + `Vec<Bytes32>` msg shape | The Foundry-side call is not part of the committed tests |
| 2 | A Fe contract calling another contract through `VerifierMsg`, and constructor arguments passed to Fe initcode from Foundry | Both are needed by the vault | The vault is tested with Fe tests |
| 3 | `mul(inv(2), 2) == 1`, `ec_add(G, G) == ec_mul(G, 2)`, a two-pair pairing check | Settles precompile `Result` handling | Unchanged |
| 4 | `absorb` over 32 zero bytes equals `keccak(0x00…00) % P` | Checks the transcript hash helper against a known hash | Unchanged |
| 5 | Foundry deploys a Fe `.bin` | Confirms the format, and that Foundry runs Osaka bytecode (`evm_version = "osaka"`; Sonatina emits `CLZ`) | Not needed by the committed tests |
| 6 | `bb prove --help` | Confirms the `bb` 6.0.0 flags and output file names | To be repeated for `-t evm` |

### Code-size strategy

`fe test` cannot catch the EIP-170 limit (its revm allows 1 MiB), so the limit is checked outside the tests. No size is recorded in this document. See [ADR-0012](adr/0012-code-size-strategy.md).

| Step | Detail |
|---|---|
| Measure early | Stage 3 compiles the largest relation and records `runtime.bin` size at `-O 1`, `-O 2` and `-O s`. |
| Project | Stage 3's number × ~4.5 projects the size of the relations. The ZK flavor adds protocol steps on top of the shared relations; their effect on size is unmeasured. |
| Enforce | A script checks the built `.runtime.bin` against 24,576 bytes. |
| Fallback 1 | `-O 2` / `-O s`. |
| Fallback 2 | A second contract, `HonkRelations`, staticcalled by the verifier (the upstream reference does the same with `RelationsLib`). |

### Toy line (branch `feature/honk-toy`, separate git worktree, runs in parallel)

Estimates sum to 5.5 h.

| # | Work | Acceptance | Est. | If cut here | Status |
|---|---|---|---|---|---|
| T1 | `reference/` extraction + generator; `f17`, `sumcheck`, `relations` | `fe test` in `ultrahonk/toy`: for the honest run, delta, round targets, pow, the 7 subrelations and the final check equal the reference; each cheating scenario fails at the same check as on the page | 2.5 h | Toy sumcheck verifier | Planned |
| T2 | `curve` (incl. Miller-loop pairing), `shplemini`, `verifier` | batched evaluation, κ, P0, P1 and both pairing values equal the reference; `verify` accepts the honest proof and gives the page's verdict for all nine non-ZK scenarios, including the "lucky dice" cheat that is accepted | 3 h | Complete toy Honk verifier | Planned |

### Order of sacrifice

If time runs short: T2 first, then vault extras, never the main-line stage in progress.

## Porting hazards (real verifier)

Implementer checklist for the port, written against the non-ZK upstream reference. Items are grouped by area and keep the plan's original numbers.

- Items tagged **[ZK: TBC]** contain orderings, counts or indices to be confirmed from the generated ZK contract (stage 0b, in progress).
- The ZK-specific steps (Libra masking, the small-subgroup consistency check, the Gemini masking polynomial) have no checklist items yet.
- "Solidity" in an item means the upstream Barretenberg reference.

**Orderings and offsets**

- [ ] 1. Three different orderings: proof order (w1, w2, w3, readCounts, readTags, w4, lookupInverses, zPerm), WIRE/commitment order (w1..w4, zPerm, lookupInverses, readCounts, readTags), and VK struct order. **[ZK: TBC]**
- [ ] 2. Shplemini scalars are offset by one (index 0 is shplonkQ with scalar 1); shifted wires are `scalars[29..33]` with evaluations 36..40; the rho power is not reset between the two loops. **[ZK: TBC]**
- [ ] 15. Length checks first: `proof.len() == (82 + 12L)*32` for the ZK flavor (the original plan had `(67 + 11L)*32`) and `public_inputs.len() == num_public_inputs − 8`. **[ZK: TBC]** for the public-input count.

**Field arithmetic**

- [ ] 3. `sub` needs b < P; `neg(0)` is P in Solidity and 0 in Fe (equal after reduction, never compare raw).
- [ ] 4. `inv(0)` must revert; modexp returns 0 silently.

**Transcript**

- [ ] 5. eta: vkHash first; each public input checked `< P`; the 8 pairing limbs follow the public inputs; `publicInputsSize` includes those 8. **[ZK: TBC]**
- [ ] 6. All challenges are full `keccak % P`. Gate challenges are successive squares of g0 and g0 is the chained value. `alphas[i] = alpha^(i+1)`. **[ZK: TBC]**

**Sumcheck and relations**

- [ ] 7. Sumcheck: initial target 0; copy the eight barycentric denominators verbatim; pow update is `pow * (1 + u*(g − 1))`. **[ZK: TBC]** (the ZK flavor has 9 values per round, not 8)
- [ ] 8. Relations: slots are not in call order (arithmetic 6–7, permutation 0–2); slots 4 and 21 are not multiplied by the domain separator; batching is `evals[0] + Σ evals[i]·alpha^i`. (The relations code is shared by both flavors upstream: same 31 subrelations.)
- [ ] 9. Public-input delta: numerator starts at `gamma + beta*(2^28 + 5)`, denominator at `gamma − beta*6`; real inputs first, then the 8 limbs. **[ZK: TBC]**

**Shplemini, MSM and pairing**

- [ ] 10. `computeFoldPosEvaluations` iterates L down to 1 (use `while`); nu power starts at nu² and multiplies by nu² each step. **[ZK: TBC]**
- [ ] 11. MSM: start the accumulator at (0,0) explicitly (Solidity relies on zeroed memory); generator (1,2) at index 36+L, kzgQuotient with scalar z at 36+L+1; any precompile failure rejects. **[ZK: TBC]**
- [ ] 12. Negate kzgQuotient on a copy (Solidity mutates in place after `batchMul`); negation is mod Q and skips y = 0. **[ZK: TBC]**
- [ ] 13. Pairing-point aggregation runs only if any limb is non-zero; coordinates are `lo | (hi << 136)`; the test circuit exercises one branch only, and the README must say which. **[ZK: TBC]**
- [ ] 14. Pairing input order: (P0, fixed G2), (P1, SRS G2); copy the eight G2 words verbatim. **[ZK: TBC]**

## Workflow

See [ADR-0014](adr/0014-staged-delivery-incremental-commits.md).

| Topic | Rule |
|---|---|
| Branches | Two branches off `develop` (gitflow): `feature/ultrahonk-verifier` in the main checkout and `feature/honk-toy` in a separate git worktree. |
| Parallelism | The approved plan allows that one parallel implementation writer in its own worktree. The two lines touch disjoint directories. |
| Incremental commits | Owner's rule of 2026-11-22: commit each working unit as soon as its tests pass, several per stage, not one commit per stage. |
| Commit hygiene | Conventional commits, no tool-attribution trailers, explicit `ultrahonk/` pathspecs only. No push unless asked. |
| Writers | One writer per stage on each line. A coordinator reports each stage's test output. |
| Review | Stages do not wait for review. Each stage is a self-contained run of commits, so review can happen at any time and a stage can be reverted alone. Work pauses only for a real decision (for example single contract vs split after stage 3). |
| Boundaries | No changes to global tools, the root library or `calculator/`. |
| Documentation | Files under `docs/` are written on their own branch, `feature/ultrahonk-docs`, and touch no code directory. |

## Verification

A reader needs only `fe`. No `forge` command is needed.

| Level | How |
|---|---|
| Per ingot | `fe check`, `fe fmt --check` and `fe test` inside the ingot. |
| Per stage | The acceptance command in the stage tables: `fe test -f <name>` in the ingot. |
| End to end | `scripts/check.sh`: `fe build` the contracts, `fe test` all ingots including the toy, check the code size of the built `.runtime.bin`, then print an accept/reject table plus size and gas. |
| Regeneration (proof, key, local oracle) | `scripts/vectors.sh`. From a clean `vectors/` it reproduces the committed files if proving is deterministic; otherwise the README pins the committed proof. Needs the [project-local tools](#project-local-tooling). |
| Regeneration (expected values) | Not possible from the repository alone: it needs the local capture harness to be recreated. Their documented provenance (tool, version, how captured) stands in for it. |
| Regeneration (toy) | `node toy/reference/gen_vectors.js` reproduces `toy/src/vectors.fe`. Needs Node 24. |

What the Fe tests and the script are meant to show in the end-to-end run:

- [ ] The Fe verifier accepts the committed proof.
- [ ] Every intermediate value equals the committed expected value from the reference oracle.
- [ ] The Fe verifier reverts with the reference selector on each tamper case.
- [ ] The vault claim works.
- [ ] Code size is within EIP-170.

## Assumptions, risks, out of scope

### Assumptions and limitations

- The project owner is registered for the contest (registration closed Nov 17).
- The test circuit exercises only one branch of pairing-point aggregation. The README must say which.
- Committed expected values are trusted on their documented provenance, because the oracle and the capture harness are not in the repository.

### Risks

| Risk | Where it is addressed |
|---|---|
| Fe compiler crash or code size on the relations | Measured in stage 3 |
| Cross-contract call or constructor arguments from Fe | Stage 0, spike 2 |
| Reaching stage 7 by the deadline is not guaranteed | Cut lines in the stage tables |
| The ZK flavor adds protocol steps (Libra masking, a small-subgroup consistency check, a Gemini masking polynomial), so the risk of not reaching the final pairing check by the deadline is higher | Cut lines in the stage tables; the stages are not yet re-cut for ZK |
| A fixed list of tamper cases replaces in-EVM fuzzed differential testing | Accepted in [ADR-0009](adr/0009-uncommitted-reference-oracle-fe-only-tests.md) |

The original plan also listed "Osaka-only bytecode in forge" (stage 0, spike 5). No committed test depends on Foundry under the Fe-only layout.

### Out of scope

- Anything running on the Aztec network.
- The non-ZK flavor of the real verifier (`-t evm-no-zk`): dropped, not built alongside the ZK one.
- Solidity in the repository, Foundry tests, and in-EVM fuzzed differential testing against the Solidity verifier.
- Vault payout logic.
- Gas optimisation.
- A VK generator CLI.
- Multiple circuits.
- Any change to the teaching page.

Not in the current stages, possible as a later step: the toy's optional ZK sumcheck-mask scenarios.

### Open points

Places where the plan and the scope changes leave a detail unassigned. They are recorded here so a reviewer does not have to rediscover them.

| Point | Current reading |
|---|---|
| Stage plan after the scope changes | Stages 1–8 and their estimates were written for the non-ZK target. The ZK-specific steps are not yet assigned to a stage, and stage 0b has no stated acceptance or estimate. |
| Contiguous absorbs for the ZK transcript | The one-`absorb`-per-round design is being re-validated against the ZK transcript. |
| Capture of expected values | How the values and selectors are captured from the local oracle (tool, version, method) is to be documented as provenance. How `verifier/src/vk.fe` is produced without the original generator is not stated. |
| Fixed tamper list | Its source is not restated. The original plan followed the upstream negative test base's case list. |
| Vault tests in Fe | They need the Fe test harness to choose the caller, which the original plan treated as unconfirmed. Which verifier answers the vault in tests before the Fe verifier exists (stage 7) is not stated, and the stage 1 cut line needs restating. |
| Size and gas "next to Solidity" | The original plan printed size and gas next to the Solidity verifier. Whether that comparison is kept, using captured figures, is not stated. |
| External transcript library | The generated ZK contract links its transcript library externally. What that means for running the local oracle is to be confirmed (stage 0b, in progress). |
| Library `-> bool` vs contract revert | The sketches and the stage 5 and 6 acceptance lines speak of `false` / `true` results, while the verifier contract must revert with the reference errors. The plan does not say at which layer the revert is raised. |

## References

Upstream Solidity files are listed as the reference being ported or consulted. None of them is in this repository.

| Reference | Location |
|---|---|
| Reference oracle | Generated locally into `ultrahonk/.oracle/` with `-t evm` (untracked). Upstream at `aztec-packages` commit `b225653c4d0521907559ae80baa626bbbff49e55`: template `honk_zk_contract.hpp`, sources `BaseZKHonkVerifier.sol` and `ZKTranscript.sol` |
| Teaching page | `https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ`. Sections `#practica` (the vault) and `#noir-fe` (modules and milestones). The first `<script>` block is the toy reference. |
| Fe std at the installed version | A local checkout of the Fe repository at tag `v26.6.0`: `ingots/std/src/evm/crypto.fe`, `ingots/std/src/evm/packed.fe`, `ingots/core/src/ptr.fe`, `ingots/core/src/abi.fe`, `ingots/std/src/abi.fe`, `docs/language/accesses.md` |
| Msg and test idioms (same checkout) | `crates/fe/tests/evm_compiler_bench/merkle_verifier.fe`, `crates/fe/tests/fixtures/fe_test/abi_dynamic_payload.fe`, `crates/fe/tests/fixtures/fe_test/address_call_method.fe`, `crates/fe/tests/fixtures/fe_test/precompile_wrappers.fe` |
| Pattern to mirror | `calculator/src/lib.fe` and `calculator/fe.toml` in this repository |
| Upstream negative test base | `barretenberg/sol/test/honk/negative/NegativeTestBase.sol` (marked `UNLICENSED`; nothing is copied) |
| Structure only | `fe-lang/rosetta`: `examples/verifier/fe/src/{field,transcript,msm}.fe`, `shared/ec/fe/src/bn254.fe`. The original plan also cited its `examples/verifier/test/PlonkBench.t.sol` as a test pattern, which no longer applies. |

## Related documents

- [Architecture Decision Records](adr/README.md): one record per decision in the [Decisions](#decisions) table.
