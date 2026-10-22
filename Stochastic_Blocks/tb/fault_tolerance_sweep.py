"""Issue #33 / A2: fault tolerance of an 8-bit SC multiply vs binary multipliers.

SC path follows the RTL (sc_multiply_chain_top_sync / fused SCMUL tile): two BTS
(galois LFSR WIDTH=8, seeds 1 and 204), stream bit = (state <= value) with the
compare done before the LFSR advances, AND, ones-count over N=255 cycles.
Binary path: 8x8 -> 16-bit product. Both are scored against ideal a*b/255 on a
0..255 scale (binary reads its product as product/255).

Error = |output - a*b/255| in percent of full scale (255), mean and p99 over random (a, b).

SC fault locations (each also reported separately):
  sc_stream  flips on the a, b and product streams (one bit per cycle each)
  sc_inreg   the two 8-bit registers holding a and b during the burst (BTS binary_in_d)
  sc_lfsr    the 8 state bits of each LFSR
  sc_cnt     the 8-bit ones-count register in the STB
  sc_all     all four at once (the whole multiplier is faulty)
  sc_tmr_out three complete copies, all locations faulty, bitwise vote on the final count
  sc_shield  streams and LFSR state unprotected; the a/b registers and the count register are
             triplicated with a voter that rewrites the voted value every cycle, so a bit is
             wrong only if two copies flip in the same cycle (p_eff = 3p^2 - 2p^3 per cycle)
  sc_shield_all  as sc_shield but the LFSR state bits are scrubbed-TMR too; only the streams
             themselves are unprotected (40 state bits triplicated)
  sc_tmr_ideal  three copies voting on the product *stream*, registers/LFSR/counter assumed
                fault-free (optimistic upper bound)
Binary: bin_raw, bin_parity (product parity, detect + one recompute), bin_tmr (3 copies,
bitwise vote on the product, operand registers faulty per copy).

Exposure conventions for flip probability p:
  per_op     every stored bit sees p once per operation (stream bits p each); SC registers get
             p/255 per cycle so the expected flips per operation match binary's
  per_cycle  every bit sees p on every clock. SC registers are held for 255 cycles; binary does
             the whole multiply in one cycle. This is the physically motivated one.
Flip models: "uniform" and "burst" (runs of 8 adjacent bits; streams and binary words only).

Run: python3 fault_tolerance_sweep.py     Output: results/fault_tolerance.csv
"""

import csv
import os

import numpy as np
from pylfsr import LFSR

from accuracy_and_correlation_sweep import fpoly_for, state_to_int

W = 8
N = 255
SEED_A, SEED_B = 1, 204
TRIALS = 3000
BURST = 8
PER_OP = [0.01, 0.02, 0.05, 0.10, 0.15]
PER_CYCLE = [1e-5, 1e-4, 3e-4, 1e-3, 3e-3]
rng = np.random.default_rng(33)


def build_next():
    nxt = np.zeros(256, dtype=np.int64)
    for s in range(1, 256):
        init = [(s >> (W - 1 - j)) & 1 for j in range(W)]
        ref = LFSR(fpoly=fpoly_for(W), initstate=init, conf="galois", verbose=False)
        ref.next()
        nxt[s] = state_to_int(ref.state, W)
    return nxt  # nxt[0] = 0: the all-zero lock-up state


NEXT = build_next()


def flip_mask(shape_bits, p, model):
    """Boolean flip mask [TRIALS, shape_bits]; burst keeps the same expected flips per row."""
    if p == 0:
        return np.zeros((TRIALS, shape_bits), dtype=bool)
    if model == "uniform":
        return rng.random((TRIALS, shape_bits)) < p
    m = np.zeros((TRIALS, shape_bits), dtype=bool)
    n_b = rng.poisson(p * shape_bits / BURST, size=TRIALS)
    for i in np.nonzero(n_b)[0]:
        for _ in range(n_b[i]):
            st = rng.integers(0, shape_bits)
            m[i, st:st + BURST] ^= True
    return m


def reg_flip(p):
    """Per-cycle flips of an 8-bit register, as an XOR mask [TRIALS]."""
    if p == 0:
        return 0
    return ((rng.random((TRIALS, 8)) < p).astype(np.int64) << np.arange(8)).sum(axis=1)


def bits_of(x, n):
    return ((x[:, None] >> np.arange(n)) & 1).astype(bool)


def val_of(b):
    return (b.astype(np.int64) << np.arange(b.shape[1])).sum(axis=1)


def sc_run(a, b, rates, model):
    """One SC multiplier; rates = per-cycle p for stream / reg / lfsr / cnt. Returns 8-bit count."""
    ps, pr, pl, pc = rates
    fs = [flip_mask(N, ps, model) for _ in range(3)] if ps else None
    sa = np.full(TRIALS, SEED_A, dtype=np.int64)
    sb = np.full(TRIALS, SEED_B, dtype=np.int64)
    ra, rb = a.copy(), b.copy()
    cnt = np.zeros(TRIALS, dtype=np.int64)
    for c in range(N):
        ba = sa <= ra
        bb = sb <= rb
        if fs is not None:
            ba = ba ^ fs[0][:, c]
            bb = bb ^ fs[1][:, c]
        bp = ba & bb
        if fs is not None:
            bp = bp ^ fs[2][:, c]
        cnt = (cnt + bp) & 0xFF
        if pr:
            ra, rb = ra ^ reg_flip(pr), rb ^ reg_flip(pr)
        if pl:
            sa, sb = sa ^ reg_flip(pl), sb ^ reg_flip(pl)
        if pc:
            cnt = cnt ^ reg_flip(pc)
        sa, sb = NEXT[sa], NEXT[sb]
    return cnt


def sc_tmr_ideal(a, b, p, model):
    base_a = np.empty((TRIALS, N), dtype=bool)
    base_b = np.empty((TRIALS, N), dtype=bool)
    sa = np.full(TRIALS, SEED_A, dtype=np.int64)
    sb = np.full(TRIALS, SEED_B, dtype=np.int64)
    for c in range(N):
        base_a[:, c] = sa <= a
        base_b[:, c] = sb <= b
        sa, sb = NEXT[sa], NEXT[sb]
    copies = []
    for _ in range(3):
        x = base_a ^ flip_mask(N, p, model)
        y = base_b ^ flip_mask(N, p, model)
        copies.append(((x & y) ^ flip_mask(N, p, model)).astype(int))
    return ((copies[0] + copies[1] + copies[2]) >= 2).sum(axis=1).astype(float)


def vote(vs, nbits):
    bits = sum(bits_of(v, nbits).astype(int) for v in vs)
    return val_of(bits >= 2)


def bin_once(a, b, p, model):
    aa = val_of(bits_of(a, W) ^ flip_mask(W, p, model))
    bb = val_of(bits_of(b, W) ^ flip_mask(W, p, model))
    return bits_of(aa * bb, 16) ^ flip_mask(16, p, model)


def run_methods(a, b, p, model, conv):
    s_reg = p / N if conv == "per_op" else p  # per-cycle p for held registers
    out = {
        "sc_stream": sc_run(a, b, (p, 0, 0, 0), model),
        "sc_inreg": sc_run(a, b, (0, s_reg, 0, 0), model),
        "sc_lfsr": sc_run(a, b, (0, 0, s_reg, 0), model),
        "sc_cnt": sc_run(a, b, (0, 0, 0, s_reg), model),
        "sc_all": sc_run(a, b, (p, s_reg, s_reg, s_reg), model),
        "sc_shield": sc_run(a, b, (p, 3 * s_reg**2 - 2 * s_reg**3, s_reg,
                                   3 * s_reg**2 - 2 * s_reg**3), model),
        "sc_shield_all": sc_run(a, b, (p, 3 * s_reg**2 - 2 * s_reg**3, 3 * s_reg**2 - 2 * s_reg**3,
                                       3 * s_reg**2 - 2 * s_reg**3), model),
        "sc_tmr_out": vote([sc_run(a, b, (p, s_reg, s_reg, s_reg), model) for _ in range(3)], 8),
        "sc_tmr_ideal": sc_tmr_ideal(a, b, p, model),
    }
    out = {k: v.astype(float) for k, v in out.items()}
    prod = bin_once(a, b, p, model)
    out["bin_raw"] = val_of(prod) / 255.0
    true_par = (bits_of(a * b, 16).sum(axis=1)) & 1
    bad = (prod.sum(axis=1) & 1) != true_par
    out["bin_parity"] = val_of(np.where(bad[:, None], bin_once(a, b, p, model), prod)) / 255.0
    out["bin_tmr"] = vote([val_of(bin_once(a, b, p, model)) for _ in range(3)], 16) / 255.0
    return out


def main():
    a = rng.integers(0, 256, TRIALS)
    b = rng.integers(0, 256, TRIALS)
    ideal = a * b / 255.0
    rows = []
    plan = [("per_op", "uniform", PER_OP), ("per_op", "burst", PER_OP),
            ("per_cycle", "uniform", PER_CYCLE)]
    for conv, model, rates in plan:
        for p in [0.0] + rates:
            row = {"convention": conv, "model": model, "p": p}
            res = run_methods(a, b, p, model, conv)
            for name, v in res.items():
                err = np.abs(v - ideal) / 255.0 * 100
                row[name + "_mean"] = round(float(err.mean()), 3)
                row[name + "_p99"] = round(float(np.percentile(err, 99)), 3)
            rows.append(row)
    out = os.path.join(os.path.dirname(__file__), "..", "results", "fault_tolerance.csv")
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    names = [k[:-5] for k in rows[0] if k.endswith("_mean")]
    print("mean |err| %FS (p99)")
    for conv, model, _ in plan:
        print(f"\n[{conv} / {model}]")
        print(f"{'p':>8} " + " ".join(f"{n:>13}" for n in names))
        for r in rows:
            if r["convention"] == conv and r["model"] == model:
                print(f"{r['p']:>8g} " + " ".join(
                    f"{r[n + '_mean']:>6.2f}({r[n + '_p99']:>5.1f})" for n in names))


if __name__ == "__main__":
    main()
