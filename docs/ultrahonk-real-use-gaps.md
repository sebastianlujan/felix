# UltraHonk in Fe: gaps before real use, and what the toy lacks to be complete

The verifier is correct for one circuit and proven on four, but it is a build for that one circuit: there is no public entry point, no how-to and no tooling to verify your own, and the two deployed contracts were never measured above `LOG_N = 5`. The toy verifies every step of the page's protocol, but only in Fe's half: the circuit and the prover exist only in Python, there is no transcript, and several steps have no negative test.

**Update, 2026-11-23, after #37 to #47.** The paragraph above is the state found on `3329eca`. Since then the library has `verify_at`, `proof_to_fe.sh --verifier` makes a verifier for any key, Garaga's three circuits (`LOG_N` 12, 17, 20) run as transactions on anvil, the vault answers `y()` and `verifier()`, and the toy has its missing negative tests and states that its prover is Python only. Each row says what remains.

- **Sources:** the owner's goal (2026-11-23): "the UltraHonk useful and functional, the toy just a toy, but a complete one"; [the gaps plan](ultrahonk-gaps.md), whose "Known limits in real use" this report extends rather than repeats.
- **State checked on:** `develop` at `3329eca`, 2026-11-23. Read-only; `fe test` and `check.sh` were not run. The toy's `gen_vectors.py --check` was run and passes.
- **Related docs:** [ultrahonk-gaps.md](ultrahonk-gaps.md) for the contest bands, the test track and the known limits; [ultrahonk/README.md](../ultrahonk/README.md) for sizes and gas.

Rows marked **new** are not in the gaps plan. The others are listed there and are repeated only where their state changed or they block real use.

## Summary

Sizes are mine, in the gaps plan's units.

| Area | Size | State | Next step |
| --- | --- | --- | --- |
| [1. Verify your own circuit](#1-verify-your-own-circuit) | half a day | Partial: the entry point, the generator and the how-to exist (#42, #44, #46) | C-3, a dependency example, and the decision of C-5 |
| [2. Deploy and integrate](#2-deploy-and-integrate) | half a day | Partial: anvil only, measured up to `LOG_N = 20` (#46) | D-2, a deploy script for a real network |
| [3. Soundness evidence](#3-soundness-evidence) | half a day | Partial: four circuits, edge inputs untested | One test per Unknown row of the test track |
| [4. The vault as an example](#4-the-vault-as-an-example) | under 2 h | Partial: no getters, promised notes unwritten | `y()` and `verifier()` messages |
| [5. The repository as a product](#5-the-repository-as-a-product) | under 2 h | Partial: a clone lands on the placeholder | #14, an install line for `fe`, the `vectors.sh` fix |
| [6. The toy, complete](#6-the-toy-complete) | half a day to a day | Partial: verifier complete, prover and circuit Python only | Decide the toy's scope, then the missing negative tests |

## Legend

| State | Meaning |
| --- | --- |
| Done | Built and tested. |
| Partial | Part of the work exists; the rest is listed. |
| To do | Nothing exists. |
| Decide | Scope unclear; needs an owner decision. |
| To verify | Claimed or estimated, not measured. |

| Prefix | Path |
| --- | --- |
| `VER` | `ultrahonk/verifier/src/lib.fe` |
| `LIB` | `ultrahonk/lib/src/` |
| `SCR` | `ultrahonk/scripts/` |
| `VLT` | `ultrahonk/vault/src/lib.fe` |
| `RD` | `ultrahonk/README.md` |
| `TOY` | `honk-toy/` |

## 1. Verify your own circuit

Since #46 the route is written down in `RD`, "Verify your own circuit": `bb write_vk -t evm`, `proof_to_fe.sh --verifier`, build, deploy the relations contract then the verifier.

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| C-1 | **new** A "Verify your own circuit" section: the commands from a Noir project to two deployed contracts | Done (#46) | `RD` "Verify your own circuit": eight steps, from `nargo execute` to `demo_anvil.sh --key`, and how the structure compares with bb and Aztec. Steps 4 to 8 were run by hand on Garaga's `hello`; steps 1 to 3 are the commands of `SCR/vectors.sh` |
| C-2 | **new** A public entry point in the library, `verify_at(vk, proof, inputs, relations)`. Today the deployable `verify` is private to the contract and bound to its constant key | Done (#42) | `verify_at` at `LIB/verifier.fe:44`; `HonkVerifier` calls it with its key (`VER:26`), and the test-only `RecursiveVerifier` with the key of Garaga's `recursive` (`VER:536`). `HonkVerifier` grew by 72, 161 and 158 bytes at the three levels (`RD:128`) |
| C-3 | **new** A dependency example: the `fe.toml` line and the `use` of the library from another ingot. The test helpers are public next to the API | To do | no match for `ultrahonk = \{` in any `*.md`; `LIB/verifier.fe:74-132` |
| C-4 | **new** Generator guards: refuse `LOG_N` above the transcript's maximum, and write the `bb` version into `vk.fe` | Done (#44) | `log_n` and `num_public_inputs` in `SCR/proof_to_fe.sh` require 1 to 25 and at least 8 in every mode; `check.sh` checks that `LOG_N` 0 and 26 are refused. The `bb` version is written into the header of a generated verifier, not into `vk.fe`, which is unchanged |
| C-5 | A suite that does not pin one proof, or one verifier ingot per circuit | Decide | `docs/ultrahonk-gaps.md:136`; after `--vk` the captured values no longer match |
| C-6 | **new** `proof_to_fe.sh --vk DIR` and `demo_anvil.sh --proof --inputs`, so a user can try their own proof without editing scripts | Done (#44, #46), as `proof_to_fe.sh --verifier DIR OUT` and `demo_anvil.sh --key DIR` | `generate_verifier` in `SCR/proof_to_fe.sh`. With `--key`, `SCR/demo_anvil.sh` generates the verifier of the `vk` and `vk_hash` in DIR, deploys it with `HonkRelations`, and verifies the `proof` and `public_inputs` of DIR, then the proof with one bit flipped. The vault is left out, and a run without `--key` is unchanged |

## 2. Deploy and integrate

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| D-1 | **new** Gas and behaviour of the two contracts at `LOG_N` 12 to 20, with pairing points. Garaga's proofs run only through the library with 100M gas. By reading, `modexp` calls grow as about 21 per round: 112 at 5 (measured), about 427 at 20 (estimate) | Done (#46) | `demo_anvil.sh --key` on Garaga's `hello`, `mutator_set` and `recursive` (`LOG_N` 12, 17 and 20; the last with pairing points): each proof is accepted, and rejected with one bit flipped, on Osaka and Prague. At `-O 1` a `verify` transaction uses 2,084,389, 2,695,688 and 3,075,743 gas on Osaka and 1,385,348, 1,713,252 and 1,923,270 on Prague, and deploying a verifier about 3.6M (`RD` "On a local node"). The forks differ by 2,699 gas times 259, 364 and 427, which is 21 `modexp` calls a round, as estimated; inferred from the difference, not counted in a trace. In a Fe test `recursive` uses 2,894,264 gas (`VER:568`) |
| D-2 | A deploy script for a real network (RPC URL, key from the environment), reusing the demo's deployment order | To do | `SCR/demo_anvil.sh` uses an unlocked anvil account |
| D-3 | **new** A way to check which relations contract a deployed verifier calls: print the keccak of both runtimes in `check.sh`, compare with `cast code` | Partial | `verify` rejects an address without code (test at `VER:489`), but nothing checks it is the right contract; no match for `codehash` |
| D-4 | **new** The drop-in claim at its edges: undecodable calldata, an unknown selector, sent value, a Fe panic. No Solidity or JavaScript caller is tested | To verify | selectors and 13 errors match by declaration (`LIB/errors.fe:77-92`); no match for `callvalue\|payable` in `ultrahonk/verifier` |
| D-5 | **new** A troubleshooting table: `SumcheckFailed` also answers a wrong public input; under low gas a valid proof reverts as an invalid one | To do | `LIB/expected.fe:135-136`; low gas appears only at `docs/ultrahonk-gaps.md:138` |
| D-6 | A run on a public test network | To do | `docs/ultrahonk-gaps.md:134` |

## 3. Soundness evidence

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| S-1 | Tests for the Unknown rows: a sumcheck challenge in 0..8, a zero denominator in the public-input delta, a single `(0, 0)` commitment, a second public input at `P` and `P - 1`, `z == -r`, `r == 0` | To do | partly covered: first input at `P` (`LIB/transcript.fe:245-249`), `z == r` (`LIB/shplemini.fe:441-450`), the generator's order (`LIB/consistency.fe:193-203`) |
| S-2 | An accepted proof that exercises the elliptic-curve relation | To do | `qElliptic` is zero in the four circuits (gaps plan, soundness evidence) |
| S-3 | A must-reject test for another `bb` version or flavor | To do | only 6.0.0 files under `ultrahonk/vectors/` |
| S-4 | **new** The Noir circuit's own tests run, and `nargo` is pinned in `Nargo.toml` | To do | `ultrahonk/circuit/src/main.nr:8-21` has three tests; no match for `nargo test` in `SCR/` or `compiler_version` in `Nargo.toml` |
| S-5 | Fuzzing or a differential loop against `bb verify` | To do | gaps plan, soundness evidence |
| S-6 | **new** `README.md:55` says any one of the 142 words "changed by one bit" is rejected. The test flips the low bit of each word only | To do | `VER:198-201` |

## 4. The vault as an example

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| V-1 | **new** `y()` and `verifier()` getters, so a claimant can read the statement and check the verifier the vault trusts | Done (#38) | `VaultMsg::YValue` and `VaultMsg::Verifier` in `VLT`; tests `test_y_and_verifier_return_the_constructor_arguments` and `test_the_selectors_of_y_and_verifier` |
| V-2 | The notes the gaps plan promised: the relayer wins, a contract wallet must prove for its own address, low gas misleads | To do | "Document it" at `docs/ultrahonk-gaps.md:138,157`; no match for `relayer\|contract wallet` in the READMEs |
| V-3 | Replay across vaults and chains, no event, a public statement | To do, documented | `ultrahonk/vault/README.md:54-57`; by decision for the contest |
| V-4 | Front-running and reentrancy | Done | caller bound (`VLT:39-41`, test `VLT:213`); static call (`VLT:36`, test `VLT:405`) |

## 5. The repository as a product

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| P-1 | A clone lands on `main`, which holds only the scaffold; no tag | To do (#14) | `main` at `21d3bbe`; no tags |
| P-2 | **new** `vectors.sh` deletes the 14 committed Garaga files with the rest of `vectors/`; the restore line names two proofs only | To do | `SCR/vectors.sh:27`; `git ls-files ultrahonk/vectors/garaga` gives 14 |
| P-3 | **new** An install line for `fe` 26.6.0. `check.sh` only warns on another version, while the tests assert 26.6.0 facts | To do | no match for `cargo install\|feup\|brew install` in any `*.md`; `SCR/check.sh:16-20` |
| P-4 | **new** The root placeholder (`fe.toml`, `src/lib.fe`) and `calculator/` with its committed build output | Decide | `git ls-files calculator/out` gives 3 files; the root files hold the owner's edits |
| P-5 | CI running `check.sh` | To do | no `.github/`. **new** The gaps plan says `.github/` is ignored (`docs/ultrahonk-gaps.md:178`); since #2 it is not |
| P-6 | Versions in prose only, macOS arm64 downloads, no checksums, `rg` needed | To do | gaps plan, toolchain |

## 6. The toy, complete

The Fe side verifies every step of the page's protocol (permutation, LogUp lookup, public-input delta, sumcheck, Gemini, Shplonk, KZG, the Tate pairing, the sumcheck mask). Everything before the proof is Python.

| # | Task | State | Evidence |
| --- | --- | --- | --- |
| T-1 | **new** The prover is Python only, and the README's Limits do not say so. Either a Fe prover, or one Limits line | Done (#40): stated as a limit | no `fn prove\|commit\|compute_z\|kzg_open` in `TOY/src`; prover at `TOY/reference/honk.py:178,369,400,465`; the limit "Verifier only" at `TOY/README.md:204-207` |
| T-2 | **new** The circuit is visible in Fe only as 15 VK points. A Fe test that commits each column with the SRS and compares with the key | To do | columns and wires at `TOY/reference/honk.py:42-57` only |
| T-3 | A toy transcript (Fiat-Shamir), or the stated limit | Decide | stated at `TOY/README.md:65-66,208`; no match for `transcript\|fiat\|keccak` in `TOY/src` |
| T-4 | **new** Missing negative tests: a wrong challenge on an honest proof, a failure at sumcheck round 1, a tampered Gemini `[A_1]` and `A_1(-r²)`, one per subrelation, and the two documented reverts (`r = 0`, a Gemini fold) | Done (#40), except one per subrelation | `test_an_honest_proof_with_one_changed_challenge_is_rejected` and `test_a_tampered_gemini_fold_is_rejected` in `TOY/src/verifier.fe`; `test_a_failure_at_round_one_stops_sumcheck` in `sumcheck.fe`; `test_reverts_when_r_is_zero` and `test_reverts_when_a_gemini_fold_divides_by_zero` in `shplemini.fe`. No test breaks one subrelation alone |
| T-5 | **new** The masked scenarios' opening traces are generated and never compared | Done (#40) | `run_masked` and `test_masked_scenarios_open_as_the_reference` in `TOY/src/shplemini.fe` |
| T-6 | **new** The Python reference has no test of its own: the expected verdicts are not asserted | To do | no match for `unittest\|pytest\|def test` in `TOY/reference` |
| T-7 | **new** README fixes: a map from page section to module; "every intermediate value" overstates the traces; `honk.py:9` names a file that does not exist (`honk_full_by_hand.py`) | Done (#40), except the map | the traces are described as what the vectors record at `TOY/README.md:78-80,109-113`; `TOY/reference/honk.py:9` names the page. No map from page section to module in `TOY/README.md` |
| T-8 | Full zero-knowledge (evaluation and Gemini masks) | Decide | by design only the sumcheck mask (`TOY/README.md:167-180`) |

## Risks to the estimates

- **Your own circuit.** C-2 moves code between the library and the contract; both runtimes are near the size limit at `-O 1` (16,638 and 8,527 bytes), so a move that grows either needs the size check again. Done in #42: `HonkVerifier` is 16,710 bytes, and `check.sh` passes.
- **Realistic sizes.** D-1 may show the two contracts above a block's gas or a fork's `modexp` price; nothing measured rules it out.
- **The toy prover.** T-1 as a Fe prover is the largest item here (a day or more: commitments, grand product, sumcheck, Gemini and Shplonk provers). As a Limits line it is minutes.
- **Deadline.** Feature freeze is 2026-11-24 14:00 UTC. Areas 1 to 3 change code and captured values; only small parts fit before it.

## Order

1. Cheap fixes with no code risk: P-2, P-5's stale line, S-6, T-7, V-2, and T-1 and T-3 as Limits lines if the toy keeps its scope.
2. Your own circuit: C-2, C-1, C-4, C-6, C-3.
3. Realistic sizes: D-1 with Garaga's `recursive` key, then D-3, D-5, D-2.
4. Soundness: S-1, S-4, S-3, then S-2 and S-5.
5. The vault: V-1.
6. The toy: T-4, T-5, T-6, T-2; then the T-1, T-3 and T-8 decisions.
7. Release (#14), when the owner says so.
