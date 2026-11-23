# UltraHonk verifier in Fe

A port of Barretenberg's zero-knowledge UltraHonk verifier (BN254, Keccak transcript: the flavor
`bb` selects with `-t evm`) from Solidity to [Fe](https://fe-lang.org).

**The Fe verifier does not verify proofs yet.** It has the ABI of the Solidity verifier and runs
its first steps (proof validation, the Fiat-Shamir transcript, the public-input delta and the
sumcheck round checks) in the same order and with the same errors. The relations, Shplemini and the
pairing are not ported, so a call that passes every implemented check reverts with
`VerificationNotImplemented`. The contract never returns `true`.

## What the repository contains

Fe, one Noir circuit and shell scripts. **No Solidity is committed.**

Barretenberg's generated Solidity verifier is used only as a local reference oracle.
`scripts/vectors.sh` writes it to `.oracle/`, which git ignores. Values captured from it are
committed as Fe constants, with the tools and versions that produced them, and the Fe tests assert
against those constants: how it reverts on invalid calls in `lib/src/expected.fe`, what it computes
for the valid proof in `lib/src/vectors.fe`.

## Status

| Stage | Scope | State |
|---|---|---|
| 0 | Tooling, circuit, ZK vector, recorded reference reverts, ingot skeletons | Done |
| 1 | Vault contract calling a verifier through `verify(bytes,bytes32[])` | Pending |
| 2 | Proof validation (length, range of every word) and Fiat-Shamir transcript | Done |
| 3-5 | Sumcheck: public-input delta and the round checks | Done |
| 3-5 | Sumcheck: the relations and the final check against them | Pending |
| 6 | Shplemini, the Libra consistency check and the pairing check | Pending |
| 7 | Verifier contract accepting proofs | Pending: it runs the steps marked done, then reverts |

### What the contract checks today

In the order of the reference verifier, each with the reference's error:

| Step | Module | Rejects with |
|---|---|---|
| Proof length | `lib/src/proof.fe` | `ProofLengthWrongWithLogN(logN, actual, expected)` |
| Every proof word in range for what it holds | `lib/src/proof.fe` | `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder` |
| Number of public inputs | `verifier/src/lib.fe` | `PublicInputsLengthWrong` |
| Public inputs in range, then the 16 challenges | `lib/src/transcript.fe` | `ValueGeFieldOrder` |
| Public-input delta | `lib/src/sumcheck.fe` | (computed, not used yet) |
| The `LOG_N` sumcheck round checks | `lib/src/sumcheck.fe` | `SumcheckFailed` |
| Everything after: relations, Shplemini, consistency check, pairing | not ported | `VerificationNotImplemented`, always |

For the pinned proof, every challenge, the delta, the target of every sumcheck round and the final
partial pow equal the values captured from the reference verifier.

Of the reverts recorded from the reference, the contract tests assert the ones these steps decide:

| Recorded case | Asserted now |
|---|---|
| 3 wrong proof lengths | Yes, the whole revert data |
| 7 overwritten proof words (range checks) | Yes |
| Each of the 142 proof words set to `Q` | Yes |
| 3 changed public inputs, 2 wrong public-input counts | Yes |
| 4 calls that break two rules at once (order of the checks) | Yes |
| Bit flips in proof words 8, 28, 29 | Yes: `SumcheckFailed` |
| Bit flips in words 74, 75, 116, 121, 129, 134, 137, 138, 140 | No: decided by steps not ported. A test asserts that they reach `VerificationNotImplemented` |

Measured at this stage, with `fe` 26.6.0:

| | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| Runtime size of `HonkVerifier`, bytes (`fe build`) | 6,801 | 6,795 | 6,638 |
| Gas of `verify` on the valid proof, up to the revert | 283,247 | 283,179 | 287,984 |

2,976 bytes of the runtime are constants (the verification key, the zeroed challenge array, the
barycentric denominators). The gas is the difference of `evm.gas()` around the call in a Fe test,
so it includes encoding the calldata in the caller; a call that fails the proof-length check costs
4,751 measured the same way. Most of it is the 46 modular inversions, one modexp call each at
about 4,400 gas (measured the same way).

## Run the tests

Needs only `fe` 26.6.0. Nothing here needs `bb`, `nargo` or Foundry.

```sh
cd ultrahonk
(cd lib && fe test)        # field arithmetic, proof checks, transcript, sumcheck rounds
(cd verifier && fe test)   # the contract against the recorded reference reverts
```

`fe build` in `verifier/` writes the contract bytecode to `verifier/out/`.

## Layout

| Path | Content |
|---|---|
| `circuit/` | Noir package `vault`: `x * x == y`, with `y` and `recipient` public |
| `vectors/` | `proof`, `public_inputs`, `vk`, `vk_hash`: raw `bb` output |
| `scripts/vectors.sh` | Regenerates `vectors/` and the local oracle in `.oracle/` |
| `scripts/proof_to_fe.sh` | Prints the proof, public inputs and verification key of `vectors/` as Fe constants; `--check` compares them with `lib/src/vectors.fe` |
| `lib/` | Ingot `ultrahonk`: the verifier steps (`proof`, `transcript`, `sumcheck`), `fr`, `errors`, `types`, `abi` |
| `lib/src/vectors.fe` | The pinned proof and the verification key, plus the challenges, delta, round targets and pow captured from the reference |
| `lib/src/expected.fe` | The reverts of the reference verifier on invalid calls |
| `docs/zk-verifier-reference.md` | What the port must reproduce: proof layout, check order, transcript, formulas, errors |
| `verifier/` | Ingot `ultrahonk_verifier`: contract `HonkVerifier` |
| `.oracle/` | Not committed: Barretenberg's Solidity verifier, for local reference |
| `.tools/` | Not committed: `bb` and `nargo` binaries |

## Test vector

| | |
|---|---|
| Witness | `x = 3` |
| Public inputs, in order | `y = 9`, `recipient = 0xc0ffe` |
| Circuit size | `N = 32`, `LOG_N = 5` |
| `NUMBER_OF_PUBLIC_INPUTS` | 10: the 2 above plus 8 pairing-point limbs carried in the proof |
| Proof | 4544 bytes: `(82 + 12 * LOG_N) * 32` |
| Pairing-point limbs (proof words 0-7) | All zero, so a verifier skips pairing-point aggregation |

```
7ff3d7402d792648e68b8aa359b27a16322859b5d1c44eb45ff36d135ad96553  vectors/proof
ea1bf219985bbd9a6d536d5235273f68d024b81a861440dc6395f301056ce5e3  vectors/public_inputs
2824ffe9888ae66b80cc020982bd2978d759b195865ccd5187fa37c23db721d2  vectors/vk
521899df739b72ff85d2b56347277d19204ebcc952ed9f266e4a44c13de5c906  vectors/vk_hash
```

**`vectors/proof` is pinned.** ZK proving is randomized: three runs of `bb prove -t evm` on the
same inputs gave three different proofs, each accepted by `bb verify`. The other three files, and
the generated Solidity verifier, came out byte-identical every time. No test regenerates the
vector or reads `vectors/`; the values in `lib/src/expected.fe` and `lib/src/vectors.fe` belong
to the pinned proof.

## The reference oracle

The oracle is the Solidity verifier `bb write_solidity_verifier -t evm` emits for `vectors/vk`
(2,518 lines, sha256 `5609d13d...3878d8bfe`). It stays out of the repository.

How the reverts in `lib/src/expected.fe` were captured:

1. `scripts/vectors.sh` wrote `.oracle/src/HonkVerifier.sol` and `.oracle/foundry.toml`.
2. A Foundry test kept locally in `.oracle/test/` deployed `HonkVerifier`, read `vectors/proof`
   and `vectors/public_inputs`, and required `verify` to return `true`.
3. For each case the same test changed one thing (the proof length, one proof word, one public
   input), called `verify` with 20,000,000 gas and logged the revert data.
4. The logged values were copied into `lib/src/expected.fe`.

The values in the second part of `lib/src/vectors.fe` came from the same local test: a contract
inheriting from the generated verifier logged the challenges of its transcript, its public-input
delta, and the target and partial pow of its sumcheck round loop for the pinned proof. The first
part of that file (proof, public inputs, verification key) is printed by `scripts/proof_to_fe.sh`
from `vectors/`; the local test also checks that `vectors/vk` lists the key's points in the order
the verifier uses them.

Measured on that verifier for the pinned proof:

| | |
|---|---|
| Runtime size | `HonkVerifier` 16,946 bytes, plus the linked libraries `RelationsLib` 8,211 and `ZKTranscriptLib` 6,008 |
| Gas for a valid `verify` | 2,654,961 (forge gas report) |

To rebuild the oracle after cloning, run `scripts/vectors.sh` (next section), then
`forge install foundry-rs/forge-std --no-git` and `forge build --sizes` inside `.oracle/`. The
script does not write the local test.

## Regenerate the vector

```sh
cd ultrahonk
mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
scripts/vectors.sh
```

The script ends with `bb verify` accepting the new proof. It **overwrites `vectors/proof` with a
different valid proof**; run `git checkout -- vectors/proof` afterwards to return to the pinned
one. Committing a new proof means capturing `lib/src/expected.fe` and the second part of
`lib/src/vectors.fe` again, and regenerating the first part with `scripts/proof_to_fe.sh`.

The archives are the macOS arm64 builds. The script calls the tools by path and exits unless they
report the versions below; tools installed elsewhere on the machine are not used.

| Tool | Version | Needed for |
|---|---|---|
| `fe` | 26.6.0 (5b3f96a) | Tests and build |
| `bb` | 6.0.0, target `evm` (Keccak, ZK) | Regenerating the vector |
| `nargo` | 1.0.0 (noirc 1.0.0+275d3ab1a5c916c6ea73e8d6b943f685f574500c) | Regenerating the vector |
| `forge` | 1.5.1-stable, solc 0.8.34, `evm_version = "osaka"` | Local oracle only |
