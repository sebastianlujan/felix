"""Generates ../src/vectors.fe from the reference implementation (./honk.py).

    python3 reference/gen_vectors.py           # writes src/vectors.fe
    python3 reference/gen_vectors.py --check   # exits 1 if src/vectors.fe is out of date

The output is deterministic: re-running reproduces the committed file byte for byte. The
layout matches `fe fmt` (max width 100), so the generated file passes `fe fmt --check`
without a formatting step. Standard library only.
"""
import argparse
import os
import sys
from collections import namedtuple
from pathlib import Path

sys.dont_write_bytecode = True   # no reference/__pycache__ next to the committed sources
import honk as H  # noqa: E402

# The page's example challenges (`DEF` in its UI script).
DEFAULT = {'beta': 2, 'gamma': 5, 'alpha': 3, 'g': 2, 'u': [9, 7], 'rho': 14, 'r': 4, 'nu': 5,
           'z': 12}
# A second, non-degenerate set: u_0 < 6 takes the Lagrange shortcut, u_1 >= 6 does not.
ALT = {'beta': 3, 'gamma': 8, 'alpha': 5, 'g': 6, 'u': [3, 12], 'rho': 10, 'r': 3, 'nu': 7, 'z': 5}
# A set for which the honest opening proof is the point at infinity ([W] = P0 = infinity).
INF = {'beta': 5, 'gamma': 3, 'alpha': 7, 'g': 11, 'u': [3, 12], 'rho': 10, 'r': 3, 'nu': 7,
       'z': 5}
X0, Y0 = 2, 4


def with_u1(ch, u1):
    return {**ch, 'u': [ch['u'][0], u1]}


def broken_copy():
    w = H.build_wires(15, Y0)
    w['w_l'][3] = 2
    return w


# name, from the page, description, wires, prover options, verifier public input, challenges
SCENARIOS = [
    ('HONEST', True, 'honest prover (x = 2, y = 4), example challenges',
     H.build_wires(X0, Y0), {}, Y0, DEFAULT),
    ('BROKEN_GATE', True, 'x = 3 is in the table, but 3 * 3 != 4',
     H.build_wires(3, Y0), {}, Y0, DEFAULT),
    ('BROKEN_LOOKUP', True, 'x = 15 is a root, but it is not in the table',
     H.build_wires(15, Y0), {}, Y0, DEFAULT),
    ('BROKEN_COPY', True, '15 in the gate, 2 in the lookup', broken_copy(), {}, Y0, DEFAULT),
    ('WRONG_PUBLIC_INPUT', True, 'the proof is for y = 4, the verifier uses y = 5',
     H.build_wires(X0, Y0), {}, 5, DEFAULT),
    ('PATCHED_UNIVARIATES', True, 'broken gate, the prover patches the univariates',
     H.build_wires(3, Y0), {'patch': True}, Y0, DEFAULT),
    ('LUCKY_DICE', True, 'same cheat, and the challenge u_1 comes out as 1',
     H.build_wires(3, Y0), {'patch': True}, Y0, with_u1(DEFAULT, 1)),
    ('FALSE_EVALUATION', True, 'honest trace, but the prover lies in the evaluation of w_l',
     H.build_wires(X0, Y0), {'lie': 'w_l'}, Y0, DEFAULT),
    ('HONEST_ALT', False, 'honest prover, second set of challenges',
     H.build_wires(X0, Y0), {}, Y0, ALT),
    ('HONEST_INFINITY', False, 'honest prover, challenges for which [W] is the point at infinity',
     H.build_wires(X0, Y0), {}, Y0, INF),
]

# The sumcheck mask of the page's ZK section: its two masks (`MASKS` in the UI script, the
# coefficients of g_0 and g_1) and its extra challenge rho_L (`DEF.rhoL`).
MASKS = {'A': [[3, 1, 4, 1, 5, 9], [2, 7, 1, 8, 2, 8]],
         'B': [[6, 2, 8, 3, 1, 12], [11, 5, 3, 16, 9, 4]]}
RHO_L = 3
# name, description, wires, mask, change applied to the proof after proving (the reference
# prover has no option to cheat in the mask). All use the example challenges and y = 4.
MASKED_SCENARIOS = [
    ('MASKED_A', 'Page ZK section, mask A: honest prover with a masked sumcheck',
     H.build_wires(X0, Y0), MASKS['A'], None),
    ('MASKED_B', 'Page ZK section, mask B: honest prover with a masked sumcheck',
     H.build_wires(X0, Y0), MASKS['B'], None),
    ('MASKED_FALSE_EVALUATION',
     'Extra scenario: mask A, and the generator adds 1 to the claimed g_0(u_0)',
     H.build_wires(X0, Y0), MASKS['A'],
     lambda p: p['libra'].update(e0=H.m(p['libra']['e0'] + 1))),
    ('MASKED_WRONG_SUM', 'Extra scenario: mask A, and the generator adds 1 to the claimed mask sum',
     H.build_wires(X0, Y0), MASKS['A'],
     lambda p: p['libra'].update(sum=H.m(p['libra']['sum'] + 1))),
    ('MASKED_BROKEN_GATE', 'Extra scenario: mask A over the broken gate (x = 3)',
     H.build_wires(3, Y0), MASKS['A'], None),
]

# ----- Fe literals, laid out like `fe fmt` -----
WIDTH = 100
Struct = namedtuple('Struct', 'name fields')


def flat(n):
    if isinstance(n, list):
        return '[' + ', '.join(flat(x) for x in n) + ']'
    if isinstance(n, Struct):
        return n.name + ' { ' + ', '.join(k + ': ' + flat(v) for k, v in n.fields) + ' }'
    if isinstance(n, bool):   # before int: bool is an int in Python
        return 'true' if n else 'false'
    if isinstance(n, int):
        return str(n)
    raise TypeError(f'no Fe literal for {n!r}')


# `col` is the column where the literal starts; `trail` is what follows it on the same line.
def render(n, indent, col, trail):
    one = flat(n)
    if not isinstance(n, (list, Struct)) or col + len(one) + trail <= WIDTH:
        return one
    pad, close = ' ' * (indent + 4), ' ' * indent
    if isinstance(n, list):
        return ('[\n' + ''.join(pad + render(x, indent + 4, indent + 4, 1) + ',\n' for x in n)
                + close + ']')
    return (n.name + ' {\n'
            + ''.join(pad + k + ': ' + render(v, indent + 4, indent + 6 + len(k), 1) + ',\n'
                      for k, v in n.fields)
            + close + '}')


def konst(doc, name, type_, value):
    head = 'pub const ' + name + ': ' + type_ + ' = '
    return ''.join('// ' + d + '\n' for d in doc) + head + render(value, 0, len(head), 0) + '\n'


# The reference uses None for the point at infinity; the port uses (0, 0), which is not on the
# curve.
def pt(A):
    return [0, 0] if A is None else [A[0], A[1]]


def challenges(ch):
    keys = ['beta', 'gamma', 'alpha', 'g', 'u', 'rho', 'r', 'nu', 'z']
    return Struct('Challenges', [(k, ch[k]) for k in keys])


def proof_lit(p):
    return Struct('Proof', [
        ('comm', [pt(p['comm'][k]) for k in H.WITNESS]),
        ('univariates', p['univariates']),
        ('evals', [p['evals'][k] for k in H.ENTITIES]),
        ('comm_a1', pt(p['comm_a1'])),
        ('gemini_a', p['gemini_a']),
        ('comm_q', pt(p['comm_q'])),
        ('comm_w', pt(p['comm_w'])),
    ])


# Rounds the reference did not run (it stops at the first failing round) are emitted as zeros.
def sumcheck_trace(sc):
    steps, fin = sc['steps'], sc['fin']

    def col(key):
        return [steps[i][key] if i < len(steps) else 0 for i in (0, 1)]

    return Struct('SumcheckTrace', [
        ('ok', sc['ok']), ('rounds_run', len(steps)),
        ('round_ok', [i < len(steps) and steps[i]['ok'] for i in (0, 1)]),
        ('sums', col('sum')), ('targets', col('target')), ('nexts', col('next')),
        ('pows', col('pow')),
        ('reached', fin['reached']), ('rs', fin['rs']), ('a', fin['A']), ('l1', fin['l1']),
        ('pow', fin['pow']), ('full', fin['full']), ('target', fin['target']),
    ])


def opening_trace(pcs):
    n = len(H.UNSHIFTED)   # msm = [Q], the 22 unshifted commitments, [A_1], [1]
    return Struct('OpeningTrace', [
        ('ok', pcs['ok']), ('batched_eval', pcs['batched_eval']), ('pos', pcs['pos']),
        ('lam', pcs['lam']), ('mu', pcs['mu']), ('xi', pcs['xi']), ('kappa', pcs['kappa']),
        ('scalars', [t['s'] for t in pcs['msm'][1:1 + n]]),
        ('msm', pt(pcs['G'])), ('p0', pt(pcs['P0'])), ('p1', pt(pcs['P1'])),
        ('e0', pcs['e0']), ('e1', pcs['e1']), ('lhs', pcs['lhs']),
    ])


def verdict(ok):
    return 'accept' if ok else 'reject'


def bool_str(b):
    return 'true' if b else 'false'


def generate():
    """Returns the text of src/vectors.fe and a one-line summary per scenario."""
    multiples = [H.ec_mul(k, H.G1) for k in range(H.P)]
    out = [
        '// GENERATED by reference/gen_vectors.py from reference/honk.py. Do not edit.\n'
        '// Regenerate with `python3 reference/gen_vectors.py`.\n'
        'use ingot::{Challenges, OpeningTrace, Proof, Scenario, SumcheckTrace}\n'
        'use ingot::{Libra, LibraTrace, MaskedScenario}\n',
        konst(['Verification key: commitments to the 15 fixed columns, in the order of ENTITIES.',
               'The point at infinity is (0, 0).'],
              'VK', '[[u256; 2]; 15]', [pt(H.VK[k]) for k in H.FIXED]),
        konst(['[tau^k]_1 for k = 0..5 (tau = 2).'], 'SRS', '[[u256; 2]; 6]',
              [pt(A) for A in H.SRS]),
        konst(['G2 generator and [tau]_2, as (x, y) with coordinates a + b*i in '
               'F_101[i]/(i^2 + 2).'], 'G2', '[[u256; 2]; 2]', H.G2),
        konst([], 'TAU_G2', '[[u256; 2]; 2]', H.TAU_G2),
        konst(['k * G1 for k = 0..16.'], 'G1_MULTIPLES', '[[u256; 2]; 17]',
              [pt(A) for A in multiples]),
        konst(['e(k * G1, G2) for k = 0..16.'], 'PAIRINGS_G2', '[[u256; 2]; 17]',
              [H.pairing(A, H.G2) for A in multiples]),
        konst(['e(k * G1, [tau]_2) for k = 0..16.'], 'PAIRINGS_TAU_G2', '[[u256; 2]; 17]',
              [H.pairing(A, H.TAU_G2) for A in multiples]),
    ]
    summary = []
    for name, from_page, desc, wires, opt, pub, ch in SCENARIOS:
        proof, _ = H.prove(wires, ch, opt)
        v = H.verify(H.VK, proof, [pub], ch)
        intro = 'Page scenario: ' if from_page else 'Extra scenario: '
        out.append(konst([intro + desc + '.', 'Reference verdict: ' + verdict(v['ok']) + '.'],
                         name, 'Scenario', Struct('Scenario', [
                             ('proof', proof_lit(proof)), ('public_inputs', [pub]),
                             ('challenges', challenges(ch)), ('delta', v['delta']),
                             ('sumcheck', sumcheck_trace(v['sc'])),
                             ('opening', opening_trace(v['pcs'])), ('ok', v['ok']),
                         ])))
        summary.append(f"{name}: {verdict(v['ok'])} (sumcheck {bool_str(v['sc']['ok'])}, "
                       f"opening {bool_str(v['pcs']['ok'])})")
    for name, desc, wires, masks, change in MASKED_SCENARIOS:
        ch = {**DEFAULT, 'rho_l': RHO_L}
        proof, _ = H.prove(wires, ch, {'masks': masks})
        if change:
            change(proof)
        v, L = H.verify(H.VK, proof, [Y0], ch), proof['libra']
        kzg = [H.kzg_check(L['comm_g0'], ch['u'][0], L['e0'], L['w0']),
               H.kzg_check(L['comm_g1'], ch['u'][1], L['e1'], L['w1'])]
        if (kzg[0] and kzg[1]) != v['ok_libra']:
            raise AssertionError(name + ': kzg_check disagrees with verify')
        out.append(konst([desc + '.', 'Reference verdict: ' + verdict(v['ok']) + '.'],
                         name, 'MaskedScenario', Struct('MaskedScenario', [
                             ('proof', proof_lit(proof)),
                             ('libra', Struct('Libra', [
                                 ('comm_g0', pt(L['comm_g0'])), ('comm_g1', pt(L['comm_g1'])),
                                 ('sum', L['sum']), ('e0', L['e0']), ('e1', L['e1']),
                                 ('w0', pt(L['w0'])), ('w1', pt(L['w1'])),
                             ])),
                             ('public_inputs', [Y0]), ('challenges', challenges(ch)),
                             ('rho_l', ch['rho_l']), ('delta', v['delta']),
                             # target: the initial sumcheck target rho_L * sum;
                             # libra_term: rho_L * (e0 + e1).
                             ('mask', Struct('LibraTrace', [
                                 ('ok', v['ok_libra']), ('target', v['sc']['steps'][0]['target']),
                                 ('libra_term', v['sc']['fin']['libra_term']), ('kzg_ok', kzg),
                             ])),
                             ('sumcheck', sumcheck_trace(v['sc'])),
                             ('opening', opening_trace(v['pcs'])), ('ok', v['ok']),
                         ])))
        summary.append(f"{name}: {verdict(v['ok'])} (sumcheck {bool_str(v['sc']['ok'])}, "
                       f"opening {bool_str(v['pcs']['ok'])}, mask {bool_str(v['ok_libra'])})")
    return '\n'.join(out), summary


def main():
    parser = argparse.ArgumentParser(description='Generate src/vectors.fe from reference/honk.py.')
    parser.add_argument('--check', action='store_true',
                        help='do not write; exit 1 if src/vectors.fe differs from the output')
    args = parser.parse_args()
    file = Path(__file__).resolve().parent.parent / 'src' / 'vectors.fe'
    rel = os.path.relpath(file)
    text, summary = generate()
    data = text.encode('utf-8')
    if args.check:
        if file.exists() and file.read_bytes() == data:
            print(rel + ' is up to date')
            return 0
        print(rel + ' differs from the generator output; run python3 reference/gen_vectors.py',
              file=sys.stderr)
        return 1
    file.write_bytes(data)
    print('wrote ' + rel + '\n' + '\n'.join(summary))
    return 0


if __name__ == '__main__':
    sys.exit(main())
