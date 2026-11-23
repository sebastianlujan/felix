# ADR-0006: Field arithmetic as plain functions on `u256`

**Status:** Accepted  
**Date:** 2026-11-22  
**Deciders:** Project owner

## Context

- The verifier does a large amount of arithmetic in the BN254 scalar field, most of it in the relations.
- A field type with overloaded operators would read closer to the mathematics.
- The plan rules that type out with a reference to `sonatina#232`. The plan does not summarise the issue.
- The EVM has `addmod` and `mulmod`, and the Fe std exposes them together with `modexp`.

## Decision

Field elements are `u256` values. Arithmetic is a set of plain functions in `fr.fe`. There is no operator-overloaded field type.

```fe
// lib/src/fr.fe
pub fn add(_ a: u256, _ b: u256) -> u256 { addmod(a, b, P) }
pub fn sub(_ a: u256, _ b: u256) -> u256 { addmod(a, P - b, P) }
pub fn mul(_ a: u256, _ b: u256) -> u256 { mulmod(a, b, P) }
pub fn neg(_ a: u256) -> u256 { sub(0, a) }
pub fn inv(_ a: u256) -> u256            // reverts on 0; modexp with exponent P - 2
```

`P` is the scalar field modulus and `Q` the base field modulus. Both are constants in `fr.fe`.

## Outcome (2026-11-23)

Carried out as decided. The relations, sumcheck and the opening use these functions only. `inv(0)` reverts with `InvertOfZero`, and a failed `modexp` call reverts with `ModExpFailed`. Since issue #4, `inv` also reverts with `ModExpFailed` unless `a * answer == 1`, which the reference does not check. Nine tests in `fr.fe` cover the wrap-around of each function, the reverts of `inv(0)` and `inv(P)`, and two large operands against values computed with Python's integers.

## Options Considered

### Option A: Plain functions on `u256` (chosen)

| Dimension | Assessment |
|-----------|------------|
| Complexity | Four small functions over std builtins |
| Readability | Expressions become nested calls |
| Risk | No type separates a field element from a raw word; rules are held by convention |
| Fit with Fe 26.6.0 | Uses `addmod`, `mulmod`, `modexp` directly |

**Pros:** Nothing between the code and the EVM operations. Avoids the issue the plan cites.  
**Cons:** Relation code is harder to read than with operators.

### Option B: An operator-overloaded field type

| Dimension | Assessment |
|-----------|------------|
| Complexity | A wrapper type plus operator implementations |
| Readability | Closest to the reference formulas |
| Risk | Ruled out by the plan with a reference to `sonatina#232` |
| Fit with Fe 26.6.0 | Not adopted: the plan cites `sonatina#232` |

**Pros:** Readable relations. The type documents which values are field elements.  
**Cons:** Ruled out by the plan, which cites `sonatina#232`.

## Trade-off Analysis

Option B offers readability, and the plan rules it out, citing `sonatina#232`. Plain functions use the std builtins directly and map one to one onto the reference's `FrLib` calls, which keeps the port mechanical.

## Consequences

- Easier: each reference call has a direct Fe counterpart.
- Harder: three rules must be held by hand:
  - `sub` needs `b ≤ P`: `P - b` underflows otherwise, where the reference wraps.
  - `neg(0)` is `P` in the upstream reference and 0 in Fe. The two are equal after reduction, so raw values are never compared.
  - `inv(0)` must revert, because `modexp` returns 0 silently.
- Revisit: a field type, once `sonatina#232` no longer applies.

## Action Items

1. [x] Stage 2: implement `fr.fe` with `add`, `sub`, `mul`, `inv` and the constants `P` and `Q`.
2. [x] Stage 2: test that `inv(0)` reverts and that `mul(inv(2), 2) == 1` (the stage 0 spike 3 check).
3. [x] Stages 3–5: write the relations with these functions only.
