# Vault

`Vault` records the first caller that proves knowledge of a square root of `y`: an `x` with
`x * x == y`, shown with a proof of the circuit in `../circuit/`. It asks a verifier contract
through the standard ABI `verify(bytes,bytes32[])`.

**The vault protects nothing.** It shows how a Fe contract consumes a Noir proof. Anyone can
compute a square root of the public `y` and prove for their own address, so the first claim wins
a race, not a puzzle. See [Not implemented](#not-implemented).

**A claim succeeds with the real verifier.** A test claims through the vault in front of
`HonkVerifier` with a second pinned proof, made for the address of the Fe test contract
(`../lib/src/test_address_vectors.fe`); the first pinned proof, made for the recipient `0xc0ffe`,
cannot be claimed from a Fe test. The other tests use stand-in verifiers. **There is no
payout:** the contract holds and moves no funds, it only records that a claim was made and by whom.

## The rule

The vault is deployed with `y` and the address of the verifier, both immutable fields (kept in
the contract's code, not in storage); `y()` and `verifier()` return them. `claim(bytes proof)`
builds the public inputs itself, `[y, caller]`, and asks the verifier with a static call.

| Situation | `claim` | Recorded |
|---|---|---|
| The verifier returns `true` | returns `true` | `claimed = true`, `winner = caller` |
| The verifier returns `false` | returns `false` | nothing |
| The vault was claimed before | returns `false`, without asking the verifier | nothing changes |
| The verifier reverts | reverts with the verifier's revert data, unchanged | nothing |
| The verifier address holds no code, or the first word of the answer is neither 0 nor 1 | reverts without data | nothing |
| The answer is longer than one word | only its first word is read | as for that word |
| The verifier writes storage while it answers | reverts without data | nothing |

`claimed()` and `winner()` read the record; `winner()` is the zero address before the claim.

Three decisions:

- **The caller is a public input.** The circuit binds a proof to a `recipient`. The vault puts
  the caller's address there, as one 32-byte word, so a proof copied from a pending transaction
  is useless to anyone else: for another caller the verifier is asked about other public inputs.
- **A static call.** `verify` is a view function, and the vault writes its storage after the
  answer. In a static call the verifier cannot change any state, nor call back into a vault
  that could.
- **The typed message, not hand-written calldata.** When the choice was made,
  `VerifierMsg::Verify` from the library gave 655 bytes of runtime and 25,496 gas for a claim;
  the same calldata written with `Packed` gave 931 bytes and 27,310 gas (`-O 1`, before `y` and
  the verifier address became immutable). The verifier does the opposite for its call to
  `HonkRelations`, where the typed message was the larger one.

## Not implemented

| Missing | Why |
|---|---|
| Payout | Out of scope by decision |
| Checks on the constructor arguments | A vault deployed with a wrong verifier address, or a `y` the verifier rejects, can never be claimed |
| A statement only the claimant can prove | The circuit proves `x * x == y` for a public `y`, and square roots modulo a prime are computed efficiently. A hash preimage would need a new circuit, a new pinned proof and new captured values |
| The vault address and the chain id among the public inputs | The public inputs are `[y, caller]`, so a caller's proof is valid at every vault with the same `y`, on every chain |
| An event | A claim can only be seen by reading `claimed()` and `winner()` |

## Tests

```sh
cd ultrahonk/vault
fe test
```

Fifteen tests. The contracts they deploy are declared in the test section of `src/lib.fe`:

| Contract | What it does |
|---|---|
| `Claimer` | Forwards `claim` to a vault, which sees it as the caller. Two of them are two callers |
| `CheckingVerifier` | Returns `true` only for one marker proof and the public inputs `[y, caller]` it was deployed with |
| `RevertingVerifier` | Reverts with the library's `SumcheckFailed` |
| `CountingVerifier` | Writes its storage, then returns `true` |
| `EchoVerifier` | Reverts with the calldata it received, so a test reads what the vault sent |
| `WordVerifier` | Answers `verify` with the word it was deployed with, in place of a `bool` |
| `TwoWordVerifier` | Answers `verify` with 64 bytes: the word 1 twice |

| Test | Asserts |
|---|---|
| `test_the_expected_caller_claims_with_the_right_proof` | The claim returns `true` and is recorded with its winner |
| `test_a_second_claim_returns_false_and_changes_nothing` | Replay, by the winner and by another caller |
| `test_another_caller_cannot_claim_with_the_same_proof` | A copied proof fails, and the right caller can still claim |
| `test_a_wrong_proof_is_not_accepted` | A changed, a shortened and an empty proof |
| `test_a_revert_of_the_verifier_reaches_the_caller_unchanged` | The revert data is the selector of `SumcheckFailed` |
| `test_a_verifier_address_without_code_makes_the_claim_revert` | No data, nothing recorded |
| `test_a_verifier_that_answers_a_word_other_than_a_bool_makes_the_claim_revert` | The word 2 reverts the claim without data; the word 1 is an answer of `true` |
| `test_a_verifier_answer_longer_than_a_word_is_read_by_its_first_word` | 64 bytes that begin with the word 1 make the claim |
| `test_a_verifier_that_writes_storage_makes_the_claim_revert` | The call to the verifier is static |
| `test_the_verifier_is_sent_the_proof_then_y_and_the_caller` | The calldata word by word, equal to the standard encoding |
| `test_y_and_verifier_return_the_constructor_arguments` | Two vaults deployed with different arguments: each getter returns its own |
| `test_the_selectors_of_y_and_verifier` | `0xa56dfe4a` for `y()` and `0x2b7ac3f3` for `verifier()`, as `cast sig` gives them |
| `test_a_test_claims_from_a_fixed_address` | The address of a test contract, and that the vault sees it as the caller |
| `test_the_real_verifier_accepts_the_proof_but_no_test_caller_can_claim` | `Vault` in front of `HonkVerifier` and `HonkRelations`, with the pinned proof |
| `test_the_real_verifier_accepts_a_claim_from_the_address_the_proof_was_made_for` | The same contracts with the second pinned proof: the claim is recorded, then replay is refused |

The last two tests put the vault in front of the real verifier. With the pinned proof, the
verifier asked directly with the public inputs the proof was made for, `[9, 0xc0ffe]`, returns
`true`; through the vault the same proof reverts with `SumcheckFailed`, because the caller is not
`0xc0ffe`. The reference verifier answered a changed recipient the same way. With the second
proof, made for `[9, 0xbd770416a3345f91e4b34576cb804a576fa48eb1]`, the test claims itself:
`claim` returns `true`, `claimed()` is `true` and `winner()` is the test address. A second
claim, by the test or by a `Claimer`, returns `false` and changes nothing. With the pinned proof
in its place, the same test reverted with `SumcheckFailed`.

The second proof is made for the address of the test contract, not for a `Claimer`:

- A Fe test contract always has the address `0xbd770416a3345f91e4b34576cb804a576fa48eb1` with
  `fe` 26.6.0 (the runner creates it from the zero address with nonce 0), and it is the caller
  of the calls the test makes itself. A test asserts both. A proof made for this address does
  not depend on any code: the test passes at `-O 0`, `-O 1`, `-O 2` and `-O s`.
- A caller contract deployed with `create2` has an address derived from its code. Measured for
  `Claimer` with salt 0: `0xfc3b…7f9b` at `-O 1`, `0x71d6…7955` at `-O 2` and `-O s`,
  `0xe33d…27c9` at `-O 0`, the same on every run. A proof made for it breaks when the contract,
  the compiler or the optimization level changes.

`scripts/vectors.sh` makes the second proof from `circuit/Prover_test_address.toml` with the
same verification key, and `scripts/proof_to_fe.sh --test-address` prints the Fe file.

## Measurements

With `fe` 26.6.0. `fe build --contract Vault` writes the bytecode to `out/`; without
`--contract` the build also writes the seven test contracts.

| | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| Runtime size of `Vault`, bytes | 761 | 761 | 747 |
| Gas of a claim that succeeds, 5-byte proof, `CheckingVerifier` | 25,092 | 25,083 | 25,224 |
| Gas of a claim that succeeds, 4,544-byte proof, a verifier that accepts everything | 29,403 | 29,397 | 29,538 |
| Gas of a claim the verifier answers `false` to (the right proof, from another caller) | 4,966 | 4,957 | 5,098 |
| Gas of a claim on a vault already claimed | 939 | 930 | 952 |
| Gas of a claim that succeeds, second pinned proof, `HonkVerifier` and `HonkRelations` | 1,178,060 | 1,176,547 | 1,192,443 |
| Gas of a second claim with that proof, on the vault it claimed | 2,828 | 2,828 | 2,850 |

The gas is the difference of `evm.gas()` around the call to `claim` in a Fe test, with the proof
built before, so it includes encoding the calldata in the caller. Those tests, and the verifier
that accepts everything, were temporary and are not committed; the last two rows came from a
temporary copy of the real-verifier claim test that measured both calls and reverted with the two
figures. The test deploys the contracts in the transaction that calls them, so the accounts are
warm; a call in a transaction of its own pays the cold surcharges on top, and the transaction's
own cost. Only the `HonkVerifier` row includes a real verification; `HonkVerifier` alone spends
1,152,338 gas (`-O 1`) accepting the pinned proof (`../README.md`).

The table was measured again on 2026-11-23, after `y` and the verifier address became immutable
and the verifier's consistency check stopped inverting the denominators it does not use
(`../README.md`). In every row the caller is the test contract. On the code before those
changes, the build and the same temporary tests give what this table held for five rows: 655,
647 and 651 bytes; 29,638, 29,615 and 29,734; 910, 901 and 901; 2,120,252, 2,117,762 and
2,133,741; 2,798. For the other two they give 25,329, 25,303 and 25,422 (the table held 25,496,
25,483 and 25,602) and 3,008, 2,988 and 3,107 (the table held 3,178, 3,171 and 3,290).

A claim the verifier answers `false` to costs more in this test than before. `claimed` used to
share a storage slot with the verifier address, which the deployment wrote in the same
transaction, so the claim read a warm slot. It now shares a slot with `winner` only, and the
claim's read is the first access. In a transaction of its own the slot is cold either way.

The table was measured once more the same day, after the getters `y()` and `verifier()` were
added. Before them the build gave 671, 671 and 675 bytes, and temporary tests written again to
the method above gave the figures this table held: 22 gas less in every gas row at `-O 1` and
`-O 2`, 44 less at `-O s`.
