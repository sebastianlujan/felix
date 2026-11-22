# honk_toy

A hand-sized Honk proof verifier written in Fe, as a pure library ingot.

It is a port of the protocol of the teaching page "UltraHonk a mano"
(<https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ>): Honk over the field F_17 with KZG
commitments on the curve y² = x³ + 3 over F_101 (subgroup of order 17). The circuit has
4 rows and 3 wires and proves "there is an x in the table {0, 1, 2, 3} with x² = y" for a
public y. The verifier checks 2 sumcheck rounds of 6 values each, 7 subrelations over 23
evaluated entities, and one Shplemini/KZG pairing check.

Every number is small enough to follow by hand, and the stages are the same as in a real
UltraHonk verifier. **It is a teaching model, not a secure verifier** (see [Limits](#limits)).

## Run

Requires `fe` 26.6.0. Node is needed only to regenerate the test vectors.

```sh
cd ultrahonk/toy
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
honk_toy = { path = "../toy" }
```

```fe
use honk_toy::verify   // also at honk_toy::verifier::verify

pub fn verify(
    vk: [[u256; 2]; 15],
    proof: Proof,
    public_inputs: [u256; 1],
    challenges: Challenges,
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

`sumcheck::verify` and `shplemini::verify` return every intermediate value
(`SumcheckTrace`, `OpeningTrace`), which is what the tests compare with the reference.

## Layout

| File | Contents |
|---|---|
| `src/lib.fe` | shared types (`Challenges`, `Proof`, the two traces, `Scenario`) and the `verify` re-export |
| `src/f17.fe` | arithmetic mod 17 |
| `src/relations.fe` | entity indices, the 7 subrelations, the alpha batching (`a` and `l1`) |
| `src/sumcheck.fe` | public-input delta, round checks, Lagrange evaluation, partial pow, final check |
| `src/curve.fe` | F_101, F_101², G1 and G2 arithmetic, Miller-loop Tate pairing |
| `src/shplemini.fe` | batched evaluation, fold evaluations, scalars, MSM, P0/P1, pairing check |
| `src/verifier.fe` | `verify` |
| `src/vectors.fe` | generated reference vectors |
| `reference/honk.js` | the reference implementation |
| `reference/gen_vectors.js` | the vector generator |

## Reference and vectors

`reference/honk.js` is the math `<script>` block of the page (no DOM), extracted
unmodified apart from a three-line header. It is the source of truth: the Fe code is a
port of its `verify`, `sumcheckVerify`, `subrelations`, `splitBatch`, `publicDelta`,
`lagrangeEval`, `shpleminiVerify`, `foldPosEvaluations`, `ecAdd`, `ecMul`, `ecNeg`, `line`,
`pairing` and the `f2*` helpers.

`reference/gen_vectors.js` runs the reference prover and verifier on the scenarios below
and writes `src/vectors.fe`: for each scenario the proof, the public input, the
challenges, the verdict and every intermediate value of both halves, plus the
verification key, the multiples of G1 and their pairings. The file is committed, so
`fe test` needs no Node.

```sh
node reference/gen_vectors.js   # reproduces src/vectors.fe byte for byte
git diff --exit-code src/vectors.fe
```

The generator lays its output out as `fe fmt` does (max width 100).

### Scenarios

Example challenges (the page's "dados del ejemplo"): beta 2, gamma 5, alpha 3, g 2,
u (9, 7), rho 14, r 4, nu 5, z 12. The prover's witness is x = 2 for y = 4 unless noted.

| Vector | Page scenario | What the prover does | Challenges | Verdict | Fails at |
|---|---|---|---|---|---|
| `HONEST` | `honesto` | follows the protocol | example | accept | — |
| `BROKEN_GATE` | `compuerta` | x = 3: in the table, but 3·3 ≠ 4 | example | reject | sumcheck round 0 |
| `BROKEN_LOOKUP` | `tabla` | x = 15: a root, but not in the table | example | reject | sumcheck round 0 |
| `BROKEN_COPY` | `copia` | 15 in the gate, 2 in the lookup | example | reject | sumcheck round 0 |
| `WRONG_PUBLIC_INPUT` | `pub` | proves y = 4, the verifier uses y = 5 | example | reject | sumcheck final check |
| `PATCHED_UNIVARIATES` | `astuto` | x = 3 and patches the univariates | example | reject | sumcheck final check |
| `LUCKY_DICE` | `suerte` | the same cheat | example with u₁ = 1 | **accept** | — |
| `FALSE_EVALUATION` | `mentira` | honest trace, lies in the evaluation of w_l | example | reject | sumcheck final check and pairing check |
| `HONEST_ALT` | — | follows the protocol | beta 3, gamma 8, alpha 5, g 6, u (3, 12), rho 10, r 3, nu 7, z 5 | accept | — |
| `HONEST_INFINITY` | — | follows the protocol | beta 5, gamma 3, alpha 7, g 11, u (3, 12), rho 10, r 3, nu 7, z 5 | accept | — |

`LUCKY_DICE` is accepted on purpose. The cheating prover adds c·(1 − X) to the true round
polynomial, which fixes S(0) + S(1) and vanishes at X = 1; when the challenge lands on 1
the cheat survives. In F_17 that single coincidence has probability 1/17. The Fe verdict
equals the reference verdict in every scenario, whatever it is.

`HONEST_INFINITY` is an honest proof whose opening proof [W] is the point at infinity
(and so are P0 and P1). It exercises the `[0, 0]` encoding in a proof; the verification
key already contains five such commitments.

## Limits

- **Not secure.** The field has 17 elements: the soundness error is large (see
  `LUCKY_DICE`) and discrete logarithms in a group of order 17 are found by inspection, so
  the commitments bind nothing. Use it to learn the structure of the verifier, never to
  protect anything.
- **Interactive.** Challenges are inputs. A real verifier derives them by Fiat–Shamir.
- **No zero-knowledge.** The reference's sumcheck mask branch (`opt.masks`,
  `proof.libra`, the challenge `rhoL`) is not ported.
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
