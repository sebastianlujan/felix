# honk_toy

A hand-sized Honk proof verifier written in Fe, as a pure library ingot.

It is a port of the protocol of the teaching page "UltraHonk by hand"
(<https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ>): Honk over the field F_17 with KZG
commitments on the curve y² = x³ + 3 over F_101 (subgroup of order 17). The circuit has
4 rows and 3 wires and proves "there is an x in the table {0, 1, 2, 3} with x² = y" for a
public y. The verifier checks 2 sumcheck rounds of 6 values each, 7 subrelations over 23
evaluated entities, and one Shplemini/KZG pairing check. It also verifies proofs whose
sumcheck is masked, the one part of the ZK flavor that the page computes
(see [Sumcheck mask](#sumcheck-mask-libra)).

Every number is small enough to follow by hand, and the stages are the same as in a real
UltraHonk verifier. **It is a teaching model, not a secure verifier** (see [Limits](#limits)).

## Run

Requires `fe` 26.6.0. Python 3 (standard library only) is needed only to regenerate the
test vectors.

```sh
cd honk-toy
fe test            # all tests, on the EVM backend
fe check           # type-check only
fe fmt --check     # formatting, including the generated vectors
```

`fe build` fails with `No contracts found to build`. That is expected: the ingot is a
library and has no contract.

## API

Another ingot depends on it with a relative path in its `fe.toml` (absolute paths are
rejected):

```toml
[dependencies]
honk_toy = { path = "../honk-toy" }
```

```fe
use honk_toy::{verify, verify_masked}   // also at honk_toy::verifier

pub fn verify(
    vk: [[u256; 2]; 15],
    proof: Proof,
    public_inputs: [u256; 1],
    challenges: Challenges,
) -> bool

// For a proof with a masked sumcheck: `libra` is the mask part of the proof and `rho_l`
// one more challenge.
pub fn verify_masked(
    vk: [[u256; 2]; 15],
    proof: Proof,
    libra: Libra,
    public_inputs: [u256; 1],
    challenges: Challenges,
    rho_l: u256,
) -> bool
```

The toy protocol is interactive: the 10 challenges (`beta`, `gamma`, `alpha`, `g`, `u[0]`,
`u[1]`, `rho`, `r`, `nu`, `z`) are inputs, not hashes of a transcript. There is no
Fiat–Shamir step.

| Value | Encoding |
|---|---|
| Element of F_17, coordinate in F_101 | reduced `u256` |
| G1 point | `[x, y]`; the point at infinity is `[0, 0]`, which is not on the curve |
| Element a + b·i of F_101² = F_101[i]/(i² + 2) | `[a, b]` |
| G2 point | `[x, y]` with coordinates in F_101² |
| Evaluations | `[u256; 23]` in the reference's `ENTITIES` order (indices in `relations.fe`) |
| Round polynomial | `[u256; 6]`: its values at 0..5 |
| Verification key | the commitments to the 15 fixed columns, in `ENTITIES` order |

`sumcheck::verify`, `shplemini::verify` and `libra::verify` return every intermediate
value (`SumcheckTrace`, `OpeningTrace`, `LibraTrace`), which is what the tests compare
with the reference.

## Layout

| File | Contents |
|---|---|
| `src/lib.fe` | shared types (`Challenges`, `Proof`, `Libra`, the traces, the scenario records) and the re-exports of `verify` and `verify_masked` |
| `src/f17.fe` | arithmetic mod 17 |
| `src/relations.fe` | entity indices, the 7 subrelations, the alpha batching (`a` and `l1`) |
| `src/sumcheck.fe` | public-input delta, round checks, Lagrange evaluation, partial pow, final check |
| `src/curve.fe` | F_101, F_101², G1 and G2 arithmetic, Miller-loop Tate pairing |
| `src/shplemini.fe` | batched evaluation, fold evaluations, scalars, MSM, P0/P1, pairing check |
| `src/libra.fe` | the sumcheck mask: KZG check of the two mask openings, initial target, final term |
| `src/verifier.fe` | `verify`, `verify_masked` |
| `src/vectors.fe` | generated reference vectors |
| `reference/honk.py` | the reference implementation |
| `reference/gen_vectors.py` | the vector generator |

## Reference and vectors

`reference/honk.py` is a Python port of the math `<script>` block of the page (no DOM),
function by function, with the page's names in snake_case (`sumcheckVerify` is
`sumcheck_verify`) and its objects as dicts. It is the source of truth: the Fe code is a
port of its `verify`, `sumcheck_verify`, `subrelations`, `split_batch`, `public_delta`,
`lagrange_eval`, `shplemini_verify`, `fold_pos_evaluations`, `kzg_check`, `ec_add`,
`ec_mul`, `ec_neg`, `line`, `pairing` and the `f2_*` helpers.

`reference/gen_vectors.py` runs the reference prover and verifier on the scenarios below
and writes `src/vectors.fe`: for each scenario the proof, the public input, the
challenges, the verdict and every intermediate value of both halves, plus the
verification key, the multiples of G1 and their pairings. The file is committed, so
`fe test` needs no Python.

```sh
python3 reference/gen_vectors.py           # reproduces src/vectors.fe byte for byte
python3 reference/gen_vectors.py --check   # exits 1, without writing, if it is out of date
```

The generator lays its output out as `fe fmt` does (max width 100).

### Scenarios

Example challenges: beta 2, gamma 5, alpha 3, g 2,
u (9, 7), rho 14, r 4, nu 5, z 12. The prover's witness is x = 2 for y = 4 unless noted.

| Vector | From the page | What the prover does | Challenges | Verdict | Fails at |
|---|---|---|---|---|---|
| `HONEST` | yes | follows the protocol | example | accept | — |
| `BROKEN_GATE` | yes | x = 3: in the table, but 3·3 ≠ 4 | example | reject | sumcheck round 0 |
| `BROKEN_LOOKUP` | yes | x = 15: a root, but not in the table | example | reject | sumcheck round 0 |
| `BROKEN_COPY` | yes | 15 in the gate, 2 in the lookup | example | reject | sumcheck round 0 |
| `WRONG_PUBLIC_INPUT` | yes | proves y = 4, the verifier uses y = 5 | example | reject | sumcheck final check |
| `PATCHED_UNIVARIATES` | yes | x = 3 and patches the univariates | example | reject | sumcheck final check |
| `LUCKY_DICE` | yes | the same cheat | example with u₁ = 1 | **accept** | — |
| `FALSE_EVALUATION` | yes | honest trace, lies in the evaluation of w_l | example | reject | sumcheck final check and pairing check |
| `HONEST_ALT` | — | follows the protocol | beta 3, gamma 8, alpha 5, g 6, u (3, 12), rho 10, r 3, nu 7, z 5 | accept | — |
| `HONEST_INFINITY` | — | follows the protocol | beta 5, gamma 3, alpha 7, g 11, u (3, 12), rho 10, r 3, nu 7, z 5 | accept | — |

`LUCKY_DICE` is accepted on purpose. The cheating prover adds c·(1 − X) to the true round
polynomial, which fixes S(0) + S(1) and vanishes at X = 1; when the challenge lands on 1
the cheat survives. In F_17 that single coincidence has probability 1/17. The Fe verdict
equals the reference verdict in every scenario, whatever it is.

`HONEST_INFINITY` is an honest proof whose opening proof [W] is the point at infinity
(and so are P0 and P1). It exercises the `[0, 0]` encoding in a proof; the verification
key already contains five such commitments.

## Sumcheck mask (Libra)

The reference runs the one part of Barretenberg's ZK flavor that fits in the toy: masking
the sumcheck round polynomials. The prover picks two polynomials of degree 5, g₀ and g₁,
commits to them and sends σ, the sum of G(X₀, X₁) = g₀(X₀) + g₁(X₁) over {0, 1}². The
verifier draws one more challenge, ρ_L, and the sumcheck runs over "relations + ρ_L·G":

| | Plain proof | Masked proof |
|---|---|---|
| Initial target | 0 | ρ_L·σ |
| Final check | pow·A + l1 = target | pow·A + l1 + ρ_L·(g₀(u₀) + g₁(u₁)) = target |
| Extra checks | — | KZG openings of g₀ at u₀ and of g₁ at u₁ |

`verify_masked` is the port of the reference's `verify` for a proof that carries `libra`,
and `libra::kzg_check` the port of `kzg_check`. A plain proof is the case of the zero mask.

**Covered:** the mask of the sumcheck univariates, and nothing else.

**Not covered**, because the reference does not implement it; the page explains why it
does not fit in F_17:

- The masks of the evaluations: extra rows with random values in the witness columns and
  the polynomial 1 − ∏_{i≥2}(1 − uᵢ) that disables the relations on those rows. With 2
  rounds the product is empty and would disable every relation. It takes at least 8 rows,
  and 8 rows of 3 wires need 24 distinct permutation identifiers; F_17 has 17 elements.
- The Gemini masking polynomial.
- The argument that the mask evaluations belong to the committed mask
  (`checkEvalsConsistency`), which works over a multiplicative subgroup of 256 elements;
  the multiplicative group of F_17 has 16. The toy opens g₀ and g₁ with two direct KZG
  openings instead.

A masked toy proof is therefore **not zero-knowledge**: the 23 evaluations still travel
unmasked, and the page recovers the witness x from w_r(u).

The masked vectors all use the example challenges, y = 4 and ρ_L = 3:

| Vector | Origin | Proof | Verdict | Fails at |
|---|---|---|---|---|
| `MASKED_A` | page, mask A | honest, g₀ = (3, 1, 4, 1, 5, 9), g₁ = (2, 7, 1, 8, 2, 8) | accept | — |
| `MASKED_B` | page, mask B | honest, g₀ = (6, 2, 8, 3, 1, 12), g₁ = (11, 5, 3, 16, 9, 4) | accept | — |
| `MASKED_FALSE_EVALUATION` | extra | mask A with 1 added to the claimed g₀(u₀) | reject | KZG opening of g₀ and sumcheck final check |
| `MASKED_WRONG_SUM` | extra | mask A with 1 added to the claimed σ | reject | sumcheck round 0 |
| `MASKED_BROKEN_GATE` | extra | mask A over the broken gate x = 3 | reject | sumcheck round 0 |

The polynomials are given by their coefficients. The reference prover has no option to
cheat in the mask, so the generator changes the proof after proving in
`MASKED_FALSE_EVALUATION` and `MASKED_WRONG_SUM`; the verdicts and intermediate values
still come from the reference verifier.

## Limits

- **Not secure.** The field has 17 elements: the soundness error is large (see
  `LUCKY_DICE`) and discrete logarithms in a group of order 17 are found by inspection, so
  the commitments bind nothing. Use it to learn the structure of the verifier, never to
  protect anything.
- **Interactive.** Challenges are inputs. A real verifier derives them by Fiat–Shamir.
- **No zero-knowledge.** Only the sumcheck mask is implemented; the evaluations are not
  masked (see [Sumcheck mask](#sumcheck-mask-libra)).
- **Degenerate challenges revert.** Where the reference throws on a zero denominator
  (delta, a Gemini fold, z equal to an opening point ±r or ±r², r = 0), the Fe code
  reverts instead of returning a verdict. More than half of the random challenge sets in
  F_17 are degenerate for the prover, according to the page.
- **Inputs are not validated.** Field elements are expected reduced, and points are
  expected in the order-17 subgroup; neither is checked, as in the reference. Scalar
  multiplication reduces the scalar mod 17, which is only right inside that subgroup.
- **One circuit shape.** 4 rows, one public input, 23 entities: the sizes are fixed in
  the types.
- **Pairing in Fe.** No precompile exists for this curve, so the pairing is a Miller loop
  with a final exponentiation, in plain Fe. A BN254 verifier calls the precompiles instead.

Two deliberate differences from the reference, neither of which changes a result:
`lagrange_eval` always evaluates the Lagrange sum (the reference returns `S[u]` directly
when u < 6, where the sum gives the same value), and `curve.fe` adds G2 addition, negation
and scalar multiplication, which the reference does not have (it only doubles G2 to get
[τ]₂) and the verifier does not use.
