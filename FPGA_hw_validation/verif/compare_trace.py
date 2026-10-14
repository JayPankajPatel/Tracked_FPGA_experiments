#!/usr/bin/env python3
"""Compare an ILA capture CSV against recorded vectors/expected outputs.

Usage: compare_trace.py <gen_dir> <capture.csv>
Checks, cycle by cycle from the first run==1 sample:
  - captured dut_in  == vectors.mem   (the replay path itself is intact)
  - captured dut_out == expected.mem  (the DUT on hardware matches simulation)
Exit 0 only if all N cycles match.
"""
import csv
import json
import sys
from pathlib import Path


def load_mem(p):
    return [int(x, 16) for x in Path(p).read_text().split()]


def decode(fields, word):
    out, shift = {}, 0
    for name, width in fields:
        out[name] = (word >> shift) & ((1 << width) - 1)
        shift += width
    return out


def main(gen, cap):
    gen = Path(gen)
    meta = json.loads((gen / "meta.json").read_text())
    vec, exp = load_mem(gen / "vectors.mem"), load_mem(gen / "expected.mem")
    rows = list(csv.reader(open(cap)))
    hdr = rows[0]
    col = lambda p: next(i for i, h in enumerate(hdr) if p in h.split("[")[0].split("/")[-1])  # noqa: E731
    c_in, c_out, c_run = col("dut_in"), col("dut_out"), col("run")
    data = [(int(r[c_in], 16), int(r[c_out], 16), int(r[c_run], 16)) for r in rows[2:] if r[c_in].strip()]
    start = next((i for i, d in enumerate(data) if d[2] == 1), None)
    if start is None:
        print("FAIL: run never went high in capture")
        return 1
    n = meta["n"]
    got = data[start : start + n]
    if len(got) < n:
        print(f"FAIL: capture has {len(got)} cycles after trigger, need {n}")
        return 1
    bad = 0
    for k, (i, o, run) in enumerate(got):
        if run != 1 or i != vec[k] or o != exp[k]:
            if bad < 5:
                print(f"MISMATCH cycle {k}: run={run} in=0x{i:x} (want 0x{vec[k]:x}) "
                      f"out=0x{o:x} (want 0x{exp[k]:x})")
                print(f"   in  {decode(meta['in_fields'], i)}")
                print(f"   out got {decode(meta['out_fields'], o)} want {decode(meta['out_fields'], exp[k])}")
            bad += 1
    print(f"{meta['name']}: cycles={n} mismatches={bad} -> {'PASS' if not bad else 'FAIL'}")
    stat_bad = 0
    wins = meta["params"].get("windows")
    if wins and not bad:
        # Hardware trace == simulation trace bit-exactly, so these decoded values are what the
        # chip produced. Statistical criterion: |decoded - ideal| <= tol_fs * full scale.
        full, tol = (1 << meta["out_fields"][-1][1]) - 1, meta["params"].get("tol_fs", 0.1)
        print("  window   a    b  decoded  ideal  err(%FS)")
        for k, w in enumerate(wins):
            err = abs(w["decoded"] - w["ideal"]) / full
            stat_bad += err > tol
            print(f"  {k:>6} {w['a']:>4} {w['b']:>4} {w['decoded']:>8} {w['ideal']:>6.1f} {100 * err:>8.2f}"
                  f"{'  <-- over tol' if err > tol else ''}")
        print(f"  statistical (tol {100 * tol:.0f}% FS): {'PASS' if not stat_bad else 'FAIL'}")
    return 0 if not (bad or stat_bad) else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
