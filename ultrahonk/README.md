# UltraHonk verifier in Fe

A port of Barretenberg's zero-knowledge UltraHonk verifier (BN254, Keccak transcript: the flavor
`bb` selects with `-t evm`) from Solidity to [Fe](https://fe-lang.org). Noir proofs verified
natively in Fe: a Noir circuit is proved by Barretenberg, and the proof is verified on the EVM by
Fe code. Nothing here runs on the Aztec network.

Three deliverables, all built and tested:

| Deliverable | Where | State |
|---|---|---|
| The verifier: contracts `HonkVerifier` and `HonkRelations` | `lib/`, `relations/`, `verifier/` | Accepts the pinned proof and rejects every recorded invalid call |
| A vault that takes a proof through the verifier | `vault/` ([README](vault/README.md)) | A claim succeeds in front of the real verifier. No payout, by decision |
| A hand-sized toy Honk verifier over F_17 | `../honk-toy/` ([README](../honk-toy/README.md)) | Its verdict equals its reference's in every scenario. A teaching model, not secure |

**The Fe verifier accepts the pinned valid proof.** It has the ABI of the Solidity verifier and
runs its steps (proof validation, the Fiat-Shamir transcript, the public-input delta, sumcheck with
the relations, then the opening: Shplemini scalars, Libra consistency check, multi-scalar
multiplication, pairing-point aggregation and pairing) in the same order and with the same errors,
with one exception among the recorded cases: where the reference runs out of gas on a point off
the curve and reverts without data (proof word 138), this contract reverts with
`ShpleminiFailed()`. It returns `true` only if the pairing holds. The tests cover the pinned proof, the recorded bit flips, the
all-zero proof, and a low-bit flip in each of the 142 proof words, none of which is accepted; they
do not show that every proof the reference rejects is rejected.

It is two contracts, as the reference is a contract and two linked libraries: `HonkVerifier`
asks `HonkRelations` for the value of the relations with a static call.

The plan, the decisions behind it and their outcome are in [`../docs/ultrahonk.md`](../docs/ultrahonk.md)
and [`../docs/adr/`](../docs/adr/README.md).

## What the repository contains

Fe, one Noir circuit, shell scripts and the toy's Python reference (`../honk-toy/reference/`).
**No Solidity and no JavaScript is committed.**

Barretenberg's generated Solidity verifier is used only as a local reference oracle.
`scripts/vectors.sh` writes it to `.oracle/`, which git ignores. Values captured from it are
committed as Fe constants, with the tools and versions that produced them, and the Fe tests assert
against those constants: how it reverts on invalid calls in `lib/src/expected.fe`, what it computes
for the valid proof in `lib/src/vectors.fe`, `lib/src/relations_vectors.fe` and
`lib/src/opening_vectors.fe`.

## Status

| Stage | Scope | State |
|---|---|---|
| 0 | Tooling, circuit, ZK vector, recorded reference reverts, ingot skeletons | Done |
| 1 | Vault contract calling a verifier through `verify(bytes,bytes32[])` | Done (`vault/README.md`). A claim succeeds through the vault in front of `HonkVerifier`, with a second pinned proof made for the address of the Fe test contract; the first pinned proof, made for `0xc0ffe`, cannot be claimed from a Fe test |
| 2 | Proof validation (length, range of every word) and Fiat-Shamir transcript | Done |
| 3-5 | Sumcheck: public-input delta and the round checks | Done |
| 3-5 | Sumcheck: the ten relations (`HonkRelations`) and the final check against them | Done |
| 6 | Shplemini, the Libra consistency check and the pairing check | Done |
| 7 | Verifier contract accepting proofs | Done: accepts both pinned proofs and rejects every recorded invalid call |
| Toy | Honk over F_17 with KZG over F_101, with the sumcheck mask (`../honk-toy/README.md`) | Done |

`scripts/check.sh` runs everything in one command: the tests and the formatting of the seven ingots,
the three contracts built at the three optimisation levels with each runtime checked against the
code-size limit, a verifier generated for another key and built the same way, and the two vector
checks.

### What the contract checks

In the order of the reference verifier, each with the reference's error:

| Step | Module | Rejects with |
|---|---|---|
| Proof length | `lib/src/proof.fe` | `ProofLengthWrongWithLogN(logN, actual, expected)` |
| Every proof word in range for what it holds | `lib/src/proof.fe` | `ValueGeLimbMax`, `ValueGeGroupOrder`, `ValueGeFieldOrder` |
| Number of public inputs | `lib/src/verifier.fe` | `PublicInputsLengthWrong` |
| Public inputs in range, then the 16 challenges | `lib/src/transcript.fe` | `ValueGeFieldOrder` |
| Public-input delta | `lib/src/sumcheck.fe` | (a value the relations read) |
| The `LOG_N` sumcheck round checks | `lib/src/sumcheck.fe` | `SumcheckFailed` |
| The ten relations at the sumcheck point, asked from `HonkRelations` | `lib/src/relations.fe`, `relations/src/lib.fe` | whatever that contract reverts with, unchanged |
| Last sumcheck comparison: relations, row-disabling factor and Libra evaluation against the target | `lib/src/sumcheck.fe` | `SumcheckFailed` |
| Shplemini scalars | `lib/src/shplemini.fe` | `InvertOfZero` on a zero denominator |
| Consistency check of the Libra evaluations | `lib/src/consistency.fe` | `GeminiChallengeInSubgroup`, `ConsistencyCheckFailed` |
| Multi-scalar multiplication | `lib/src/opening.fe` | `ShpleminiFailed` |
| Pairing-point aggregation, only when a limb is non-zero | `lib/src/opening.fe` | `ValueGeGroupOrder`, `PointAtInfinity`, `ShpleminiFailed` |
| Pairing | `lib/src/opening.fe`, `lib/src/verifier.fe` | `ShpleminiFailed` |

For the pinned proof, every challenge, the delta, the target of every sumcheck round, the final
partial pow, the batched value of the relations, every Shplemini scalar, the terms of the
consistency check and the two points of the pairing equal the values captured from the reference
verifier.

One more difference from the reference is recorded in `lib/src/errors.fe` and reached by no
test: if the modexp precompile call itself fails, the reference reverts with four raw bytes
(`0xf8d61709`) and `fr::inv` reverts with `ModExpFailed()`. `fr::inv` also checks the answer of a
call that succeeds, where the reference uses whatever the precompile returns: unless
`a * answer == 1` it reverts with `ModExpFailed()` (tested with `inv(P)`, for which the precompile
answers 0).

`HonkVerifier` takes the address of `HonkRelations` as its constructor argument and keeps it in
an immutable field (in its code, not in storage), so `HonkRelations` is deployed first.
`relations()` (selector `0xb3a480f2`) returns that address, so a deployed verifier can be checked
against the contract it calls. It is a message of its own, `VerifierInfoMsg`: `VerifierMsg` stays
the ABI of the Solidity verifier. The calldata the verifier sends is the encoding of
`RelationsMsg::Accumulate` (`lib/src/relations.fe`), written from the proof bytes instead of through
the typed message: sending the typed message made the runtime 2,103 bytes larger and the call
13,708 gas dearer (9,712 bytes and 326,250 gas against 7,609 and 312,542, at `-O 1`, measured
before the opening was ported), and a
library test asserts that both encodings are the same bytes. If the relations contract reverts,
the verifier reverts with the same data; if the address holds no code, the verifier reverts with
no data.

Every revert recorded from the reference is asserted, in the contract tests unless the row says
otherwise:

| Recorded case | Asserted |
|---|---|
| 4 wrong proof lengths, the empty proof among them | Yes, the whole revert data |
| 7 overwrites of 6 proof words: 6 fail a range check, one passes it and fails in sumcheck | Yes |
| Each of the 142 proof words set to `Q` | Yes |
| 3 changed public inputs, 3 wrong public-input counts (0, 1, 3) | Yes |
| 4 calls that break two rules at once (order of the checks) | Yes |
| Bit flips in proof words 8, 28, 29 | Yes: `SumcheckFailed`, from a round check |
| Bit flips in words 75, 116 | Yes: `SumcheckFailed`, from the last comparison |
| Every proof word at its largest allowed value, with and without the limbs | Yes: `SumcheckFailed` |
| Bit flips in words 74, 121, 129, 134, 137, 138, 140 | Yes: the selector the reference gave (`ConsistencyCheckFailed` or `ShpleminiFailed`); word 138 reverts with `ShpleminiFailed()`, the reference reverts without data |
| The all-zero proof (reference: `ShpleminiFailed`) | Yes: `ShpleminiFailed` |
| The low bit of each of the 142 proof words flipped, one at a time (not recorded from the reference) | Yes: none is accepted |
| What the reference's sumcheck alone does with the bit flips, the changed public inputs, the all-zero proof and the largest values | Yes, in the library tests of `lib/src/sumcheck.fe` |

Measured with `fe` 26.6.0:

| | `-O 1` | `-O 2` | `-O s` |
|---|---|---|---|
| Runtime size of `HonkVerifier`, bytes (`fe build`) | 16,710 | 16,637 | 16,504 |
| Runtime size of `HonkRelations`, bytes (`fe build`) | 8,527 | 6,336 | 6,343 |
| Gas of `verify` on the valid proof, accepted | 1,153,013 | 1,151,747 | 1,167,457 |

Before the opening was ported, 2,976 bytes of the then 7,609-byte `HonkVerifier` runtime were
constants (the verification key, the zeroed challenge array, the barycentric denominators); that
share was not measured again. `HonkRelations` has none. The limit for one contract is 24,576
bytes. The reference's Solidity verifier is 16,946 bytes plus 14,219 of linked libraries
(`The reference oracle` below).

A size is half the length of the hex text `fe build` writes to `out/<Contract>.runtime.bin`.

The gas is the difference of `evm.gas()` around the call in a Fe test, with the proof and the
public inputs built before, so it includes encoding the calldata in the caller. The tests that
measured it are not committed, except one: a verifier test asserts that `verify` on the valid
proof stays below 1,270,000 gas.

The table was measured on 2026-11-23, after three changes: `fr::inv` checks the answer of the
precompile, the relations address is immutable, and the consistency check inverts only the
denominators it uses (`consistency::evaluate_sparse`: 9 x 5 + 2 of them, where the reference
inverts all 256). The same test gives 2,106,146 gas at `-O 1` with the first two changes only,
so the third saves 953,808: about 4,560 for each of the 209 inversions left out. On the code
before the three changes it gives 2,094,295, 2,091,825 and 2,107,685 at the three levels. This
README gave 2,108,994, 2,106,426 and 2,124,076 for that code, which the test does not
reproduce; it gives 2,107,422 at `-O 1` when the proof is built inside the measured call.

The `HonkVerifier` and gas rows were measured again the same day, after the steps of `verify`
moved into the library function `verifier::verify_at`, which takes the key as an argument (#42).
Before that they held 16,638, 16,476 and 16,346 bytes and 1,152,338, 1,150,828 and 1,166,583
gas, the figures the paragraph above compares with. The runtime of `HonkRelations` is the same,
byte for byte.

A `verify` of the pinned proof makes 112 modexp calls, counted in a call trace of the
valid-proof test (`fe test --call-trace`): 46 up to the end of sumcheck and 66 in the opening,
48 of them in the consistency check (the 47 denominators and the inverse of 256). It made 321
before the consistency check changed.

Measured the same way, at `-O 1`: 312,293 with the opening left out (most of it the 46 modular
inversions), so the opening costs about 840,000; 2,849 for a call with a proof of three words,
which fails the proof-length check. Measured before the opening was ported and not again:
283,050 for sumcheck without the relations and the last comparison, and 29,359 for a call to
`HonkRelations` alone, whose runtime has not changed since. The test deploys both contracts in
the transaction that calls them, so the two accounts are warm (a second identical call was not
cheaper); a call in a transaction of its own pays the cold surcharges on top, and the
transaction's own cost: the next section measures it.

## On a local node

`scripts/demo_anvil.sh` runs the built artifacts outside the Fe test harness. It builds the three
contracts, starts `anvil` (Foundry) with the real code-size limit, deploys them with `cast`, and
checks that `verify` answers `true` for the pinned proof, that the same proof with one bit flipped
reverts with `ShpleminiFailed()`, and that `0xc0ffe`, the recipient the first pinned proof was
made for, claims through the vault while another caller cannot. It passes at `-O 1`, `-O 2` and
`-O s`.

Gas used by the transactions, measured with it on 2026-11-23 (anvil 1.5.1, `-O 1`):

| | Osaka | Prague, Cancun |
|---|---|---|
| `verify` of the pinned proof | 1,240,270 | 937,982 |
| A claim through the vault | 1,268,126 | 965,838 |
| Deploying `HonkRelations`, `HonkVerifier`, `Vault` | 1,893,267, 3,610,429, 233,218 | not recorded |

These include the 21,000 of the transaction and its calldata. The forks differ by 302,288 gas,
about 2,700 for each of the 112 modexp calls: Osaka prices that precompile higher (EIP-7883). On
Osaka, `-O 2` gives 1,239,012 and 1,266,868, and `-O s` 1,254,722 and 1,282,719. The deployed
code is 8,527, 16,742 and 825 bytes at `-O 1`: the runtime, plus 32 bytes for each immutable
field.

With `--key <directory>` the script runs the verifier of another circuit. It generates the
verifier for the `vk` and `vk_hash` of the directory (`proof_to_fe.sh --verifier`), deploys it
with `HonkRelations`, and checks that `verify` answers `true` for the `proof` and `public_inputs`
of the directory and reverts for that proof with its last bit flipped. The vault is left out: it
is bound to the pinned circuit. Garaga's three bundles ([Other circuits](#other-circuits)),
measured with it on 2026-11-23 (anvil 1.5.1):

| `--key vectors/garaga/` | `LOG_N` | Level | Runtime of the verifier, bytes | Deploying it | `verify`, Osaka | `verify`, Prague |
|---|---|---|---|---|---|---|
| `hello` | 12 | `-O 1` | 16,692 | 3,611,105 | 2,084,389 | 1,385,348 |
| `mutator_set` | 17 | `-O 1` | 16,723 | 3,626,991 | 2,695,688 | 1,713,252 |
| `recursive` | 20 | `-O 1` | 16,706 | 3,620,305 | 3,075,743 | 1,923,270 |
| `recursive` | 20 | `-O 2` | 16,633 | 3,604,509 | 3,073,684 | not run |
| `recursive` | 20 | `-O s` | 16,515 | 3,579,037 | 3,107,123 | not run |

`--key vectors/pedersen_commit`, the circuit of `examples/pedersen_commit` (`LOG_N` 15), measured
on 2026-11-24 at `-O 1`: 16,700 bytes, 3,622,085 gas to deploy, and `verify` in 2,450,610 gas on
Osaka and 1,581,532 on Prague.

The eight runs passed, and each flipped proof reverted with `ShpleminiFailed()`. The gas columns
are transactions, as above, and deploying costs the same on both forks. The runtime is the
deployed code (`cast codesize`) less the 32 bytes of the relations address. `HonkRelations` is
the contract of the first table; deploying it uses 1,421,112 gas at `-O 2` and 1,422,619 at
`-O s`. anvil kept its default block gas limit of 30,000,000: the largest transaction, a
deployment, uses 3,626,991 gas, under Osaka's limit of 16,777,216 for one transaction (EIP-7825).
The forks differ by 699,041, 982,436 and 1,152,473 gas, which is 2,699 times 259, 364 and 427:
the 2,699 a `modexp` call costs more on Osaka for the pinned proof, and the 112 calls of the
pinned circuit plus 21 for each round above 5. That number of calls is inferred from the
difference, not counted in a trace.

What a chain needs:

- **Cancun or later.** On Shanghai `HonkVerifier` does not deploy: the node reports an opcode that
  is not activated. `HonkRelations` deploys there.
- **The precompiles at 0x05 to 0x08:** `modexp` and the three BN254 operations.

The contracts were not run on a public test network.

## Verify your own circuit

In one command: `felix/out/felix up DIR` runs the steps below on the Noir package in DIR, checks
the proof with `bb verify`, verifies it on anvil and leaves the verifier ingot in
`DIR/target/verifier` ([`../felix/`](../felix/README.md)). The steps follow one by one.

`HonkVerifier` is built for the vault circuit, but the algorithm is not. It is the library
function `verifier::verify_at(vk, proof, public_inputs, relations)` (`lib/src/verifier.fe`): every
step, with the verification key as an argument and the relations asked from the `HonkRelations`
contract at `relations`. `HonkVerifier` only calls it with the key of its circuit. A verifier for
another circuit is the same shell over another key, which `felix new` ([`../felix/`](../felix/README.md))
writes, and one `HonkRelations` serves them all.

The steps, from the directory of a Noir package, with `nargo` 1.0.0, `bb` 6.0.0, `fe` 26.6.0,
`python3` and Foundry's `cast`. `-t evm` is the target of `bb` for the EVM: Keccak transcript,
zero knowledge.

```sh
NAME=my_circuit      # the package name in Nargo.toml
REPO=~/fe-ultrahonk  # where this repository is checked out
INGOT=my-verifier    # where the verifier ingot is written

# 1. Compile the circuit and execute it on Prover.toml: target/$NAME.json and target/$NAME.gz
nargo execute
# 2. The verification key: target/vk and target/vk_hash
bb write_vk -b "target/$NAME.json" -o target -t evm
# 3. A proof: target/proof and target/public_inputs
bb prove -b "target/$NAME.json" -w "target/$NAME.gz" -k target/vk -o target -t evm
# 4. The verifier ingot of that key: $INGOT/fe.toml, $INGOT/src/vk.fe and $INGOT/src/lib.fe.
#    `felix gen-vk target/vk > "$INGOT/src/vk.fe"` changes the key alone.
(cd "$REPO/felix" && fe build --backend native --out-dir out)
"$REPO/felix/out/felix" new target "$INGOT"
# 5. Build the verifier and HonkRelations: out/<Contract>.bin in each ingot
(cd "$INGOT" && fe build --contract HonkVerifier)
(cd "$REPO/ultrahonk/relations" && fe build --contract HonkRelations)
# 6. Deploy HonkRelations once: it takes no key and serves every verifier. Then deploy the
#    verifier with that address, $RELATIONS, as its constructor argument. Each command prints
#    a contractAddress. Add --rpc-url and how you sign.
cast send --create "0x$(cat "$REPO/ultrahonk/relations/out/HonkRelations.bin")"
cast send --create "0x$(cat "$INGOT/out/HonkVerifier.bin")$(cast abi-encode 'constructor(address)' "$RELATIONS" | cut -c 3-)"
# 7. Call verify(bytes,bytes32[]), the ABI of bb's Solidity verifier, on the verifier's
#    address: the proof, and the public inputs as 32-byte words. It prints true.
cast call "$VERIFIER" 'verify(bytes,bytes32[])(bool)' "0x$(xxd -p target/proof | tr -d '\n')" \
    "[$(xxd -p -c 32 target/public_inputs | sed 's/^/0x/' | paste -sd, -)]"
# 8. Or try steps 4 to 7 on a local anvil node, in one command
"$REPO/ultrahonk/scripts/demo_anvil.sh" --key target
```

The generator refuses a key whose `LOG_N` is outside 1 to 25, or that counts fewer than 8 public
inputs: the count in a key includes the 8 pairing-point limbs. The ingot names `ultrahonk/lib` of
the checkout by a relative path in its `fe.toml`, so it builds only while both stay where they
are. Its contract is the `HonkVerifier` of `verifier/src/lib.fe`, copied over the other key; the
tests stay in that ingot. The eight steps were run as written on 2026-11-24, from a fresh clone,
on `examples/pedersen_commit`: that is how `vectors/pedersen_commit/` was made.

### How this compares with bb and Aztec

`verify_at` is the Fe counterpart of bb's `abstract contract BaseZKHonkVerifier`. The generated
shell is bb's generated `contract HonkVerifier is BaseZKHonkVerifier(...)`, which only supplies
the key. The shared `HonkRelations` stands where bb's linked library would. Aztec's L1 `Rollup`
holds its generated verifier as an immutable `IVerifier` (`EPOCH_PROOF_VERIFIER`) and calls
`verify(proof, publicInputs)` on it, as `Vault` holds the immutable address `verifier()` returns.
Aztec pins the hash of the verifier's creation code and compares the generated file with the
committed one in CI; `check.sh` mirrors the comparison for the pinned key, whose generated
verifier must build to the runtime of the committed `HonkVerifier`, byte for byte. The Aztec
side is in its `l1-contracts`: `src/core/interfaces/IVerifier.sol`, `RollupCore.sol` and
`DeployRollupLib.sol`.

## Other circuits

`verifier::verify` runs the steps of `verify_at` with the relations evaluated in place. With it
the library tests verify proofs that another project made
with `bb` 6.0.0: the bundles Garaga commits, copied into `vectors/garaga/` with their provenance
and the verdict of `bb verify` (`vectors/garaga/README.md`).

| Bundle | `LOG_N` | Public inputs | Shown by the tests of `lib/src/garaga_<bundle>.fe` |
|---|---|---|---|
| `hello` | 12 | 1 | The 23 challenges of the transcript equal the ones Garaga pins for this proof. The proof is accepted. It is not accepted with the low bit of any one of its 226 words flipped, nor with its public input changed |
| `mutator_set` | 17 | 3 | The proof is accepted. It is not accepted with the low bit of any one of its 286 words flipped, nor with any one of its three public inputs changed |
| `recursive` | 20 | 1 | The proof is accepted. Its circuit verifies another proof, so it carries pairing points (the eight limbs are not zero) and is accepted through the aggregation: the second point of its pairing is not the negated KZG quotient. It is not accepted with the low bit of any one of its 322 words flipped |

The flips and the changed inputs go through `KeyedVerifier`, a contract only the tests deploy,
which runs `verifier::verify` with the key in the calldata. None of these tests goes through
`HonkRelations`.

One verifier test does, for `recursive`. It deploys `RecursiveVerifier`, the shell of
`HonkVerifier` over the key of that bundle (16,671 bytes at `-O 1`, and only the tests deploy
it), next to `HonkVerifier`, with one `HonkRelations` for both. The proof is accepted; with the
low bit of its last word flipped it reverts with `ShpleminiFailed`; and each verifier rejects the
proof of the other's circuit with `ProofLengthWrongWithLogN`, the first check. The accepted call
uses 2,894,264 gas at `-O 1`, 2,892,207 at `-O 2` and 2,925,664 at `-O s`, measured on 2026-11-23
as the gas of `verify` above, and the test asserts that it stays below 3,180,000. On a local
node the generated verifier of that key accepts the proof in a transaction of 3,075,743 gas
([On a local node](#on-a-local-node)).

`vectors/pedersen_commit/` holds a proof this project made, of `examples/pedersen_commit`
(`LOG_N = 15`, one public input), which `bb verify` accepts. The tests of
`lib/src/pedersen_commit.fe` show it accepted, and not accepted with the low bit of any one of its
262 words flipped, nor with its public input changed. A second verifier test deploys
`PedersenVerifier`, the shell over its key, with `HonkRelations`: the proof is accepted for
2,302,243 gas at `-O 1` (the test asserts below 2,530,000); with the low bit of its last word
flipped it reverts with `ShpleminiFailed`, and with its public input plus one with
`SumcheckFailed`.

These proofs also reach relations the pinned proof does not. The range, elliptic, memory,
non-native field and Poseidon2 relations are scaled by their selector, so where the selector
evaluates to zero at the sumcheck point an accepted proof says nothing about them. In the pinned
proof every gate selector but `qArith` is zero there. A test asserts which are not in Garaga's:

| Selector not zero at the sumcheck point | In |
|---|---|
| `qDeltaRange` | `hello`, `mutator_set`, `recursive` |
| `qLookup` | `mutator_set` |
| `qMemory` | `mutator_set`, `recursive` |
| `qNnf`, `qPoseidon2External`, `qPoseidon2Internal` | `recursive` |
| `qElliptic` | `pedersen_commit` only (its test asserts it) |

Garaga's fourth bundle, `memory` (`LOG_N = 12`), is not used: `bb verify` accepts it, and its
key has no selector the three others lack.

## Limits

- The tests do not show that every proof the reference rejects is rejected. The evidence is the
  recorded invalid calls and the 142 low-bit flips above.
- The contracts accept two pinned proofs in the tests. Ten fresh proofs of the same circuit were
  also accepted, by hand, on a local node (see [Regenerate the vector](#regenerate-the-vector)).
- `HonkVerifier` is built for the vault circuit (`LOG_N = 5`): its key is the constant `VK` in
  `lib/src/vk.fe`, generated from `vectors/vk` by `scripts/proof_to_fe.sh --vk`. A verifier for
  another key is generated by `--verifier`. The two contracts are also tested at `LOG_N` 20
  (Garaga's `recursive`) and 15 (`pedersen_commit`), and four circuits run on a local node
  through generated verifiers, by hand ([Other circuits](#other-circuits),
  [On a local node](#on-a-local-node)). No other size or circuit is tested.
- No pinned proof carries pairing points: the eight limbs are zero, so the contract tests run
  only the branch that skips the aggregation. The aggregation is tested in the library: against
  values the reference computed with limbs put in place of the zeros, and on Garaga's `recursive`
  proof, which carries pairing points and is accepted through it. One contract test accepts that
  proof too ([Other circuits](#other-circuits)).
- One accepted proof exercises the elliptic-curve relation: `pedersen_commit`, which this
  project made and `bb verify` accepts. `qElliptic` is zero in the four other circuits. With the
  relation disabled, its three library tests fail; the only other tests that fail are the four on
  the reference's values for a synthetic input (`lib/src/relations_vectors.fe`).
- The captured values rest on their documented provenance. The oracle and the local tests that
  read it are not committed.
- This port has not been audited.
- The vault has no payout, and the toy is a teaching model that protects nothing.

What is missing to rely on this code outside its tests, with the smallest fix for each limit, is
in [`../docs/ultrahonk-gaps.md`](../docs/ultrahonk-gaps.md).

## Run the tests

Needs only `fe` 26.6.0. Nothing here needs `bb`, `nargo`, Python or Foundry. `scripts/check.sh`
runs these commands and the other checks at once; its checks of the vectors and of the generated
verifier also need `xxd`, `shasum` and `python3`.

```sh
cd ultrahonk
(cd key && fe test)        # 2: the limits and the layout of bb's key against their values
(cd lib && fe test)        # 202: field arithmetic, proof checks, transcript, relations, sumcheck, opening, all of them in one call, Garaga's proofs, a Pedersen proof
(cd relations && fe test)  # 2: the relations contract against the reference values
(cd verifier && fe test)   # 21: both contracts against the recorded reference reverts, the `relations()` getter, a gas bound, two other keys
(cd vault && fe test)      # 15: the vault against stand-in verifiers, its two getters, and in front of HonkVerifier
(cd ../honk-toy && fe test) # 76: the toy verifier against its Python reference's vectors
(cd ../felix && fe test)  # 3: felix's relative paths, key checks and Nargo.toml name, run natively
```

The numbers are the tests that pass in each ingot, counted on 2026-11-24.

`fe build --contract HonkRelations` in `relations/`, `fe build --contract HonkVerifier` in
`verifier/` and `fe build --contract Vault` in `vault/` write the bytecode to `out/` in each
directory. Without `--contract`, the build in `verifier/` also writes three contracts that only
its tests deploy (`FixedRelations` and `FailingRelations`, two stand-ins for the relations
contract, and `RecursiveVerifier`), and the
build in `vault/` the seven contracts its tests deploy. `lib/` is a library: its one contract,
`KeyedVerifier`, runs the library verifier with the key in the calldata and is deployed only by
its tests. `key/` and `../honk-toy/` have no contract to build.

## Layout

| Path | Content |
|---|---|
| `circuit/` | Noir package `vault`: `x * x == y`, with `y` and `recipient` public. Prover inputs: `Prover.toml` (recipient `0xc0ffe`) and `Prover_test_address.toml` (the Fe test address) |
| `vectors/` | `proof`, `public_inputs`, `vk`, `vk_hash`: raw `bb` output. `test_address/`: the second proof and its public inputs, for the same `vk` |
| `examples/pedersen_commit/` | Noir package `pedersen_commit`: the public output is the Pedersen hash of two private inputs. Its key uses the elliptic-curve, lookup and range relations |
| `vectors/pedersen_commit/` | The proof bundle of that circuit (`LOG_N = 15`), made here: raw `bb` 6.0.0 output. See `vectors/pedersen_commit/README.md` |
| `vectors/garaga/` | Proof bundles of other circuits, copied from Garaga (MIT) with its licence text: raw `bb` 6.0.0 output. `hello` (`LOG_N = 12`), `mutator_set` (17) and `recursive` (20). See `vectors/garaga/README.md` |
| `scripts/check.sh` | Builds and tests everything in one command, and checks the code size of the three contracts. It also generates a verifier with `proof_to_fe.sh --verifier` for the key of Garaga's `recursive` bundle and formats, builds and measures it; checks that the one generated for the pinned key has the runtime of `HonkVerifier`, byte for byte; and checks that a key with `LOG_N` 0 or 26 is refused |
| `scripts/demo_anvil.sh` | Deploys the built contracts on a local `anvil` node, verifies the pinned proof and claims through the vault. With `--key <directory>` it generates, deploys and runs the verifier of the key and the proof `bb` wrote there, without the vault |
| `scripts/vectors.sh` | Regenerates `vectors/` and the local oracle in `.oracle/` |
| `scripts/proof_to_fe.sh` | Prints the proof and public inputs of `vectors/` as Fe constants; `--vk` prints the verification key from `vectors/vk` and `vectors/vk_hash` alone, and refuses a key whose public-input offset is not 5; `--test-address` prints the second proof; `--garaga <bundle>` and `--garaga-key <bundle>` print a proof of `vectors/garaga/` and its key; `--bundle <bundle>` and `--bundle-key <bundle>` do the same for a bundle made here, `vectors/<bundle>/`; `--verifier <key dir> <out dir>` writes a verifier ingot for the `vk` and `vk_hash` in a directory, as `bb write_solidity_verifier` writes a Solidity verifier: `fe.toml`, and `src/lib.fe` with the key and the `HonkVerifier` contract of `verifier/src/lib.fe` (it needs `python3`, for the relative path to `lib/`); every mode refuses a key with `LOG_N` outside 1 to 25 or with fewer than 8 public inputs; `--check` compares them with `lib/src/vectors.fe`, `lib/src/vk.fe`, `lib/src/test_address_vectors.fe`, every `lib/src/garaga_*.fe` and the two `lib/src/pedersen_commit*.fe` |
| `key/` | Ingot `ultrahonk_key`: what bb 6.0.0 fixes about a verification key: `MAX_LOG_N`, `PAIRING_POINTS_SIZE`, `PUBLIC_INPUTS_OFFSET` and the words of the `vk` and `vk_hash` files. No test needs the EVM |
| `lib/` | Ingot `ultrahonk`: the verifier steps (`proof`, `transcript`, `sumcheck`, `relations` with the entity indices in `wire`, `shplemini`, `consistency`, `opening`), `fr`, `errors`, `types`, `abi`. The limits of the key live in `ultrahonk_key`, which `types` re-exports, so the verifier and `felix` ([`../felix/`](../felix/README.md)) share them |
| `lib/src/verifier.fe` | `verify_at(vk, proof, public_inputs, relations)`: every step in one call, with the verification key as an argument and the relations asked from `HonkRelations`. It is what `HonkVerifier` runs. `verify(vk, proof, public_inputs)`: the same with the relations evaluated in place. No contract of the project calls it; the tests use it for circuits other than the vault's |
| `lib/src/std_assumptions.fe` | Tests only: they pin the behaviour of the std precompile wrappers and of Keccak hashing that the port depends on |
| `lib/src/vk.fe` | The verification key of the vault circuit, which `HonkVerifier` is built with. Generated |
| `lib/src/vectors.fe` | The pinned proof, plus the challenges, delta, round targets and pow captured from the reference. Re-exports the key |
| `lib/src/test_address_vectors.fe` | The second pinned proof and its public inputs, which the vault test claims with |
| `lib/src/garaga_<bundle>_proof.fe` | A proof of `vectors/garaga/` and its public inputs, generated |
| `lib/src/garaga_<bundle>.fe` | The verification key of that bundle, generated, then the tests that verify its proof with `verifier::verify`. For `hello`, also the challenges Garaga pins; in `garaga_recursive.fe`, also which gate selectors the three proofs reach |
| `lib/src/pedersen_commit_proof.fe`, `lib/src/pedersen_commit.fe` | The proof and public input of `vectors/pedersen_commit/`, generated, and its verification key, generated, then the constant `VK`. No test reads them yet |
| `lib/src/relations_vectors.fe` | Inputs and outputs of the reference's relations, for the pinned proof and for a synthetic input that makes all 31 subrelations non-zero |
| `lib/src/opening_vectors.fe` | What the reference computes after sumcheck for the pinned proof: Shplemini scalars, terms of the consistency check, pairing points, and the aggregation on limbs put in place of the zeros |
| `lib/src/expected.fe` | The reverts of the reference verifier on invalid calls, and what its sumcheck alone does with them |
| `docs/zk-verifier-reference.md` | What the port reproduces: proof layout, check order, transcript, formulas, errors |
| `relations/` | Ingot `ultrahonk_relations`: contract `HonkRelations` |
| `verifier/` | Ingot `ultrahonk_verifier`: contract `HonkVerifier`, which calls `verifier::verify_at` with the key of the vault circuit; its tests deploy both contracts |
| `vault/` | Ingot `ultrahonk_vault`: contract `Vault`, which records the first caller with a proof for `[y, caller]`; no payout. See `vault/README.md` |
| `../honk-toy/` | Ingot `honk_toy`: a hand-sized Honk verifier over F_17 with KZG over F_101, with its Python reference and vector generator in `../honk-toy/reference/`. See `../honk-toy/README.md` |
| `../docs/ultrahonk.md` | At the repository root: the project plan and its outcome |
| `../docs/adr/` | At the repository root: the 14 decision records |
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
vector or reads `vectors/`; the values in `lib/src/expected.fe` and `lib/src/vectors.fe` belong
to the pinned proof.

A second pinned proof, `vectors/test_address/proof`, has the same witness and verification key
and the public inputs `y = 9`, `recipient = 0xbd770416a3345f91e4b34576cb804a576fa48eb1`: the
address of the Fe test contract, so a vault test can claim with it (`vault/README.md`).
`bb write_vk` on the compiled circuit gave `vectors/vk` and `vectors/vk_hash` byte for byte, and
`bb verify` accepted the proof against `vectors/vk`. Only the vault test uses it; no value was
captured from the reference for it.

```
ae40808061c90671310321108d88e50985c6f83e8f12afcc12a8567ed390268a  vectors/test_address/proof
d6906f479962dbe20325f74826e61cc1b19c5a77af4acce826522605f4cfcc47  vectors/test_address/public_inputs
```

## The reference oracle

The oracle is the Solidity verifier `bb write_solidity_verifier -t evm` emits for `vectors/vk`
(2,518 lines, sha256 `5609d13d...3878d8bfe`). It stays out of the repository.

How the reverts in `lib/src/expected.fe` were captured:

1. `scripts/vectors.sh` wrote `.oracle/src/HonkVerifier.sol` and `.oracle/foundry.toml`.
2. A Foundry test kept locally in `.oracle/test/` deployed `HonkVerifier`, read `vectors/proof`
   and `vectors/public_inputs`, and required `verify` to return `true`.
3. For each case the same test changed one thing (the proof length, one proof word, one public
   input) or replaced the proof with one built from a rule (all zeros, every word at its largest
   allowed value), called `verify` with 20,000,000 gas and logged the revert data.
4. The logged values were copied into `lib/src/expected.fe`.

The verdicts of sumcheck alone in `lib/src/expected.fe` came from the same local test: a contract
inheriting from the generated verifier ran the steps of its `verify` up to `verifySumcheck` and
returned the result.

The values in the second part of `lib/src/vectors.fe` came from the same local test too: a contract
inheriting from the generated verifier logged the challenges of its transcript, its public-input
delta, and the target and partial pow of its sumcheck round loop for the pinned proof. The first
part of that file (proof, public inputs, verification key) is printed by `scripts/proof_to_fe.sh`
from `vectors/`; the local test also checks that `vectors/vk` lists the key's points in the order
the verifier uses them.

`lib/src/relations_vectors.fe` and `lib/src/opening_vectors.fe` came from two more local tests
in `.oracle/test/`. Each file states at its top what was run and how the values were read.

Measured on that verifier for the pinned proof:

| | |
|---|---|
| Runtime size | `HonkVerifier` 16,946 bytes, plus the linked libraries `RelationsLib` 8,211 and `ZKTranscriptLib` 6,008 |
| Gas for a valid `verify` | 2,654,961 (forge gas report) |

To rebuild the oracle after cloning, run `scripts/vectors.sh` (next section), then
`forge install foundry-rs/forge-std --no-git` and `forge build --sizes` inside `.oracle/`. The
script does not write the local tests, so the captured values cannot be regenerated from the
repository alone.

## Regenerate the vector

```sh
cd ultrahonk
mkdir -p .tools/bb .tools/nargo/bin
curl -sSfL https://github.com/AztecProtocol/aztec-packages/releases/download/v6.0.0/barretenberg-arm64-darwin.tar.gz | tar -xz -C .tools/bb
curl -sSfL https://github.com/noir-lang/noir/releases/download/v1.0.0/noir-aarch64-apple-darwin.tar.gz | tar -xz -C .tools/nargo/bin
scripts/vectors.sh
```

The script was run from start to end on 2026-11-23, in a clone of `develop`, with `bb` 6.0.0 and
`nargo` 1.0.0. `vectors/vk`, `vectors/vk_hash`, both `public_inputs` files and the generated
Solidity verifier came out byte-identical to the committed ones (the sha256 values above). The
two proofs came out different, as proving is randomized, and `bb verify` accepted both.

Ten more proofs of the first input were then made with the same `bb prove` command, all
different. Each was given to the built contracts on `anvil` with `scripts/demo_anvil.sh`: each
was accepted by `HonkVerifier`, rejected with its last bit flipped, and claimed through the vault
by `0xc0ffe`. No test in the repository does this: it was run by hand.

The script ends with `bb verify` accepting both new proofs. It **overwrites `vectors/proof` and
`vectors/test_address/proof` with different valid proofs**; run `git checkout -- vectors`
afterwards to return to the pinned ones. It removes only the files it writes, so the Garaga
bundles under `vectors/garaga/` are kept. Committing a new first proof means capturing `lib/src/expected.fe`, the second part of
`lib/src/vectors.fe`, the `PROOF_*` values of `lib/src/relations_vectors.fe` and
`lib/src/opening_vectors.fe` again, and regenerating the first part of `lib/src/vectors.fe` with
`scripts/proof_to_fe.sh`. A new second proof only needs
`scripts/proof_to_fe.sh --test-address > lib/src/test_address_vectors.fe`.

The toy has its own generator, which needs Python 3 and nothing else:
`python3 ../honk-toy/reference/gen_vectors.py --check` (`../honk-toy/README.md`).

The archives are the macOS arm64 builds. The script calls the tools by path and exits unless they
report the versions below; tools installed elsewhere on the machine are not used.

| Tool | Version | Needed for |
|---|---|---|
| `fe` | 26.6.0 (5b3f96a) | Tests and build |
| `bb` | 6.0.0, target `evm` (Keccak, ZK) | Regenerating the vector |
| `nargo` | 1.0.0 (noirc 1.0.0+275d3ab1a5c916c6ea73e8d6b943f685f574500c) | Regenerating the vector |
| `forge` | 1.5.1-stable, solc 0.8.34, `evm_version = "osaka"` | Local oracle only |
