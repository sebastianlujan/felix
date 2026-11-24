# Proof bundle of the Pedersen commitment circuit

A proof of a circuit of this repository,
[`../../examples/pedersen_commit/`](../../examples/pedersen_commit/): raw `bb` 6.0.0 output, as
`bb` wrote it. The circuit returns the Pedersen hash of two private inputs. Its key has a
non-zero `qElliptic`, unlike the key of the vault circuit and the three of `../garaga/`.

| | |
|---|---|
| Circuit | `examples/pedersen_commit/`, with its `Prover.toml`: `secret = 42`, `salt = 7` |
| `nargo` | 1.0.0 |
| `bb` | 6.0.0, target `evm`: Keccak transcript, zero knowledge |
| Made | 2026-11-24 |
| `LOG_N` | 15 |
| Public inputs | 1, the commitment `0x090d1d9d27a969472666023a558a40bc04e71be04da345a0b417cfa64637e004`. The key counts 9, with the 8 pairing-point limbs |
| Pairing-point limbs (proof words 0-7) | All zero |
| Proof | 8384 bytes: `(82 + 12 * LOG_N) * 32` |

## Commands

In the directory of the circuit, then the four files were copied here from its `target/`,
unchanged:

```sh
nargo execute
bb write_vk -b target/pedersen_commit.json -o target -t evm
bb prove -b target/pedersen_commit.json -w target/pedersen_commit.gz -k target/vk -o target -t evm
```

Each file is 32-byte big-endian words.

```
346c6bdecbbb34b0ef63364208b3157afb3594276240621c536cc421267b7ff9  proof
138321e8f3bb7bfdae2aeaada4ef712acea68b96b8bc77cb65c011af4e0666f6  public_inputs
9456295221ec8e1f6304371d791ab9c3a5071b4f397ceb7ddea206e14848729d  vk
6e3e6528865f47a9790125b89f06e44c1186a5e3b44daf8f5a9dbeb3454d59ea  vk_hash
```

**`proof` is pinned.** ZK proving is randomized ("Test vector" in
[`../../README.md`](../../README.md#test-vector)): `bb prove` run again on the same inputs writes
a different valid proof. The Fe constants below belong to this one.

## Checked with `bb`

On 2026-11-24, with the `bb` 6.0.0 of this project (`.tools/bb/bb`):

```sh
bb verify -k vk -p proof -i public_inputs -t evm
```

It prints `Proof verified successfully`.

## Selectors

`qMemory`, `qNnf`, `qPoseidon2External` and `qPoseidon2Internal` commit to `(0, 0)` in `vk`: the
circuit does not use them. Every other point of the key is non-zero, among them `qElliptic`,
`qLookup` and `qDeltaRange`.

## In the Fe library

`scripts/proof_to_fe.sh --bundle pedersen_commit` prints the proof and its public input as the Fe
constants of `lib/src/pedersen_commit_proof.fe`, and `--bundle-key pedersen_commit` prints the key
as the first part of `lib/src/pedersen_commit.fe`. `scripts/proof_to_fe.sh --check` fails if a
committed file differs from what they print. The two modes are `--garaga` and `--garaga-key`
reading another directory, with the same guards: `LOG_N` from 1 to 25, at least 8 public inputs,
a key of 59 words with the public-input offset 5, and a proof and public inputs of the lengths
the key gives. No test reads the two modules yet.
