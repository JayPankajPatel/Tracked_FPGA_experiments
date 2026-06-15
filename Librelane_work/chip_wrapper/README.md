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
  efpga_top_bb.v      CLEAN-ROOM black-box stub of the generated eFPGA_top
profiles/
  caravel.yml         eFabless Caravel user_project_wrapper target
  standalone.yml      standalone sky130 target (sized to the #12 macro)
fabrics/
  baseline14.yml      fabric size descriptor (measured macro geometry + provenance)
shims/
  chip_top_standalone.v   standalone pad shim (the conformant target)
tools/
  check_conformance.py    validation layer 2: static MPW conformance gate
```

## Interface contract (size-independent)
`clk, rst_n, cfg_sclk, cfg_sdata, cfg_busy, cfg_done, user_io[N] (out/oeb/in), vdd, vss`

## Quick checks (no PDK / no P&R)
```bash
export PATH=$HOME/.fabulous/oss-cad-suite/bin:$PATH    # iverilog/verilator/yosys

# RTL elaboration (authoritative well-formedness)
iverilog -g2012 -Wall -o /tmp/x rtl/efpga_top_bb.v rtl/io_mux.v rtl/config_adapter.v \
    rtl/chip_top.v shims/chip_top_standalone.v

# Static MPW conformance (validation layer 2)
python3 tools/check_conformance.py --all
```
Current result: **standalone CONFORMANT; Caravel NOT CONFORMANT** — the macro
(2482x3930 um) overflows Caravel's user area (2920x3520 um) in any orientation.
The checker reproduces that blocker mechanically. Caravel needs a shrunk fabric.

## Status / not yet done
- Functional + shim-replay sim against the FABulous-sim oracle (`fabric_baseline_proj/Test/`):
  next increment — needs a regenerated geometry-matched `eFPGA_top` + a real bitstream.
- Clean-room regeneration script (pinned FABulous v2.0.0b5 + LibreLane).
- Reference hardening (LibreLane P&R + DRC/LVS/Antenna) — later milestone.
See `docs/issue-16/mpw-validation-plan.md` for the full pyramid and sequencing.
