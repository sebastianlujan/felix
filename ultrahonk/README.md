# UltraHonk verifier in Fe

A port of Barretenberg's non-ZK UltraHonk verifier (BN254, Keccak transcript) from Solidity to
[Fe](https://fe-lang.org), checked against the Solidity verifier that `bb` generates for the same
circuit.

**The Fe verifier does not verify proofs yet.** It has the ABI and the proof-length check of the
Solidity verifier and then reverts. What works today is the oracle: a Noir circuit, a real proof,
the Solidity verifier that accepts it, and a test suite both verifiers are run against.

## Status

| Stage | Scope | State |
|---|---|---|
| 0 | Tooling, circuit, vectors, Solidity oracle tests, ingot skeletons | Done |
| 1 | Vault contract calling a verifier through `verify(bytes,bytes32[])` | Pending |
| 2 | Proof decoding and Fiat-Shamir transcript | Pending |
| 3-5 | Sumcheck and the relations | Pending |
| 6 | Shplemini and the pairing check | Pending |
| 7 | Verifier contract accepting proofs, differential tests | Pending |

## Run the tests

Tested with `fe` 26.6.0 and `forge` 1.5.1. Nothing here needs `bb` or `nargo`: the proof is committed.

```sh
cd ultrahonk
(cd lib && fe test)                       # field arithmetic, precompiles, hashing
(cd verifier && fe test && fe build)      # contract skeleton; writes out/HonkVerifier.bin
(cd oracle && forge install foundry-rs/forge-std --no-git)   # once
(cd oracle && forge test)                 # Solidity verifier, then the Fe bytecode
```

`forge test` reads `verifier/out/HonkVerifier.bin`, so run `fe build` first and again after any
change to the Fe sources. Run `forge install` from inside `oracle/`, as shown.

## Layout

| Path | Content |
|---|---|
| `circuit/` | Noir package `vault`: `x * x == y`, with `y` and `recipient` public |
| `vectors/` | `proof`, `public_inputs`, `vk`, `vk_hash`: raw `bb` output |
| `scripts/vectors.sh` | Regenerates `vectors/` and `oracle/src/HonkVerifier.sol` |
| `oracle/` | Foundry project: the generated Solidity verifier (unedited) and the tests |
| `lib/` | Ingot `ultrahonk`: verifier message, errors, scalar field arithmetic |
| `verifier/` | Ingot `ultrahonk_verifier`: contract `HonkVerifier` |

The tests in `oracle/test/` are written once in `NegativeBase` and run against each verifier:
`NegativeSol` deploys the Solidity one, `NegativeFe` the Fe one. A case moves into `NegativeBase`
when the Fe port implements the check behind it.

## Test vector

| | |
|---|---|
| Witness | `x = 3` |
| Public inputs, in order | `y = 9`, `recipient = 0xc0ffe` |
| Circuit size | `N = 32`, `LOG_N = 5` |
| `NUMBER_OF_PUBLIC_INPUTS` | 10: the 2 above plus 8 pairing-point limbs carried in the proof |
| Proof | 3904 bytes: `(67 + 11 * LOG_N) * 32` |
| Pairing-point limbs (proof words 0-7) | All zero, so the verifier skips pairing-point aggregation |

```
cb6e426743c228723bbe7832c7f77cc87f312064e6a38732b5204a88c5a4daea  vectors/proof
ea1bf219985bbd9a6d536d5235273f68d024b81a861440dc6395f301056ce5e3  vectors/public_inputs
2824ffe9888ae66b80cc020982bd2978d759b195865ccd5187fa37c23db721d2  vectors/vk
521899df739b72ff85d2b56347277d19204ebcc952ed9f266e4a44c13de5c906  vectors/vk_hash
642dd97d6306d163195ad61e47b314333648defc49700ba3b6cdc8607d764711  oracle/src/HonkVerifier.sol
```

## Regenerate the vector

Proving was deterministic across repeated runs: the script reproduced the files above byte for byte.

```sh
cd ultrahonk
mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
scripts/vectors.sh
```

The archives are the macOS arm64 builds. The script calls the tools by path and exits unless they
report the versions below; tools installed elsewhere on the machine are not used.

| Tool | Version |
|---|---|
| `bb` | 6.0.0, target `evm-no-zk` |
| `nargo` | 1.0.0 (noirc 1.0.0+275d3ab1a5c916c6ea73e8d6b943f685f574500c) |
| `fe` | 26.6.0 (5b3f96a) |
| `forge` | 1.5.1-stable, solc 0.8.34, `evm_version = "osaka"` |
| forge-std | 1.17.0 |
