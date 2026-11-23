# UltraHonk verification in Fe: gaps before shipping and before real use

> **Status (2026-11-23).** The verifier, the vault and the toy are complete and their 275 Fe tests pass. This document lists what is still missing: to submit the contest entry, and for the code to be relied on outside its tests. Nothing listed here is fixed yet. Feature freeze: 2026-11-24 14:00 UTC. Submission: 2026-11-24 23:59 UTC.

> **How to read this document.** It does not repeat the limits already written down: [Limits](../ultrahonk/README.md#limits) in the verifier README, [Not done](ultrahonk.md#not-done) and [Out of scope](ultrahonk.md#out-of-scope) in the plan, [Not implemented](../ultrahonk/vault/README.md#not-implemented) in the vault README. It adds what those sections do not say, and orders the work.

## Quick path

| Band | What | Items | Estimate |
|---|---|---|---|
| 1 | Must be done before submitting | M1 to M10 | about 6 h |
| 2 | Should be done before the freeze | H1 to H3, E1, H4 to H6 | about 10 h |
| 3 | Known limits, each with its smallest fix | [Known limits in real use](#known-limits-in-real-use) | after the contest |

Evidence is marked **V** (verified in the code or the data) or **I** (inferred by reading, not run). Every gas figure says whether it was measured or estimated.

No discordance was found in the test vectors themselves: every Fe constant equals the raw `bb` bytes, the local reference oracle, or an independent recomputation. The discordances are in what the documents say about them: see [Documentation corrections](#documentation-corrections).

## Contest checklist

The rules as read on the contest page on 2026-11-23. Read them again before quoting them.

- [ ] A public GitHub repository with an OSI-approved licence. Today: no `LICENSE` file; the visibility of the repository was not checked.
- [ ] The full commit SHA, the project manifest and the exact Fe version. Today: Fe 26.6.0 is documented; nothing is pushed, `main` holds none of the work, there is no tag.
- [ ] Reproducible build instructions and automated tests. Today: in `ultrahonk/README.md`, as five commands; no single command.
- [ ] A README covering the approach, the architecture and the limitations. Today: only `ultrahonk/README.md`; the root `README.md` describes a placeholder library with one function.
- [ ] A short pitch, a Fe-specific highlight, and a demo or reproducible example. Today: no pitch and no highlight; the tests are the example.
- [ ] A declaration of pre-existing work, reused code and AI assistance. Today: a reuse table in the plan ([Reuse and licences](ultrahonk.md#reuse-and-licences)); no declaration.

## Decisions for the owner

| Decision | Recommendation |
|---|---|
| Licence | Apache-2.0. It is OSI-approved and it is the licence of the Fe test helper that `ultrahonk/lib/src/std_assumptions.fe` follows |
| The three uncommitted edits at the root (`README.md`, `fe.toml`, `src/lib.fe`) | Commit or drop them before the release. The README edit is superseded by M9 |
| Rewrite the root `README.md` as the entry page | Yes. It reverses "do not modify the root README": the contest reads the README |
| Use the consistency check with fewer inversions (H3) | Yes. It reverses "Gas optimisation" in [Out of scope](ultrahonk.md#out-of-scope) |
| Push `develop`, release to `main`, make the repository public | Yes, each step on the owner's word |

## Band 1: before submitting

| ID | Gap | Evidence | Action | Effort |
|---|---|---|---|---|
| M1 | The work exists on one disk | V: `develop` is 90 commits ahead of its remote | Push `develop` | under 30 min |
| M2 | Three uncommitted edits at the root | V: `git status` | The owner commits or drops them | under 30 min |
| M3 | No licence | V | Add `LICENSE` | under 30 min |
| M4 | The root `.gitignore` is not tracked. Its `.*` rule ignores the file itself and would hide a `.github/` directory | V | Replace `.*` with explicit entries and track the file | under 30 min |
| M5 | No single command builds and tests everything | V: `scripts/check.sh` is listed under Not done | `ultrahonk/scripts/check.sh`: `fe test` and `fe fmt --check` in the five ingots, `fe build --contract` for the three contracts, each runtime against 24,576 bytes, `proof_to_fe.sh --check`, `gen_vectors.py --check` | under 2 h |
| M6 | The documents state things the data does not support | V: [Documentation corrections](#documentation-corrections) | One pass over them. Where a test is cheaper than rewording, add the test | under 2 h |
| M7 | The vault protects nothing. The circuit proves `x * x == y` for a public `y`, and square roots modulo a prime are computed efficiently, so anyone can prove for their own address. The plan gives "the vault hides a secret" as the reason for the ZK flavor (`docs/ultrahonk.md:76`, `:83`, `:363`) | V: `ultrahonk/circuit/src/main.nr` | Say it plainly in the plan, the vault README and ADR-0010: the vault shows how a Fe contract consumes a proof. The ZK flavor is ported because private applications need it, not because this circuit does | under 30 min |
| M8 | The chain requirements are not stated | V: the Fe backend targets Osaka; the `-O s` runtime uses `MCOPY` (Cancun); precompiles 0x05 to 0x08 are called. The test harness lifts the code-size, init-code and gas limits | Three lines in `ultrahonk/README.md`: minimum fork, precompiles, and that the sizes fit the real limits (runtime 16,446 bytes at `-O 1` against 24,576) | under 30 min |
| M9 | The root README does not mention the entry | V | Entry page: pitch, what the repository contains, quick path (`check.sh`), architecture in a paragraph, the Fe-specific highlight, limits, and the declarations (pre-existing work, reused code, AI assistance, the teaching page) | under 2 h |
| M10 | Nothing is released | V | `develop` into `main`, a tag, the repository public, `check.sh` in a fresh clone, the full SHA recorded for the form | under 2 h |

## Band 2: before the freeze

Code first, then one measurement of sizes and gas, then the documentation of band 1, so that each table is edited once. If time runs out, cut from the bottom: H6, then H5, then the larger fixtures of E1.

| ID | Gap | Evidence | Action | Effort and risk |
|---|---|---|---|---|
| H1 | `fr::inv` trusts what the `modexp` precompile returns. On a chain with no code at 0x05 an inversion returns 0. Read through the code, the all-zero proof is then accepted, provided the pairing precompile exists. The reference has the same hole | I, not run: `ultrahonk/lib/src/fr.fe:32-40`; Fe 26.6.0 `ingots/std/src/evm/crypto.fe:103-124` checks only the success flag | Revert with `ModExpFailed` unless `mul(a, value) == 1`. About 30 gas per inversion (estimated). The port becomes stricter than the reference: record it as a difference | under 30 min; none |
| H2 | The relations address, and the vault's `y` and verifier address, are mutable storage. There is no getter, so a deployed verifier cannot be checked against the relations contract it calls | V: `ultrahonk/verifier/src/lib.fe:43`, `ultrahonk/vault/src/lib.fe:47-48` | Drop `mut` (fields are immutable without it since Fe 26.2.0). Put the getter in a message of its own, so that `VerifierMsg` stays the ABI of the Solidity verifier | under 30 min; sizes and gas move |
| H3 | About 321 `modexp` calls per `verify`, 257 of them in the consistency check. A tested variant needs 48 | V: `ultrahonk/lib/src/consistency.fe:74`, `:117-132`, equivalence tests at `:282-314` | `check` calls `evaluate_sparse`. It is safe: the subgroup check runs first (`:49-52`), so no skipped inversion could have reverted. Estimated saving: 0.85M gas | under 30 min of code, under 2 h of documentation |
| E1 | One circuit, one size and no recursive proof: the largest hole in the evidence. Garaga commits four sets of proof, key and public inputs made with `bb` 6.0.0 at the `v6.0.0` commit, flavor `ultra_keccak_zk`, target `evm`: `LOG_N` 12 (two circuits, 1 public input), 17 (3 public inputs) and 20 (a recursive circuit). It also pins the expected challenges of the first | V, by fetching: [Independent vectors](#independent-vectors-from-public-repositories) | Confirm each set with the local `bb verify`. Then a library test that runs every step with the key passed as an argument: the challenges of `hello` equal Garaga's, each proof is accepted, each low-bit flip is rejected. Order: `hello`, `mutator_set`, `recursive`. A set that fails is a finding and is disclosed | half a day; touches no captured value; test counts change |
| H4 | The contracts have never run outside the test harness, and no test runs the built `out/*.bin`. The tests compile at `-O 1` | V | `ultrahonk/scripts/demo_anvil.sh`, in shell with `anvil --hardfork osaka` and `cast`: build, deploy the three contracts, call `verify` with the pinned proof and with a tampered one, and claim as `0xc0ffe` with the first pinned proof. It gives the gas of a real transaction | under 2 h; none |
| H5 | Nothing shows that the two-proof `scripts/vectors.sh` ran from start to end: `vectors/vk` is older than the script that deletes it first | V: file dates | Run it in a throwaway clone, or say in the documents that the second proof was made with the same commands run by hand | under 30 min |
| H6 | The deployed verifier takes its key from the file of test vectors. `scripts/proof_to_fe.sh` needs a proof to print a key, and ignores the third word of the key's header | V: `ultrahonk/verifier/src/lib.fe:20`, `ultrahonk/lib/src/vectors.fe:244`, `ultrahonk/lib/src/sumcheck.fe:22` | A generated `vk.fe`, re-exported from `vectors.fe`; a `--vk` mode; a guard that the third header word is 5. Dropped if not started by 2026-11-24 08:00 UTC | under 2 h; low |

## Test track: a unit test per gap, written first

The rule: the test is written before the fix and run red where the gap is real. A red test that is not fixed is a finding, and is recorded in this document. The expected value of a test never comes from the code under test: it is an external vector, a value captured from the reference, or a direct computation in the test.

| Gap | Function | Test | Expected today |
|---|---|---|---|
| H1 | `fr::inv` | `inv(P)` reverts with `ModExpFailed`; `mul(a, inv(a)) == 1` for 1, 2, `P - 1` and external operands | Red: `inv(P)` returns 0 |
| H3 | `consistency::evaluate_sparse` | Equal to `evaluate` on synthetic proofs for `LOG_N` 1, 5 and 25: both must agree whatever the proof. A committed upper bound on the gas of `verify` | Unknown outside `LOG_N = 5` |
| M6 | `opening_vectors` | Assert `NUMERATOR`, `DENOMINATOR_0` and `DENOMINATOR_255` | Green expected: recomputed by hand |
| M6 | `Vault::claim` | A verifier that answers the word 2, and one that answers 64 bytes: the claim reverts without data | Unknown: only the address without code is tested |
| H2 | `HonkVerifier` | The getter returns the constructor argument | New |
| E1 | `transcript`, `sumcheck`, `relations`, `shplemini`, `consistency`, `opening` | Garaga's sets: pinned challenges, acceptance, bit flips, at `LOG_N` 12, 17 and 20 | Unknown: this is the test that can find a real error |
| Soundness | Barycentric evaluation in `sumcheck` | A known polynomial of degree 8 at 10, against its direct evaluation. A challenge inside the domain 0..8: record what happens and compare with the reference | Unknown: no test has a challenge in 0..8 |
| Soundness | `transcript` | A second public input at `P` reverts with `ValueGeFieldOrder`; `P - 1` passes the range check | Unknown |
| Soundness | `shplemini` | The zero denominators other than `z == r`: `z == -r`, the fold points, `r == 0` | Unknown |
| Soundness | `sumcheck::public_input_delta` | A zero denominator | Unknown |
| Soundness | `proof::validate`, `opening` | One commitment set to (0, 0): accepted by the decoding as in the reference, rejected by the opening | Unknown |
| Environment | `std_assumptions` | External precompile vectors for point addition, scalar multiplication, pairing and `modexp`, with failing cases | Green expected |
| Field | `fr` | `mul`, `add` and the square on Barretenberg's fixed operands | Green expected |
| Constants | `fr`, `consistency` | `P` and `Q` against arkworks; the subgroup generator equals `5^((P - 1) / 256)`, with `g^256 == 1` and `g^128 != 1` | Green expected |
| H6 | `scripts/proof_to_fe.sh` | `--check` fails on a key whose third header word is not 5 | Red: the word is ignored |

### Independent vectors from public repositories

All were fetched and read on 2026-11-23. Pin the commit when transcribing. Every transcribed file states its source, its commit and its licence. A vector made by another `bb` version or flavor is used only for functions that do not depend on the proof layout.

| Source | Licence | What to take | Tests | Caveat |
|---|---|---|---|---|
| `keep-starknet-strange/garaga` at `86b6025`: `hydra/garaga/starknet/honk_contract_generator/examples/` (`hello`, `memory`, `mutator_set`, `recursive`) and `src/src/apps/noir/test_fixtures.cairo` | MIT | The four sets, and the challenges of `hello` | The whole verifier on other circuits and sizes (E1) | The sets are on `main`, not in a release. The contract is built for one key, so the test goes through the library |
| `AztecProtocol/aztec-packages` at `v6.0.0`: `barretenberg/cpp/src/barretenberg/ecc/curves/bn254/fr.test.cpp` | Apache-2.0 | Fixed operands and results | `fr::mul`, `fr::add`, the square | 64-bit limbs, least significant first, in Montgomery form: a committed script multiplies by `R^-1 mod P` and says so |
| Same tag: `polynomials/barycentric.test.cpp`, `relations/relation_manual.test.cpp` | Apache-2.0 | Small-integer barycentric cases; Poseidon2 relation cases | The evaluation in `sumcheck`; two relations | Small values only |
| Same tag: `barretenberg/sol/test/honk/negative/NegativeTestBaseZK.sol` | Apache-2.0 | The list of mutations, not the code: aliased values (`Q + 1`), overflowing pairing limbs, corrupted masking and Libra values | A loop of proofs that must be rejected, on the pinned proof | No expected selector without the local oracle |
| `ethereum/execution-specs`: `tests/byzantium/eip196_ec_add_mul`, `eip197_ec_pairing` | CC0 | The failing cases: points off the curve, coordinates not below the modulus | `std_assumptions` | The values come from Python generators |
| `ethereum/go-ethereum`: `core/vm/testdata/precompiles/*.json`; the examples of EIP-198 | LGPL-3.0: cite the cases, do not copy the files | A few cases: (1, 2) + (1, 2), a point times 0, the two-pair pairing that returns 1, `3^(p - 1) mod p` | `std_assumptions` | No failing bn256 case |
| `arkworks-rs/algebra` at `v0.6.0`: `curves/bn254` | MIT or Apache-2.0 | The two moduli and the generator 5 of the scalar field | Constants | Constants only: no fixed vectors |
| `zkVerify/ultrahonk_verifier` at `689f627`: `tests/data/zk` | MIT or Apache-2.0 | A `bb` 5.0.0 proof of the same length | Later: a proof that must be rejected, for version drift | The wrong version on purpose |

Not found: fixed vectors for Gemini, Shplonk or the small-subgroup check on their own. Barretenberg's own repository and the Noir examples pin no proof: they generate proofs when the tests run.

## Known limits in real use

Each limit names its smallest fix. None blocks the submission once band 1 is done.

### Chain and deployment

| Limit | Consequence | Smallest fix |
|---|---|---|
| Never deployed outside the test harness | What would be deployed has run on no other EVM | H4 |
| One verifier per circuit, with no generator | Verifying another circuit means editing the key constants by hand; the test suite then fails, because its captured values belong to the pinned proof | H6, then a generator |
| A real `verify` transaction costs about 2.2M gas (estimated): 21,000 intrinsic, about 65,000 of calldata and about 4,500 of cold access, on top of the measured 2,108,994. The figures are priced at Osaka | The READMEs give the cost of the call, not of the transaction | H4 measures it; H3 lowers it |
| Under low gas a valid proof reverts with the error of an invalid one | It fails closed, but the error misleads | Document it |
| The key appears twice in the `-O s` runtime, about 1.8 KB | Size only | Later |

### Soundness evidence

| Limit | Consequence | Smallest fix |
|---|---|---|
| One circuit, one size (`LOG_N = 5`), no recursive proof verified from start to end | Other sizes and the aggregation rest on the formulas being right | E1 |
| No fuzzing, no differential testing against the reference over many proofs | Rejection is shown for recorded cases and bit flips only | A seeded loop of tampered proofs against `bb verify` |
| The failed `modexp` call has no test. The carried point off the curve does (`ultrahonk/lib/src/opening.fe:668-674`) | One recorded difference from the reference is untested | H1 covers the branch next to it |
| The port is not audited | As stated in [Limits](../ultrahonk/README.md#limits) | An audit |

### The vault as an application

| Limit | Consequence | Smallest fix |
|---|---|---|
| The statement is not secret (M7) | Anyone can claim | A hash preimage in the circuit: a new circuit, a new pinned proof and new captured values |
| No event | A claim cannot be watched for | An event with the winner |
| The public inputs are `[y, caller]`: no vault address, no chain id | The caller's proof is valid at every vault with the same `y`, on every chain | Two more public inputs: a new circuit |
| The winner is the caller | With a relayer, the relayer wins; a contract wallet must prove for its own address | Document it |
| No payout, no checks on the constructor arguments | As stated in [Not implemented](../ultrahonk/vault/README.md#not-implemented) | By decision |

### Toolchain

| Limit | Consequence | Smallest fix |
|---|---|---|
| The versions are pinned in the documents and in the checks of `vectors.sh`, not in a manifest | Nothing stops a build with another `fe` | State the exact version in the root README (M9) |
| `bb` 6.1.0 was released on 2026-11-19 and is untested here. A `bb` 5.0.0 proof has the same length as a 6.0.0 one | A proof of another version must be rejected by the transcript, and no test shows it | The zkVerify proof as a must-reject test |
| The downloads of `bb` and `nargo` are for macOS arm64, without checksums; `vectors.sh` needs `rg` and does not say so | Regenerating the vectors works on one platform | Document `rg`; add checksums |
| The captured values cannot be regenerated from the repository alone | They rest on their documented provenance | By decision (ADR-0009) |
| No CI | Nothing runs the tests on a push | After M4 and M5, a workflow that runs `check.sh` |
| A worktree left by the development holds an untracked `ultrahonk/lib/src/verifier.fe` (144 lines: the whole verifier in one call) | Removing the worktree deletes it | Read it for E1, then keep or delete it on purpose |

## Not to attempt before the deadline

| Not attempted | Why |
|---|---|
| Replacing `x * x == y` by a hash preimage | Every captured value belongs to the pinned proof of this circuit, and the oracle is local: more than half a day, with the suite at risk |
| Running `scripts/vectors.sh` in the working tree | It deletes `vectors/` first, and proving is randomised |
| Proving a second or a recursive circuit of our own; fuzzing | Half a day or more each. Garaga's sets (E1) give other circuits without proving |
| CI | `.github/` is ignored today, and installing `fe` on Linux was not verified |
| Shipping the worktree's `verifier.fe` as public API | It is at most the start of E1's test helper |

## Documentation corrections

| Where | It says | The data says |
|---|---|---|
| `ultrahonk/README.md:80-83`, `docs/ultrahonk.md:238`, `:518` | Every captured value equals the value the Fe code computes | Three constants of `ultrahonk/lib/src/opening_vectors.fe` (`NUMERATOR`, `DENOMINATOR_0`, `DENOMINATOR_255`) are asserted by no test. They are correct; add the test |
| `ultrahonk/docs/zk-verifier-reference.md:158` | The reference costs "about 2.65M to 2.97M" gas | The measured figure is 2,654,961. Nothing records 2.97M |
| `ultrahonk/docs/zk-verifier-reference.md:3` | Line numbers (`L…`) point into the reference | The document has none |
| `docs/ultrahonk.md:323` | The reference reverts without data on a carried point off the curve "according to the comment" | It was captured from the reference (`ultrahonk/lib/src/opening_vectors.fe:364-365`) |
| `ultrahonk/verifier/src/lib.fe:188-189` | The recorded flips pin the reference's selector for 12 words | For 11. The twelfth, word 138, had no revert data |
| `ultrahonk/docs/zk-verifier-reference.md:157` | Index 255 of the Lagrange array is non-zero | Only indices 0 to 9L are. Index 255 enters through a denominator |
| `docs/ultrahonk.md:269`, `docs/adr/0001-port-bb-6-zk-verifier.md:46` | 41 entities as "37 unshifted, 5 shifted"; "42 evaluated entities" | 41 = 36 unshifted + 5 shifted. The 42 evaluations add the masking polynomial |
| `ultrahonk/README.md:105` | 7 overwritten proof words, range checks | 7 cases on 6 words. One passes its range check and fails in sumcheck |
| `ultrahonk/vault/README.md:24` | An answer that is not one ABI `bool` reverts | Only the address without code is tested. Add the test |
| `docs/ultrahonk.md:60`, `:85`, ADR-0001 and ADR-0013 | Barretenberg's verifier is "audited"; ZK is "the flavor Aztec's own L1 verifier uses" | Neither claim has a source in the repository. Give one or remove them |
| `docs/ultrahonk.md:76`, `:83`, `:363` | The vault hides a secret, so it needs ZK | See M7 |
| `docs/ultrahonk.md:584` | The reference's upstream sources are at `aztec-packages` commit `b225653c…` | Garaga's record of the same toolchain names the `v6.0.0` commit as `0219f11d…`. Not checked: confirm that both name the 6.0.0 sources |

## Sequence and budget

1. M1 and the owner's decisions.
2. M3, M4, M5.
3. H1, H2, H3, each with its test first.
4. E1, starting with `hello`.
5. One measurement of sizes and gas.
6. H4.
7. M6, M7, M8, M9.
8. H5, then H6 if there is time.
9. M10.

Band 1 is about 6 hours and band 2 about 10, against about 29 hours to the freeze on 2026-11-23 at 08:30 UTC. After the freeze: documentation and the release only.

## Related documents

- [Plan and outcome](ultrahonk.md): scope, stages, measured results, and the lists this document extends.
- [`ultrahonk/README.md`](../ultrahonk/README.md): status, test coverage, measurements and limits of the verifier.
- [`ultrahonk/vault/README.md`](../ultrahonk/vault/README.md): the vault's rule, tests and what it does not implement.
- [Architecture Decision Records](adr/README.md): ADR-0009 (the local oracle), ADR-0010 (the vault), ADR-0012 (code size).
