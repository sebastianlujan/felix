"""Reference implementation: the math block of the teaching page "UltraHonk by hand",
https://claude.ai/artifact/TiC5eZeQs2U1Q9V3nAudPZ (first inline <script> block, no DOM),
ported to Python (standard library only).

The port keeps the page's order, function structure and names, in snake_case
(`sumcheckVerify` is `sumcheck_verify`), so it reads side by side with the page. Objects
are dicts, with snake_case keys (`commA1` is `comm_a1`); the point at infinity is None.

Toy Honk over F_17, with a public input and a lookup, as on the page "UltraHonk by hand".
"""

P, Q, N, D, LEN, TAU, SEP, PI_ROW = 17, 101, 4, 2, 6, 2, 4, 1


# The page normalizes with ((x % P) + P) % P; Python's % is already non-negative here.
def m(x):
    return x % P


def mq(x):
    return x % Q


def pw(b, e, mod):
    r, b = 1, b % mod
    while e > 0:
        if e & 1:
            r = r * b % mod
        b = b * b % mod
        e >>= 1
    return r


def inv(a, why=None):
    a = m(a)
    if a == 0:
        raise ZeroDivisionError(why or 'division by zero')
    return pw(a, P - 2, P)


# row 0: zeros; row 1: public input (w_l = w_r = y); row 2: x*x = y; row 3: lookup of x in t
FIXED = {
    'q_m': [0, 0, 1, 0], 'q_c': [0, 0, 0, 0], 'q_l': [0, 0, 0, 0], 'q_r': [0, 0, 0, 0],
    'q_o': [0, 0, 16, 0], 'q_lk': [0, 0, 0, 1],
    's1': [0, 15, 6, 2], 's2': [4, 10, 3, 7], 's3': [8, 9, 1, 11],
    'id1': [0, 1, 2, 3], 'id2': [4, 5, 6, 7], 'id3': [8, 9, 10, 11],
    'L_first': [1, 0, 0, 0], 'L_last': [0, 0, 0, 1], 't': [0, 1, 2, 3],
}
WITNESS = ['w_l', 'w_r', 'w_o', 'm', 'tag', 'I', 'z']
UNSHIFTED = list(FIXED) + WITNESS     # 22
TO_BE_SHIFTED = ['z']
ENTITIES = UNSHIFTED + ['z_shift']    # 23 evaluations
POWED = [1, 1, 1, 1, 1, 0, 1]         # subrelation 5 (the LogUp sum) carries no pow
NREL = 7


def build_wires(x, y):
    return {'w_l': [0, y, x, x], 'w_r': [0, y, x, 0], 'w_o': [0, 0, y, 0]}


def count_lookups(wires):
    mm, tag = [0, 0, 0, 0], [0, 0, 0, 0]
    for row in range(N):
        if FIXED['q_lk'][row]:
            for k in range(N):
                if FIXED['t'][k] == m(wires['w_l'][row]):
                    mm[k] += 1
                    tag[k] = 1
                    break
    return {'m': mm, 'tag': tag}


def fold(t, u):
    return [m((1 - u) * t[2 * j] + u * t[2 * j + 1]) for j in range(len(t) // 2)]


def map_cols(cols, f):
    return {k: f(c) for k, c in cols.items()}


def public_delta(pis, beta, gamma):
    num, den = 1, 1
    na, da = gamma + beta * (SEP + PI_ROW), gamma - beta * (PI_ROW + 1)
    for pi in pis:
        num, den = m(num * (na + pi)), m(den * (da + pi))
        na += beta
        da -= beta
    return m(num * inv(den, 'the denominator of delta is 0: try other beta, gamma'))


def compute_inverses(cols, gamma):
    return [
        inv((cols['w_l'][k] + gamma) * (cols['t'][k] + gamma),
            f'a lookup term is 0 in row {k}: try another gamma')
        if cols['tag'][k] or cols['q_lk'][k] else 0
        for k in range(4)
    ]


def perm_factors(v, beta, gamma):
    num = m(m(v['w_l'] + beta * v['id1'] + gamma) * m(v['w_r'] + beta * v['id2'] + gamma)
            * m(v['w_o'] + beta * v['id3'] + gamma))
    den = m(m(v['w_l'] + beta * v['s1'] + gamma) * m(v['w_r'] + beta * v['s2'] + gamma)
            * m(v['w_o'] + beta * v['s3'] + gamma))
    return num, den


def subrelations(v, beta, gamma, delta):
    r0 = (v['q_m'] * v['w_l'] * v['w_r'] + v['q_l'] * v['w_l'] + v['q_r'] * v['w_r']
          + v['q_o'] * v['w_o'] + v['q_c'])
    num, den = perm_factors(v, beta, gamma)
    r1 = (v['z'] + v['L_first']) * num - (v['z_shift'] + v['L_last'] * delta) * den
    read, write = m(v['w_l'] + gamma), m(v['t'] + gamma)
    l0 = m(read * write) * v['I'] - (v['tag'] + v['q_lk'] - v['tag'] * v['q_lk'])
    l1 = v['q_lk'] * m(v['I'] * write) - v['m'] * m(v['I'] * read)
    rs = [r0, r1, v['L_last'] * v['z_shift'], v['L_first'] * v['z'], l0, l1,
          v['tag'] * v['tag'] - v['tag']]
    return [m(r) for r in rs]


# A = the six subrelations that carry pow, batched with alpha; l1 = alpha^5 * L_1, without pow
def split_batch(rs, alpha):
    A = sum(r * pw(alpha, i, P) for i, r in enumerate(rs) if POWED[i])
    return m(A), m(pw(alpha, 5, P) * rs[5])


def batched(v, ch, delta, powv):
    A, l1 = split_batch(subrelations(v, ch['beta'], ch['gamma'], delta), ch['alpha'])
    return m(powv * A + l1)


def compute_z(cols, beta, gamma):
    z = [0, 1]
    for i in range(1, N - 1):
        num, den = perm_factors(map_cols(cols, lambda c: c[i]), beta, gamma)
        why = f'the denominator of z_perm in row {i} is 0: try other beta, gamma'
        z.append(m(z[-1] * num * inv(den, why)))
    return z


def lagrange_eval(S, u):
    u = m(u)
    if u < len(S):
        return S[u]
    tot = 0
    for i in range(len(S)):
        num, den = 1, 1
        for j in range(len(S)):
            if j != i:
                num, den = m(num * (u - j)), m(den * (i - j))
        tot += S[i] * num * inv(den)
    return m(tot)


def round_terms(cols, i, t, ch, delta):   # by-hand detail of one evaluation S_i(t)
    g_rest, half, rows = pw(ch['g'], 2 ** (i + 1), P), len(cols['w_l']) // 2, []
    for j in range(half):
        v = map_cols(cols, lambda c: m(c[2 * j] + t * (c[2 * j + 1] - c[2 * j])))
        rs = subrelations(v, ch['beta'], ch['gamma'], delta)
        A, l1 = split_batch(rs, ch['alpha'])
        pj = pw(g_rest, j, P)
        rows.append({'j': j, 'v': v, 'rs': rs, 'A': A, 'l1': l1, 'pj': pj, 'term': m(pj * A)})
    return rows


def mask_sum(masks):
    g0, g1 = masks
    return m(2 * (p_eval(g0, 0) + p_eval(g0, 1)) + 2 * (p_eval(g1, 0) + p_eval(g1, 1)))


def libra_uni(masks, i, t, us):
    g0, g1 = masks
    if i == 0:
        return m(2 * p_eval(g0, t) + p_eval(g1, 0) + p_eval(g1, 1))
    return m(p_eval(g0, us[0]) + p_eval(g1, t))


def sumcheck_prove(cols, ch, delta, opt=None):
    opt = opt or {}
    cols = map_cols(cols, list)
    univariates, rounds, pow_partial = [], [], 1
    target = m(ch['rho_l'] * mask_sum(opt['masks'])) if opt.get('masks') else 0
    for i in range(D):
        gi, S = pw(ch['g'], 2 ** i, P), []
        for t in range(LEN):
            terms = round_terms(cols, i, t, ch, delta)
            a, l1 = sum(r['term'] for r in terms), sum(r['l1'] for r in terms)
            val = pow_partial * m((1 - t) + t * gi) * m(a) + l1
            if opt.get('masks'):
                val += ch['rho_l'] * libra_uni(opt['masks'], i, t, ch['u'])
            S.append(m(val))
        true_s, diff = S[:], 0
        if opt.get('patch'):
            diff = m(target - S[0] - S[1])
            S = [m(s + diff * (1 - t)) for t, s in enumerate(S)]
        rounds.append({'cols': cols, 'pow_partial': pow_partial, 'target': target,
                       'true_s': true_s, 'diff': diff, 'gi': gi})
        univariates.append(S)
        u = ch['u'][i]
        target, pow_partial = lagrange_eval(S, u), m(pow_partial * ((1 - u) + u * gi))
        cols = map_cols(cols, lambda c: fold(c, u))
    return {'univariates': univariates, 'evals': map_cols(cols, lambda c: c[0]), 'rounds': rounds}


def sumcheck_verify(univariates, evals, ch, delta, target=0, libra_term=0):
    pow_partial, ok, steps = 1, True, []
    for i, S in enumerate(univariates):
        total, u = m(S[0] + S[1]), ch['u'][i]
        good = total == target
        nxt, gi = lagrange_eval(S, u), pw(ch['g'], 2 ** i, P)
        pnext = m(pow_partial * (1 + u * (gi - 1)))
        steps.append({'i': i, 'S': S, 'sum': total, 'target': target, 'ok': good, 'u': u,
                      'next': nxt, 'gi': gi, 'pow_before': pow_partial, 'pow': pnext})
        if not good:
            ok = False
            break
        target, pow_partial = nxt, pnext
    rs = subrelations(evals, ch['beta'], ch['gamma'], delta)
    A, l1 = split_batch(rs, ch['alpha'])
    full = m(pow_partial * A + l1 + libra_term)
    fin = {'rs': rs, 'A': A, 'l1': l1, 'pow': pow_partial, 'libra_term': libra_term, 'full': full,
           'target': target, 'ok': ok and full == target, 'reached': ok}
    return {'ok': fin['ok'], 'steps': steps, 'fin': fin}


# ----- curve y^2 = x^3 + 3 over F_101, subgroup of order 17 -----
G1 = [1, 2]


def ec_add(A, B):
    if A is None:
        return B
    if B is None:
        return A
    (x1, y1), (x2, y2) = A, B
    if x1 == x2 and mq(y1 + y2) == 0:
        return None
    if x1 == x2 and y1 == y2:
        lam = mq(3 * x1 * x1 * pw(2 * y1, Q - 2, Q))
    else:
        lam = mq((y2 - y1) * pw(x2 - x1, Q - 2, Q))
    x3 = mq(lam * lam - x1 - x2)
    return [x3, mq(lam * (x1 - x3) - y1)]


def ec_mul(k, A):
    k, R = m(k), None
    while k:
        if k & 1:
            R = ec_add(R, A)
        A = ec_add(A, A)
        k >>= 1
    return R


def ec_neg(A):
    return [A[0], mq(-A[1])] if A is not None else None


def ec_eq(A, B):
    return A == B


SRS = [ec_mul(pw(TAU, k, P), G1) for k in range(6)]   # up to tau^5: the masks have degree 5


def commit(c):
    C = None
    for k, ci in enumerate(c):
        C = ec_add(C, ec_mul(ci, SRS[k]))
    return C


def dlog(A):
    for k in range(P):
        if ec_eq(ec_mul(k, G1), A):
            return k
    return None


# ----- F_101^2 = F_101[i]/(i^2 + 2) and the Tate pairing -----
def f2(a, b=0):
    return [mq(a), mq(b)]


def f2_mul(x, y):
    return f2(x[0] * y[0] - 2 * x[1] * y[1], x[0] * y[1] + x[1] * y[0])


def f2_sub(x, y):
    return f2(x[0] - y[0], x[1] - y[1])


def f2_add(x, y):
    return f2(x[0] + y[0], x[1] + y[1])


def f2_inv(x):
    n = pw(x[0] * x[0] + 2 * x[1] * x[1], Q - 2, Q)
    return f2(x[0] * n, -x[1] * n)


def f2_pow(x, e):
    r = f2(1)
    while e:
        if e & 1:
            r = f2_mul(r, x)
        x = f2_mul(x, x)
        e >>= 1
    return r


def g2_double(A):
    x, y = A
    lam = f2_mul(f2_mul(f2(3), f2_mul(x, x)), f2_inv(f2_mul(f2(2), y)))
    x3 = f2_sub(f2_sub(f2_mul(lam, lam), x), x)
    return [x3, f2_sub(f2_mul(lam, f2_sub(x, x3)), y)]


G2 = [f2(36), f2(0, 31)]
TAU_G2 = g2_double(G2)


def line(R, S, Qp):
    (xr, yr), (xs, ys), (xq, yq) = R, S, Qp
    if xr == xs and mq(yr + ys) == 0:
        return f2_sub(xq, f2(xr))
    if xr == xs and yr == ys:
        lam = mq(3 * xr * xr * pw(2 * yr, Q - 2, Q))
    else:
        lam = mq((ys - yr) * pw(xs - xr, Q - 2, Q))
    return f2_sub(f2_sub(yq, f2(yr)), f2_mul(f2(lam), f2_sub(xq, f2(xr))))


def pairing(A, Qp):
    if A is None:
        return f2(1)
    f, R = f2(1), A
    for bit in '0001':
        f = f2_mul(f2_mul(f, f), line(R, R, Qp))
        R = ec_add(R, R)
        if bit == '1':
            f = f2_mul(f, line(R, A, Qp))
            R = ec_add(R, A)
    return f2_pow(f, (Q * Q - 1) // P)


# ----- univariate polynomials -----
def p_eval(c, x):
    return m(sum(ci * pw(x, i, P) for i, ci in enumerate(c)))


def p_div_linear(c, a):
    q, carry = [0] * (len(c) - 1), 0
    for i in range(len(c) - 1, 0, -1):
        carry = m(c[i] + carry * a)
        q[i - 1] = carry
    return q


def p_lin(terms, size=None):
    o = [0] * (size or N)
    for s, c in terms:
        for i, ci in enumerate(c):
            o[i] = m(o[i] + s * ci)
    return o


def gemini_prove(cols, ch):
    rho, r, u = ch['rho'], ch['r'], ch['u']
    F = p_lin([(pw(rho, j, P), cols[k]) for j, k in enumerate(UNSHIFTED)])
    G = p_lin([(pw(rho, len(UNSHIFTED) + j, P), cols[k]) for j, k in enumerate(TO_BE_SHIFTED)])
    A0 = [m(f + (G[k + 1] if k + 1 < N else 0)) for k, f in enumerate(F)]
    folds = [A0]
    for ui in u:
        folds.append(fold(folds[-1], ui))
    r_inv = inv(r, 'r = 0 is not a valid Gemini challenge')
    A0pos, A0neg = p_lin([(1, F), (r_inv, G)]), p_lin([(1, F), (-r_inv, G)])
    a = [p_eval(A0neg, -r), p_eval(folds[1], -r * r)]
    return {'F': F, 'G': G, 'folds': folds, 'a0_pos': A0pos, 'a0_neg': A0neg, 'a': a,
            'comm_a1': commit(folds[1])}


def fold_pos_evaluations(batched_eval, a, ch):
    out, steps, acc = [0] * D, [], batched_eval
    for i in range(D, 0, -1):
        cp, u, prev = pw(ch['r'], 2 ** (i - 1), P), ch['u'][i - 1], acc
        numr = m(2 * cp * acc - a[i - 1] * (cp * (1 - u) - u))
        den = m(cp * (1 - u) + u)
        acc = m(numr * inv(den, f'r^(2^{i - 1}) * (1 - u) + u is 0: try another r'))
        out[i - 1] = acc
        steps.append({'l': i - 1, 'cp': cp, 'u': u, 'prev': prev, 'a': a[i - 1], 'numr': numr,
                      'den': den, 'res': acc})
    return {'pos': out, 'steps': steps}


BAD_Z = 'z coincides with an opening point (±r or ±r²): try another z'


def shplonk_prove(gem, ch):
    r, nu, z = ch['r'], ch['nu'], ch['z']
    A1 = gem['folds'][1] + [0, 0]
    claims = [
        {'name': 'A₀₊', 'f': gem['a0_pos'], 'x': m(r), 'v': p_eval(gem['a0_pos'], r)},
        {'name': 'A₀₋', 'f': gem['a0_neg'], 'x': m(-r), 'v': gem['a'][0]},
        {'name': 'A₁', 'f': A1, 'x': m(r * r), 'v': p_eval(A1, r * r)},
        {'name': 'A₁', 'f': A1, 'x': m(-r * r), 'v': gem['a'][1]},
    ]
    Qp = p_lin([(pw(nu, j, P), p_div_linear(c['f'], c['x'])) for j, c in enumerate(claims)], N - 1)
    G = Qp + [0]
    for j, c in enumerate(claims):
        s = m(pw(nu, j, P) * inv(z - c['x'], BAD_Z))
        G = p_lin([(1, G), (-s, c['f']), (s * c['v'], [1])])
    W = p_div_linear(G, z)
    return {'claims': claims, 'Q': Qp, 'G': G, 'Gz': p_eval(G, z), 'W': W,
            'comm_q': commit(Qp), 'comm_w': commit(W)}


def shplemini_verify(vk, proof, ch):
    rho, r, nu, z = ch['rho'], ch['r'], ch['nu'], ch['z']
    ev, a = proof['evals'], proof['gemini_a']
    comms = {**vk, **proof['comm']}
    batched_eval = m(sum(pw(rho, j, P) * ev[k] for j, k in enumerate(ENTITIES)))
    fp = fold_pos_evaluations(batched_eval, a, ch)
    pos = fp['pos']
    dpos0, dneg0 = inv(z - r, BAD_Z), inv(z + r, BAD_Z)
    dpos1, dneg1 = inv(z - r * r, BAD_Z), inv(z + r * r, BAD_Z)
    lam, mu = m(dpos0 + nu * dneg0), m(inv(r) * (dpos0 - nu * dneg0))
    xi = m(-(nu * nu) * dpos1 - pw(nu, 3, P) * dneg1)
    kappa = m(pos[0] * dpos0 + a[0] * nu * dneg0 + nu * nu * pos[1] * dpos1
              + pw(nu, 3, P) * a[1] * dneg1)
    msm = [{'name': '[Q]', 's': 1, 'C': proof['comm_q']}]
    sc = {k: m(-lam * pw(rho, j, P)) for j, k in enumerate(UNSHIFTED)}
    for j, k in enumerate(TO_BE_SHIFTED):
        sc[k] = m(sc[k] - mu * pw(rho, len(UNSHIFTED) + j, P))
    msm += [{'name': f'[{k}]', 's': sc[k], 'C': comms[k]} for k in UNSHIFTED]
    msm += [{'name': '[A₁]', 's': xi, 'C': proof['comm_a1']}, {'name': '[1]', 's': kappa, 'C': G1}]
    acc = None
    for t in msm:
        acc = ec_add(acc, ec_mul(t['s'], t['C']))
    P0, P1 = ec_add(acc, ec_mul(z, proof['comm_w'])), ec_neg(proof['comm_w'])
    e0, e1 = pairing(P0, G2), pairing(P1, TAU_G2)
    lhs = f2_mul(e0, e1)
    return {'ok': lhs[0] == 1 and lhs[1] == 0, 'batched_eval': batched_eval, 'fp': fp, 'pos': pos,
            'dpos0': dpos0, 'dneg0': dneg0, 'dpos1': dpos1, 'dneg1': dneg1, 'lam': lam, 'mu': mu,
            'xi': xi, 'kappa': kappa, 'msm': msm, 'G': acc, 'P0': P0, 'P1': P1, 'e0': e0, 'e1': e1,
            'lhs': lhs}


def kzg_open(c, x):
    return p_eval(c, x), commit(p_div_linear(c, x))


def kzg_check(C, x, v, W):
    lhs = ec_add(ec_add(C, ec_mul(-v, G1)), ec_mul(x, W))
    e = f2_mul(pairing(lhs, G2), pairing(ec_neg(W), TAU_G2))
    return e[0] == 1 and e[1] == 0


VK = map_cols(FIXED, commit)


# opt['patch']: patches the univariates (the page's cheating prover) · opt['lie']: lies in one
# evaluation · opt['masks']: sumcheck mask
def prove(wires, ch, opt=None):
    opt = opt or {}
    w = {k: [m(x) for x in wires[k]] for k in ('w_l', 'w_r', 'w_o')}
    lk = count_lookups(w)
    cols = {**FIXED, **w, **lk}
    # the prover uses the public input it wrote in row 1
    pub = w['w_l'][PI_ROW]
    delta = public_delta([pub], ch['beta'], ch['gamma'])
    cols['I'] = compute_inverses(cols, ch['gamma'])
    cols['z'] = compute_z(cols, ch['beta'], ch['gamma'])
    full = {**cols, 'z_shift': cols['z'][1:] + [0]}
    sc = sumcheck_prove(full, ch, delta, opt)
    evals, true_evals = dict(sc['evals']), sc['evals']
    if opt.get('lie'):
        evals[opt['lie']] = m(evals[opt['lie']] + 1)
    gem = gemini_prove(cols, ch)
    shp = shplonk_prove(gem, ch)
    comm = {k: commit(cols[k]) for k in WITNESS}
    proof = {'comm': comm, 'univariates': sc['univariates'], 'evals': evals,
             'comm_a1': gem['comm_a1'], 'gemini_a': gem['a'], 'comm_q': shp['comm_q'],
             'comm_w': shp['comm_w']}
    if opt.get('masks'):
        g0, g1 = opt['masks']
        o0, o1 = kzg_open(g0, ch['u'][0]), kzg_open(g1, ch['u'][1])
        proof['libra'] = {'comm_g0': commit(g0), 'comm_g1': commit(g1), 'e0': o0[0], 'e1': o1[0],
                          'w0': o0[1], 'w1': o1[1], 'sum': mask_sum(opt['masks'])}
    aux = {'cols': cols, 'full': full, 'sc': sc, 'gem': gem, 'shp': shp,
           'true_evals': true_evals, 'delta': delta, 'pub': pub}
    return proof, aux


def verify(vk, proof, pis, ch):
    delta = public_delta(pis, ch['beta'], ch['gamma'])
    target, libra_term, ok_libra = 0, 0, True
    if proof.get('libra'):
        L = proof['libra']
        target = m(ch['rho_l'] * L['sum'])
        libra_term = m(ch['rho_l'] * (L['e0'] + L['e1']))
        ok_libra = (kzg_check(L['comm_g0'], ch['u'][0], L['e0'], L['w0'])
                    and kzg_check(L['comm_g1'], ch['u'][1], L['e1'], L['w1']))
    sc = sumcheck_verify(proof['univariates'], proof['evals'], ch, delta, target, libra_term)
    pcs = shplemini_verify(vk, proof, ch)
    return {'ok': sc['ok'] and pcs['ok'] and ok_libra, 'sc': sc, 'pcs': pcs, 'ok_libra': ok_libra,
            'delta': delta}
