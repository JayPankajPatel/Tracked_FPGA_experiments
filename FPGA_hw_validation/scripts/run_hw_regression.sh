#!/usr/bin/env bash
# Run record->build->run->compare->negative-control for every replay block (or the
# ones named) one after another (single JTAG chain) and print a PASS/FAIL table.
# Usage: run_hw_regression.sh [block ...]
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"$here/scripts/hw_session.sh" "$here/scripts/hw_check.tcl" 2>&1 | grep -q 'HW_CHECK PASS' \
  || { echo "hw_check failed: tunnel/board not available"; exit 2; }
if [[ $# -gt 0 ]]; then blocks=("$@"); else
  mapfile -t blocks < <(cd "$here/blocks" && ls -d */ | tr -d / | while read -r b; do [[ -f $b/record.py ]] && echo "$b"; done); fi
rc=0; rows=()
for b in "${blocks[@]}"; do
  log="$here/build/$b.flow.log"
  if "$here/scripts/run_replay_block.sh" "$b" >"$log" 2>&1; then
    rows+=("PASS  $b  $(grep -E 'cycles=' "$log" | tail -1)")
  else
    rows+=("FAIL  $b  (see $log)"); rc=1
  fi
done
printf '\n=== hardware regression (%s) ===\n' "$(date +%F)"; printf '%s\n' "${rows[@]}"
exit $rc
