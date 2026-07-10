# chip_wrapper — MPW-portable chip wrapper for the eFPGA macro (issue #16)

Parametrized, MPW-neutral wrapper around the #12 LVS-clean FABulous `eFPGA` macro.
One fixed interface contract + fabric size as a knob; per-MPW integration is a thin pad shim.
Full rationale, decisions, and validation strategy: `docs/issue-16/`.

## Layout
```
rtl/
  chip_top.v          parametrized MPW-neutral top (the portable artifact)
  config_adapter.v    thin serial->FABulous-controller adapter (preserves the
                      2-cycle / address-before-frame frame protocol; Dirk Koch note)
  io_mux.v            N chip user-IO pins <-> fabric bidirectional IO triples
  efpga_top_bb.v            CLEAN-ROOM black-box stub of the baseline14 eFPGA_top
  efpga_top_caravel_bb.v    CLEAN-ROOM black-box stub of the shrunk 8x8 eFPGA_top
                            (stubs are per-target ALTERNATIVES — compile exactly one)
profiles/
  caravel.yml         Caravel user_project_wrapper target
  standalone.yml      standalone sky130 target (sized to the #12 macro)
fabrics/
  baseline14.yml      fabric size descriptor (measured macro geometry + provenance)
  caravel_shrunk.yml  shrunk 8x8 fabric descriptor (hardened 1989.96x2457.52 um)
fabric/
  caravel_shrunk.fabric.csv   FABulous fabric definition for the shrunk 8x8 fabric
shims/
  chip_top_standalone.v   standalone pad shim (the conformant reference target)
  user_project_wrapper.v  Caravel CC2509 shim (config over GPIO serial; lint-clean)
tests/
  tb_config_adapter.v     adapter unit TB (serial -> SelfWriteData/Strobe)
  tb_chip_top_efpga.v     end-to-end TB: serial contract -> real behavioral eFPGA_top
tools/
  check_conformance.py    validation layer 2: static MPW conformance gate
  estimate_area.py        tile-abutment area model (from measured tile LEFs)
  run_functional_sim.sh   validation layer 3: bitstream + FABulous-oracle sim
  regen_caravel_fabric.sh clean-room regeneration of the shrunk fabric RTL
  harden_caravel_fabric.sh clean-room harden of the shrunk fabric (tiles + stitch)
```

## Interface contract (size-independent)
`clk, rst_n, cfg_sclk, cfg_sdata, cfg_busy, cfg_done, user_io[N] (out/oeb/in), vdd, vss`

## Quick checks (no PDK / no P&R)
```bash
export PATH=$HOME/.fabulous/oss-cad-suite/bin:$PATH    # iverilog/verilator/yosys

# RTL elaboration (authoritative well-formedness) — exactly one eFPGA_top stub
iverilog -g2012 -Wall -o /tmp/x rtl/efpga_top_bb.v rtl/io_mux.v rtl/config_adapter.v \
    rtl/chip_top.v shims/chip_top_standalone.v

# Static MPW conformance (validation layer 2).
# --all sweeps profiles x baseline14; caravel x baseline14 is EXPECTEDLY
# NOT CONFORMANT (area) -> exit 1. The Caravel target is the shrunk fabric:
python3 tools/check_conformance.py --all
python3 tools/check_conformance.py --profile profiles/caravel.yml --fabric fabrics/caravel_shrunk.yml

# Adapter unit sim + end-to-end functional sim vs the FABulous oracle (layer 3)
iverilog -g2012 -o /tmp/tb tests/tb_config_adapter.v rtl/config_adapter.v && vvp /tmp/tb
bash tools/run_functional_sim.sh
```
Current result: **standalone x baseline14 CONFORMANT; caravel x baseline14 NOT
CONFORMANT** (macro 2482x3930 um overflows the 2920x3520 um user area in any
orientation — the documented blocker that motivated the shrunk fabric);
**caravel x caravel_shrunk CONFORMANT** (hardened macro 1989.96x2457.52 um).

## Status
- DONE: functional sim vs the FABulous oracle (baseline14) — `run_functional_sim.sh`
  builds a real bitstream and `chip_top` matches the behavioral golden end-to-end.
- DONE: shrunk 8x8 Caravel fabric hardened LVS/DRC/Antenna-clean (clean-room scripts
  in `tools/`); Caravel CC2509 `user_project_wrapper` shim written + lint-clean.
- NOT YET: V1–V3 shrunk-fabric validation (a fit-for-purpose <=16-IO design +
  bitstream + behavioral/gate-level sim) — required BEFORE chip-level Harden A/B.
- NOT YET: Harden A (`chip_top` user macro) / Harden B (`user_project_wrapper`) /
  `make run-precheck`.
See `docs/issue-16/mpw-validation-plan.md` and `docs/issue-16/caravel-integration-plan.md`.
