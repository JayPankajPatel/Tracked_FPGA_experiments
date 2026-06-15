#!/usr/bin/env python3
"""Parametric fabric-area estimator for MPW geometry sizing (issue #16).

FABulous fabrics are built by tile abutment: macro width = sum of column tile
widths, macro height = (number of tile rows incl. terminators) * row pitch.
This predicts the hardened eFPGA macro footprint for a candidate grid so we can
pick the largest fabric that still fits a target MPW *before* paying for a
multi-hour regenerate+harden.

Tile widths/heights are measured from the #12 hardened tile LEFs (provenance in
fabrics/baseline14.yml / tile macro final_views). Row pitch is uniform.

Usage:
    estimate_area.py --grid fabrics/caravel_shrunk.yml
"""
import argparse
import sys
import yaml

# Measured tile macro sizes (um) from baseline14 hardened tiles (LEF SIZE).
TILE_W = {
    "W_IO": 246.10, "LUT4AB": 246.10, "RAM_IO": 246.10, "RegFile": 260.36,
    "DSP": 250.24, "N_term_single": 246.10, "S_term_single": 246.10,
    "N_term_single2": 260.36, "S_term_single2": 260.36,
    "N_term_RAM_IO": 246.10, "S_term_RAM_IO": 246.10,
    "N_term_DSP": 250.24, "S_term_DSP": 250.24,
}
ROW_PITCH = 245.48          # um per tile row (uniform; DSP supertile = 2 rows)


def estimate(grid):
    cols = grid["columns"]                 # list of column tile-type names
    func_rows = int(grid["functional_rows"])
    # tile rows = functional rows + north terminator + south terminator
    tile_rows = func_rows + 2
    width = sum(TILE_W[c] for c in cols)
    height = tile_rows * ROW_PITCH
    return width, height, tile_rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", required=True)
    args = ap.parse_args()
    with open(args.grid) as fh:
        grid = yaml.safe_load(fh)["grid"]
    w, h, tr = estimate(grid)
    print(f"columns        : {len(grid['columns'])}  {grid['columns']}")
    print(f"functional rows: {grid['functional_rows']}  (tile rows incl. term: {tr})")
    print(f"predicted macro: {w:.1f} x {h:.1f} um  ({w*h/1e6:.2f} mm^2)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
