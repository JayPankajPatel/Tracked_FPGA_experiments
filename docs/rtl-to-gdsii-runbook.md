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

## Environment setup (Flow B and D — Flows A and C don't need this)

Flow B needs LibreLane + the sky130A PDK via Nix. Flows A and C only need the plain
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
