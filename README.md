# UltraHonk verification in Fe

**Noir proofs verified natively in [Fe](https://fe-lang.org).** This repository ports the
zero-knowledge UltraHonk verifier that Barretenberg 6.0.0 generates for the EVM (BN254, Keccak
transcript) from Solidity to Fe, and checks the port value by value against Barretenberg's own
verifier. A vault contract consumes a proof through it, and a hand-sized toy verifier shows the
same protocol with numbers small enough to follow.

It is an entry for the Fe Builders Challenge. Nothing here runs on the Aztec network.

## What is here

| Path | What |
|---|---|
| [`ultrahonk/`](ultrahonk/README.md) | The verifier: a library ingot and two contracts, `HonkVerifier` and `HonkRelations`. Also the Noir circuit, the pinned proofs and the scripts |
| [`ultrahonk/vault/`](ultrahonk/vault/README.md) | `Vault`: a Fe contract that asks the verifier about a Noir proof bound to its caller |
| [`honk-toy/`](honk-toy/README.md) | A toy Honk verifier over the field of 17 elements, with a Python reference. A teaching model, not secure |
| [`docs/`](docs/ultrahonk.md) | The plan and its outcome, the [decision records](docs/adr/README.md), and the [gaps](docs/ultrahonk-gaps.md) that remain |
| `src/`, `calculator/` | The scaffold the repository started from. Not part of the entry: see [the end of this page](#the-root-library-and-calculator) |

## Run it

Install `fe` 26.6.0 from its release, which has builds for macOS, Linux and Windows (here macOS
on Apple silicon; `fe_linux_amd64` for Linux on x86-64):

```sh
curl -L -o fe https://github.com/argotorg/fe/releases/download/v26.6.0/fe_mac_arm64
chmod +x fe && ./fe --version   # fe 26.6.0 (5b3f96a)
```

Then move `fe` to a directory on your `PATH`.

One command builds and tests everything:

```sh
ultrahonk/scripts/check.sh
```

It needs `fe` 26.6.0 (`fe 26.6.0 (5b3f96a)`); its checks of the vectors and of the generated
verifier also need `xxd`, `shasum` and `python3`. It runs the tests and the formatter in the five
ingots, builds the three contracts at three optimisation levels, fails if a runtime exceeds the
code-size limit, generates and builds a verifier for another key, and compares the committed
vectors with their generators. It takes under a minute and writes nothing into the repository.

To see the built contracts run on a local node, with [Foundry](https://getfoundry.sh) installed:

```sh
ultrahonk/scripts/demo_anvil.sh
```

It deploys the three artifacts on `anvil`, verifies the pinned proof, shows the same proof
rejected with one bit flipped, and claims through the vault.

For a proof of your own Noir circuit, follow
[Verify your own circuit](ultrahonk/README.md#verify-your-own-circuit): the commands from
`nargo execute` to a deployed verifier, which `demo_anvil.sh --key <directory>` runs on the local
node.

## How it is checked

Barretenberg's generated Solidity verifier is the reference. It is not committed: it is
regenerated locally by `ultrahonk/scripts/vectors.sh`, and the values captured from it are
committed as Fe constants with their provenance.

- **Value by value.** For the pinned proof, the Fe code reproduces every transcript challenge,
  every sumcheck round target, the value of the relations, every opening scalar and the two
  pairing points the reference computes.
- **Revert by revert.** For a recorded list of invalid calls, the Fe contract reverts with the
  error the reference gave.
- **Tampering.** A proof with the low bit of any one of its 142 words flipped is never accepted.
- **Fresh proofs.** Ten newly generated proofs, which no test had seen, were accepted on a local
  node. This was run by hand.
- **Other circuits.** Garaga's three `bb` 6.0.0 proofs (`LOG_N` 12, 17 and 20, one with pairing
  points) and `pedersen_commit` (`LOG_N` 15), made here and the only one whose key uses the
  elliptic-curve relation, are accepted by the library tests; `recursive` and `pedersen_commit`
  also through the two contracts in a test, and all four as transactions on a local node.

What the tests do not show is stated in [Limits](#limits).

## Architecture

The verifier follows the reference step by step: proof validation, the Fiat-Shamir transcript,
sumcheck with the relations, then the opening (Shplemini, the consistency check of the ZK flavor,
a multi-scalar multiplication and one pairing).

- `ultrahonk/lib` is a library ingot with one module per step. It has no state. Its
  `verifier::verify_at(vk, proof, public_inputs, relations)` is the algorithm, the Fe
  counterpart of bb's `BaseZKHonkVerifier`.
- `HonkVerifier` is a shell over the key of its circuit, as bb's generated `HonkVerifier` is.
  `ultrahonk/scripts/proof_to_fe.sh --verifier` writes the same shell for another key.
- `HonkVerifier` and `HonkRelations` are two contracts. The relations take no key, so one
  `HonkRelations` serves the verifier of every circuit. One contract with everything would fit,
  by 131 bytes at `-O s` (ADR-0012). The verifier asks the relations contract with a static call.
- `Vault` knows only the ABI `verify(bytes,bytes32[])`. It builds the public inputs itself, as
  `[y, caller]`, so a proof copied from a pending transaction is useless to another caller.

The decisions and their trade-offs are in [`docs/adr/`](docs/adr/README.md).

## What Fe brings

- **The Solidity ABI as a type.** `VerifierMsg` declares `verify(bytes,bytes32[])` once, with
  its Solidity selector. The verifier receives it and the vault sends it in a typed static call,
  so the Fe verifier is a drop-in for the Solidity one.
- **Errors that match.** The custom errors are Fe structs with the selectors of the Solidity
  verifier's, and a test asserts each selector.
- **No storage in the verifier.** The address of the relations contract is an immutable field,
  kept in the code. The contract reads and writes no storage.
- **Precompiles as `Result`.** The BN254 and `modexp` calls return a `Result` the code must
  match on. The port checks the answer of `modexp` where the reference trusts it.
- **Tests beside the code.** Every module carries its tests, and `fe test` runs them on an EVM,
  contracts included: a test can deploy a contract, call it, and assert the revert selector.

## Measured

With `fe` 26.6.0 at `-O 1`, on the pinned proof. Methods and the other levels are in
[`ultrahonk/README.md`](ultrahonk/README.md).

| | Fe port | Barretenberg's Solidity verifier |
|---|---|---|
| Runtime size | `HonkVerifier` 16,710 bytes, `HonkRelations` 8,527 | 16,946 bytes, plus two linked libraries of 8,211 and 6,008 |
| Gas of `verify`, the call alone | 1,153,013 | 2,654,961 |
| Gas of a `verify` transaction on a local node | 1,240,270 on Osaka, 937,982 on Cancun and Prague | not measured |

The two gas figures of the call come from different harnesses (a Fe test and a `forge` gas
report). Most of the difference is one change: the consistency check inverts the 47 denominators
it uses, where the reference inverts all 256.

## Limits

- The port is **not audited**.
- The tests do not show that every proof the reference rejects is rejected.
- Each deployed verifier serves one circuit, as bb's does: its key is a constant, and
  `proof_to_fe.sh --verifier` makes one for another key.
- Only `bb` 6.0.0 and its ZK flavor (`-t evm`) are ported. `bb` 6.1.0 is out and untested here.
  Aztec's own L1 rollup verifier is the non-ZK flavor, so this port does not replace it.
- The contracts need **Cancun or later** and the precompiles at 0x05 to 0x08. They ran on a
  local node, not on a public test network.
- **The vault protects nothing.** Its circuit proves `x * x == y` for a public `y`, which anyone
  can solve. It shows how a contract consumes a proof.
- The toy is a teaching model.

The full lists are in [`ultrahonk/README.md`](ultrahonk/README.md#limits) and
[`docs/ultrahonk-gaps.md`](docs/ultrahonk-gaps.md).

## Declarations

- **Pre-existing work.** None in this repository: its first commit is from 2026-11-22. The
  owner's teaching page, "UltraHonk by hand", sketched the vault and holds the math the toy's
  Python reference ports.
- **Reused code.** No code is copied. The Fe verifier is a port of the Solidity verifier that
  Barretenberg generates (Apache-2.0), which stays out of the repository. One test file follows
  a helper pattern from the Fe repository (Apache-2.0). Every source is listed in
  [Reuse and licences](docs/ultrahonk.md#reuse-and-licences).
- **AI assistance.** The Fe code, the tests, the scripts and the documents were written with an
  AI coding assistant, Claude Code, under the owner's direction. The owner set the scope and
  made the decisions recorded in `docs/adr/`.
- **Toolchain.** `fe` 26.6.0 (5b3f96a) for everything. `bb` 6.0.0 and `nargo` 1.0.0 only to
  regenerate the vectors. The manifests are the `fe.toml` of each ingot: `ultrahonk/lib`,
  `ultrahonk/relations`, `ultrahonk/verifier`, `ultrahonk/vault` and `honk-toy`.
- **Licence.** [MIT](LICENSE).

## The root library and `calculator/`

The repository started as a one-function library ingot, `no_name_yet_but_zk_fe` (`src/lib.fe`,
`fe.toml`), with `calculator/` as an example contract that imports it. They are the pattern the
entry's ingots follow and are otherwise unrelated to it.

```sh
fe test                    # the root library: one test
(cd calculator && fe test) # the example contract
```

`fe build` at the root fails with "No contracts found to build": a library produces no bytecode.
