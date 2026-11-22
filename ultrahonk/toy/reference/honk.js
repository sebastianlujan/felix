// Reference implementation: the math block of the teaching page "UltraHonk a mano",
// https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ (first inline <script> block, no DOM).
// Extracted unmodified: everything below this header is verbatim.
// ===== Honk de juguete sobre F_17, con entrada pública y lookup: mismo algoritmo que honk_full_by_hand.py =====
const P = 17, Q = 101, N = 4, D = 2, LEN = 6, TAU = 2, SEP = 4, PI_ROW = 1;
const m = x => ((x % P) + P) % P, mq = x => ((x % Q) + Q) % Q;
function pw(b, e, mod) { let r = 1; b = ((b % mod) + mod) % mod; while (e > 0) { if (e & 1) r = r * b % mod; b = b * b % mod; e >>= 1; } return r; }
function inv(a, why) { a = m(a); if (a === 0) throw new Error(why || 'división por cero'); return pw(a, P - 2, P); }

// fila 0: ceros · fila 1: entrada pública (w_l = w_r = y) · fila 2: x·x = y · fila 3: lookup de x en t
const FIXED = {
  q_m: [0, 0, 1, 0], q_c: [0, 0, 0, 0], q_l: [0, 0, 0, 0], q_r: [0, 0, 0, 0], q_o: [0, 0, 16, 0], q_lk: [0, 0, 0, 1],
  s1: [0, 15, 6, 2], s2: [4, 10, 3, 7], s3: [8, 9, 1, 11],
  id1: [0, 1, 2, 3], id2: [4, 5, 6, 7], id3: [8, 9, 10, 11],
  L_first: [1, 0, 0, 0], L_last: [0, 0, 0, 1], t: [0, 1, 2, 3]
};
const WITNESS = ['w_l', 'w_r', 'w_o', 'm', 'tag', 'I', 'z'];
const UNSHIFTED = Object.keys(FIXED).concat(WITNESS);   // 22
const TO_BE_SHIFTED = ['z'];
const ENTITIES = UNSHIFTED.concat(['z_shift']);         // 23 evaluaciones
const POWED = [1, 1, 1, 1, 1, 0, 1];                    // la subrelación 5 (suma LogUp) no lleva pow
const NREL = 7;

function buildWires(x, y) { return { w_l: [0, y, x, x], w_r: [0, y, x, 0], w_o: [0, 0, y, 0] }; }
function countLookups(wires) {
  const mm = [0, 0, 0, 0], tag = [0, 0, 0, 0];
  for (let row = 0; row < N; row++) if (FIXED.q_lk[row]) for (let k = 0; k < N; k++) if (FIXED.t[k] === m(wires.w_l[row])) { mm[k]++; tag[k] = 1; break; }
  return { m: mm, tag };
}
function fold(t, u) { const o = []; for (let j = 0; j < t.length / 2; j++) o.push(m((1 - u) * t[2 * j] + u * t[2 * j + 1])); return o; }
function mapCols(cols, f) { const o = {}; for (const k in cols) o[k] = f(cols[k], k); return o; }

function publicDelta(pis, beta, gamma) {
  let num = 1, den = 1, na = gamma + beta * (SEP + PI_ROW), da = gamma - beta * (PI_ROW + 1);
  pis.forEach(pi => { num = m(num * (na + pi)); den = m(den * (da + pi)); na += beta; da -= beta; });
  return m(num * inv(den, 'el denominador de δ da 0: probá otros β, γ'));
}
function computeInverses(cols, gamma) {
  return [0, 1, 2, 3].map(k => (cols.tag[k] || cols.q_lk[k]) ? inv((cols.w_l[k] + gamma) * (cols.t[k] + gamma), 'un término del lookup da 0 en la fila ' + k + ': probá otro γ') : 0);
}
function permFactors(v, beta, gamma) {
  const num = m(m(v.w_l + beta * v.id1 + gamma) * m(v.w_r + beta * v.id2 + gamma) * m(v.w_o + beta * v.id3 + gamma));
  const den = m(m(v.w_l + beta * v.s1 + gamma) * m(v.w_r + beta * v.s2 + gamma) * m(v.w_o + beta * v.s3 + gamma));
  return { num, den };
}
function subrelations(v, beta, gamma, delta) {
  const r0 = v.q_m * v.w_l * v.w_r + v.q_l * v.w_l + v.q_r * v.w_r + v.q_o * v.w_o + v.q_c;
  const { num, den } = permFactors(v, beta, gamma);
  const r1 = (v.z + v.L_first) * num - (v.z_shift + v.L_last * delta) * den;
  const read = m(v.w_l + gamma), write = m(v.t + gamma);
  const l0 = m(read * write) * v.I - (v.tag + v.q_lk - v.tag * v.q_lk);
  const l1 = v.q_lk * m(v.I * write) - v.m * m(v.I * read);
  return [r0, r1, v.L_last * v.z_shift, v.L_first * v.z, l0, l1, v.tag * v.tag - v.tag].map(m);
}
// A = las seis subrelaciones que llevan pow, juntadas con α; l1 = α⁵·L₁, que va sin pow
function splitBatch(rs, alpha) { let A = 0; rs.forEach((r, i) => { if (POWED[i]) A += r * pw(alpha, i, P); }); return { A: m(A), l1: m(pw(alpha, 5, P) * rs[5]) }; }
function batched(v, ch, delta, powv) { const b = splitBatch(subrelations(v, ch.beta, ch.gamma, delta), ch.alpha); return m(powv * b.A + b.l1); }
function computeZ(cols, beta, gamma) {
  const z = [0, 1];
  for (let i = 1; i < N - 1; i++) {
    const { num, den } = permFactors(mapCols(cols, c => c[i]), beta, gamma);
    z.push(m(z[z.length - 1] * num * inv(den, 'el denominador de z_perm en la fila ' + i + ' da 0: probá otros β, γ')));
  }
  return z;
}
function lagrangeEval(S, u) {
  u = m(u); if (u < S.length) return S[u];
  let tot = 0;
  for (let i = 0; i < S.length; i++) { let num = 1, den = 1; for (let j = 0; j < S.length; j++) if (j !== i) { num = m(num * (u - j)); den = m(den * (i - j)); } tot += S[i] * num * inv(den); }
  return m(tot);
}
function roundTerms(cols, i, t, ch, delta) {   // detalle "a mano" de una evaluación S_i(t)
  const gRest = pw(ch.g, 2 ** (i + 1), P), half = cols.w_l.length / 2, rows = [];
  for (let j = 0; j < half; j++) {
    const v = mapCols(cols, c => m(c[2 * j] + t * (c[2 * j + 1] - c[2 * j])));
    const rs = subrelations(v, ch.beta, ch.gamma, delta), b = splitBatch(rs, ch.alpha), pj = pw(gRest, j, P);
    rows.push({ j, v, rs, A: b.A, l1: b.l1, pj, term: m(pj * b.A) });
  }
  return rows;
}
function maskSum(masks) { const [g0, g1] = masks; return m(2 * (pEval(g0, 0) + pEval(g0, 1)) + 2 * (pEval(g1, 0) + pEval(g1, 1))); }
function libraUni(masks, i, t, us) { const [g0, g1] = masks; return i === 0 ? m(2 * pEval(g0, t) + pEval(g1, 0) + pEval(g1, 1)) : m(pEval(g0, us[0]) + pEval(g1, t)); }
function sumcheckProve(cols, ch, delta, opt) {
  opt = opt || {};
  cols = mapCols(cols, c => c.slice());
  const univariates = [], rounds = []; let powPartial = 1, target = opt.masks ? m(ch.rhoL * maskSum(opt.masks)) : 0;
  for (let i = 0; i < D; i++) {
    const gi = pw(ch.g, 2 ** i, P), S = [];
    for (let t = 0; t < LEN; t++) {
      let a = 0, l = 0; roundTerms(cols, i, t, ch, delta).forEach(r => { a += r.term; l += r.l1; });
      let val = powPartial * m((1 - t) + t * gi) * m(a) + l;
      if (opt.masks) val += ch.rhoL * libraUni(opt.masks, i, t, ch.u);
      S.push(m(val));
    }
    const trueS = S.slice(); let diff = 0;
    if (opt.astuto) { diff = m(target - S[0] - S[1]); for (let t = 0; t < LEN; t++) S[t] = m(S[t] + diff * (1 - t)); }
    rounds.push({ cols, powPartial, target, trueS, diff, gi });
    univariates.push(S);
    const u = ch.u[i];
    target = lagrangeEval(S, u); powPartial = m(powPartial * ((1 - u) + u * gi));
    cols = mapCols(cols, c => fold(c, u));
  }
  return { univariates, evals: mapCols(cols, c => c[0]), rounds };
}
function sumcheckVerify(univariates, evals, ch, delta, target, libraTerm) {
  target = target || 0; libraTerm = libraTerm || 0;
  let powPartial = 1, ok = true; const steps = [];
  for (let i = 0; i < univariates.length; i++) {
    const S = univariates[i], sum = m(S[0] + S[1]), good = sum === target, u = ch.u[i];
    const next = lagrangeEval(S, u), gi = pw(ch.g, 2 ** i, P), pnext = m(powPartial * (1 + u * (gi - 1)));
    steps.push({ i, S, sum, target, ok: good, u, next, gi, powBefore: powPartial, pow: pnext });
    if (!good) { ok = false; break; }
    target = next; powPartial = pnext;
  }
  const rs = subrelations(evals, ch.beta, ch.gamma, delta), b = splitBatch(rs, ch.alpha), full = m(powPartial * b.A + b.l1 + libraTerm);
  const fin = { rs, A: b.A, l1: b.l1, pow: powPartial, libraTerm, full, target, ok: ok && full === target, reached: ok };
  return { ok: fin.ok, steps, fin };
}

// ----- curva y^2 = x^3 + 3 sobre F_101, subgrupo de orden 17 -----
const G1 = [1, 2];
function ecAdd(A, B) {
  if (!A) return B; if (!B) return A;
  const [x1, y1] = A, [x2, y2] = B;
  if (x1 === x2 && mq(y1 + y2) === 0) return null;
  const lam = (x1 === x2 && y1 === y2) ? mq(3 * x1 * x1 * pw(2 * y1, Q - 2, Q)) : mq((y2 - y1) * pw(x2 - x1, Q - 2, Q));
  const x3 = mq(lam * lam - x1 - x2); return [x3, mq(lam * (x1 - x3) - y1)];
}
function ecMul(k, A) { k = m(k); let R = null; while (k) { if (k & 1) R = ecAdd(R, A); A = ecAdd(A, A); k >>= 1; } return R; }
function ecNeg(A) { return A ? [A[0], mq(-A[1])] : null; }
function ecEq(A, B) { return (!A && !B) || (A && B && A[0] === B[0] && A[1] === B[1]); }
const SRS = [0, 1, 2, 3, 4, 5].map(k => ecMul(pw(TAU, k, P), G1));   // hasta τ⁵: las máscaras tienen grado 5
function commit(c) { let C = null; c.forEach((ci, k) => { C = ecAdd(C, ecMul(ci, SRS[k])); }); return C; }
function dlog(A) { for (let k = 0; k < P; k++) if (ecEq(ecMul(k, G1), A)) return k; }

// ----- F_101^2 = F_101[i]/(i^2+2) y pairing de Tate -----
const f2 = (a, b) => [mq(a), mq(b || 0)];
const f2mul = (x, y) => f2(x[0] * y[0] - 2 * x[1] * y[1], x[0] * y[1] + x[1] * y[0]);
const f2sub = (x, y) => f2(x[0] - y[0], x[1] - y[1]);
const f2add = (x, y) => f2(x[0] + y[0], x[1] + y[1]);
function f2inv(x) { const n = pw(x[0] * x[0] + 2 * x[1] * x[1], Q - 2, Q); return f2(x[0] * n, -x[1] * n); }
function f2pow(x, e) { let r = f2(1); while (e) { if (e & 1) r = f2mul(r, x); x = f2mul(x, x); e >>= 1; } return r; }
function g2Double(A) { const [x, y] = A; const lam = f2mul(f2mul(f2(3), f2mul(x, x)), f2inv(f2mul(f2(2), y))); const x3 = f2sub(f2sub(f2mul(lam, lam), x), x); return [x3, f2sub(f2mul(lam, f2sub(x, x3)), y)]; }
const G2 = [f2(36), f2(0, 31)], TAU_G2 = g2Double(G2);
function line(R, S, Qp) {
  const [xr, yr] = R, [xs, ys] = S, [xq, yq] = Qp;
  if (xr === xs && mq(yr + ys) === 0) return f2sub(xq, f2(xr));
  const lam = (xr === xs && yr === ys) ? mq(3 * xr * xr * pw(2 * yr, Q - 2, Q)) : mq((ys - yr) * pw(xs - xr, Q - 2, Q));
  return f2sub(f2sub(yq, f2(yr)), f2mul(f2(lam), f2sub(xq, f2(xr))));
}
function pairing(A, Qp) {
  if (!A) return f2(1);
  let f = f2(1), R = A;
  for (const bit of '0001') { f = f2mul(f2mul(f, f), line(R, R, Qp)); R = ecAdd(R, R); if (bit === '1') { f = f2mul(f, line(R, A, Qp)); R = ecAdd(R, A); } }
  return f2pow(f, (Q * Q - 1) / P);
}

// ----- polinomios univariados -----
function pEval(c, x) { let s = 0; c.forEach((ci, i) => s += ci * pw(x, i, P)); return m(s); }
function pDivLinear(c, a) { const q = new Array(c.length - 1).fill(0); let carry = 0; for (let i = c.length - 1; i > 0; i--) { carry = m(c[i] + carry * a); q[i - 1] = carry; } return q; }
function pLin(terms, size) { const o = new Array(size || N).fill(0); terms.forEach(([s, c]) => c.forEach((ci, i) => { o[i] = m(o[i] + s * ci); })); return o; }

function geminiProve(cols, ch) {
  const { rho, r, u } = ch;
  const F = pLin(UNSHIFTED.map((k, j) => [pw(rho, j, P), cols[k]]));
  const G = pLin(TO_BE_SHIFTED.map((k, j) => [pw(rho, UNSHIFTED.length + j, P), cols[k]]));
  const A0 = F.map((f, k) => m(f + (k + 1 < N ? G[k + 1] : 0)));
  const folds = [A0]; u.forEach(ui => folds.push(fold(folds[folds.length - 1], ui)));
  const rInv = inv(r, 'r = 0 no sirve como desafío de Gemini');
  const A0pos = pLin([[1, F], [rInv, G]]), A0neg = pLin([[1, F], [-rInv, G]]);
  const a = [pEval(A0neg, -r), pEval(folds[1], -r * r)];
  return { F, G, folds, A0pos, A0neg, a, commA1: commit(folds[1]) };
}
function foldPosEvaluations(batchedEval, a, ch) {
  const out = new Array(D).fill(0), steps = []; let acc = batchedEval;
  for (let i = D; i > 0; i--) {
    const cp = pw(ch.r, 2 ** (i - 1), P), u = ch.u[i - 1], prev = acc;
    const numr = m(2 * cp * acc - a[i - 1] * (cp * (1 - u) - u)), den = m(cp * (1 - u) + u);
    acc = m(numr * inv(den, 'r^(2^' + (i - 1) + ')·(1−u)+u da 0: probá otro r'));
    out[i - 1] = acc; steps.push({ l: i - 1, cp, u, prev, a: a[i - 1], numr, den, res: acc });
  }
  return { pos: out, steps };
}
function shplonkProve(gem, ch) {
  const { r, nu, z } = ch, A1 = gem.folds[1].concat([0, 0]);
  const claims = [
    { name: 'A₀₊', f: gem.A0pos, x: m(r), v: pEval(gem.A0pos, r) },
    { name: 'A₀₋', f: gem.A0neg, x: m(-r), v: gem.a[0] },
    { name: 'A₁', f: A1, x: m(r * r), v: pEval(A1, r * r) },
    { name: 'A₁', f: A1, x: m(-r * r), v: gem.a[1] }];
  const Qp = pLin(claims.map((c, j) => [pw(nu, j, P), pDivLinear(c.f, c.x)]), N - 1);
  let G = Qp.concat([0]);
  claims.forEach((c, j) => { const s = m(pw(nu, j, P) * inv(z - c.x, 'z coincide con un punto de apertura (±r o ±r²): probá otro z')); G = pLin([[1, G], [-s, c.f], [s * c.v, [1]]]); });
  const W = pDivLinear(G, z);
  return { claims, Q: Qp, G, Gz: pEval(G, z), W, commQ: commit(Qp), commW: commit(W) };
}
function shpleminiVerify(vk, proof, ch) {
  const { rho, r, nu, z } = ch, ev = proof.evals, a = proof.geminiA;
  const comms = Object.assign({}, vk, proof.comm);
  let batchedEval = 0; ENTITIES.forEach((k, j) => batchedEval += pw(rho, j, P) * ev[k]); batchedEval = m(batchedEval);
  const fp = foldPosEvaluations(batchedEval, a, ch), pos = fp.pos;
  const bad = 'z coincide con un punto de apertura (±r o ±r²): probá otro z';
  const dpos0 = inv(z - r, bad), dneg0 = inv(z + r, bad), dpos1 = inv(z - r * r, bad), dneg1 = inv(z + r * r, bad);
  const lam = m(dpos0 + nu * dneg0), mu = m(inv(r) * (dpos0 - nu * dneg0));
  const xi = m(-(nu * nu) * dpos1 - pw(nu, 3, P) * dneg1);
  const kappa = m(pos[0] * dpos0 + a[0] * nu * dneg0 + nu * nu * pos[1] * dpos1 + pw(nu, 3, P) * a[1] * dneg1);
  const msm = [{ name: '[Q]', s: 1, C: proof.commQ }];
  const sc = {}; UNSHIFTED.forEach((k, j) => { sc[k] = m(-lam * pw(rho, j, P)); });
  TO_BE_SHIFTED.forEach((k, j) => { sc[k] = m(sc[k] - mu * pw(rho, UNSHIFTED.length + j, P)); });
  UNSHIFTED.forEach(k => msm.push({ name: '[' + k + ']', s: sc[k], C: comms[k] }));
  msm.push({ name: '[A₁]', s: xi, C: proof.commA1 }, { name: '[1]', s: kappa, C: G1 });
  let acc = null; msm.forEach(t => { acc = ecAdd(acc, ecMul(t.s, t.C)); });
  const P0 = ecAdd(acc, ecMul(z, proof.commW)), P1 = ecNeg(proof.commW);
  const e0 = pairing(P0, G2), e1 = pairing(P1, TAU_G2), lhs = f2mul(e0, e1);
  return { ok: lhs[0] === 1 && lhs[1] === 0, batchedEval, fp, pos, dpos0, dneg0, dpos1, dneg1, lam, mu, xi, kappa, msm, G: acc, P0, P1, e0, e1, lhs };
}

const kzgOpen = (c, x) => [pEval(c, x), commit(pDivLinear(c, x))];
function kzgCheck(C, x, v, W) { const l = ecAdd(ecAdd(C, ecMul(-v, G1)), ecMul(x, W)), e = f2mul(pairing(l, G2), pairing(ecNeg(W), TAU_G2)); return e[0] === 1 && e[1] === 0; }

const VK = mapCols(FIXED, c => commit(c));
// opt.astuto: parchea las univariadas · opt.lie: miente en una evaluación · opt.masks: máscara de sumcheck
function prove(wires, ch, opt) {
  opt = opt || {};
  const w = mapCols({ w_l: wires.w_l, w_r: wires.w_r, w_o: wires.w_o }, c => c.map(m)), lk = countLookups(w);
  const cols = Object.assign({}, FIXED, w, lk);
  const pub = w.w_l[PI_ROW], delta = publicDelta([pub], ch.beta, ch.gamma);   // el prover usa la entrada pública que escribió en la fila 1
  cols.I = computeInverses(cols, ch.gamma); cols.z = computeZ(cols, ch.beta, ch.gamma);
  const full = Object.assign({}, cols, { z_shift: cols.z.slice(1).concat([0]) });
  const sc = sumcheckProve(full, ch, delta, opt);
  const evals = Object.assign({}, sc.evals), trueEvals = sc.evals;
  if (opt.lie) evals[opt.lie] = m(evals[opt.lie] + 1);
  const gem = geminiProve(cols, ch), shp = shplonkProve(gem, ch);
  const comm = {}; WITNESS.forEach(k => { comm[k] = commit(cols[k]); });
  const proof = { comm, univariates: sc.univariates, evals, commA1: gem.commA1, geminiA: gem.a, commQ: shp.commQ, commW: shp.commW };
  if (opt.masks) {
    const [g0, g1] = opt.masks, o0 = kzgOpen(g0, ch.u[0]), o1 = kzgOpen(g1, ch.u[1]);
    proof.libra = { commG0: commit(g0), commG1: commit(g1), e0: o0[0], e1: o1[0], W0: o0[1], W1: o1[1], sum: maskSum(opt.masks) };
  }
  return { proof, aux: { cols, full, sc, gem, shp, trueEvals, delta, pub } };
}
function verify(vk, proof, pis, ch) {
  const delta = publicDelta(pis, ch.beta, ch.gamma); let target = 0, libraTerm = 0, okLibra = true;
  if (proof.libra) { const L = proof.libra; target = m(ch.rhoL * L.sum); libraTerm = m(ch.rhoL * (L.e0 + L.e1)); okLibra = kzgCheck(L.commG0, ch.u[0], L.e0, L.W0) && kzgCheck(L.commG1, ch.u[1], L.e1, L.W1); }
  const sc = sumcheckVerify(proof.univariates, proof.evals, ch, delta, target, libraTerm), pcs = shpleminiVerify(vk, proof, ch);
  return { ok: sc.ok && pcs.ok && okLibra, sc, pcs, okLibra, delta };
}

if (typeof module !== 'undefined') module.exports = { P, Q, N, D, LEN, FIXED, WITNESS, UNSHIFTED, ENTITIES, buildWires, prove, verify, VK, SRS, G2, TAU_G2, pairing, G1, dlog, commit, ecMul, subrelations, splitBatch, publicDelta, mapCols, m, pw };

