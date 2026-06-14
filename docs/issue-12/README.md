# Issue #12 — fabric-stitch LVS blocker: resolved

The standard FABulous `v2.0.0b5` example fabric now reaches a **manufacturability-clean** fabric-level
result on sky130A (LVS / DRC / Antenna all pass), via the official FABulous / LibreLane flow.

- **[root-cause.md](root-cause.md)** — full diagnosis, two-pass review, before/after fingerprint, fix.
- **[patches/fabric_io_place-overlap-iterm.patch](patches/)** — the fix (tracked; the FABulous checkout
  is gitignored). Place each top-level IO pin over its tile terminal(s) so the no-router abutment fabric
  connects at extraction. +37/−83; applies cleanly on `v2.0.0b5`.
- **[apply-fix.sh](apply-fix.sh)** — `apply-fix.sh <FABulous-checkout>` (idempotent).
- **evidence/** — the failing-run artifacts (before). **evidence-after/** — the green run.

## Reproduce
```sh
cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5 (4a2047b)
../../docs/issue-12/apply-fix.sh .                # or: docs/issue-12/apply-fix.sh FABulous_work/fabulous-v2
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk" FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71
  FABulous --project-dir fabric_baseline_proj run "gen_fabric_macro"
'
# => Report Manufacturability: Antenna/LVS/DRC Passed; netgen "Circuits match uniquely"
```
Local run: 24c/29 GB host, ~4.5 min, ~19 GB peak RSS. Stock 4c/16 GB CI runners still OOM during P&R
(documented; CI `gds-fabric-stitch` job applies the patch and stays non-failing on OOM).

## One-line root cause
The fabric stitch has no router and connects by abutment; `fabric_io_place.py` placed every top-level
IO pin on the die edge while every tile is 1 µm halo-inset → all ~1581 top ports floated and LVS failed
top-level pin matching. **Not PDN.** Fix: overlap each pin with its tile terminal(s).
