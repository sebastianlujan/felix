# Proof bundles from Garaga

Proofs of other circuits than the vault's, made by another project with the same prover: raw
`bb` 6.0.0 output copied from [Garaga](https://github.com/keep-starknet-strange/garaga), so that
the Fe verifier is tested at circuit sizes other than `LOG_N = 5`. Nothing here was produced by
this repository.

| | |
|---|---|
| Repository | `keep-starknet-strange/garaga` |
| Commit | `86b6025567c5e2395947f9c6d40262c9ead2a54c` |
| Directory | `hydra/garaga/starknet/honk_contract_generator/examples/` |
| Licence | MIT, Copyright (c) 2023 Keep StarkNet Strange. [`LICENSE`](LICENSE) is the file at the root of that commit |
| Copied | 2026-11-23, unchanged except for the file names |

The toolchain, as recorded in `noir_artifacts.json` of that directory:

| | |
|---|---|
| `bb_version` | 6.0.0 |
| `bb_source_revision` | `0219f11d8133970df3974fe5ae65e006bf8c193a` |
| `nargo_version` | 1.0.0 |
| `noir_source_revision` | `275d3ab1a5c916c6ea73e8d6b943f685f574500c` |
| `flavor` | `ultra_keccak_zk` |
| `verifier_target` | `evm` |

## Bundles

| Bundle | `LOG_N` | Public inputs | Pairing-point limbs (proof words 0-7) | Proof |
|---|---|---|---|---|
| `hello` | 12 | 1 | All zero | 7232 bytes |
| `mutator_set` | 17 | 3 | All zero | 9152 bytes |
| `recursive` | 20 | 1 | All eight non-zero: the circuit verifies another proof (`std::verify_proof_with_type` in its `main.nr`), so this proof carries pairing points | 10304 bytes |

Garaga's fourth bundle, `memory` (`LOG_N = 12`, 1 public input), is not copied. `bb verify`
accepts it as well; its key has no selector that the three above lack.

Each file is 32-byte big-endian words, as `bb` writes them. The sha256 of each equals the one
`noir_artifacts.json` records for it.

| File here | File there | sha256 |
|---|---|---|
| `hello/proof` | `proof_ultra_keccak_zk.bin` | `0337b1b9eb1aa3ad453cabdb7dd356a9625ff79e43a69eb8024991f057bb9e3f` |
| `hello/public_inputs` | `public_inputs_ultra_keccak.bin` | `9267d3dbed802941483f1afa2a6bc68de5f653128aca9bf1461c5d0a3ad36ed2` |
| `hello/vk` | `vk_ultra_keccak.bin` | `d46d8978b63f8a74457e7f211b44b4450ad9a7a6c53b2b5f70e851a4a6c1817f` |
| `hello/vk_hash` | `vk_hash_ultra_keccak.bin` | `aa77f65715081b4e5a29304d21c9c29aa398aaa58d78c8fde6153985395dca76` |
| `mutator_set/proof` | `mutator_set/proof.bin` | `ce341a3ff5d807f2cb6238d3379d9265aa66775ea1206b290163e7829abc48c3` |
| `mutator_set/public_inputs` | `mutator_set/public_inputs.bin` | `d437be64fd04cc426363354a58720c6e87f00d21cdaaa0a93e3814e893483654` |
| `mutator_set/vk` | `mutator_set/vk.bin` | `07b9940d010c10be31114bac7c460b4c7541e25a4051c00014ba87755ffd37f8` |
| `mutator_set/vk_hash` | `mutator_set/vk_hash.bin` | `5d6799a209806b342564b2d23dd48a20c8a951c528c2ac10c3163f39f3321443` |
| `recursive/proof` | `recursive/proof.bin` | `689230ecb9711bec05576480c3c093c483a84d9a979c3d0962194077bb88db75` |
| `recursive/public_inputs` | `recursive/public_inputs.bin` | `9267d3dbed802941483f1afa2a6bc68de5f653128aca9bf1461c5d0a3ad36ed2` |
| `recursive/vk` | `recursive/vk.bin` | `26349fea23eb7768f407670df67e79f13d719095bcecb3706c563caacb47951d` |
| `recursive/vk_hash` | `recursive/vk_hash.bin` | `6c98377e71d8dd5907c717f99bdcb41d027bfc95941b42bdf30778120cd486ad` |

## Checked with `bb`

On 2026-11-23, with the `bb` 6.0.0 of this project (`.tools/bb/bb`), for each bundle:

```sh
bb verify -k <bundle>/vk -p <bundle>/proof -i <bundle>/public_inputs -t evm
```

| Bundle | Result |
|---|---|
| `hello` | `Proof verified successfully` |
| `mutator_set` | `Proof verified successfully` |
| `recursive` | `Proof verified successfully` |

## In the Fe tests

`scripts/proof_to_fe.sh --garaga <bundle>` prints the proof and its public inputs as the Fe
constants of `lib/src/garaga_<bundle>_proof.fe`, and `--garaga-key <bundle>` prints the key as the
first part of `lib/src/garaga_<bundle>.fe`. `scripts/proof_to_fe.sh --check` fails if a committed
file differs from what they print. `--verifier vectors/garaga/<bundle> <out dir>` writes a verifier
contract for the key of a bundle; `scripts/check.sh` does it for `recursive` and builds it.

The tests are in the second part of `lib/src/garaga_<bundle>.fe`; what they show is listed under
"Other circuits" in [`../../README.md`](../../README.md#other-circuits).

For `hello`, Garaga also pins the challenges it expects: `get_expected_transcript` in
`src/src/apps/noir/test_fixtures.cairo` of the same commit, where its own test compares them with
the transcript of its Cairo verifier. That file holds this proof and this key: its proof literals
are the 226 words of `hello/proof` and the public input, its key points are those of `hello/vk`
in the same order, and its `vk_hash` is `hello/vk_hash` (compared on 2026-11-23). Each challenge
is one Cairo `u256` literal holding the whole value, the Keccak digest reduced modulo the scalar
field, so it is compared as it is with the `u256` this port computes: all 23 are equal.
