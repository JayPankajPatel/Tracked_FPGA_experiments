#!/usr/bin/env bash
# Derive a sync-reset variant of a Microarch_Lib test integration top by renaming the
# instantiated modules to their _sync versions (multiplier is combinational: no twin).
# Usage: make_sync_top.sh <in.sv> <out.sv>
set -euo pipefail
mkdir -p "$(dirname "$2")"
sed -E 's/^( *)binary_stochastic_converter #\(/\1binary_stochastic_converter_sync #(/;
        s/^( *)stochastic_to_binary #\(/\1stochastic_to_binary_sync #(/;
        s/^( *)stochastic_adder #\(/\1stochastic_adder_sync #(/' "$1" > "$2"
