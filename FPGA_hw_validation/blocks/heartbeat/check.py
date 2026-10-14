#!/usr/bin/env python3
"""Heartbeat pass criteria on the ILA capture:
 - samples with rst_n==0 must have cnt==0 (reset works, VIO drives it)
 - samples with rst_n==1 must increment cnt by exactly 1 per cycle
 - both regions must be present (the VIO release was actually captured)
"""
import csv, sys
rows = list(csv.reader(open(sys.argv[1])))
hdr = rows[0]
c_cnt = next(i for i, h in enumerate(hdr) if h.startswith("cnt"))
c_rst = next(i for i, h in enumerate(hdr) if h.startswith("rst_n"))
data = [(int(r[c_cnt], 16), int(r[c_rst], 16)) for r in rows[2:] if r[c_cnt].strip()]
held = [c for c, r in data if r == 0]
run = [(c, r) for c, r in data if r == 1]
bad_held = [c for c in held if c != 0]
vals = [c for c, _ in run]
bad_run = [i for i in range(1, len(vals)) if (vals[i] - vals[i - 1]) & 0xFFFF != 1]
print(f"held={len(held)} (nonzero={len(bad_held)}) running={len(run)} (non-increment={len(bad_run)})")
ok = held and run and not bad_held and not bad_run
print("HEARTBEAT", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
