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

Each file is 32-byte big-endian words, as `bb` writes them. The sha256 of each equals the one
`noir_artifacts.json` records for it.

| File here | File there | sha256 |
|---|---|---|
| `hello/proof` | `proof_ultra_keccak_zk.bin` | `0337b1b9eb1aa3ad453cabdb7dd356a9625ff79e43a69eb8024991f057bb9e3f` |
| `hello/public_inputs` | `public_inputs_ultra_keccak.bin` | `9267d3dbed802941483f1afa2a6bc68de5f653128aca9bf1461c5d0a3ad36ed2` |
| `hello/vk` | `vk_ultra_keccak.bin` | `d46d8978b63f8a74457e7f211b44b4450ad9a7a6c53b2b5f70e851a4a6c1817f` |
| `hello/vk_hash` | `vk_hash_ultra_keccak.bin` | `aa77f65715081b4e5a29304d21c9c29aa398aaa58d78c8fde6153985395dca76` |

## Checked with `bb`

On 2026-11-23, with the `bb` 6.0.0 of this project (`.tools/bb/bb`), for each bundle:

```sh
bb verify -k <bundle>/vk -p <bundle>/proof -i <bundle>/public_inputs -t evm
```

| Bundle | Result |
|---|---|
| `hello` | `Proof verified successfully` |

## In the Fe tests

`scripts/proof_to_fe.sh --garaga <bundle>` prints the proof and its public inputs as the Fe
constants of `lib/src/garaga_<bundle>_proof.fe`, and `scripts/proof_to_fe.sh --check` fails if a
committed file differs from what it prints.
