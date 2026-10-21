# RTL-to-GDSII Runbook

A practical, step-by-step guide to the flows this project actually uses, built from the
real scripts/commands already verified working here (`Librelane_work/chip_wrapper/tools/`,
`FABulous_work/fabulous-v2/fabric_caravel_proj/Test/Makefile`) — not generic external
documentation. If a command here stops matching what's on disk, trust the actual files
over this document and update it.

## 0. Which flow do you actually need?

"RTL to GDSII" gets used loosely. Pick based on what you're trying to do:

| You want to... | Flow | Time | Needs PDK/heavy EDA? |
|---|---|---|---|
| Run your RTL *on* the already-hardened fabric, get a real bitstream + LC-count/Fmax | **A: Map a user design onto the fabric** | Minutes | No (just yosys/nextpnr, no PDK needed) |
| Get a cheap area/gate-count datapoint for a standalone RTL module, no fabric at all | **C: Standalone sky130 synthesis smoke** | Seconds | Yes, but Yosys-only, no P&R |
| Get a real, signed-off GDSII of one RTL module in isolation (not the fabric, not mapped onto anything) | **D: Standalone RTL-to-GDSII of one block** | Minutes | Yes, full LibreLane P&R |
| Change the fabric's own architecture (tile count, tile types) and produce a new physical macro | **B: Harden the fabric itself** | Hours, tens of GB RAM | Yes, full LibreLane P&R |
| Add a new custom tile (new hardened block) and carry it through to the full-fabric GDS | **E: New custom tile to full fabric** | Hours (B's cost plus authoring) | Yes, full LibreLane P&R |

Flow A is what you want almost all the time — "run my design on the FPGA I already built."
Flow B is rare and expensive — only needed if the *fabric itself* changes (different tile
count, new tile types). Flow C is the fastest sanity check when you just want an area number
for one module, no fabric involved at all. Flow D is what "did we actually run this block through
RTL-to-GDSII" really means — a genuine physical layout for just that block, much cheaper than
Flow B since there's no fabric-scale stitching involved.

---

## Flow A — Map a user design onto the existing shrunk fabric

This takes your Verilog/SystemVerilog design, synthesizes it for the fabric's LUT/tile
architecture, places-and-routes it (`nextpnr`), and produces a bitstream — the same three-stage
flow already proven for `lfsr8`/`shiftreg8` (issue #16 V1).

**Prerequisites:** the shrunk fabric must already be hardened (see Flow B) or at least
regenerated (Flow B's Stage 1) — you're mapping *onto* it, not building it.

```bash
export PATH="$HOME/.fabulous/oss-cad-suite/bin:$PATH"   # yosys, nextpnr, iverilog

FAB_V2="$HOME/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2"
PROJ="$FAB_V2/fabric_caravel_proj"

# 1. Your design + its top-level IO wrapper go here (see
#    Librelane_work/chip_wrapper/user_design_shrunk/top_wrapper_lfsr8.v for the wrapper
#    convention: 16 bidirectional IO cells, one Global_Clock instance, io_in/io_out/io_oeb).
cp your_design.v top_wrapper_your_design.v "$PROJ/user_design/"

# 2. Synthesize for the fabric (yosys's synth_fabulous pass -- NOT generic synth)
yosys -p "synth_fabulous -top top_wrapper_your_design -json build/your_design.json" \
  "$PROJ/user_design/your_design.v" "$PROJ/user_design/top_wrapper_your_design.v"

# 3. Place and route onto the fabric (nextpnr-generic is this project's default --
#    confirmed from fabric_caravel_proj/Test/Makefile's NEXTPNR variable; don't
#    substitute nextpnr-himbaechel, both exist on this machine but the Makefile
#    default is what's actually been validated here)
FAB_ROOT="$PROJ" nextpnr-generic --uarch fabulous --json build/your_design.json \
  -o fasm=build/your_design.fasm

# 4. Generate the bitstream
bit_gen -genBitstream build/your_design.fasm "$PROJ/.FABulous/bitStreamSpec.bin" \
  build/your_design.bin
```

Or, more simply, reuse the project's own Makefile target directly (this is exactly what the
four manual steps above do):

```bash
cd "$FAB_V2/fabric_caravel_proj/Test"
make DESIGN=your_design TOP_WRAPPER=top_wrapper_your_design build_test_design
# Bitstream lands at build/your_design.bin (+ .hex, .fasm)
```

**LC count / Fmax numbers** come from `nextpnr`'s own stdout during step 3/the Makefile run —
look for the utilization and timing summary it prints at the end of place-and-route.

**Behavioral verification before trusting the bitstream:** simulate it against the FABulous
oracle testbench before assuming it's correct — `-DDUT_MODULE=` is required (tells the
testbench which module to instantiate):

```bash
BEH="$(ls "$PROJ/Test/build/fabric_files"/*.v | grep -vE '\.(bb|nl|pnl)\.v$')"
iverilog -g2012 -s tb_shrunk_oracle -DDUT_MODULE=your_design -o build/oracle.vvp \
  $BEH "$PROJ/user_design/your_design.v" \
  "$HOME/Repos/Tracked_FPGA_experiments/Librelane_work/chip_wrapper/tests/tb_shrunk_oracle.v"
vvp build/oracle.vvp +bitstream_hex=build/your_design.hex
# grep the output for "PASS:" -- sims exit 0 even on FAIL displays, so a zero
# exit code alone doesn't mean the design matched the oracle (see
# run_shrunk_validation.sh's `simgrade` helper, which greps for this reason).
```

See `Librelane_work/chip_wrapper/tools/run_shrunk_validation.sh` for the full V1-V3 gate
(bitstream build, behavioral sim, gate-level sim) if you want the complete, stricter check
used before anything goes to chip-level hardening.

**Multi-file / self-contained designs (no `tb_shrunk_oracle` stimulus block written for them
yet):** `sc_multiply_chain_fabric_tb.v` (in the same `user_design_shrunk/` directory) is a worked
example of the same self-write-config-load pattern, written directly against a multi-file
SystemVerilog design instead of `tb_shrunk_oracle`'s single-file `-DDUT_MODULE=` convention.
Compile it with a curated file list, not the stock `copy-files` Makefile target's glob — that
glob picks up every `.v` under `Tile/`, including stale LibreLane hardening-run artifacts
(`*.bb.v` blackbox stubs from `macro/runs/`) that declare the same sky130 cell multiple times and
fail to compile:

```bash
cd "$FAB_V2/fabric_caravel_proj/Test"
TILE_FILES=$(find ../Tile -iname "*.v" ! -path "*/macro/*" ! -path "*/runs/*" \
  ! -path "../Tile/RAM_IO/Config_access.v")   # RAM_IO and W_IO both define Config_access; pick one
FABRIC_FILES=$(find ../Fabric -maxdepth 1 -iname "*.v")
iverilog -g2012 -DYOSYS -I../user_design/common \
  -s your_design_tb -o build/your_design.vvp \
  $TILE_FILES $FABRIC_FILES \
  ../user_design/<your design's .sv files, in dependency order> \
  your_design_tb.v
vvp build/your_design.vvp +output_waveform=build/your_design.fst \
  +bitstream_hex=build/your_design.hex -fst
```

`-DYOSYS` forces `ma_assert.svh`'s dummy (no-op) elaboration-check path — Icarus doesn't support
SystemVerilog `inside` expressions, which `MA_ASSERT_ELABOR`'s real macro body uses.

**A clean structural/protocol match (0 mismatches vs. the golden RTL) is not proof the design's
numeric behavior is sane** — see
`~/wiki/fpga_stochastic_blocks/reusable_lessons/free-running-generator-period-lock-with-encoder-width.md`
for a real case where a design passed a perfect structural match while silently computing a
constant `0 * const` on every cycle. If a design's stimulus comes from an internal free-running
generator (the pin-budget trick used here), trace its actual captured value at the consumer (e.g.
via a hierarchical reference like `dut_i.chain_i.u_encoder_a.r.binary_in_d` in the testbench) and
confirm it actually varies across samples, not just that outputs match another instance of the
same buggy RTL.

---

## Flow B — Harden the fabric itself (full RTL-to-GDSII of the fabric macro)

Only do this if the fabric's own architecture changed (tile count, new tile types, different
`fabric.csv`). This is the expensive, hours-class flow.

### Stage 1 — Regenerate fabric RTL (fast, minutes)

```bash
export PATH="$HOME/.fabulous/oss-cad-suite/bin:$PATH"
FAB_V2="$HOME/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2"
bash ~/Repos/Tracked_FPGA_experiments/Librelane_work/chip_wrapper/tools/regen_caravel_fabric.sh
```

This produces `Fabric/eFPGA_top.v` with the current `fabric.csv`'s tile layout. Sanity-check the
printed `NumberOfRows=`/`NumberOfCols=` lines match what you expect before continuing — Stage 2
is expensive, don't discover a wrong fabric.csv after a multi-hour run.

### Stage 2 — GDS harden (hours, tens of GB RAM)

Needs the Nix devshell with LibreLane + the sky130A PDK (see **Environment setup** below —
first time only, takes a while to fetch).

```bash
bash ~/Repos/Tracked_FPGA_experiments/Librelane_work/chip_wrapper/tools/harden_caravel_fabric.sh
```

This runs, in order: `gen_all_tile_macros` (hardens each tile type), then `gen_fabric_macro`
(stitches tiles into the full fabric macro, LVS/DRC/Antenna signoff). It automatically applies
the known IO-placement fix (`docs/issue-12/apply-fix.sh`) before stitching — **do not skip
this fix**, fabric-stitch LVS fails without it (see `docs/issue-12/root-cause.md`).

Logs land in `FABulous_work/harden-caravel-shrunk.log`; a RAM usage trace writes to
`FABulous_work/harden-ram.log` (useful if you need to know what's actually eating memory).

**Check the result:**

```bash
grep -aiE 'Circuits match|LVS|DRC|Antenna|violation' FABulous_work/harden-caravel-shrunk.log
ls -la FABulous_work/fabulous-v2/fabric_caravel_proj/Fabric/macro/final_views/lef/eFPGA.lef
grep -m1 'SIZE' FABulous_work/fabulous-v2/fabric_caravel_proj/Fabric/macro/final_views/lef/eFPGA.lef
```

`Circuits match` (from Netgen LVS) with no DRC/Antenna violations reported = clean.
The GDSII file itself is under `Fabric/macro/final_views/gds/`.

---

## Flow E — New custom tile to full-fabric GDSII

Use this when a new hardened block (e.g. `BTS`, `STB`, `SMUL`, `SADD`) becomes a **tile** in the
fabric. It is the front half that Flow B assumes already exists: author the tile, harden it alone,
then harden the whole fabric. Every step below was hit and solved during issue #22; the root-cause
writeups are linked at the end. The reusable-lesson version of the tile rules is
`~/wiki/fpga_stochastic_blocks/reusable_lessons/fabulous-custom-tile-authoring-methodology.md`.

`FABulous_work/` is gitignored, so tile sources live only there. The tracked backups are under
`docs/issue-22/*/source/` with a `restore-tile-files.sh` each. After authoring a new tile, copy its
files into a new `docs/issue-<n>/<name>/source/` the same way, or they exist nowhere in git.

**Project directory:** the issue-22 READMEs say `fabric_btos_only_proj`, which no longer exists on
disk. The current stochastic project is `FABulous_work/fabulous-v2/fabric_sc_proj` (grid
`W_IO,BTS,LUT4AB,RegFile,LUT4AB,…,STB,E_IO`). Substitute it in those READMEs' commands. Check
`ls FABulous_work/fabulous-v2` first, since project names change.

All `FABulous` commands run inside the Nix devshell (see **Environment setup**):

```bash
cd ~/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2     # pinned v2.0.0b5
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  FABulous --project-dir fabric_sc_proj run "<command>"
'
```

### Stage 0 — Prove the RTL first

Functional correctness comes before any physical step (LVS/DRC prove manufacturability, not
function). Run the block's cocotb bench in `~/Repos/Microarch_Lib`, and for a stochastic block
optionally the on-FPGA replay check in `FPGA_hw_validation/`. Both test the RTL, not the FABulous
wrapper, so Stage 6 still needs a fabric-level simulation.

### Stage 1 — Write the BEL as one self-contained `.sv` under `Tile/<Name>/`

- Vendor the RTL into the tile directory. File discovery is scoped to the tile's own tree, so do
  not reference `Stochastic_Blocks/rtl/` or `Microarch_Lib`.
- Tag the ports on the BEL top module: `(* FABulous, EXTERNAL, SHARED_PORT *) input logic UserCLK`
  for the clock, and `SHARED_RESET` / `SHARED_ENABLE` for a shared reset or enable.
- **Add a dummy carry pair even if the tile has no arithmetic.** Put
  `(* CARRY="dummy" *)` on one unused input and one unused output, and tie them
  together (`assign out = in;`). Without it the tile has one fewer real pin than carry-capable
  tiles like `LUT4AB`, `UserCLK` lands one pin-width out of alignment, and fabric-stitch LVS fails
  with no earlier symptom. Reference: `docs/issue-22/bts-carry-chain-fix/`.
- The tile generator supports at most 32 input and 8 output BEL ports in total per tile (shared
  reset/enable and `CARRY` ports don't count). This is why `STB` uses `WIDTH=6`.
- Port declarations go one per line, and the BEL needs a `NoConfigBits` parameter (0 if it has no
  config bits). A BEL with config bits also needs a `BelMap` attribute.
- The docs call tile generation experimental. Read every generated file.
- Pure `.sv` BELs need the tile-macro glob patch (tracked, idempotent):

  ```bash
  docs/issue-22/tile-macro-sv-glob-fix/apply-fix.sh FABulous_work/fabulous-v2
  ```

  Skip it and hardening dies at `Verilator MODMISSING` before floorplan.

### Stage 2 — Scaffold the tile config with the tool

```bash
# Delete stale generated files first, including <Name>.csv, *_switch_matrix.*,
# *_ConfigMem.*, *_io_pin_order.yaml, the BEL .json and the whole macro/ directory.
# generate_custom_tile_config silently skips if ANY .csv survives under the tile dir
# (including macro/final_views/metrics.csv from a previous harden).
FABulous --project-dir fabric_sc_proj run "generate_custom_tile_config Tile/<Name>"
```

This writes `Tile/<Name>/<Name>.csv`, `<Name>_generated_switch_matrix.list` (based on the `LUT4AB`
switch matrix, so routing stays uniform) and updates `user_design/custom_prims.v` (see Stage 5).
Don't hand-edit the tile CSV's carry line. While the CSV says `MATRIX,GENERATE`, the `.list` is
regenerated on every `generate_custom_tile_config` and `run_FABulous_fabric`, so edits to it are
lost, and the switch-matrix `.csv` is always rebuilt from the `.list`.

To hand-tune the routing, change `MATRIX,GENERATE` to
`MATRIX,./<Name>_generated_switch_matrix.list`. After that the list stops regenerating and is yours
to edit. List lines are `<output>,<input>`, several lines for one output make a mux, and
`[a|b]`, `{N}` and `INCLUDE` are shorthand. Note that if the list is edited by hand, re-running
`generate_custom_tile_config` no longer updates it when the BELs change.

Add `Tile/<Name>/gds_config.yaml` with `DIE_AREA: [0, 0, 246, 245]` (the standard single-tile
footprint, which keeps pin alignment with the other tiles). Copy `docs/issue-22/stb-eio-fabric-integration/source/STB/gds_config.yaml` as a starting point.
If the logic does not fit, size it with `--optimise balance`, then verify at the real footprint
with a `no_opt` harden.

### Stage 3 — Place the tile in the fabric and regenerate the model

Edit `fabric.csv`: put the tile in the grid and add it to the tile-inclusion list at the bottom.
Then:

```bash
FABulous --project-dir fabric_sc_proj run "run_pyscript $(pwd)/fabric_sc_proj/build_fabric.py"
```

Use `run_pyscript` with an **absolute** path. The documented `script` command treats a `.py` file as
Tcl in this fork, and a relative path is not resolved against the project directory.

**Edge-IO tiles are not text-mirrors.** If you mirror `W_IO` into an east-edge tile, keep the
reference tile's direction-line **block order**. A pin's Y-slot comes from declaration order, not
from the `WEST`/`EAST` keyword or the port name. A name-only mirror shorts two drivers together
and shows up only at fabric-stitch LVS. Reference: `docs/issue-22/stb-eio-fabric-integration/`.

### Stage 4 — Harden the tile alone, then read the metrics

```bash
FABulous --project-dir fabric_sc_proj run "gen_tile_macro <Name>"
```

Do not trust the pass/fail line alone. Check that `design__lvs_error__count`,
`route__drc_errors`, `klayout__drc_error__count`, `antenna__violating__nets`,
`design__disconnected_pin__count` and `design__critical_disconnected_pin__count` are all `0`
and that the manufacturability report shows Antenna/LVS/DRC `Passed`. Also grep the post-PnR STA
`checks.rpt` at the worst corner (see the max-slew gotcha below).

### Stage 5 — Make yosys and nextpnr see the primitive

- **nextpnr:** nothing to do by hand. The model (`bel.txt`, `pips.txt`) is written during fabric
  generation (`gen_model`, part of `run_FABulous_fabric`), so regenerate the fabric after any tile
  change and the new BEL appears in `.FABulous/bel.txt`.
- **yosys:** `generate_custom_tile_config` adds a blackbox of the BEL to
  `user_design/custom_prims.v`, with every vector unrolled to single-bit ports (`binary_in0`,
  `binary_in1`, …) and `UserCLK` renamed `CLK`. The `Test/Makefile` passes it as
  `-extra-plib` automatically. Run yosys by hand and you must pass it yourself:
  `yosys -p "synth_fabulous -top <top> -json out.json -extra-plib user_design/custom_prims.v" ...`.
- **User design:** instantiate the primitive by its module name with the unrolled port names (see
  `fabric_sc_proj/user_design/bts_test.v`, which instantiates `FABulous_binary_stochastic_converter_sync`).
  Without a techmap yosys treats it as a blackbox and won't optimize through it. A techmap is
  optional and only needed for yosys to infer the BEL from plain RTL.
- Clocked designs need `(* keep *) Global_Clock inst_clk (.CLK(clk));` in the top module.

### Stage 6 — Simulate with the new tile in the fabric

Do this before the multi-hour fabric harden. Map a design that exercises the tile through Flow A
and run `Librelane_work/chip_wrapper/tools/run_shrunk_validation.sh`. The SMUL/SADD chain
testbench (`user_design_shrunk/sc_multiply_chain_fabric_tb.v`) is the closest example. Grep the output
for `PASS:`, because the sims exit 0 even on a FAIL display. Use Verilator 2-state for gate-level
sims, since icarus X-locks on this netlist family.

### Stage 7 — Harden every tile, then stitch the fabric

```bash
FABulous --project-dir fabric_sc_proj run "gen_fabric"
FABulous --project-dir fabric_sc_proj run "gen_all_tile_macros --parallel"
FABulous --project-dir fabric_sc_proj run "gen_fabric_macro"
```

If you run `gen_fabric_macro` by hand, apply `docs/issue-12/apply-fix.sh` first (the Flow B wrapper
script does it for you). Expect hours and tens of GB of RAM at the stitch.

Success is `Circuits match uniquely` with `design__lvs_device_difference__count`,
`design__lvs_unmatched_device__count`, `design__lvs_unmatched_net__count` and
`design__lvs_unmatched_pin__count` all `0`, and equal `Number of devices` / `Number of nets` on both
sides. Ignore the long `Cell <Tile> (0) disconnected node` section in netgen's report, which is a
benign per-macro listing. A real failure shows as a nonzero `unmatched_net`/`unmatched_pin` count.
`unmatched_net: 1` counts *groups*, so it can hide hundreds of nets.

The GDSII is under `Fabric/macro/final_views/gds/`.

### Stage 8 — Record it

1. Copy the new tile's `.csv`, BEL `.sv`, `gds_config.yaml`, switch-matrix `.list` (if
   hand-authored) and the updated `fabric.csv` into `docs/issue-<n>/<name>/source/`, with a
   `restore-tile-files.sh` modelled on `docs/issue-22/smul-sadd-fabric-integration/`.
2. Add the result to `HANDOFF.md`, and any new failure mode to the wiki reusable lesson.
3. If the fabric size or tile set changed, re-diff `rtl/efpga_top_caravel_bb.v` against the new
   macro (Flow B's note) and re-run the chip-wrapper checks.

### Limits of this flow

- Stage 0's on-FPGA check validates the RTL on 7-series, not the FABulous wrapper or the sky130
  netlist. Gate-level simulation of the hardened fabric is the check that covers those.
- The `.lib` timing models for the hardened macros are tracked in issue #21, so timing signoff is
  not part of this flow yet.

### Root-cause writeups behind these steps

- `docs/issue-22/tile-macro-sv-glob-fix/` — `.sv` files dropped from tile hardening.
- `docs/issue-22/bts-carry-chain-fix/` — dummy `CARRY` for tiles with no carry chain.
- `docs/issue-22/stb-eio-fabric-integration/` — edge-IO mirroring and direction-line block order.
- `docs/issue-22/smul-sadd-fabric-integration/` — the same methodology applied cleanly the first
  time.
- `docs/issue-12/root-cause.md` — fabric-stitch IO-placement fix.

---

## Flow C — Standalone sky130 synthesis smoke (no fabric, no P&R)

For a quick area/gate-count datapoint on one RTL module, no fabric or PnR involved —
Yosys-only, generic or sky130-mapped. This is what was used for the `Microarch_Lib`
stochastic-block RTL (`Stochastic_Blocks/rtl/`).

```bash
export PATH="$HOME/.fabulous/oss-cad-suite/bin:$PATH"

# Generic (technology-independent) gate count:
yosys -p "read_verilog -sv your_module.sv; synth -top your_module; stat"

# sky130-mapped (real standard-cell area in um^2):
LIB=~/.ciel/ciel/sky130/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71/sky130B/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys -p "
  read_verilog -sv your_module.sv;
  synth -top your_module -flatten;
  dfflibmap -liberty $LIB;
  abc -liberty $LIB;
  stat -liberty $LIB
"
```

`stat -liberty` prints per-cell-type counts and a total chip-area figure in µm² at the bottom.
No `PDK_ROOT`/ciel/Nix setup needed for this — just the `.lib` file path above, which is
already fetched on this machine.

---

## Flow D — Standalone RTL-to-GDSII of one block in isolation (real physical layout, not through the fabric)

For a real, signed-off GDSII of a single RTL module on its own — not mapped onto the FABulous
fabric, not part of a larger macro. This is the "did we actually run this block through the full
RTL-to-GDSII flow" question, answered concretely: yes, via a plain LibreLane "Classic" flow config,
the same shape as `librelane`'s own `examples/spm/config.yaml` (no FABulous-specific machinery
involved at all).

Needs the same Nix devshell + sky130A PDK as Flow B (see **Environment setup** below).

```yaml
# Stochastic_Blocks/librelane/<block_name>/config.yaml
DESIGN_NAME: your_module
VERILOG_FILES:
  - dir::../../rtl/common/ma_assert.svh   # only ma_assert.svh -- it transitively
                                            # includes ma_assert_std/dummy.svh itself;
                                            # listing those directly too causes a
                                            # macro-redefinition lint warning
  - dir::../../rtl/your_module.sv
VERILOG_INCLUDE_DIRS:
  - dir::../../rtl/common
CLOCK_PORT: clk
CLOCK_PERIOD: 10

# Tiny/small designs need an explicit die size -- utilization-based
# auto-sizing (FP_CORE_UTIL) has no sensible floor for near-zero-area
# designs and can produce a die too narrow for the default PDN strap
# configuration (PDN-0185). 100x100 worked for a 4-gate design; scale up
# for designs with real sequential logic.
FP_SIZING: absolute
DIE_AREA: [0, 0, 200, 200]
```

```bash
cd ~/Repos/Tracked_FPGA_experiments/FABulous_work/fabulous-v2
nix develop --command bash -c "
  export PDK_ROOT=\$PWD/.pdk
  cd ~/Repos/Tracked_FPGA_experiments/Stochastic_Blocks/librelane/your_module
  librelane config.yaml
"
```

**Check the result the same way as Flow B:** `Antenna: Passed / LVS: Passed / DRC: Passed` in the
final output means the GDSII is geometrically manufacturable — but that is a *different* guarantee
than "meets timing at every corner." Explicitly check the post-PnR STA report at your worst corner
before trusting a "Flow complete" result as fully clean:

```bash
RUN=$(ls -td Stochastic_Blocks/librelane/your_module/runs/*/ | head -1)
grep -A20 "report_check_types -max_slew -max_cap -max_fanout -violators" \
  "$RUN/*openroad-stapostpnr*/nom_ss_100C_1v60/checks.rpt"
```

See the **Known gotchas** section below for a real max-slew-at-worst-corner failure this exact
check caught, and its fix.

## Environment setup (Flows B, D and E — Flows A and C don't need this)

Flows B, D and E need LibreLane + the sky130A PDK via Nix. Flows A and C only need the plain
`oss-cad-suite` binaries (`yosys`, `nextpnr-generic`, `bit_gen`, `iverilog`), already on
`PATH` via the exports above — no Nix, no PDK fetch.

```bash
# One-time, from FABulous_work/ (never ~/Repos/FABulous):
git clone https://github.com/FPGA-Research/FABulous.git fabulous-v2
cd fabulous-v2 && git checkout 4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a   # pinned v2.0.0b5
nix develop   # builds/fetches the devshell: FABulous + LibreLane v3.0.3 + EDA tools
```

The PDK (sky130A, ciel commit `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`) auto-fetches into
`PDK_ROOT` (a multi-GB download, not cached in the Nix store) the first time a project inside
the devshell references it. See `docs/gds-toolchain-bootstrap.md` for the full pin table and
why each version is pinned where it is.

**Do not** `nix flake update` this project's pins without re-validating — LibreLane is a
floating flake input; reproducibility rests entirely on the committed `flake.lock`.

---

## Known gotchas (already hit once, recorded so you don't rediscover them)

- **Vivado (a separate tool, used for the Zybo Z7 FPGA comparison, not this ASIC flow) needs
  `libtinfo.so.5`**, which isn't installed system-wide on this machine (only `.so.6` is).
  Vivado bundles a compatible one:
  `export LD_LIBRARY_PATH="/home/jay/Programs/AMD/Vivado/2024.1/lib/lnx64.o/Rhel/9:$LD_LIBRARY_PATH"`
  before running `vivado`. Not relevant to Flows A/B/C above, only if you're also doing the
  FPGA-side comparison.
- **Fabric-stitch LVS fails without the issue #12 IO-placement patch** — `harden_caravel_fabric.sh`
  applies it automatically; if you ever run `gen_fabric_macro` manually outside that script,
  apply `docs/issue-12/apply-fix.sh` first.
- **A TB that drives DUT inputs on the sampling posedge** causes golden-vs-gate-netlist mismatches
  that look like a single wrong bit walking down a shift chain — drive stimulus on the *negedge*
  instead (see `docs/issue-16/shrunk-validation.md`'s debugging notes).
- **icarus (iverilog/vvp) 4-state simulation X-locks on this netlist family** at the gate level —
  use Verilator in 2-state mode for gate-level sims, not icarus, if you're doing Flow B's
  post-layout verification.
- **"Flow complete" + Antenna/LVS/DRC all Passed does NOT mean timing is closed at every corner.**
  Hardening `Microarch_Lib`'s `binary_stochastic_converter` (Flow D) passed manufacturability
  cleanly but failed max slew at the slow-slow corner — a reset-fanout buffer satisfied
  `MAX_FANOUT_CONSTRAINT`'s default of 10 (a load-count limit) without having enough drive
  strength to swing that load fast enough at the worst corner. Neither `DESIGN_REPAIR_MAX_SLEW_PCT`
  nor enabling `RUN_POST_GRT_DESIGN_REPAIR` fixed it — tightening `MAX_FANOUT_CONSTRAINT` itself
  (to 4) did. Full writeup, ruled-out fixes, and how to spot this pattern:
  `~/wiki/fpga_stochastic_blocks/reusable_lessons/max-fanout-constraint-vs-max-slew-at-worst-corner.md`.
  Always grep the post-PnR STA `checks.rpt` at your worst corner directly (see Flow D above) rather
  than trusting the summary line alone.

## See Also

- `Librelane_work/chip_wrapper/tools/run_shrunk_validation.sh` — the full V1-V3 pre-harden
  gate (bitstream build + behavioral sim + gate-level sim), stricter than Flow A alone.
- `docs/gds-toolchain-bootstrap.md` — full toolchain pin table and rationale.
- `docs/issue-12/root-cause.md` — the fabric-stitch LVS fix Flow B depends on.
- `docs/issue-16/shrunk-validation.md` — the original V1-V3 validation this runbook's Flow A
  reuses commands from.
