# Tracked_FPGA_experiments

A reproducible **platform for experimenting with novel FPGA architectures** on the open-source
SkyWater 130nm PDK: fabric definition → generation → bitstream/behavioral/gate-level validation →
MPW-portable chip integration → manufacturability signoff. First architecture payload:
silicon-hardened **stochastic-computing blocks**. The work moves from RTL prototypes and
simulation toward FABulous/OpenFPGA fabric integration, LibreLane/OpenLane physical
implementation, and eventual tapeout. See `CLAUDE.md` for the full charter and working
conventions, and `HANDOFF.md` for the live session log.

## Repository layout

| Path | Contents |
|---|---|
| `docs/` | Setup/usage notes, decision records, and per-issue evidence (`docs/issue-NN/`). |
| `FABulous_work/` | FABulous fabric definition/generation and local harden workspaces (gitignored generated artifacts; clean-room recipes are tracked). |
| `Librelane_work/` | sky130 ASIC implementation: the chip-level wrapper (`chip_wrapper/`) and Caravel integration. |
| `Stochastic_Blocks/` | RTL, testbenches, and sims for the stochastic blocks. |
| `HANDOFF.md` | Running project log — read first, update last. |

## Status (2026-06-15)

- **eFPGA hard macro (issue #12):** the standard FABulous demo fabric is **LVS/DRC/Antenna-clean**
  on sky130A (14-row, 2482×3930 µm).
- **Chip wrapper (issue #16, in progress):** an **MPW-portable** wrapper around the eFPGA macro —
  one fixed interface contract (serial config + muxed user IO + clk/reset) with fabric size as a
  knob, retargetable to any MPW via a thin pad shim.
  - A static **conformance gate** (`Librelane_work/chip_wrapper/tools/check_conformance.py`) showed
    the 14-row macro **cannot** fit Caravel (area), so a **shrunk 8×8 fabric** was generated and
    **hardened LVS/DRC/Antenna-clean** (1990×2457 µm) to fit the Caravel user area.
  - Wrapper RTL + config adapter are **functionally validated** against FABulous's own simulator
    (end-to-end programmed-design smoke test passes).
  - Integration target: **ChipFoundry Caravel `user_project_wrapper` (tag CC2509)** via the
    LibreLane 1-Macro-First flow. Shim written and lint-clean; macro/wrapper hardens are next.

## Reproduce the cheap checks (no PDK / no P&R)

```bash
export PATH=$HOME/.fabulous/oss-cad-suite/bin:$PATH
cd Librelane_work/chip_wrapper
# RTL elaboration — pick ONE eFPGA_top stub; the two rtl/efpga_top*_bb.v files are
# per-target alternatives (baseline14 vs shrunk Caravel) and cannot be compiled together
iverilog -g2012 -Wall -o /tmp/x rtl/chip_top.v rtl/config_adapter.v rtl/io_mux.v \
    rtl/efpga_top_bb.v shims/chip_top_standalone.v
# static MPW conformance; --all sweeps profiles x baseline14, where caravel is
# EXPECTEDLY NOT CONFORMANT (area) -> exit 1. The actual Caravel target is the
# shrunk 8x8 fabric, which must be CONFORMANT -> exit 0:
python3 tools/check_conformance.py --all
python3 tools/check_conformance.py --profile profiles/caravel.yml --fabric fabrics/caravel_shrunk.yml
# end-to-end functional sim against the FABulous oracle (builds a real bitstream)
bash tools/run_functional_sim.sh
```

## Tracking

Work is tracked via GitHub Issues/PRs (every task → issue → branch → PR). Durable findings are
promoted to `~/wiki/fpga_stochastic_blocks/`.
