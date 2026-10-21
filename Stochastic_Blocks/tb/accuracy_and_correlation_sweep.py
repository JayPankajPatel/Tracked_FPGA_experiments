"""Issue #22 v0 metrics: estimate error vs stream length N, and correlation
sensitivity across several LFSR-seeding strategies, for the SNG + AND-multiply
stochastic-computing "hello world."

Golden-model methodology (LFSR construction, tap-mirroring convention, bit-0
pre-advance-state comparison) is the exact one used and cross-validated
against the real RTL (`galois_lfsr.sv`, `binary_stochastic_converter.sv`)
across the full Microarch_Lib test suite this project's SNG/multiplier RTL
was ported from -- see rtl/ in this directory and
docs/adr/0002-taps-lut-correctness-methodology.md /
docs/adr/0006-galois-lfsr-tap-mirroring.md in Microarch_Lib for how that
methodology was itself established and verified.

Key finding this script exists to characterize (see results/README.md for
the full writeup): naively picking "a different seed" for two same-polynomial
LFSR instances does NOT reliably decorrelate them. Adjacent integer seeds
(e.g. 1 and 2 -- the actual default used in Microarch_Lib's
test_b_mult_s_integration/test_b_add_s_integration) turned out to be only
ONE STEP apart in the LFSR's own state cycle, producing near-total
correlation. A well-separated phase (near half the LFSR's period) performs
much better empirically, but this needs to be verified per-(WIDTH, taps)
combination, not assumed.

Run: python3 accuracy_and_correlation_sweep.py
Output: results/accuracy_vs_n.csv, results/correlation_sensitivity.csv
"""

import csv
import os
import random

from pylfsr import LFSR

TAPS_LUT = {4: 0x4, 5: 0x4, 6: 0x10, 7: 0x20, 8: 0x38}


def fpoly_for(width):
    mask = TAPS_LUT[width]
    taps = [i + 1 for i in range(width) if (mask >> i) & 1]
    return sorted(set(taps + [width]), reverse=True)


def state_to_int(state, width):
    value = 0
    for j, bit in enumerate(state):
        value |= (int(bit) & 1) << (width - 1 - j)
    return value


def phase_lag(width, seed_start, seed_target):
    """Number of LFSR advances from seed_start until the state equals
    seed_target -- i.e. how far apart the two seeds are on the LFSR's own
    cycle. This is the actual quantity that determines correlation between
    two same-polynomial LFSR instances, not the numeric difference between
    the seed values themselves.
    """
    fpoly = fpoly_for(width)
    initstate = [(seed_start >> (width - 1 - j)) & 1 for j in range(width)]
    ref = LFSR(fpoly=fpoly, initstate=initstate, conf="galois", verbose=False)
    state = state_to_int(initstate, width)
    period = (1 << width) - 1
    for lag in range(period + 1):
        if state == seed_target:
            return lag
        ref.next()
        state = state_to_int(ref.state, width)
    return None


def lfsr_bitstream(width, seed, threshold, n):
    """One binary_stochastic_converter-equivalent bitstream: n bits, each
    equal to (lfsr_state < threshold), lfsr advancing once per bit (matching
    the RTL's per-bit en-gated advance). Bit 0 compares against the seed
    itself, before any advance -- same convention as
    binary_stochastic_converter's own golden_model in Microarch_Lib.
    """
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


def true_random_bitstream(p, n, rng):
    """Idealized control: genuine iid Bernoulli(p) samples, not derived from
    any LFSR. Establishes the sampling-noise-only error floor a stochastic
    representation could achieve at a given N if correlation were not a
    concern at all -- the number every LFSR-based strategy below should be
    compared against, not just against 0.
    """
    return [1 if rng.random() < p else 0 for _ in range(n)]


def and_multiply_estimate(bits_a, bits_b):
    n = len(bits_a)
    return sum(a & b for a, b in zip(bits_a, bits_b)) / n


def make_strategy_streams(strategy, width, p1, p2, n, rng):
    """Returns (bits_a, bits_b) for a named decorrelation strategy."""
    max_value = (1 << width) - 1
    ta, tb = round(p1 * max_value), round(p2 * max_value)

    if strategy == "true_random_control":
        return true_random_bitstream(p1, n, rng), true_random_bitstream(p2, n, rng)
    if strategy == "shared_identical_seed":
        # The original bug shape (docs/adr/0015 in Microarch_Lib): both
        # operands driven from the literal same LFSR state sequence.
        return lfsr_bitstream(width, 1, ta, n), lfsr_bitstream(width, 1, tb, n)
    if strategy == "adjacent_seed_1_2":
        # The actual default used in this session's integration tests
        # (INIT_SEED_A=1, INIT_SEED_B=2) -- looks "distinct" but is only
        # phase_lag(width, 1, 2) steps apart on the same cycle.
        return lfsr_bitstream(width, 1, ta, n), lfsr_bitstream(width, 2, tb, n)
    if strategy == "half_period_seed":
        period = (1 << width) - 1
        target_lag = period // 2
        seed_b = 1
        for candidate in range(1, 1 << width):
            if phase_lag(width, 1, candidate) == target_lag:
                seed_b = candidate
                break
        return lfsr_bitstream(width, 1, ta, n), lfsr_bitstream(width, seed_b, tb, n)
    if strategy == "different_polynomial":
        # Genuinely different LFSR structure (different WIDTH -> different
        # TAPS_LUT entry), the same decorrelation approach
        # stochastic_adder.sv's select LFSR already uses relative to its
        # operand encoders (docs/adr/0014/0018 in Microarch_Lib).
        other_width = 5 if width != 5 else 7
        other_max = (1 << other_width) - 1
        tb_other = round(p2 * other_max)
        return lfsr_bitstream(width, 1, ta, n), lfsr_bitstream(other_width, 1, tb_other, n)
    raise ValueError(f"unknown strategy {strategy}")


def main():
    width = 8
    rng = random.Random(12345)
    p_pairs = [(0.3, 0.7), (0.5, 0.5), (0.1, 0.9), (0.25, 0.25)]
    ns_full = [2**k for k in range(4, 17)]  # 2^4 .. 2^16 (below and above the period)
    strategies = [
        "true_random_control",
        "shared_identical_seed",
        "adjacent_seed_1_2",
        "half_period_seed",
        "different_polynomial",
    ]

    results_dir = os.path.join(os.path.dirname(__file__), "..", "results")
    os.makedirs(results_dir, exist_ok=True)

    period = (1 << width) - 1
    lag_1_2 = phase_lag(width, 1, 2)
    print(f"WIDTH={width}: period={period}, phase_lag(seed=1, seed=2)={lag_1_2}")

    # 1. Accuracy vs N, per strategy -- generate once per (strategy, p1, p2)
    # at the largest N, then slice prefixes for smaller N (same underlying
    # bit sequence at every N, not independently re-sampled per N, which
    # would conflate "does error shrink with N" with fresh sampling luck).
    accuracy_rows = []
    max_n = max(ns_full)
    for strategy in strategies:
        for p1, p2 in p_pairs:
            bits_a, bits_b = make_strategy_streams(strategy, width, p1, p2, max_n, rng)
            expected = p1 * p2
            for n in ns_full:
                estimate = and_multiply_estimate(bits_a[:n], bits_b[:n])
                accuracy_rows.append(
                    {
                        "strategy": strategy, "p1": p1, "p2": p2, "n": n,
                        "expected_product": expected, "estimate": estimate,
                        "abs_error": abs(estimate - expected),
                    }
                )

    with open(os.path.join(results_dir, "accuracy_vs_n.csv"), "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(accuracy_rows[0].keys()))
        writer.writeheader()
        writer.writerows(accuracy_rows)

    # 2. Correlation sensitivity summary at the largest N -- one row per
    # (strategy, p1, p2), the table results/README.md's writeup is built from.
    correlation_rows = []
    for strategy in strategies:
        for p1, p2 in p_pairs:
            matching = [
                r for r in accuracy_rows
                if r["strategy"] == strategy and r["p1"] == p1 and r["p2"] == p2 and r["n"] == max_n
            ]
            row = matching[0]
            correlation_rows.append(
                {
                    "strategy": strategy, "p1": p1, "p2": p2, "n": max_n,
                    "expected_product": row["expected_product"],
                    "expected_min": min(p1, p2),
                    "estimate": row["estimate"],
                    "abs_error_vs_product": row["abs_error"],
                    "abs_error_vs_min": abs(row["estimate"] - min(p1, p2)),
                }
            )

    with open(os.path.join(results_dir, "correlation_sensitivity.csv"), "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(correlation_rows[0].keys()))
        writer.writeheader()
        writer.writerows(correlation_rows)

    print(f"\nWrote {len(accuracy_rows)} rows to results/accuracy_vs_n.csv")
    print(f"Wrote {len(correlation_rows)} rows to results/correlation_sensitivity.csv")

    print(f"\n--- Correlation sensitivity summary (N = {max_n}) ---")
    for strategy in strategies:
        print(f"\n{strategy}:")
        for row in correlation_rows:
            if row["strategy"] != strategy:
                continue
            print(
                f"  p1={row['p1']}, p2={row['p2']}: estimate={row['estimate']:.4f} "
                f"(true product={row['expected_product']:.4f}, err={row['abs_error_vs_product']:.4f}; "
                f"true min={row['expected_min']:.2f}, err vs min={row['abs_error_vs_min']:.4f})"
            )


if __name__ == "__main__":
    main()
