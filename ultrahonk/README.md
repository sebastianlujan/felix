# UltraHonk verifier in Fe

A port of Barretenberg's zero-knowledge UltraHonk verifier (BN254, Keccak transcript: the flavor
`bb` selects with `-t evm`) from Solidity to [Fe](https://fe-lang.org).

**The Fe verifier does not verify proofs yet.** It has the ABI and the proof-length check of the
Solidity verifier and then reverts. What exists today is the ground to build on: a Noir circuit, a
real ZK proof, and the behaviour of Barretenberg's own verifier on that proof, recorded as Fe
constants.

## What the repository contains

Fe, one Noir circuit and shell scripts. **No Solidity is committed.**

Barretenberg's generated Solidity verifier is used only as a local reference oracle.
`scripts/vectors.sh` writes it to `.oracle/`, which git ignores. Values captured from it are
committed as Fe constants in `verifier/src/expected.fe`, with the tools and versions that produced
them, and the Fe tests assert against those constants.

## Status

| Stage | Scope | State |
|---|---|---|
| 0 | Tooling, circuit, ZK vector, recorded reference reverts, ingot skeletons | Done |
| 1 | Vault contract calling a verifier through `verify(bytes,bytes32[])` | Pending |
| 2 | Proof decoding and Fiat-Shamir transcript | Pending |
| 3-5 | Sumcheck and the relations | Pending |
| 6 | Shplemini, the Libra consistency check and the pairing check | Pending |
| 7 | Verifier contract accepting proofs, tests against the recorded reverts | Pending |

## Run the tests

Needs only `fe` 26.6.0. Nothing here needs `bb`, `nargo` or Foundry.

```sh
cd ultrahonk
(cd lib && fe test)        # field arithmetic, precompiles, hashing, error selectors
(cd verifier && fe test)   # contract skeleton against the recorded reference reverts
```

`fe build` in `verifier/` writes the contract bytecode to `verifier/out/`.

## Layout

| Path | Content |
|---|---|
| `circuit/` | Noir package `vault`: `x * x == y`, with `y` and `recipient` public |
| `vectors/` | `proof`, `public_inputs`, `vk`, `vk_hash`: raw `bb` output |
| `scripts/vectors.sh` | Regenerates `vectors/` and the local oracle in `.oracle/` |
| `lib/` | Ingot `ultrahonk`: verifier message, errors, scalar field arithmetic |
| `verifier/` | Ingot `ultrahonk_verifier`: contract `HonkVerifier` and `expected.fe` |
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
vector or reads `vectors/`; the values in `verifier/src/expected.fe` belong to the pinned proof.

## The reference oracle

The oracle is the Solidity verifier `bb write_solidity_verifier -t evm` emits for `vectors/vk`
(2,518 lines, sha256 `5609d13d...3878d8bfe`). It stays out of the repository.

How the values in `verifier/src/expected.fe` were captured:

1. `scripts/vectors.sh` wrote `.oracle/src/HonkVerifier.sol` and `.oracle/foundry.toml`.
2. A Foundry test kept locally in `.oracle/test/` deployed `HonkVerifier`, read `vectors/proof`
   and `vectors/public_inputs`, and required `verify` to return `true`.
3. For each case the same test changed one thing (the proof length, one proof word, one public
   input), called `verify` with 20,000,000 gas and logged the revert data.
4. The logged values were copied into `verifier/src/expected.fe`.

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
one. Committing a new proof means capturing `verifier/src/expected.fe` again.

The archives are the macOS arm64 builds. The script calls the tools by path and exits unless they
report the versions below; tools installed elsewhere on the machine are not used.

| Tool | Version | Needed for |
|---|---|---|
| `fe` | 26.6.0 (5b3f96a) | Tests and build |
| `bb` | 6.0.0, target `evm` (Keccak, ZK) | Regenerating the vector |
| `nargo` | 1.0.0 (noirc 1.0.0+275d3ab1a5c916c6ea73e8d6b943f685f574500c) | Regenerating the vector |
| `forge` | 1.5.1-stable, solc 0.8.34, `evm_version = "osaka"` | Local oracle only |
