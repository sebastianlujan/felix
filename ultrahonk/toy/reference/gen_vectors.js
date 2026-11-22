// Generates ../src/vectors.fe from the reference implementation (./honk.js).
//
//   node reference/gen_vectors.js
//
// The output is deterministic: re-running reproduces the committed file byte
// for byte. The layout matches `fe fmt` (max width 100), so the generated
// file passes `fe fmt --check` without a formatting step.
'use strict';
const fs = require('fs');
const path = require('path');
const H = require('./honk.js');

// The page's example challenges ("dados del ejemplo", `DEF` in its UI script).
const DEFAULT = { beta: 2, gamma: 5, alpha: 3, g: 2, u: [9, 7], rho: 14, r: 4, nu: 5, z: 12 };
// A second, non-degenerate set: u_0 < 6 takes the Lagrange shortcut, u_1 >= 6 does not.
const ALT = { beta: 3, gamma: 8, alpha: 5, g: 6, u: [3, 12], rho: 10, r: 3, nu: 7, z: 5 };
// A set for which the honest opening proof is the point at infinity ([W] = P0 = infinity).
const INF = { beta: 5, gamma: 3, alpha: 7, g: 11, u: [3, 12], rho: 10, r: 3, nu: 7, z: 5 };
const X0 = 2, Y0 = 4;

const withU1 = (ch, u1) => Object.assign({}, ch, { u: [ch.u[0], u1] });
const brokenCopy = () => { const w = H.buildWires(15, Y0); w.w_l[3] = 2; return w; };

// name, page scenario, description, wires, prover options, verifier public input, challenges
const SCENARIOS = [
  ['HONEST', 'honesto', 'honest prover (x = 2, y = 4), example challenges', H.buildWires(X0, Y0), {}, Y0, DEFAULT],
  ['BROKEN_GATE', 'compuerta', 'x = 3 is in the table, but 3 * 3 != 4', H.buildWires(3, Y0), {}, Y0, DEFAULT],
  ['BROKEN_LOOKUP', 'tabla', 'x = 15 is a root, but it is not in the table', H.buildWires(15, Y0), {}, Y0, DEFAULT],
  ['BROKEN_COPY', 'copia', '15 in the gate, 2 in the lookup', brokenCopy(), {}, Y0, DEFAULT],
  ['WRONG_PUBLIC_INPUT', 'pub', 'the proof is for y = 4, the verifier uses y = 5', H.buildWires(X0, Y0), {}, 5, DEFAULT],
  ['PATCHED_UNIVARIATES', 'astuto', 'broken gate, the prover patches the univariates', H.buildWires(3, Y0), { astuto: true }, Y0, DEFAULT],
  ['LUCKY_DICE', 'suerte', 'same cheat, and the challenge u_1 comes out as 1', H.buildWires(3, Y0), { astuto: true }, Y0, withU1(DEFAULT, 1)],
  ['FALSE_EVALUATION', 'mentira', 'honest trace, but the prover lies in the evaluation of w_l', H.buildWires(X0, Y0), { lie: 'w_l' }, Y0, DEFAULT],
  ['HONEST_ALT', null, 'honest prover, second set of challenges', H.buildWires(X0, Y0), {}, Y0, ALT],
  ['HONEST_INFINITY', null, 'honest prover, challenges for which [W] is the point at infinity', H.buildWires(X0, Y0), {}, Y0, INF],
];

// ----- Fe literals, laid out like `fe fmt` -----
const WIDTH = 100;
const struct = (name, fields) => ({ name, fields });
const flat = n => Array.isArray(n) ? '[' + n.map(flat).join(', ') + ']'
  : n && n.fields ? n.name + ' { ' + n.fields.map(([k, v]) => k + ': ' + flat(v)).join(', ') + ' }'
  : String(n);
// `col` is the column where the literal starts; `trail` is what follows it on the same line.
function render(n, indent, col, trail) {
  const one = flat(n);
  if (typeof n !== 'object' || col + one.length + trail <= WIDTH) return one;
  const pad = ' '.repeat(indent + 4), close = ' '.repeat(indent);
  if (Array.isArray(n)) return '[\n' + n.map(x => pad + render(x, indent + 4, indent + 4, 1) + ',\n').join('') + close + ']';
  return n.name + ' {\n' + n.fields.map(([k, v]) => pad + k + ': ' + render(v, indent + 4, indent + 6 + k.length, 1) + ',\n').join('') + close + '}';
}
function konst(doc, name, type, value) {
  const head = 'pub const ' + name + ': ' + type + ' = ';
  return doc.map(d => '// ' + d + '\n').join('') + head + render(value, 0, head.length, 0) + '\n';
}

// The reference uses `null` for the point at infinity; the port uses (0, 0), which is not on the curve.
const pt = A => A ? [A[0], A[1]] : [0, 0];
const challenges = ch => struct('Challenges', ['beta', 'gamma', 'alpha', 'g', 'u', 'rho', 'r', 'nu', 'z'].map(k => [k, ch[k]]));
const proofLit = p => struct('Proof', [
  ['comm', H.WITNESS.map(k => pt(p.comm[k]))],
  ['univariates', p.univariates],
  ['evals', H.ENTITIES.map(k => p.evals[k])],
  ['comm_a1', pt(p.commA1)],
  ['gemini_a', p.geminiA],
  ['comm_q', pt(p.commQ)],
  ['comm_w', pt(p.commW)],
]);
// Rounds the reference did not run (it stops at the first failing round) are emitted as zeros.
function sumcheckTrace(sc) {
  const col = f => [0, 1].map(i => i < sc.steps.length ? f(sc.steps[i]) : 0), fin = sc.fin;
  return struct('SumcheckTrace', [
    ['ok', sc.ok], ['rounds_run', sc.steps.length], ['round_ok', [0, 1].map(i => i < sc.steps.length && sc.steps[i].ok)],
    ['sums', col(s => s.sum)], ['targets', col(s => s.target)], ['nexts', col(s => s.next)], ['pows', col(s => s.pow)],
    ['reached', fin.reached], ['rs', fin.rs], ['a', fin.A], ['l1', fin.l1], ['pow', fin.pow], ['full', fin.full], ['target', fin.target],
  ]);
}
function openingTrace(pcs) {
  const n = H.UNSHIFTED.length;   // msm = [Q], the 22 unshifted commitments, [A_1], [1]
  return struct('OpeningTrace', [
    ['ok', pcs.ok], ['batched_eval', pcs.batchedEval], ['pos', pcs.pos],
    ['lam', pcs.lam], ['mu', pcs.mu], ['xi', pcs.xi], ['kappa', pcs.kappa],
    ['scalars', pcs.msm.slice(1, 1 + n).map(t => t.s)],
    ['msm', pt(pcs.G)], ['p0', pt(pcs.P0)], ['p1', pt(pcs.P1)], ['e0', pcs.e0], ['e1', pcs.e1], ['lhs', pcs.lhs],
  ]);
}

const multiples = [...Array(H.P).keys()].map(k => H.ecMul(k, H.G1));
const out = [
  '// GENERATED by reference/gen_vectors.js from reference/honk.js. Do not edit.\n' +
  '// Regenerate with `node reference/gen_vectors.js`.\n' +
  'use ingot::{Challenges, OpeningTrace, Proof, Scenario, SumcheckTrace}\n',
  konst(['Verification key: commitments to the 15 fixed columns, in the order of ENTITIES.', 'The point at infinity is (0, 0).'],
    'VK', '[[u256; 2]; 15]', Object.keys(H.FIXED).map(k => pt(H.VK[k]))),
  konst(['[tau^k]_1 for k = 0..5 (tau = 2).'], 'SRS', '[[u256; 2]; 6]', H.SRS.map(pt)),
  konst(['G2 generator and [tau]_2, as (x, y) with coordinates a + b*i in F_101[i]/(i^2 + 2).'], 'G2', '[[u256; 2]; 2]', H.G2),
  konst([], 'TAU_G2', '[[u256; 2]; 2]', H.TAU_G2),
  konst(['k * G1 for k = 0..16.'], 'G1_MULTIPLES', '[[u256; 2]; 17]', multiples.map(pt)),
  konst(['e(k * G1, G2) for k = 0..16.'], 'PAIRINGS_G2', '[[u256; 2]; 17]', multiples.map(A => H.pairing(A, H.G2))),
  konst(['e(k * G1, [tau]_2) for k = 0..16.'], 'PAIRINGS_TAU_G2', '[[u256; 2]; 17]', multiples.map(A => H.pairing(A, H.TAU_G2))),
];
const summary = [];
for (const [name, page, desc, wires, opt, pub, ch] of SCENARIOS) {
  const { proof } = H.prove(wires, ch, opt), v = H.verify(H.VK, proof, [pub], ch);
  out.push(konst([(page ? 'Page scenario "' + page + '": ' : 'Extra scenario: ') + desc + '.', 'Reference verdict: ' + (v.ok ? 'accept' : 'reject') + '.'],
    name, 'Scenario', struct('Scenario', [
      ['proof', proofLit(proof)], ['public_inputs', [pub]], ['challenges', challenges(ch)], ['delta', v.delta],
      ['sumcheck', sumcheckTrace(v.sc)], ['opening', openingTrace(v.pcs)], ['ok', v.ok],
    ])));
  summary.push(name + ': ' + (v.ok ? 'accept' : 'reject') + ' (sumcheck ' + v.sc.ok + ', opening ' + v.pcs.ok + ')');
}
const file = path.join(__dirname, '..', 'src', 'vectors.fe');
fs.writeFileSync(file, out.join('\n'));
console.log('wrote ' + path.relative(process.cwd(), file) + '\n' + summary.join('\n'));
