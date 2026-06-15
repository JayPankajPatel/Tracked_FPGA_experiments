#!/usr/bin/env bash
# regen_caravel_fabric.sh — reproduce the shrunk Caravel-targeted FABulous
# fabric from clean-room sources (issue #16). Clean-room: the generated fabric
# lives under the gitignored FABulous_work/; this script + fabric/caravel_shrunk.
# fabric.csv are the committed recipe.
#
# Stage 1 (fast, RTL gen only — validated): produces Fabric/eFPGA_top.v with
#   NumberOfRows=8 NumberOfCols=8, config_C[31:0], I/O/T_top[15:0], 4x BlockRAM.
# Stage 2 (hours, ~tens of GB — the GDS harden) is intentionally separate and
#   must reuse the #12 fabric_io_place fix (docs/issue-12/) at fabric stitch.
set -euo pipefail

FAB_V2="${FAB_V2:-$HOME/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2}"
BASE="$FAB_V2/fabric_baseline_proj"
PROJ="$FAB_V2/fabric_caravel_proj"
HERE="$(cd "$(dirname "$0")/.." && pwd)"     # chip_wrapper/
export PATH="$HOME/.fabulous/oss-cad-suite/bin:$PATH"   # yosys/nextpnr/iverilog

echo "== Stage 1: regenerate shrunk fabric RTL =="
# Source-only project (reuse baseline tile defs; exclude huge macro/ outputs).
rsync -a --exclude='macro' --exclude='runs' --exclude='Fabric' "$BASE/" "$PROJ/"
rsync -a --exclude='macro' "$BASE/Fabric/" "$PROJ/Fabric/"     # for models_pack.v
cp "$HERE/fabric/caravel_shrunk.fabric.csv" "$PROJ/fabric.csv"

FABulous -p "$PROJ" run "load_fabric; run_FABulous_fabric"

echo "== Stage 1 result =="
grep -E 'NumberOfRows=|NumberOfCols=|\[31:0\] A_config_C|\[15:0\] I_top' "$PROJ/Fabric/eFPGA_top.v"

cat <<'NOTE'

== Stage 2 (NOT run here): GDS harden ==
  Needs LibreLane + sky130A PDK (Nix devshell; openroad/klayout/magic).
  Per docs/issue-12: apply patches/fabric_io_place-overlap-iterm.patch before
  fabric stitch, then:  gen_all_tile_macros ; gen_fabric_macro
  Expect ~tens of minutes tile harden + ~minutes stitch; stitch peaks ~tens of
  GB RAM (baseline 14-row peaked ~19 GB; shrunk should be lower). Capture the
  new macro LEF SIZE and re-diff rtl/efpga_top_caravel_bb.v against the result.
NOTE
