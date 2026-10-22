"""Issue #33 / A2: fault tolerance of an 8-bit SC multiply vs binary multipliers.

SC path: two BTS (LFSR seeds 1 and 204, the chain seeds) -> AND -> popcount over
N=256 cycles. LFSR is the galois WIDTH=8 one from accuracy_and_correlation_sweep.py
(pylfsr, TAPS_LUT[8]); its next-state table is built once and reused.
Binary path: 8x8 -> 16-bit product, read as product/256 so both land on 0..255.

Error = |output - a*b/256| in percent of full scale (256), mean over random (a, b).
Per-bit flip probability p is applied once per *stored/transmitted bit per operation*.
Fault locations are reported separately (this is the pessimistic-review requirement):
  sc_stream  flips on the two input streams and the product stream (256 bits each)
  sc_inreg   flips on the 8-bit a and b registers feeding the BTS (binary-like)
  sc_lfsr    flips on the 8 state bits of each LFSR, at a random cycle
  bin_raw    flips on a, b (8 bits each) and the 16-bit product, unprotected
  bin_parity product parity, detect-only, one recompute on detect
  bin_tmr    three independent copies of bin_raw, bitwise majority voter (voter fault-free)
Flip models: "uniform" (independent bits) and "burst" (runs of 8 adjacent bits, the
expected number of flipped bits is kept at p x bits).

Run: python3 fault_tolerance_sweep.py
Output: results/fault_tolerance.csv
"""

import csv
import os

import numpy as np
from pylfsr import LFSR

from accuracy_and_correlation_sweep import TAPS_LUT, fpoly_for, state_to_int

W = 8
N = 256
SEED_A, SEED_B = 1, 204
TRIALS = 4000
BURST = 8
RATES = [0.01, 0.02, 0.05, 0.10, 0.15]
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


def lfsr_states(seed, flips=None):
    """States over N cycles for each trial. flips: (cycle[T], bit[T], active[T]) or None."""
    t = seed if np.ndim(seed) else np.full(TRIALS, seed, dtype=np.int64)
    out = np.empty((N, TRIALS), dtype=np.int64)
    s = t.copy()
    for c in range(N):
        if flips is not None:
            cyc, bit, act = flips
            hit = act & (cyc == c)
            s = np.where(hit, s ^ (1 << bit), s)
        out[c] = s
        s = NEXT[s]
    return out


def flip_mask(shape_bits, p, model):
    """Boolean flip mask [TRIALS, shape_bits]. Same expected flips per row for both models."""
    if model == "uniform":
        return rng.random((TRIALS, shape_bits)) < p
    m = np.zeros((TRIALS, shape_bits), dtype=bool)
    n_b = rng.poisson(p * shape_bits / BURST, size=TRIALS)
    for i in np.nonzero(n_b)[0]:
        for _ in range(n_b[i]):
            st = rng.integers(0, shape_bits)
            m[i, st:st + BURST] ^= True
    return m


def bits_of(x, n):
    return ((x[:, None] >> np.arange(n)) & 1).astype(bool)


def val_of(b):
    return (b.astype(np.int64) << np.arange(b.shape[1])).sum(axis=1)


def sc_multiply(a, b, loc, p, model):
    if loc == "sc_inreg":
        fa = flip_mask(W, p, model)
        fb = flip_mask(W, p, model)
        a = val_of(bits_of(a, W) ^ fa)
        b = val_of(bits_of(b, W) ^ fb)
    fl_a = fl_b = None
    if loc == "sc_lfsr":
        def mk():
            m = flip_mask(W, p, model)  # one chance per state bit
            act = m.any(axis=1)
            bit = np.where(act, m.argmax(axis=1), 0)
            return rng.integers(0, N, TRIALS), bit, act
        fl_a, fl_b = mk(), mk()
    sa = lfsr_states(SEED_A, fl_a) < a[None, :]
    sb = lfsr_states(SEED_B, fl_b) < b[None, :]
    prod = (sa & sb).T
    if loc == "sc_stream":
        sa = sa ^ flip_mask(N, p, model).T
        sb = sb ^ flip_mask(N, p, model).T
        prod = (sa & sb).T ^ flip_mask(N, p, model)
    return prod.sum(axis=1).astype(float)


def bin_once(a, b, p, model):
    fa, fb = flip_mask(W, p, model), flip_mask(W, p, model)
    aa, bb = val_of(bits_of(a, W) ^ fa), val_of(bits_of(b, W) ^ fb)
    prod = bits_of(aa * bb, 16) ^ flip_mask(16, p, model)
    return prod


def bin_raw(a, b, p, model):
    return val_of(bin_once(a, b, p, model)) / 256.0


def bin_parity(a, b, p, model):
    prod = bin_once(a, b, p, model)
    # parity of the true product is held in a fault-free-at-compute side bit; a flip of
    # that bit is ignored (kindest case for parity)
    true_par = ((a * b)[:, None] >> np.arange(16) & 1).sum(axis=1) & 1
    bad = (prod.sum(axis=1) & 1) != true_par
    prod2 = bin_once(a, b, p, model)
    out = np.where(bad[:, None], prod2, prod)
    return val_of(out) / 256.0


def bin_tmr(a, b, p, model):
    c = [bin_once(a, b, p, model) for _ in range(3)]
    maj = (c[0].astype(int) + c[1] + c[2]) >= 2
    return val_of(maj) / 256.0


METHODS = {
    "sc_stream": lambda a, b, p, m: sc_multiply(a, b, "sc_stream", p, m),
    "sc_inreg": lambda a, b, p, m: sc_multiply(a, b, "sc_inreg", p, m),
    "sc_lfsr": lambda a, b, p, m: sc_multiply(a, b, "sc_lfsr", p, m),
    "bin_raw": bin_raw,
    "bin_parity": bin_parity,
    "bin_tmr": bin_tmr,
}


def main():
    a = rng.integers(0, 256, TRIALS)
    b = rng.integers(0, 256, TRIALS)
    ideal = a * b / 256.0
    rows = []
    for model in ("uniform", "burst"):
        for p in [0.0] + RATES:
            row = {"model": model, "p": p}
            for name, fn in METHODS.items():
                err = np.abs(fn(a, b, p, model) - ideal) / 256.0 * 100
                row[name + "_mean"] = round(float(err.mean()), 3)
                row[name + "_p99"] = round(float(np.percentile(err, 99)), 3)
            rows.append(row)
    out = os.path.join(os.path.dirname(__file__), "..", "results", "fault_tolerance.csv")
    with open(out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    names = list(METHODS)
    print("mean |err| %FS   (p99 in brackets)")
    for model in ("uniform", "burst"):
        print(f"\n[{model}]  p      " + "  ".join(f"{n:>16}" for n in names))
        for r in rows:
            if r["model"] == model:
                print(f"        {r['p']:<5} " + "  ".join(
                    f"{r[n + '_mean']:>8.2f} ({r[n + '_p99']:>5.1f})" for n in names))


if __name__ == "__main__":
    main()
