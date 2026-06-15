#!/usr/bin/env python3
"""Issue #16 validation layer 2 — static MPW conformance check.

Given an MPW target profile and a fabric size descriptor, assert that the
parametrized chip_top wrapper can target that MPW:
  * every interface-contract signal is mapped to a harness pin/bus,
  * exposed pin count fits the harness pin budget,
  * the fabric macro (+ soft overhead) fits the user-area in some orientation,
  * power pins are mapped.

This is the cheap, automatable gate that makes "works for MPW X" concrete and
the one that mechanically reproduces the Caravel area blocker. It runs for ANY
profile in seconds — no P&R, no toolchain.

Usage:
    check_conformance.py --profile profiles/caravel.yml --fabric fabrics/baseline14.yml
    check_conformance.py --all          # every profile x baseline14
Exit code 0 = all checks pass, 1 = at least one failure.
"""
import argparse
import glob
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# Fixed interface contract (chip_top ports, size-independent).
CONTRACT_SIGNALS = ["clk", "rst_n", "cfg_sclk", "cfg_sdata",
                    "cfg_busy", "cfg_done", "user_io", "power"]
# Scalar contract pins that each consume exactly one chip pin.
SCALAR_PINS = ["clk", "rst_n", "cfg_sclk", "cfg_sdata", "cfg_busy", "cfg_done"]


def load(path):
    with open(path) as fh:
        return yaml.safe_load(fh)


def fits_area(mw, mh, uw, uh):
    """True if a macro mw x mh fits a uw x uh area in either orientation."""
    return (mw <= uw and mh <= uh) or (mh <= uw and mw <= uh)


def check(profile, fabric):
    name = profile.get("name", "?")
    fab = fabric.get("name", "?")
    results = []  # (ok, label, detail)

    # --- 1. contract mapping completeness ---
    cmap = profile.get("contract_map", {})
    for sig in CONTRACT_SIGNALS:
        ok = sig in cmap and cmap[sig] not in (None, "", [])
        results.append((ok, f"contract '{sig}' mapped",
                        str(cmap.get(sig)) if ok else "MISSING"))

    # --- 2. pin budget ---
    n_user = int(profile.get("chip_top_params", {}).get("N_USER_IO", 0))
    dbg = int(profile.get("chip_top_params", {}).get("DBG_CONFIG_C_W", 0))
    need_pins = len(SCALAR_PINS) + n_user + dbg
    budget = profile.get("budget", {})
    avail = int(budget.get("gpio", 0)) + int(budget.get("logic_analyzer", 0))
    ok = need_pins <= avail
    results.append((ok, "pin budget",
                    f"need {need_pins} (= {len(SCALAR_PINS)} cfg/clk/rst + "
                    f"{n_user} user + {dbg} dbg), have {avail}"))

    # --- 3. area fit (the Caravel-catching check) ---
    m = fabric["macro_um"]
    over = float(fabric.get("overhead_factor", 1.0))
    # apply overhead isotropically (sqrt on each edge) for the sanity estimate
    scale = over ** 0.5
    mw, mh = m["width"] * scale, m["height"] * scale
    u = profile["user_area_um"]
    uw, uh = float(u["width"]), float(u["height"])
    ok = fits_area(mw, mh, uw, uh)
    results.append((ok, "area fit",
                    f"macro+ovh {mw:.0f}x{mh:.0f} um vs user area {uw:.0f}x{uh:.0f} um"))

    # --- 4. power mapped ---
    pwr = cmap.get("power")
    ok = isinstance(pwr, list) and len(pwr) >= 2
    results.append((ok, "power pins", str(pwr) if ok else "need >=2 (supply+ground)"))

    passed = all(r[0] for r in results)
    return name, fab, passed, results


def report(name, fab, passed, results):
    print(f"\n=== profile '{name}'  x  fabric '{fab}' ===")
    for ok, label, detail in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {label:22s} {detail}")
    print(f"  -> {'CONFORMANT' if passed else 'NOT CONFORMANT'}")
    return passed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile")
    ap.add_argument("--fabric", default=os.path.join(ROOT, "fabrics", "baseline14.yml"))
    ap.add_argument("--all", action="store_true",
                    help="check every profiles/*.yml against --fabric")
    args = ap.parse_args()

    fabric = load(args.fabric)
    if args.all:
        profiles = sorted(glob.glob(os.path.join(ROOT, "profiles", "*.yml")))
    elif args.profile:
        profiles = [args.profile]
    else:
        ap.error("give --profile or --all")

    all_ok = True
    for p in profiles:
        name, fab, passed, results = check(load(p), fabric)
        report(name, fab, passed, results)
        all_ok = all_ok and passed

    print("\n" + ("ALL PROFILES CONFORMANT" if all_ok
                  else "SOME PROFILES NOT CONFORMANT (see above)"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
