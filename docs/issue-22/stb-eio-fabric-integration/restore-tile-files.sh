#!/usr/bin/env bash
# restore-tile-files.sh — Restore STB's and E_IO's tile-definition source
# files, and the 10-column fabric.csv, into a (gitignored, clean-room)
# FABulous project checkout.
#
# FABulous_work/fabulous-v2/ is entirely gitignored, so the fixed source
# files for STB (Stochastic-to-Binary) and E_IO (the mirrored east-edge IO
# tile) have no other tracked copy. If that checkout is ever wiped or a
# project regenerated fresh, use this script to put the fixed source files
# back before running generate_custom_tile_config / build_fabric.py.
#
# Usage: docs/issue-22/stb-eio-fabric-integration/restore-tile-files.sh <path-to-project-dir>
#   e.g. docs/issue-22/stb-eio-fabric-integration/restore-tile-files.sh \
#          FABulous_work/fabulous-v2/fabric_btos_only_proj
#
# This restores ONLY the hand-authored source files (STB.csv, its BEL
# wrapper, E_IO.csv, E_IO_switch_matrix.list, both tiles' gds_config.yaml,
# and fabric.csv). Everything else under each Tile/*/ (ConfigMem,
# io_pin_order.yaml, *.v, macro/) is auto-generated -- regenerate with:
#   FABulous --project-dir <proj> run "generate_custom_tile_config Tile/STB"
#   FABulous --project-dir <proj> run "gen_fabric"
set -euo pipefail

DEST="${1:?usage: restore-tile-files.sh <path-to-project-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$DEST" ] || { echo "ERROR: $DEST is not a directory"; exit 1; }

mkdir -p "$DEST/Tile/STB" "$DEST/Tile/E_IO"

cp -v "$HERE/source/STB/STB.csv" "$DEST/Tile/STB/STB.csv"
cp -v "$HERE/source/STB/gds_config.yaml" "$DEST/Tile/STB/gds_config.yaml"
cp -v "$HERE/source/STB/FABulous_stochastic_to_binary_sync.sv" \
      "$DEST/Tile/STB/FABulous_stochastic_to_binary_sync.sv"

cp -v "$HERE/source/E_IO/E_IO.csv" "$DEST/Tile/E_IO/E_IO.csv"
cp -v "$HERE/source/E_IO/E_IO_switch_matrix.list" "$DEST/Tile/E_IO/E_IO_switch_matrix.list"
cp -v "$HERE/source/E_IO/gds_config.yaml" "$DEST/Tile/E_IO/gds_config.yaml"

cp -v "$HERE/source/fabric.csv" "$DEST/fabric.csv"

echo "Restored STB, E_IO tile sources and fabric.csv to $DEST."
echo "Now regenerate (from the FABulous project root, inside the nix devshell):"
echo "  FABulous --project-dir <proj> run \"gen_fabric\""
echo "  FABulous --project-dir <proj> run \"gen_tile_macro STB\""
echo "  FABulous --project-dir <proj> run \"gen_tile_macro E_IO\""
echo "  FABulous --project-dir <proj> run \"gen_all_tile_macros --parallel\""
echo "  FABulous --project-dir <proj> run \"gen_fabric_macro\""
