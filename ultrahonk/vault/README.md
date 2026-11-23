# Vault

`Vault` records the first caller that proves knowledge of a square root of `y`: an `x` with
`x * x == y`, shown with a proof of the circuit in `../circuit/`. It asks a verifier contract
through the standard ABI `verify(bytes,bytes32[])`.

**No claim can succeed with the real verifier in a Fe test.** `HonkVerifier` accepts the pinned
proof, but it was made for the recipient `0xc0ffe` and the vault passes the caller, so the tests
use stand-in verifiers. **There is no payout:** the contract holds and
moves no funds, it only records that a claim was made and by whom.

## The rule

The vault is deployed with `y` and the address of the verifier. `claim(bytes proof)` builds the
public inputs itself, `[y, caller]`, and asks the verifier with a static call.

| Situation | `claim` | Recorded |
|---|---|---|
| The verifier returns `true` | returns `true` | `claimed = true`, `winner = caller` |
| The verifier returns `false` | returns `false` | nothing |
| The vault was claimed before | returns `false`, without asking the verifier | nothing changes |
| The verifier reverts | reverts with the verifier's revert data, unchanged | nothing |
| The verifier address holds no code, or the answer is not one ABI `bool` | reverts without data | nothing |
| The verifier writes storage while it answers | reverts without data | nothing |

`claimed()` and `winner()` read the record; `winner()` is the zero address before the claim.

Three decisions:

- **The caller is a public input.** The circuit binds a proof to a `recipient`. The vault puts
  the caller's address there, as one 32-byte word, so a proof copied from a pending transaction
  is useless to anyone else: for another caller the verifier is asked about other public inputs.
- **A static call.** `verify` is a view function, and the vault writes its storage after the
  answer. In a static call the verifier cannot change any state, nor call back into a vault
  that could.
- **The typed message, not hand-written calldata.** `VerifierMsg::Verify` from the library gave
  655 bytes of runtime and 25,496 gas for a claim; the same calldata written with `Packed` gave
  931 bytes and 27,310 gas (`-O 1`). The verifier does the opposite for its call to
  `HonkRelations`, where the typed message was the larger one.

## Not implemented

| Missing | Why |
|---|---|
| Payout | Out of scope by decision |
| A claim accepted by `HonkVerifier` | The verifier accepts the pinned proof for `[9, 0xc0ffe]`; through the vault the caller is the second input, so sumcheck rejects it |
| A proof a Fe test can claim with | The pinned proof was made for the recipient `0xc0ffe`, and a Fe test cannot choose the caller of a call |
| Checks on the constructor arguments | A vault deployed with a wrong verifier address, or a `y` the verifier rejects, can never be claimed |

A claim that succeeds end to end needs a second pinned proof, made for the address of the
caller. Two facts about that address:

- A Fe test contract always has the address `0xbd770416a3345f91e4b34576cb804a576fa48eb1` with
  `fe` 26.6.0 (the runner creates it from the zero address with nonce 0), and it is the caller
  of the calls the test makes itself. A test asserts both. A proof made for this address does
  not depend on any code.
- A caller contract deployed with `create2` has an address derived from its code. Measured for
  `Claimer` with salt 0: `0xfc3b…7f9b` at `-O 1`, `0x71d6…7955` at `-O 2` and `-O s`,
  `0xe33d…27c9` at `-O 0`, the same on every run. A proof made for it breaks when the contract,
  the compiler or the optimization level changes.

## Tests

```sh
cd ultrahonk/vault
fe test
```

Ten tests. The contracts they deploy are declared in the test section of `src/lib.fe`:

| Contract | What it does |
|---|---|
| `Claimer` | Forwards `claim` to a vault, which sees it as the caller. Two of them are two callers |
| `CheckingVerifier` | Returns `true` only for one marker proof and the public inputs `[y, caller]` it was deployed with |
| `RevertingVerifier` | Reverts with the library's `SumcheckFailed` |
| `CountingVerifier` | Writes its storage, then returns `true` |
| `EchoVerifier` | Reverts with the calldata it received, so a test reads what the vault sent |

| Test | Asserts |
|---|---|
| `test_the_expected_caller_claims_with_the_right_proof` | The claim returns `true` and is recorded with its winner |
| `test_a_second_claim_returns_false_and_changes_nothing` | Replay, by the winner and by another caller |
| `test_another_caller_cannot_claim_with_the_same_proof` | A copied proof fails, and the right caller can still claim |
| `test_a_wrong_proof_is_not_accepted` | A changed, a shortened and an empty proof |
| `test_a_revert_of_the_verifier_reaches_the_caller_unchanged` | The revert data is the selector of `SumcheckFailed` |
| `test_a_verifier_address_without_code_makes_the_claim_revert` | No data, nothing recorded |
| `test_a_verifier_that_writes_storage_makes_the_claim_revert` | The call to the verifier is static |
| `test_the_verifier_is_sent_the_proof_then_y_and_the_caller` | The calldata word by word, equal to the standard encoding |
| `test_a_test_claims_from_a_fixed_address` | The address of a test contract, and that the vault sees it as the caller |
| `test_the_real_verifier_accepts_the_proof_but_no_test_caller_can_claim` | `Vault` in front of `HonkVerifier` and `HonkRelations`, with the pinned proof |

The last test shows both sides. The verifier, asked directly with the public inputs the proof
was made for, returns `true`. Through the vault the same proof reverts with `SumcheckFailed`,
because the caller is not `0xc0ffe`. The reference verifier answered a changed
recipient the same way, so that part stays.

## Measurements

With `fe` 26.6.0. `fe build --contract Vault` writes the bytecode to `out/`; without
`--contract` the build also writes the five test contracts.

| | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| Runtime size of `Vault`, bytes | 655 | 647 | 651 |
| Gas of a claim that succeeds, 5-byte proof, `CheckingVerifier` | 25,496 | 25,483 | 25,602 |
| Gas of a claim that succeeds, 4,544-byte proof, a verifier that accepts everything | 29,638 | 29,615 | 29,734 |
| Gas of a claim the verifier answers `false` to | 3,178 | 3,171 | 3,290 |
| Gas of a claim on a vault already claimed | 910 | 901 | 901 |

The gas is the difference of `evm.gas()` around the call to `claim` in a Fe test, with the proof
built before, so it includes encoding the calldata in the caller. Those tests, and the verifier
that accepts everything, were temporary and are not committed. The test deploys the contracts in
the transaction that calls them, so the accounts are warm; a call in a transaction of its own
pays the cold surcharges on top, and the transaction's own cost. None of the figures includes a
real verification: `HonkVerifier` spends 2,108,994 gas (`-O 1`) accepting the pinned proof.
