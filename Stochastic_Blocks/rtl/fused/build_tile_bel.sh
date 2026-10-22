#!/usr/bin/env bash
# Concatenate the self-contained tile BEL file (FABulous tile hardening only
# sees files inside the tile dir). Usage: build_tile_bel.sh <out.sv>
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
{
  for f in counter_sync galois_lfsr_sync binary_stochastic_converter_sync stochastic_binary_converter_sync; do
    # strip the elaboration-assert include/checks; a tile dir can't reach ma_assert.svh
    grep -v '^`include' "$R/$f.sv" | grep -v 'MA_ASSERT_ELABOR'
  done
  cat "$R/fused/sc_multiply_fused_core.sv" "$R/fused/FABulous_sc_multiply_fused_wrapper.sv"
} > "$1"
