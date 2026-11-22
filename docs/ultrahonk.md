# UltraHonk verification in Fe: project plan

This project adds UltraHonk proof verification written natively in Fe, as new packages under `ultrahonk/`. It has three deliverables: a port of Barretenberg's non-ZK UltraHonk verifier (BN254, Keccak transcript), a vault contract that consumes a Noir + Barretenberg proof through that verifier, and a hand-sized toy Honk verifier over F_17. The real verifier is to be checked bit-for-bit against the Solidity verifier that Barretenberg itself generates, on a real Noir proof. The work is a contest entry due **Nov 24, 2026 23:59 UTC** and is delivered in stages, so that whatever passes by the deadline is coherent, tested and honestly labelled.

> **Status (2026-11-22): planned.** Implementation started on 2026-11-22. No stage is recorded as complete and no test result is reported in this document. Code blocks labelled "sketch" have not been compiled.

## Quick path

These are the **intended** commands. They work only once the stages that create them have landed (see [Stages](#stages)).

1. Run the end-to-end check. It is meant to need only `fe` and `forge`.

   ```sh
   cd ultrahonk
   scripts/check.sh
   ```

2. Read the result. The script is meant to build the contracts, run `fe test` in every ingot (including the toy), run `forge test`, and print an accept/reject table plus code size and gas next to the Solidity verifier.

3. Check a single stage with its acceptance command from the stage tables.

   ```sh
   fe test -f <name>     # inside the ingot under test, for example ultrahonk/lib
   forge test            # inside ultrahonk/oracle
   ```

4. Optionally regenerate the test vectors. This needs the [project-local tools](#project-local-tooling), and Node 24 for the toy.

   ```sh
   scripts/vectors.sh
   node toy/reference/gen_vectors.js
   ```

Prerequisite for any `forge` command: forge-std is not committed, so it is installed once with `forge install foundry-rs/forge-std --no-git` inside `ultrahonk/oracle` (see [open points](#open-points)).

| If you are | Read |
|---|---|
| The repository owner, reviewing stage by stage | [Stages](#stages), [Porting hazards](#porting-hazards-real-verifier), [Workflow](#workflow) |
| A contest judge | [Purpose and context](#purpose-and-context), [Oracle and vectors pipeline](#oracle-and-vectors-pipeline), [Verification](#verification), [Assumptions, risks, out of scope](#assumptions-risks-out-of-scope) |
| Looking for the reason behind a choice | [Decisions](#decisions) and the [ADR index](adr/README.md) |

## Deliverables

| # | Deliverable | Package | What it is | Status |
|---|---|---|---|---|
| 1 | Real verifier | `ultrahonk/lib`, `ultrahonk/verifier` | Port of Barretenberg's non-ZK UltraHonk verifier (BN254, Keccak transcript) | Planned |
| 2 | Integration contract | `ultrahonk/vault` | A Fe application contract that consumes a Noir + Barretenberg proof through the verifier (the teaching page's vault, "cofre") | Planned |
| 3 | Toy verifier | `ultrahonk/toy` | The teaching page's hand-sized Honk over F_17, ported to Fe | Planned |

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

**Outcome wanted:** at any cut point, coherent, tested, honestly-labelled packages under `ultrahonk/`, with the real verifier checked bit-for-bit against Barretenberg's own Solidity verifier on a real Noir proof.

## Decisions

Each row links to the Architecture Decision Record that holds the context, the options considered and the consequences.

| Topic | Decision | ADR |
|---|---|---|
| Source of truth (real) | The `HonkVerifier.sol` that `bb` 6.0.0 generates with `-t evm-no-zk` (same logic as `aztec-packages@b225653`, `barretenberg/sol/src/honk/`, 2,286 lines). The ZK flavor is deferred. | [0001](adr/0001-port-bb-6-non-zk-verifier.md) |
| Tooling | Project-local `bb` 6.0.0 and `nargo` 1.0.0 in `ultrahonk/.tools/`. The installed `bb` 0.84.0 / `nargo` beta.3 are too old and are left untouched. | [0002](adr/0002-project-local-bb-and-nargo.md) |
| Layout | Sibling ingots with relative path dependencies, no workspace. | [0003](adr/0003-sibling-ingots-without-workspace.md) |
| Proof representation (real) | Keep the proof as `Bytes` and read words by offset; no `Proof` struct. Each Fiat–Shamir round hashes `prev ‖ one contiguous run of proof words`, so the transcript becomes one `absorb` helper. | [0004](adr/0004-proof-as-bytes-read-by-offset.md) |
| Sizes (real) | Runtime `log_n` with fixed maximum-size arrays (`[u256; 25]`, `[u256; 63]`), like Solidity. No const generics. | [0005](adr/0005-runtime-log-n-fixed-max-arrays.md) |
| Field | Plain functions on `u256`, no operator-overloaded type (`sonatina#232`). | [0006](adr/0006-field-arithmetic-plain-u256-functions.md) |
| Hashing | The std `Packed` builder for every multi-word hash and for the pairing input, instead of a hand-rolled buffer. Single-word rehash: `keccak_words([x]) % P`. | [0007](adr/0007-hashing-with-std-packed-builder.md) |
| Precompiles | Always `match` on `Result`; `Err` reverts. Never `unwrap_or(default: 0)` (a silent 0 would be a soundness bug). | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Failure | Same as Solidity: the verifier contract reverts on a bad proof, with the same custom errors as `Errors.sol`, so it is a drop-in replacement. The differential test defines reject as "reverted or did not return true". | [0008](adr/0008-precompile-match-and-solidity-compatible-errors.md) |
| Vectors | Generated (Foundry for the real verifier, Node for the toy) into Fe constant modules and committed, so `fe test` and `forge test` run without `bb`, `nargo` or Node. | [0009](adr/0009-solidity-oracle-committed-vectors-shared-negative-suite.md) |
| Negative tests | One shared suite run against both verifiers, rewritten from the upstream case list (not copied). forge-std instead of a hand-written `Vm.sol`. | [0009](adr/0009-solidity-oracle-committed-vectors-shared-negative-suite.md) |
| Circuit | The teaching page's vault circuit: `fn main(x: Field, y: pub Field, recipient: pub Field) { assert(x * x == y); assert(recipient != 0); }` | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Vault ↔ verifier | External call through the standard ABI `verify(bytes,bytes32[])`, not library linking. The same vault then works against bb's Solidity verifier (available from stage 0) and against the Fe verifier (stage 7), and stays small. | [0010](adr/0010-vault-calls-verifier-through-abi.md) |
| Source of truth (toy) | The math block of the teaching page (a DOM-free script that already exports for Node), extracted verbatim and run under Node 24 to generate vectors. Challenges are inputs; ZK mask scenarios are excluded. | [0011](adr/0011-toy-verifier-vectors-from-reference-js.md) |
| Code size | Measure early (stage 3), try optimisation levels first, then split the relations into a second contract. | [0012](adr/0012-code-size-strategy.md) |
| Scope and framing | Noir + Barretenberg proofs verified on the EVM by Fe, not the Aztec network. | [0013](adr/0013-scope-noir-barretenberg-on-evm.md) |
| Delivery | Stages with cut lines, incremental commits, and one parallel worktree for the toy line. | [0014](adr/0014-staged-delivery-incremental-commits.md) |
| `fe-lang/rosetta` | Structure and test pattern only. It targets the 26.1 std and does not compile on 26.6.0. It has no licence, so nothing is copied from it. | [0001](adr/0001-port-bb-6-non-zk-verifier.md) |

## Package layout

Everything is new. The root library, `calculator/` and the root `README.md` are not modified.

```
ultrahonk/
  README.md
  lib/                 ingot "ultrahonk" (pure library)
    src/lib.fe abi.fe fr.fe types.fe proof.fe transcript.fe sumcheck.fe
        relations.fe shplemini.fe verifier.fe
        vectors.fe     GENERATED test constants
  verifier/            ingot "ultrahonk_verifier": contract HonkVerifier
    src/lib.fe  src/vk.fe (GENERATED per circuit)
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
  oracle/              Foundry project using forge-std (installed locally, not committed)
    src/HonkVerifier.sol      GENERATED by bb, committed unedited
    test/OracleHarness.sol Oracle.t.sol GenVectors.t.sol Vault.t.sol
         NegativeBase.sol Negative.t.sol Differential.t.sol
  scripts/vectors.sh  scripts/check.sh
  .tools/              bb + nargo binaries (ignored by the root `.*` rule)
```

| Rule | Detail |
|---|---|
| Shared ABI | `lib/src/abi.fe` holds the `msg` for `verify(bytes,bytes32[])`, shared by the verifier (which receives it) and the vault (which sends it). |
| Build outputs | `out/`, `oracle/cache/` and `circuit/target/` are never staged. |
| forge-std | Installed with `forge install foundry-rs/forge-std --no-git` inside `ultrahonk/oracle`. Its directory is not committed. |
| Negative suite files | `NegativeBase.sol` is the abstract base; `Negative.t.sol` holds its two instantiations, `NegativeSol` and `NegativeFe`. |

## Project-local tooling

The installed `bb` 0.84.0 and `nargo` beta.3 are too old. The project downloads `bb` 6.0.0 and `nargo` 1.0.0 into `ultrahonk/.tools/` instead of replacing them ([ADR-0002](adr/0002-project-local-bb-and-nargo.md)). The asset names below were verified for Darwin arm64.

```sh
cd ultrahonk && mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
.tools/bb/bb --version && .tools/nargo/bin/nargo --version   # expect 6.0.0 and 1.0.0
```

This downloads and runs two official release binaries. `~/.bb` and `~/.nargo` are not touched. The tools are needed only to regenerate vectors, not to run the tests.

## Oracle and vectors pipeline

The Solidity verifier generated by `bb` is the test oracle. Vectors are generated from it once and committed ([ADR-0009](adr/0009-solidity-oracle-committed-vectors-shared-negative-suite.md)).

### Pipeline (`scripts/vectors.sh`)

```sh
(cd circuit && nargo execute)
bb write_vk -b circuit/target/vault.json -o vectors -t evm-no-zk
bb prove    -b circuit/target/vault.json -w circuit/target/vault.gz -o vectors -t evm-no-zk
bb verify   -k vectors/vk -p vectors/proof -i vectors/public_inputs -t evm-no-zk
bb write_solidity_verifier -k vectors/vk -o oracle/src/HonkVerifier.sol -t evm-no-zk
(cd oracle && forge test --match-contract OracleTest && GEN=1 forge test --match-contract GenVectors)
```

The `bb` 6.0.0 flags and output file names are still to be confirmed with `bb prove --help` (stage 0, spike 6).

### Test-vector provenance

| Artifact | Produced by | Committed |
|---|---|---|
| `circuit/src/main.nr` | The teaching page's vault circuit | Yes |
| `vectors/proof`, `vectors/public_inputs`, `vectors/vk` | `bb` 6.0.0 (`write_vk`, `prove`) with `-t evm-no-zk` | Yes, raw `bb` output |
| `oracle/src/HonkVerifier.sol` | `bb write_solidity_verifier` | Yes, unedited |
| `lib/src/vectors.fe` | `GenVectors.t.sol` run with `GEN=1` | Yes |
| `verifier/src/vk.fe` | `GenVectors.t.sol` run with `GEN=1` | Yes, one per circuit |
| `toy/reference/honk.js` | The teaching page's math block, verbatim | Yes |
| `toy/src/vectors.fe` | `toy/reference/gen_vectors.js` under Node 24 | Yes |

### Foundry test files (`oracle/test/`)

| File | Role |
|---|---|
| `Oracle.t.sol` | Deploys the generated verifier, reads `vectors/proof` and `vectors/public_inputs`, requires `verify == true`, asserts `proof.length == (67 + 11*LOG_N)*32`, plus tamper cases. |
| `OracleHarness.sol` | `OracleHarness is HonkVerifier`. Exposes `transcript()`, `sumcheckTrace()` and `subrelations()` by calling the generated internals, and `shplemini()` as a marked ~110-line copy of `verifyShplemini` that also returns `scalars`, `P0`, `P1`. |
| `GenVectors.t.sol` | Runs only with `GEN=1`. Writes `lib/src/vectors.fe` (proof words, public inputs, every challenge, delta, per-round targets, pow, 31 subrelations, grand sum, scalars, P0, P1) and `verifier/src/vk.fe` (`N`, `LOG_N`, `NUM_PUBLIC_INPUTS`, `VK_HASH`, `VK_POINTS: [u256; 56]` in commitment order). |
| `NegativeBase.sol`, `Negative.t.sol` | One abstract base with a virtual `_createVerifier()`, instantiated as `NegativeSol` and `NegativeFe`. The case list follows upstream `barretenberg/sol/test/honk/negative/NegativeTestBase.sol` (34 expectations) but is rewritten, not copied, because that file is marked `UNLICENSED`. |
| `Differential.t.sol` | Both verifiers accept the proof and reject every tamper. It also fuzzes one random proof word and requires both verifiers to agree, calling `verify{gas: 15_000_000}`, and asserts `code.length <= 24576`. |
| `Vault.t.sol` | Vault claim tests (see [Design: vault](#design-vault-integration-contract)). |

### Reuse and licences

| Source | Licence position | What the project does |
|---|---|---|
| Fe repository fixtures | Apache-2.0 | Idioms may be copied with attribution. |
| `fe-lang/rosetta` | No licence | Learn from it, copy nothing. |
| Upstream `NegativeTestBase.sol` | Marked `UNLICENSED` | Follow the case list, rewrite the code. |
| Other contest entries | — | Nothing is taken from them. |

`ultrahonk/README.md` gets a "reused from / learned from" table.

## Design: real verifier

### Proof word layout

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

### Key signatures (sketch)

Uncompiled sketches in Fe 26.6.0 syntax. They show intent, not final code.

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
pub fn accumulate(_ p: [u256; 41], t: Transcript, pow: u256) -> u256                // relations
pub fn verify(vk: VerificationKey, _ proof: Bytes, _ public_inputs: Vec<Bytes32>) -> bool
```

| Convention | Rule |
|---|---|
| Parameters | Plain parameters view the caller's value in place (no copy). Outputs go through `mut` parameters. |
| Arity | Every function keeps six parameters or fewer. |

### Failure behaviour

The Fe verifier reverts with the same custom errors as `Errors.sol`, declared as `#[error]` structs and raised with `revert_error`, so it is a drop-in for the Solidity verifier ([ADR-0008](adr/0008-precompile-match-and-solidity-compatible-errors.md)).

Errors: `SumcheckFailed`, `ShpleminiFailed`, `ProofLengthWrongWithLogN`, `PublicInputsLengthWrong`, `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder`, `InvertOfZero`.

The check order must match Solidity, or the selectors differ:

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

The vault follows the teaching page's sketch: storage `{ y, verifier, claimed }`, `init(y, verifier)` and `claim(bytes proof) -> bool`.

`claim` does four things:

1. Reject if already claimed.
2. Build the public inputs itself: `[y, caller]`. The claimant never supplies them, so a proof copied from the mempool is useless to anyone else.
3. Call `verifier.verify(proof, public_inputs)` through `VerifierMsg`. A revert or `false` fails the claim.
4. Set `claimed`.

| Aspect | Detail |
|---|---|
| Payout | Not implemented. The contract records the claim only. |
| Tests | In forge (`Vault.t.sol`), where `vm.prank` fixes the caller to the `recipient` the proof was made for: a valid claim succeeds, a replay fails, a different caller fails. |
| Fe-side test | Added only if the Fe test harness can choose the caller. |
| Verifier behind it | bb's Solidity verifier from stage 1; the Fe verifier from stage 7. |

## Design: toy verifier

A port of the teaching page's `verify(vk, proof, pis, ch)`: 4 rows, 3 wires, 23 evaluations, 7 subrelations, 2 sumcheck rounds of 6 values, and 10 challenges passed in as inputs (the toy is interactive, as on the page). See [ADR-0011](adr/0011-toy-verifier-vectors-from-reference-js.md).

| Module | Content |
|---|---|
| `f17.fe` | Arithmetic mod 17. |
| `curve.fe` | F_101, F_101², the curve y² = x³ + 3, G1/G2 addition and scalar multiplication, Miller-loop pairing (no precompile exists for this curve). |
| `sumcheck.fe`, `relations.fe` | Public-input delta, round checks, Lagrange evaluation, partial pow, the 7 subrelations, final check `pow·A + l1 == target`. |
| `shplemini.fe` | Batched evaluation, fold evaluations, MSM over the 22 unshifted commitments plus `[Q]`, `[A₁]`, `[1]`, then `e(P0, G2)·e(P1, τG2) == 1`. |
| `reference/gen_vectors.js` | Runs the page's scenarios and writes `src/vectors.fe`. |

## Stages

Hard rule: at **Nov 24, 2026 14:00 UTC** feature work stops and the docs stage starts. The status table in `ultrahonk/README.md` is updated at the end of every stage.

The Status column below reflects 2026-11-22. Implementation has started; no stage is recorded as complete.

### Main line (branch `feature/ultrahonk-verifier`)

The Work column names the Solidity pieces each stage ports. Estimates sum to 25 h.

| # | Work (ports) | Acceptance | Est. | If the deadline hits here | Status |
|---|---|---|---|---|---|
| 0 | Tooling, Noir circuit, `vectors.sh`, `Oracle.t.sol`, ingot skeletons, spikes | `scripts/vectors.sh` ends with bb verify OK; `forge test --match-contract OracleTest` passes; `fe test` green | 3 h | Reproducible oracle pipeline + skeleton | Planned |
| 1 | `abi.fe` + `Vault` contract, wired to bb's Solidity verifier | `forge test --match-contract VaultTest`: valid claim true; replay and wrong caller fail | 2 h | "A Fe contract that verifies Noir proofs" (through the Solidity verifier) | Planned |
| 2 | `fr`, `types`, `proof`, `transcript`; harness `transcript()`; generator v1 (`FrLib`, `loadProof` checks, all `generate*Challenge`) | `fe test -f transcript`: every challenge equals the oracle; reverts on scalar ≥ P and coordinate ≥ Q | 2.5 h | + bit-exact UltraHonk transcript in Fe | Planned |
| 3 | Risk spike: `accumulateMemoryRelation` (largest, 169 lines) | Compiles; slots 14–19 match; record `runtime.bin` size at `-O 1/2/s` | 1.5 h | Decides single contract vs split | Planned |
| 4 | `sumcheck` without relations (`computePublicInputDelta`, `checkSum`, `computeNextTargetSum`, `partiallyEvaluatePOW`) | delta, every round target and final pow match | 1.5 h | + sumcheck reduction | Planned |
| 5 | Other nine relations + `scaleAndBatchSubrelations`; finish `sumcheck::verify` | 31 slots match one by one; grand sum equals target; tampered evaluation → false | 5 h | "Full sumcheck verifier in Fe; no opening proof" | Planned |
| 6 | `shplemini` (`computeSquares`, `computeFoldPosEvaluations`, scalars, `batchMul`, pairing-point aggregation, `pairing`) | scalars match by index; P0, P1 match; `verifier::verify` returns true | 4 h | Complete verifier library | Planned |
| 7 | `HonkVerifier` contract, `Differential.t.sol`, vault re-run against the Fe verifier, size and gas | both verifiers accept the proof and reject every tamper; vault claim passes with the Fe verifier; runtime ≤ 24,576 bytes | 2.5 h | Full submission | Planned |
| 8 | README, `scripts/check.sh`, reproduce steps | fresh clone passes `scripts/check.sh` with only `fe` and `forge` | 3 h | — | Planned |

### Stage 0 spikes

Each spike is kept as real code or as a test. The items they cover are unverified until the spike runs.

| # | Spike | Why |
|---|---|---|
| 1 | Contract skeleton with `verify(bytes,bytes32[])` that checks lengths then always reverts, called from a Fe test and from forge with Solidity-encoded calldata | Settles the untested `Bytes` + `Vec<Bytes32>` msg shape |
| 2 | A Fe contract calling another contract through `VerifierMsg`, and constructor arguments passed to Fe initcode from forge | Both are needed by the vault |
| 3 | `mul(inv(2), 2) == 1`, `ec_add(G, G) == ec_mul(G, 2)`, a two-pair pairing check | Settles precompile `Result` handling |
| 4 | `absorb` over 32 zero bytes equals `keccak(0x00…00) % P` | Checks the transcript hash helper against a known hash |
| 5 | Forge deploys a Fe `.bin` | Confirms the format, and that forge runs Osaka bytecode (`evm_version = "osaka"`; Sonatina emits `CLZ`) |
| 6 | `bb prove --help` | Confirms the `bb` 6.0.0 flags and output file names |

### Code-size strategy

`fe test` cannot catch the EIP-170 limit (its revm allows 1 MiB), so the limit is enforced in forge. No size has been measured yet. See [ADR-0012](adr/0012-code-size-strategy.md).

| Step | Detail |
|---|---|
| Measure early | Stage 3 compiles the largest relation and records `runtime.bin` size at `-O 1`, `-O 2` and `-O s`. |
| Project | Stage 3's number × ~4.5 projects the size of the relations. |
| Enforce | `Differential.t.sol` asserts `code.length <= 24576`. |
| Fallback 1 | `-O 2` / `-O s`. |
| Fallback 2 | A second contract, `HonkRelations`, staticcalled by the verifier (what Solidity does with `RelationsLib`). |

### Toy line (branch `feature/honk-toy`, separate git worktree, runs in parallel)

Estimates sum to 5.5 h.

| # | Work | Acceptance | Est. | If cut here | Status |
|---|---|---|---|---|---|
| T1 | `reference/` extraction + generator; `f17`, `sumcheck`, `relations` | `fe test` in `ultrahonk/toy`: for the honest run, delta, round targets, pow, the 7 subrelations and the final check equal the reference; each cheating scenario fails at the same check as on the page | 2.5 h | Toy sumcheck verifier | Planned |
| T2 | `curve` (incl. Miller-loop pairing), `shplemini`, `verifier` | batched evaluation, κ, P0, P1 and both pairing values equal the reference; `verify` accepts the honest proof and gives the page's verdict for all nine non-ZK scenarios, including the "lucky dice" cheat that is accepted | 3 h | Complete toy Honk verifier | Planned |

### Order of sacrifice

If time runs short: T2 first, then vault extras, never the main-line stage in progress.

## Porting hazards (real verifier)

Implementer checklist for the port. Items are grouped by area and keep the plan's original numbers.

**Orderings and offsets**

- [ ] 1. Three different orderings: proof order (w1, w2, w3, readCounts, readTags, w4, lookupInverses, zPerm), WIRE/commitment order (w1..w4, zPerm, lookupInverses, readCounts, readTags), and VK struct order.
- [ ] 2. Shplemini scalars are offset by one (index 0 is shplonkQ with scalar 1); shifted wires are `scalars[29..33]` with evaluations 36..40; the rho power is not reset between the two loops.
- [ ] 15. Length checks first: `proof.len() == (67 + 11L)*32` and `public_inputs.len() == num_public_inputs − 8`.

**Field arithmetic**

- [ ] 3. `sub` needs b < P; `neg(0)` is P in Solidity and 0 in Fe (equal after reduction, never compare raw).
- [ ] 4. `inv(0)` must revert; modexp returns 0 silently.

**Transcript**

- [ ] 5. eta: vkHash first; each public input checked `< P`; the 8 pairing limbs follow the public inputs; `publicInputsSize` includes those 8.
- [ ] 6. All challenges are full `keccak % P`. Gate challenges are successive squares of g0 and g0 is the chained value. `alphas[i] = alpha^(i+1)`.

**Sumcheck and relations**

- [ ] 7. Sumcheck: initial target 0; copy the eight barycentric denominators verbatim; pow update is `pow * (1 + u*(g − 1))`.
- [ ] 8. Relations: slots are not in call order (arithmetic 6–7, permutation 0–2); slots 4 and 21 are not multiplied by the domain separator; batching is `evals[0] + Σ evals[i]·alpha^i`.
- [ ] 9. Public-input delta: numerator starts at `gamma + beta*(2^28 + 5)`, denominator at `gamma − beta*6`; real inputs first, then the 8 limbs.

**Shplemini, MSM and pairing**

- [ ] 10. `computeFoldPosEvaluations` iterates L down to 1 (use `while`); nu power starts at nu² and multiplies by nu² each step.
- [ ] 11. MSM: start the accumulator at (0,0) explicitly (Solidity relies on zeroed memory); generator (1,2) at index 36+L, kzgQuotient with scalar z at 36+L+1; any precompile failure rejects.
- [ ] 12. Negate kzgQuotient on a copy (Solidity mutates in place after `batchMul`); negation is mod Q and skips y = 0.
- [ ] 13. Pairing-point aggregation runs only if any limb is non-zero; coordinates are `lo | (hi << 136)`; the test circuit exercises one branch only, and the README must say which.
- [ ] 14. Pairing input order: (P0, fixed G2), (P1, SRS G2); copy the eight G2 words verbatim.

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

| Level | How |
|---|---|
| Per stage | The acceptance command in the stage tables: `fe test -f <name>` in the ingot, `forge test` in `ultrahonk/oracle`. |
| End to end | `scripts/check.sh`: `fe build` the contracts, `fe test` all ingots including the toy, `forge test`, then print an accept/reject table plus size and gas next to Solidity. |
| Regeneration (real) | `scripts/vectors.sh` from a clean `vectors/` reproduces the committed files if proving is deterministic; otherwise the README pins the committed proof. |
| Regeneration (toy) | `node toy/reference/gen_vectors.js` reproduces `toy/src/vectors.fe`. |

What `forge test` is meant to show in the end-to-end run:

- [ ] The oracle accepts the proof.
- [ ] The Fe verifier accepts the same proof.
- [ ] Both reject each tampered proof and each tampered public input.
- [ ] The vault claim works against both verifiers.
- [ ] Code size is within EIP-170.

## Assumptions, risks, out of scope

### Assumptions and limitations

- The project owner is registered for the contest (registration closed Nov 17).
- The test circuit exercises only one branch of pairing-point aggregation. The README must say which.

### Risks

| Risk | Where it is addressed |
|---|---|
| Fe compiler crash or code size on the relations | Measured in stage 3 |
| Osaka-only bytecode in forge | Stage 0, spike 5 |
| Cross-contract call or constructor arguments from Fe | Stage 0, spike 2 |
| Reaching stage 7 by the deadline is not guaranteed | Cut lines in the stage tables |

### Out of scope

- Anything running on the Aztec network.
- The ZK flavor (`-t evm`).
- The toy's ZK mask scenarios.
- Vault payout logic.
- Gas optimisation.
- A VK generator CLI.
- Multiple circuits.
- Any change to the teaching page.

### Open points

Places where the plan leaves a detail unassigned. They are recorded here so a reviewer does not have to rediscover them.

| Point | Current reading |
|---|---|
| Library `-> bool` vs contract revert | The sketches and the stage 5 and 6 acceptance lines speak of `false` / `true` results, while the verifier contract must revert with `SumcheckFailed` or `ShpleminiFailed`. The plan does not say at which layer the revert is raised. |
| Stage for the shared negative suite and the fuzz case | The plan adds them without assigning a stage. `NegativeFe` and the differential fuzz need the Fe verifier contract, which is stage 7's work. |
| forge-std on a fresh clone | Vectors are committed so that tests need no `bb`, `nargo` or Node, but forge-std is not committed. A fresh clone therefore needs the `forge install` step before `forge test`. The plan does not say whether `scripts/check.sh` runs it. |

## References

| Reference | Location |
|---|---|
| Generated oracle | `ultrahonk/oracle/src/HonkVerifier.sol`. Upstream template: `barretenberg/cpp/src/barretenberg/dsl/acir_proofs/honk_contract.hpp` @ `b225653c4d0521907559ae80baa626bbbff49e55` |
| Teaching page | `https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ`. Sections `#practica` (the vault) and `#noir-fe` (modules and milestones). The first `<script>` block is the toy reference. |
| Fe std at the installed version | A local checkout of the Fe repository at tag `v26.6.0`: `ingots/std/src/evm/crypto.fe`, `ingots/std/src/evm/packed.fe`, `ingots/core/src/ptr.fe`, `ingots/core/src/abi.fe`, `ingots/std/src/abi.fe`, `docs/language/accesses.md` |
| Msg and test idioms (same checkout) | `crates/fe/tests/evm_compiler_bench/merkle_verifier.fe`, `crates/fe/tests/fixtures/fe_test/abi_dynamic_payload.fe`, `crates/fe/tests/fixtures/fe_test/address_call_method.fe`, `crates/fe/tests/fixtures/fe_test/precompile_wrappers.fe` |
| Pattern to mirror | `calculator/src/lib.fe` and `calculator/fe.toml` in this repository |
| Upstream negative case list | `barretenberg/sol/test/honk/negative/NegativeTestBase.sol` (case list only; marked `UNLICENSED`) |
| Structure only | `fe-lang/rosetta`: `examples/verifier/fe/src/{field,transcript,msm}.fe`, `shared/ec/fe/src/bn254.fe`, `examples/verifier/test/PlonkBench.t.sol` |

## Related documents

- [Architecture Decision Records](adr/README.md): one record per decision in the [Decisions](#decisions) table.
