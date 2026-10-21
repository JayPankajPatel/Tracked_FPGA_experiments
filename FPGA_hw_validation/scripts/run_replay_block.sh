#!/usr/bin/env bash
# Full record -> build -> run -> compare for one replay block.
# Usage: run_replay_block.sh <block> [make-vars, e.g. WIDTH=16 SEED=0xACE1]
set -euo pipefail
block=$1; shift
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export MICROARCH_LIB=${MICROARCH_LIB:-$HOME/Repos/Microarch_Lib}

echo "== record ($block)"
rm -rf "$here/blocks/$block/gen" "$here/blocks/$block/sim_build"
(cd "$here/blocks/$block" && pixi run --manifest-path "$MICROARCH_LIB/pixi.toml" make "$@") >"$here/build/$block.record.log" 2>&1 \
  || { tail -20 "$here/build/$block.record.log"; echo "RECORD FAIL"; exit 1; }
echo "== build"
"$here/scripts/hw_session.sh" "$here/scripts/build_block.tcl" "$block" >"$here/build/$block.build.log" 2>&1 \
  || { grep -E "ERROR|RUN_ERROR" "$here/build/$block.build.log" | head; echo "BUILD FAIL"; exit 1; }
echo "== run on hardware"
"$here/scripts/hw_session.sh" "$here/scripts/run_block.tcl" "$block" >"$here/build/$block.run.log" 2>&1 \
  || { grep -E "ERROR|RUN_ERROR" "$here/build/$block.run.log" | head; echo "RUN FAIL"; exit 1; }
grep -E 'REPLAY' "$here/build/$block.run.log" || true
echo "== compare"
python3 "$here/verif/compare_trace.py" "$here/blocks/$block/gen" "$here/waveforms/$block/capture.csv" || { echo "BLOCK $block: FAIL"; exit 1; }
echo "== negative control (corrupt one expected word; checker must FAIL)"
nc=$(mktemp -d); cp "$here/blocks/$block/gen/"* "$nc/"
python3 - "$nc/expected.mem" <<'PY'
import sys
p = sys.argv[1]; w = open(p).read().split()
w[len(w)//2] = f"{int(w[len(w)//2], 16) ^ 1:0{len(w[0])}x}"
open(p, "w").write("\n".join(w) + "\n")
PY
if python3 "$here/verif/compare_trace.py" "$nc" "$here/waveforms/$block/capture.csv" >/dev/null; then
  echo "NEGATIVE CONTROL FAILED: corrupted expectation still passed"; exit 1
else echo "negative control OK (corrupted expectation detected)"; fi
rm -rf "$nc"
echo "BLOCK $block: PASS"
