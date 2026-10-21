#!/usr/bin/env bash
# restore-tile-files.sh — Restore SMUL's and SADD's tile-definition source
# files, and the 10-column fabric.csv (now including both), into a
# (gitignored, clean-room) FABulous project checkout.
#
# FABulous_work/ is gitignored, so these are the only tracked copies of the
# fixed source files. If that checkout is ever wiped or a project
# regenerated fresh, use this script to put the fixed source files back
# before running generate_custom_tile_config / gen_fabric.
#
# Usage: docs/issue-22/smul-sadd-fabric-integration/restore-tile-files.sh <path-to-project-dir>
#   e.g. docs/issue-22/smul-sadd-fabric-integration/restore-tile-files.sh \
#          FABulous_work/fabulous-v2/fabric_sc_proj
#
# This restores ONLY the hand-authored source files (SMUL.csv, its BEL
# wrapper, SADD.csv, its BEL wrapper, both tiles' gds_config.yaml, and
# fabric.csv). Everything else under each Tile/*/ (ConfigMem,
# io_pin_order.yaml, *.v, macro/) is auto-generated -- regenerate with:
#   FABulous --project-dir <proj> run "generate_custom_tile_config Tile/SMUL"
#   FABulous --project-dir <proj> run "generate_custom_tile_config Tile/SADD"
#   FABulous --project-dir <proj> run "gen_fabric"
set -euo pipefail

DEST="${1:?usage: restore-tile-files.sh <path-to-project-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -d "$DEST" ] || { echo "ERROR: $DEST is not a directory"; exit 1; }

mkdir -p "$DEST/Tile/SMUL" "$DEST/Tile/SADD"

cp -v "$HERE/source/SMUL/SMUL.csv" "$DEST/Tile/SMUL/SMUL.csv"
cp -v "$HERE/source/SMUL/gds_config.yaml" "$DEST/Tile/SMUL/gds_config.yaml"
cp -v "$HERE/source/SMUL/FABulous_stochastic_multiplier.sv" \
      "$DEST/Tile/SMUL/FABulous_stochastic_multiplier.sv"

cp -v "$HERE/source/SADD/SADD.csv" "$DEST/Tile/SADD/SADD.csv"
cp -v "$HERE/source/SADD/gds_config.yaml" "$DEST/Tile/SADD/gds_config.yaml"
cp -v "$HERE/source/SADD/FABulous_stochastic_adder_sync.sv" \
      "$DEST/Tile/SADD/FABulous_stochastic_adder_sync.sv"

cp -v "$HERE/source/fabric.csv" "$DEST/fabric.csv"

echo "Restored SMUL, SADD tile sources and fabric.csv to $DEST."
echo "Now regenerate (from the FABulous project root, inside the nix devshell):"
echo "  FABulous --project-dir <proj> run \"gen_fabric\""
echo "  FABulous --project-dir <proj> run \"gen_tile_macro SMUL\""
echo "  FABulous --project-dir <proj> run \"gen_tile_macro SADD\""
echo "  FABulous --project-dir <proj> run \"gen_all_tile_macros --parallel\""
echo "  FABulous --project-dir <proj> run \"gen_fabric_macro\""
