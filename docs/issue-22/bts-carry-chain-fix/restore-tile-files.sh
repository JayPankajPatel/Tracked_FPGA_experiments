#!/usr/bin/env bash
# restore-tile-files.sh — Restore BTS's tile-definition source files into a
# (gitignored, clean-room) FABulous project checkout.
#
# FABulous_work/fabulous-v2/ is entirely gitignored, so the BTS.csv and BEL
# wrapper files that fix the fabric-stitch carry-chain/pin-alignment issue
# (see ../root-cause.md and the wiki writeup it links) have no other tracked
# copy. If that checkout is ever wiped or a project regenerated fresh, use
# this script to put the fixed source files back before running
# generate_custom_tile_config / build_fabric.py.
#
# Usage: docs/issue-22/bts-carry-chain-fix/restore-tile-files.sh <path-to-BTS-tile-dir>
#   e.g. docs/issue-22/bts-carry-chain-fix/restore-tile-files.sh \
#          FABulous_work/fabulous-v2/fabric_sc_proj/Tile/BTS
#
# This restores ONLY the two hand-authored source files (BTS.csv, the BEL
# wrapper). Everything else under Tile/BTS/ (switch matrix, ConfigMem,
# io_pin_order.yaml, BTS.v, macro/) is auto-generated -- regenerate it with:
#   FABulous --project-dir <proj> run "generate_custom_tile_config Tile/BTS"
#   FABulous --project-dir <proj> run "run_pyscript <proj>/build_fabric.py"
set -euo pipefail

DEST="${1:?usage: restore-tile-files.sh <path-to-BTS-tile-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$DEST" ] || { echo "ERROR: $DEST is not a directory"; exit 1; }

cp -v "$HERE/source/BTS.csv" "$DEST/BTS.csv"
cp -v "$HERE/source/FABulous_binary_stochastic_converter_sync.sv" \
      "$DEST/FABulous_binary_stochastic_converter_sync.sv"

echo "Restored BTS.csv and the BEL wrapper to $DEST."
echo "Now regenerate (from the FABulous project root, inside the nix devshell):"
echo "  FABulous --project-dir <proj> run \"generate_custom_tile_config Tile/BTS\""
echo "  FABulous --project-dir <proj> run \"run_pyscript <proj>/build_fabric.py\""
