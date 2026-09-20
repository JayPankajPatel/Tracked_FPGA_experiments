# Tile-macro flow drops `.sv` BEL primitives from `VERILOG_FILES`: root cause

**Status:** RESOLVED. `BTS` (binary-stochastic-converter tile) now hardens clean:
Antenna/LVS/DRC all Passed (`RUN_2026-09-13_20-13-36`, `no_opt`, standard 245.18×245.48 µm tile footprint).
**Env (inherited #7/#10/#12):** FABulous `v2.0.0b5` `4a2047b`, LibreLane `v3.0.3`, sky130A
`FAB_PDK_HASH=8afc8346…`.

## TL;DR

`FABulousTileVerilogMacroFlow.__init__` builds its `VERILOG_FILES` list for the tile-hardening flow
(lint → synth → P&R → signoff) by globbing `tile_type.tileDir.parent.glob("**/*.v")` — **`.v` only**.
`Tile/BTS`'s custom BEL primitive, `FABulous_binary_stochastic_converter_sync.sv`, is genuine
SystemVerilog (`logic`, `always_ff`, `$clog2`), not a `.v` file with a typo'd extension. It was silently
excluded from every hardening step. `BTS.v` instantiates that module, so `Verilator.Lint` failed with
`MODMISSING` at the very first step — before DIE_AREA/floorplan/P&R were ever reached.

This is a tile-hardening-flow-specific gap: the *synthesis* path (`fab-yosys` mapping a user design onto
the fabric) already reads `.sv` correctly via `user_design/custom_prims.v` BEL registration, which is why
this went unnoticed until the first custom-tile GDS harden was attempted.

## Evidence

Failing run: `Tile/BTS/macro/no_opt/runs/RUN_2026-09-13_20-05-56/01-verilator-lint/verilator-lint.log`:

```
%Error-MODMISSING: .../Tile/BTS/BTS.v:1611:1: Cannot find file containing module:
'FABulous_binary_stochastic_converter_sync'
```

`COMMANDS` for that step confirms the file list passed to Verilator was exactly:

```
Tile/BTS/BTS.v
Tile/BTS/BTS_switch_matrix.v
Tile/BTS/BTS_ConfigMem.v
Fabric/models_pack.v
```

— `Tile/BTS/FABulous_binary_stochastic_converter_sync.sv` is absent, despite sitting directly in the
tile directory the flow globs.

Source of the gap (`fabulous/fabric_generator/gds_generator/flows/tile_macro_flow.py:102-107`, pre-fix):

```python
file_list = [
    str(f)
    for f in tile_type.tileDir.parent.glob("**/*.v")
    if "macro" not in f.parts
]
```

## Fix

Glob both `**/*.v` and `**/*.sv`:

```python
file_list = [
    str(f)
    for pattern in ("**/*.v", "**/*.sv")
    for f in tile_type.tileDir.parent.glob(pattern)
    if "macro" not in f.parts
]
```

`patches/tile_macro_flow-include-sv-files.patch` (+5/−2; applies cleanly on `v2.0.0b5`).

## Validation

- Post-fix: the same glob (run standalone against `Tile/BTS`) includes
  `FABulous_binary_stochastic_converter_sync.sv` alongside the three `.v` files. `py_compile` clean.
- Post-fix `gen_tile_macro BTS` (`no_opt`, standard tile `DIE_AREA` inherited from
  `Tile/include/gds_config.yaml` = 245×245): `Checker.LintErrors` → 0 lint errors (down from the
  `MODMISSING` failure); full 36-stage flow completes; final `metrics.json`:
  `design__lvs_error__count: 0`, `route__drc_errors: 0`, `klayout__drc_error__count: 0`,
  `antenna__violating__nets: 0`; `Report Manufacturability`: Antenna/LVS/DRC all **Passed**.
- Remaining warnings on the clean run are known/benign categories already tracked elsewhere in this
  project: missing macro `.lib`/SDC (open issue #21 — no timing signoff yet), Magic DRC skipped
  (KLayout is this project's DRC signoff tool throughout), and one switch-matrix-level `UNOPTFLAT`
  (`BTS.last_cycle`, fanned into the generated routing muxes) — the same structural-cycle pattern
  already documented for `lfsr8` in `HANDOFF.md`, not a new functional defect. `last_cycle` itself is a
  single documented `assign` from `burst_complete` in the BEL, not an accidental combinational loop.
- Separately noted: `gen_tile_macro BTS --optimise balance` predicted a **210.68×306.00 µm** minimum
  die area (taller than the row's 245 µm) via `_apply_tile_die_area_config`'s pre-check — but the real
  `no_opt` P&R at 245×245 hardened clean. The `--optimise` mode's minimum-area estimate appears to be a
  conservative pin/pitch-based pre-check, not reflective of what actual placement/routing achieves; not
  investigated further here since `no_opt` at the standard footprint already succeeds.

## Reproduce

```sh
cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5 (4a2047b)
../../docs/issue-22/tile-macro-sv-glob-fix/apply-fix.sh .
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  FABulous --project-dir fabric_btos_only_proj run "gen_tile_macro BTS"
'
# => Report Manufacturability: Antenna/LVS/DRC Passed
```
