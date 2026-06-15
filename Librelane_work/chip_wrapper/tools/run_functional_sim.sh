#!/usr/bin/env bash
# run_functional_sim.sh — issue #16 functional sim (validation layer 3).
#
# Proves the wrapper end-to-end with NO PDK/P&R: builds a real FABulous
# bitstream for the baseline demo design, runs the FABulous oracle behaviorally
# (golden == fabric via parallel SelfWrite), then runs chip_top driven through
# the serial cfg contract and checks it reproduces the same golden output.
#
# Clean-room: operates on the gitignored generated baseline project; the
# committed inputs are the wrapper RTL + tests/. All tools from oss-cad-suite
# + FABulous bit_gen (miniforge). ~2 min for the oracle build + a few min sim.
set -euo pipefail
export PATH="$HOME/.fabulous/oss-cad-suite/bin:$HOME/miniforge3/bin:$PATH"

FAB_V2="${FAB_V2:-$HOME/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2}"
TEST="$FAB_V2/fabric_baseline_proj/Test"
W="$(cd "$(dirname "$0")/.." && pwd)"      # chip_wrapper/
TMP="$(mktemp -d)"

echo "== 1. build bitstream (yosys+nextpnr+bit_gen) =="
( cd "$TEST" && make build_test_design >/dev/null 2>&1 )
HEX="$TEST/build/sequential_16bit_en.hex"
[ -s "$HEX" ] || { echo "FAIL: no bitstream"; exit 1; }

echo "== 2. behavioral file set (exclude gate .nl/.pnl + sky130 .bb stubs) =="
ls "$TEST"/build/fabric_files/*.v | grep -vE '\.(bb|nl|pnl)\.v$' > "$TMP/flist.txt"

echo "== 3. FABulous oracle (golden == fabric, parallel SelfWrite) =="
iverilog -g2012 -s sequential_16bit_en_tb -o "$TMP/oracle.vvp" \
  $(cat "$TMP/flist.txt") "$TEST/../user_design/sequential_16bit_en.v" \
  "$TEST/sequential_16bit_en_tb.v" 2>/dev/null
vvp "$TMP/oracle.vvp" +bitstream_hex="$HEX" 2>&1 | grep -qE 'I_top.*gold' \
  && echo "   oracle ran (golden vs fabric, no \$fatal = match)"

echo "== 4. chip_top end-to-end (serial cfg contract -> real eFPGA_top) =="
iverilog -g2012 -s tb_chip_top_efpga -o "$TMP/chip.vvp" \
  $(cat "$TMP/flist.txt") \
  "$W/rtl/io_mux.v" "$W/rtl/config_adapter.v" "$W/rtl/chip_top.v" \
  "$TEST/../user_design/sequential_16bit_en.v" \
  "$W/tests/tb_chip_top_efpga.v" 2>/dev/null
vvp "$TMP/chip.vvp" +bitstream_hex="$HEX"
rm -rf "$TMP"
