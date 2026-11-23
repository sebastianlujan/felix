# ZK UltraHonk verifier reference (bb 6.0.0, `-t evm`)

What the Fe port reproduces, extracted from the verifier that Barretenberg 6.0.0 generates for this project's circuit. The port is complete: `HonkVerifier` accepts the pinned proof and rejects every recorded invalid call (`../README.md`). The generated file is a local, untracked reference (`ultrahonk/.oracle/src/HonkVerifier.sol`, 2,518 lines, sha256 `5609d13d…8bfe`); line numbers below (`L…`) point into it. `L` in formulas is `LOG_N`. Every layout row and every transcript row was checked against that reference on the pinned proof.

## This circuit

| Item | Value |
|---|---|
| `N`, `LOG_N` | 32, 5 |
| `NUMBER_OF_PUBLIC_INPUTS` | 10 (2 real + 8 pairing limbs) |
| Public inputs | `[9, 0xc0ffe]` (y, recipient) |
| Proof | 142 words = 4,544 bytes |
| `VK_HASH` | `0x03e0d5e7c5aee8b953749c3240e058d6ab8ac1735bec103038e76b3c008bbf1c` |
| Pairing limbs in the pinned proof | all zero (only the skip-aggregation branch is exercised) |
| Proving | randomized: `bb prove -t evm` gives a different valid proof each run; `vectors/proof` is pinned |

## Constants

| Constant | Value |
|---|---|
| Subrelations / alphas | 31 / 30 |
| Entities read by relations | 41 |
| Evaluations in the proof | 42 (index 0 = masking polynomial, index e + 1 = entity e) |
| Unshifted / shifted | 37 / 5 |
| Values per sumcheck round | 9 |
| Pairing limbs | 8 |
| `SUBGROUP_SIZE` | 256 |
| `SUBGROUP_GENERATOR` | `0x07b0c561a6148404f086204a9f36ffb0617942546750f230c893619174a57a76` |
| `SUBGROUP_GENERATOR_INVERSE` | `0x204bd3277422fad364751ad938e2b5e6a54cf8c68712848a692c553d0329f5d6` |
| Libra commitments / Libra polynomial evaluations | 3 / 4 |
| `SHIFTED_COMMITMENTS_START` | 30 |
| MSM size | 42 + L |
| Permutation value separator | `1 << 28` |
| Public-input offset | 5 |
| Array bound (`CONST_PROOF_SIZE_LOG_N`) | 25 |

Relation parameters: `eta`, `romLogupGamma`, `beta`, `gamma`, `publicInputsDelta`. The ten relation functions and the commitment-scheme helpers are byte-identical to the non-ZK flavor; only the transcript and the base verifier differ.

## Proof layout (calldata order)

Points are plain 32-byte `(x, y)`, two words each. Total **82 + 12L words**.

| Words | L = 5 | Content |
|---|---|---|
| 0 – 7 | 0–7 | pairing limbs: `P0.x_lo, P0.x_hi, P0.y_lo, P0.y_hi, P1.x_lo, …` |
| 8 – 9 | 8–9 | Gemini masking polynomial commitment |
| 10 – 15 | 10–15 | `w1`, `w2`, `w3` |
| 16 – 21 | 16–21 | `lookupReadCounts`, `lookupReadTags`, `w4` |
| 22 – 25 | 22–25 | `lookupInverses`, `zPerm` |
| 26 – 27 | 26–27 | `libraCommitments[0]` |
| 28 | 28 | `libraSum` |
| 29 + 9i … 37 + 9i | 29–73 | sumcheck univariate of round i (9 values) |
| 29 + 9L … 70 + 9L | 74–115 | 42 evaluations |
| 71 + 9L | 116 | `libraEvaluation` |
| 72 + 9L … 75 + 9L | 117–120 | `libraCommitments[1]`, `libraCommitments[2]` |
| 76 + 9L … 73 + 11L | 121–128 | Gemini fold commitments `[0 … L−2]` |
| 74 + 11L … 73 + 12L | 129–133 | Gemini evaluations `[0 … L−1]` |
| 74 + 12L … 77 + 12L | 134–137 | `libraPolyEvals[0 … 3]` |
| 78 + 12L, 79 + 12L | 138–139 | `shplonkQ` |
| 80 + 12L, 81 + 12L | 140–141 | `kzgQuotient` |

## Checks before any algebra, in this order

1. `proof.length == (82 + 12L) * 32`, else `ProofLengthWrongWithLogN(logN, actual, expected)`.
2. Walking the proof in word order: limbs `< 2^136` (even index) or `< 2^120` (odd), else `ValueGeLimbMax`; point coordinates `< Q`, else `ValueGeGroupOrder` (`(0,0)` accepted, no on-curve check); scalars `< P`, else `ValueGeFieldOrder`.
3. `publicInputs.length == NUMBER_OF_PUBLIC_INPUTS − 8`, else `PublicInputsLengthWrong`.
4. Each public input `< P`, else `ValueGeFieldOrder`.

Order confirmed on the reference with calls that break two rules at once.

## Transcript

Every challenge is `keccak256(input) % P`, full width. Each round hashes the previous challenge followed by **one contiguous run of proof words**, so a single `absorb(prev, proof, start, count)` covers everything except `eta`.

| # | Challenge | Input | Proof words (start, count) |
|---|---|---|---|
| 1 | `eta` | `vkHash ‖ real public inputs ‖ words` (no previous challenge) | 0, 16 |
| 1b | `romLogupGamma` | `eta` | — |
| 2 | `beta` | `prev ‖ words` | 16, 6 |
| 2b | `gamma` | `beta` | — |
| 3 | `alpha` | `prev ‖ words` | 22, 4 |
| 4 | `gateChallenges[0]` | `prev` | — |
| 5 | `libraChallenge` | `prev ‖ words` | 26, 3 |
| 6 | `u_i` (i < L) | `prev ‖ words` | 29 + 9i, 9 |
| 7 | `rho` | `prev ‖ words` | 29 + 9L, 47 |
| 8 | `geminiR` | `prev ‖ words` | 76 + 9L, 2(L − 1) |
| 9 | `shplonkNu` | `prev ‖ words` | 74 + 11L, L + 4 |
| 10 | `shplonkZ` | `prev ‖ words` | 78 + 12L, 2 |

The value chained forward is the last one produced in each row (`romLogupGamma` after row 1, `gamma` after row 2). `alphas[i] = alpha^(i+1)`. `gateChallenges[i] = gateChallenges[i−1]²`. `kzgQuotient` is never hashed.

## Verify steps

Length check, load VK, load proof with range checks, public-input count, transcript, public-input delta, sumcheck (`SumcheckFailed`), Shplemini (`ShpleminiFailed`).

**Public-input delta** (same as non-ZK): numerator starts at `gamma + beta·(2^28 + 5)`, denominator at `gamma − beta·6`; real inputs first, then the 8 limbs; steps `+beta` and `−beta`.

**Sumcheck**
- Initial target: `libraChallenge · libraSum`.
- Each round: `S[0] + S[1] == target`; next target by barycentric evaluation over points 0..8 with denominators `[0x9d80, P−0x13b0, 0x5a0, P−0x2d0, 0x240, P−0x2d0, 0x5a0, P−0x13b0, 0x9d80]`; `pow *= 1 + u·(g − 1)`.
- Final: relations read evaluations 1..41; `evaluation = Π_{i=2}^{L−1}(1 − u_i)`; `grand = grand·(1 − evaluation) + libraEvaluation·libraChallenge`; accept iff `grand == target`.

**Shplemini**: `posInv = 1/(z − r)`, `negInv = 1/(z + r)`, `unshifted = posInv + ν·negInv`, `shifted = r⁻¹(posInv − ν·negInv)`.

| Slot | Commitment | Scalar |
|---|---|---|
| 0 | `shplonkQ` | 1 |
| 1 | masking polynomial | `−unshifted·ρ⁰` |
| 2 – 29 | VK points: `s1..s4, id1..id4, lagrangeFirst, lagrangeLast, qLookup, t1..t4, qm, qr, qo, qc, ql, q4, qArith, qDeltaRange, qElliptic, qMemory, qNnf, qPoseidon2External, qPoseidon2Internal` | `−unshifted·ρ^(slot−1)` |
| 30 – 34 | `w1, w2, w3, w4, zPerm` | `−unshifted·ρ^(slot−1) − shifted·ρ^(37+i)`, i = slot − 30 |
| 35 – 37 | `lookupInverses, lookupReadCounts, lookupReadTags` | `−unshifted·ρ^(slot−1)` |
| 38 … 36 + L | fold commitments `[0 … L−2]` | `−ν^(2i+2)/(z − r^(2^(i+1))) − ν^(2i+3)/(z + r^(2^(i+1)))` |
| 37 + L | `libraCommitments[0]` | `bs[0]` |
| 38 + L | `libraCommitments[1]` | `bs[1] + bs[2] + bs[3]` |
| 39 + L | `libraCommitments[2]` | `bs[4]` |
| 40 + L | `(1, 2)` | constant-term accumulator |
| 41 + L | `kzgQuotient` | `z` |

- Batched evaluation: `Σ_{i=0}^{36} evals[i]·ρ^i + Σ_{i=0}^{4} evals[37+i]·ρ^(37+i)`; the ρ power is not reset between the two sums.
- Fold loop: power starts at `ν²`, multiplies by `ν²` each step, ends at `ν^(2L)`.
- Libra claims, opening points `{r, g·r, r, 1, r}`: `den[0] = 1/(z − r)`, `den[1] = 1/(z − g·r)`, `den[2] = den[4] = den[0]`, `den[3] = 1/(z − 1)`; `sf_k = den[k]·ν^(2L+k)`, `bs[k] = −sf_k`; the constant term adds `sf_0·e[0] + sf_1·e[1] + sf_2·e[2] + sf_4·e[3]` with `e = libraPolyEvals`.
- Consistency check, before the MSM: `Z = r^256 − 1` (`Z == 0` → `GeminiChallengeInSubgroup`); `lagrange[0] = 1`, `lagrange[1 + 9k + j] = u_k^j` (k < L, j in 0..8), other entries 0; `den[idx] = 1/(g^(−idx)·r − 1)`; `c = (Z/256)·Σ lagrange[idx]·den[idx]`; `Lfirst = (Z/256)·den[0]`, `Llast = (Z/256)·den[255]`; `diff = Lfirst·e[2] + (r − g⁻¹)·(e[1] − e[2] − e[0]·c) + Llast·(e[2] − libraEvaluation) − Z·e[3]`; `diff != 0` → `ConsistencyCheckFailed`.
- MSM over all 42 + L slots, accumulator starting at `(0,0)`; a precompile failure → `ShpleminiFailed`.
- `P1 = −kzgQuotient` (mod Q, skipped when y = 0), computed on a copy after the MSM.
- Aggregation, only if some limb is non-zero: coordinates `lo | (hi << 136)`, each `< Q` else `ValueGeGroupOrder`; `sep = keccak(proofP0.x, proofP0.y, proofP1.x, proofP1.y, P0.x, P0.y, P1.x, P1.y) % P`; neither proof point may be `(0,0)` (`PointAtInfinity`); `P0 = sep·P0 + proofP0`, `P1 = sep·P1 + proofP1`.
- Pairing: `e(P0, G2 generator) · e(P1, VK G2 point) == 1`.

## Errors

| Signature | Selector |
|---|---|
| `ProofLengthWrongWithLogN(uint256,uint256,uint256)` | `0x59895a53` |
| `ValueGeLimbMax()` | `0xeb73e0bd` |
| `ValueGeGroupOrder()` | `0x607be13e` |
| `ValueGeFieldOrder()` | `0x20a33589` |
| `PublicInputsLengthWrong()` | `0xfa066593` |
| `SumcheckFailed()` | `0x9fc3a218` |
| `ShpleminiFailed()` | `0xa5d82e8a` |
| `ConsistencyCheckFailed()` | `0xa2a2ac83` |
| `GeminiChallengeInSubgroup()` | `0x835eb8f7` |
| `PointAtInfinity()` | `0x4ddaa5e5` |
| `InvertOfZero()` | `0xb2c952e2` |
| `NotPowerOfTwo()` | `0x24e8e742` |

Observed on the pinned proof with the lowest bit of one word flipped: words 8, 28, 29, 75, 116 → `SumcheckFailed`; words 74, 121, 134, 137 → `ConsistencyCheckFailed`; words 129, 140 → `ShpleminiFailed`; word 138 (`shplonkQ` x) → revert with empty data. Changing either public input → `SumcheckFailed`.

Observed on `verifySumcheck` alone (a contract inheriting from the reference ran `verify` up to it): it reverts inside its round loop for words 8, 28, 29 and for either changed public input, returns false for words 75 and 116, and returns true for the other seven flips.

Observed on proofs built from a rule: the all-zero proof of the right length → `ShpleminiFailed`, with the valid public inputs and with zero public inputs, and `verifySumcheck` returns true for it (every check compares 0 with 0); every word at its largest in-range value, with or without the limbs → `SumcheckFailed` in the first round; the empty proof → `ProofLengthWrongWithLogN(5, 0, 4544)`; no public inputs → `PublicInputsLengthWrong`.

## Risks for the port, and what became of them

| Risk | In the reference | In the Fe port |
|---|---|---|
| Code size | Three contracts: 16,946 + 8,211 + 6,008 runtime bytes = 31,165, above the 24,576-byte limit for one contract | Two contracts: `HonkVerifier` 16,446 bytes and `HonkRelations` 8,527 at `-O 1` (`../README.md`) |
| Off-curve points | A failed precompile call consumes the gas forwarded to it, so the reference can revert with empty data instead of `ShpleminiFailed` | The first failed call reverts with `ShpleminiFailed()`. For proof word 138 the two verifiers therefore differ, and the Fe tests assert `ShpleminiFailed()` |
| Consistency check cost | 256 modular inversions, most multiplied by zero (only indices 0..9L and 255 of the Lagrange array are non-zero) | `consistency::check` keeps the 256 inversions. `evaluate_sparse`, with 9L + 2 inversions, is tested to give the same values and is not used by the verifier |
| Gas for a valid proof | About 2.65M to 2.97M | 2,108,994 at `-O 1` (`../README.md`) |
| Branches no proof reaches | Aggregation with non-zero limbs, `PointAtInfinity`, `InvertOfZero`, `GeminiChallengeInSubgroup` and `NotPowerOfTwo` were read on the reference. Later the aggregation was run on it with limbs put in place of the zeros (`lib/src/opening_vectors.fe`) | Library tests cover the aggregation against those values, and trigger `PointAtInfinity`, `InvertOfZero` and `GeminiChallengeInSubgroup`. `NotPowerOfTwo` is never raised: `r^256` is computed by eight squarings |

## Fe 26.6.0 notes from this stage

- Full revert data in a test: `evm.try_call(...)`, then `outcome.success()`, `outcome.returndata_len()`, `revert_selector(outcome.returndata())`, `Bytes::from_payload(source: outcome.returndata()).word_at(byte_offset)`.
- Error selector: `<E as core::error::ErrorVariant<std::abi::Sol>>::SELECTOR` (`u32`).
- Const tables of structs work; iterate with `for ref x in TABLE` or make the struct `Copy`.
- Raw bytecode can be deployed in a test with `evm.create_raw(value:, init_code:)` and called with `evm.try_call_raw`.
- Hashing: `use std::evm::packed::Packed`; `Packed::with_capacity(bytes:)`, `.u256(x)`, `.append_span(span)`, `.keccak256()`, `.span()`.
- A contract type of another ingot deploys in a test once that ingot is a path dependency: `use ultrahonk_relations::HonkRelations`, then `evm.create2<HonkRelations>(value: Wei::zero(), args: (), salt: 0)`. Constructor arguments are a tuple: `args: (relations,)`.
- A contract field set at construction: field `relations: Address,`, `init(relations_address: Address) uses (mut relations) { relations = relations_address }`, and a handler that reads it declares `uses (relations, call: Call, ctx: Ctx)`. Without `mut` the field is immutable and lives in the contract's code; with `mut` it is storage, as it was here before issue #5.
- Static call with calldata built by hand: `staticcall_decode(addr:, gas: ctx.gas(), args: packed.span())` (`std::evm`) decodes one return value, reverts with the callee's revert data when the call fails, and reverts with no data when the callee returns nothing. `Address::static(message)` does the same for a typed message, at a higher cost when the message holds a large array.
- A message variant is a type: `RelationsMsg::Accumulate` can be a return type, and its selector is `<RelationsMsg::Accumulate as core::message::MsgVariant<Sol>>::SELECTOR`. `std::evm::encode_msg_calldata(message)` gives its calldata without calling.
- No `cfg(test)` exists in the std or the compiler fixtures: a contract declared for the tests is also written by `fe build`, unless `--contract` names the one wanted.
- `Vec<T>` is an alias of `std::abi::DynArray<T>`; the empty one is `DynArray::empty()` (`Vec::empty()` does not resolve).
- `fe test -O <level>` and `fe build -O <level>` take the same levels. A test prints a measured number by ending in `revert(value)`.
