#!/usr/bin/env bash
# harden_caravel_fabric.sh — Stage-2 GDS harden of the shrunk Caravel fabric (#16).
#
# Runs the known-good FABulous v2.0.0b5 GDS flow (same as #10/#12) on
# fabric_caravel_proj, WITH the #12 fabric_io_place fix applied first (required
# for fabric-stitch LVS). Staged with checkpoints; logs to FABulous_work/.
#
#   gen_all_tile_macros  -> harden the (size-independent) tile macros
#   gen_fabric_macro     -> stitch the 8x8 eFPGA + IO-pin overlap fix -> LVS/DRC
#
# Hours-class, ~tens of GB RAM (shrunk < baseline's ~19 GB). No args.
set -uo pipefail
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true

REPO=/home/jay/Repos/Tracked_FPGA_experiments
WS=$REPO/FABulous_work
FV=$WS/fabulous-v2
PROJ=fabric_caravel_proj
LOG=$WS/harden-caravel-shrunk.log
INNER=$WS/harden-caravel-inner.sh
RAMLOG=$WS/harden-ram.log

echo "=== HARDEN START $(date -Is) ===" | tee "$LOG"

# RAM monitor: every 20 s log total usage + the top-5 RSS processes, so we can
# see what dominates (gen_fabric_macro/OpenROAD/Magic) and tune it later.
: > "$RAMLOG"
( while true; do
    echo "--- $(date -Is) ---" >> "$RAMLOG"
    free -m | awk 'NR<=2' >> "$RAMLOG"
    ps -eo rss,comm,args --sort=-rss 2>/dev/null | head -6 \
      | awk '{printf "%8.1f MB  %s\n", $1/1024, substr($0, index($0,$2))}' >> "$RAMLOG"
    sleep 20
  done ) &
RAMMON=$!
trap 'kill $RAMMON 2>/dev/null' EXIT

# 1. Apply the #12 IO-placement fix to the FABulous checkout (idempotent).
bash "$REPO/docs/issue-12/apply-fix.sh" "$FV" 2>&1 | tee -a "$LOG"

# 2. Inner script (runs inside the nix devshell).
cat > "$INNER" <<INNEREOF
#!/usr/bin/env bash
set -uo pipefail
export PDK_ROOT="$FV/.pdk"
cd "$FV"
echo "--- versions \$(date -Is) ---"
FABulous --version 2>&1 | head -2 || true
echo "--- gen_all_tile_macros \$(date -Is) ---"
/usr/bin/time -v FABulous --project-dir $PROJ run "gen_all_tile_macros" 2>&1 || { echo "TILE HARDEN FAILED rc=\$?"; exit 11; }
echo "--- gen_fabric_macro (stitch + #12 IO overlap) \$(date -Is) ---"
/usr/bin/time -v FABulous --project-dir $PROJ run "gen_fabric_macro" 2>&1 || { echo "FABRIC STITCH FAILED rc=\$?"; exit 12; }
echo "--- inner done \$(date -Is) ---"
INNEREOF
chmod +x "$INNER"

# 3. Run inside the devshell. MUST cd into $FV first: the flake shellHook derives
#    the repo root (-> PYTHONPATH for the editable `fabulous` pkg) from $PWD.
cd "$FV"
nix develop "$FV" --command bash "$INNER" 2>&1 | tee -a "$LOG"
RC=${PIPESTATUS[0]}

echo "=== HARDEN END $(date -Is) rc=$RC ===" | tee -a "$LOG"

# 4. Report manufacturability if the stitch produced a run.
echo "--- manufacturability scan ---" | tee -a "$LOG"
MAC=$(find "$FV/$PROJ/Fabric/macro" -name 'manufacturability*.txt' -o -name '*signoff*summary*' 2>/dev/null | head -1)
ls -la "$FV/$PROJ/Fabric/macro/final_views/lef/eFPGA.lef" 2>/dev/null | tee -a "$LOG"
grep -m1 'SIZE' "$FV/$PROJ/Fabric/macro/final_views/lef/eFPGA.lef" 2>/dev/null | tee -a "$LOG"
grep -aiE 'Circuits match|LVS|DRC|Antenna|violation' "$LOG" | tail -20
exit $RC
