"""Follow-up to accuracy_and_correlation_sweep.py: find a verified,
well-separated seed pair for EACH WIDTH this project's galois_lfsr
polynomial table supports, and empirically check whether that strategy
(half-period phase separation) actually gives good AND-multiply accuracy
at every width, or only at widths with a long-enough period -- the
WIDTH=4 case already showed no seed pair works at all at that width
(period 15 too short relative to any useful N), so this must be verified
per width, not assumed from the WIDTH=8 result.

TAPS_LUT below is transcribed directly from Microarch_Lib's
blocks/stocastic/rtl/galois_lfsr.sv `taps()` function (verified identical,
not retyped from memory) -- keep in sync if that table changes.

Run: python3 decorrelation_seed_sweep.py
Output: results/decorrelation_seed_sweep.csv, prints a WIDTH -> recommended
seed_b table (relative to seed_a=1) plus a per-width verdict.
"""

import csv
import os

from pylfsr import LFSR

TAPS_LUT = {
    2: 0x1, 3: 0x1, 4: 0x4, 5: 0x4, 6: 0x10, 7: 0x20, 8: 0x38,
    9: 0x10, 10: 0x40, 11: 0x100, 12: 0x29, 13: 0x241, 14: 0x409,
    15: 0x2000, 16: 0x406, 17: 0x2000, 18: 0x400, 19: 0x1101,
    20: 0x10000,
}


def fpoly_for(width):
    mask = TAPS_LUT[width]
    taps = [i + 1 for i in range(width) if (mask >> i) & 1]
    return sorted(set(taps + [width]), reverse=True)


def state_to_int(state, width):
    value = 0
    for j, bit in enumerate(state):
        value |= (int(bit) & 1) << (width - 1 - j)
    return value


def build_lag_table(width, seed_start):
    """One O(period) walk of the full cycle starting from seed_start,
    returning {state: lag}. Computing every candidate seed's phase_lag via
    a fresh O(period) simulation each (as the original per-pair experiment
    script did, fine for a handful of one-off checks) would be O(period^2)
    for a full per-width seed search -- this builds the mapping once
    instead.
    """
    fpoly = fpoly_for(width)
    initstate = [(seed_start >> (width - 1 - j)) & 1 for j in range(width)]
    ref = LFSR(fpoly=fpoly, initstate=initstate, conf="galois", verbose=False)
    period = (1 << width) - 1
    state = state_to_int(initstate, width)
    lag_of = {}
    for lag in range(period):
        lag_of[state] = lag
        ref.next()
        state = state_to_int(ref.state, width)
    return lag_of


def best_half_period_seed(width, seed_a=1):
    """Seed whose phase_lag from seed_a is closest to period/2."""
    period = (1 << width) - 1
    target = period / 2
    lag_of = build_lag_table(width, seed_a)
    best_seed, best_diff, best_lag = None, None, None
    for candidate, lag in lag_of.items():
        if candidate == seed_a:
            continue
        diff = abs(lag - target)
        if best_diff is None or diff < best_diff:
            best_seed, best_diff, best_lag = candidate, diff, lag
    return best_seed, best_lag, period


def lfsr_bitstream(width, seed, threshold, n):
    fpoly = fpoly_for(width)
    initstate = [(seed >> (width - 1 - j)) & 1 for j in range(width)]
    ref = LFSR(fpoly=fpoly, initstate=initstate, conf="galois", verbose=False)
    state = state_to_int(initstate, width)
    bits = []
    for _ in range(n):
        bits.append(1 if state < threshold else 0)
        ref.next()
        state = state_to_int(ref.state, width)
    return bits


def estimate(width, seed_a, seed_b, p1, p2, n):
    max_value = (1 << width) - 1
    ta, tb = round(p1 * max_value), round(p2 * max_value)
    a = lfsr_bitstream(width, seed_a, ta, n)
    b = lfsr_bitstream(width, seed_b, tb, n)
    return sum(x & y for x, y in zip(a, b)) / n


def main():
    p_pairs = [(0.3, 0.7), (0.5, 0.5), (0.1, 0.9), (0.25, 0.25)]
    n = 2**16
    # Below WIDTH=6 (period<64), N=2^16 is >>period, matching the WIDTH=4
    # regime already shown to fail regardless of seed. Widths above that
    # start to have periods approaching/exceeding a meaningful sample size.
    # Capped at 16 to match this project's earlier width sweeps and keep
    # runtime reasonable (building the full-period lag table is O(period),
    # which grows fast beyond this).
    widths = [w for w in sorted(TAPS_LUT.keys()) if w <= 16]

    results_dir = os.path.join(os.path.dirname(__file__), "..", "results")
    os.makedirs(results_dir, exist_ok=True)

    rows = []
    print(f"{'WIDTH':>5} {'period':>7} {'seed_b':>7} {'lag':>5} {'avg_abs_err':>12} {'verdict'}")
    for width in widths:
        seed_b, lag, period = best_half_period_seed(width)
        errors = []
        for p1, p2 in p_pairs:
            est = estimate(width, 1, seed_b, p1, p2, n)
            errors.append(abs(est - p1 * p2))
            rows.append(
                {
                    "width": width, "period": period, "seed_a": 1, "seed_b": seed_b,
                    "lag": lag, "p1": p1, "p2": p2, "n": n,
                    "expected_product": p1 * p2, "estimate": est,
                    "abs_error": abs(est - p1 * p2),
                }
            )
        avg_err = sum(errors) / len(errors)
        # ~0.01 threshold: roughly an order of magnitude above the
        # true-random sampling-noise floor measured in
        # accuracy_and_correlation_sweep.py (~0.0016 at this N) but well
        # below the adjacent-seed failure mode (~0.038-0.13 there).
        verdict = "OK" if avg_err < 0.01 else "POOR (period too short for this N)"
        print(f"{width:>5} {period:>7} {seed_b:>7} {lag:>5} {avg_err:>12.4f} {verdict}")

    with open(os.path.join(results_dir, "decorrelation_seed_sweep.csv"), "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"\nWrote {len(rows)} rows to results/decorrelation_seed_sweep.csv")


if __name__ == "__main__":
    main()
