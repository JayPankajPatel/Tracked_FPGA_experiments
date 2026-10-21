# Findings log for the paper

What has been tested, how, what came out, and what it does and does not mean. Every number has a source. Where a number
comes from a git-ignored file (Vivado or LibreLane run directories), it is copied here so it can be cited without
re-running; the command to regenerate it is given.

Status key: **Measured** = produced by a tool run in this project. **Reproduces literature** = agrees with a published
claim. **Pending** = run in progress or not yet done.

## 1. Claims the evidence supports

| # | Claim | Strength | Section |
|---|---|---|---|
| C1 | Every stochastic RTL block behaves identically on real silicon (Zybo Z7-10) and in cocotb simulation, cycle for cycle | Measured, 18 configurations, 0 mismatches | 3.1 |
| C2 | Naive seed-based decorrelation fails: seeds 1 and 2 are one LFSR step apart, so a multiplier approximates min(a,b) | Measured (Python golden model, N up to 2^16) | 3.2 |
| C3 | With separated seeds, the multiply and add chains decode within 0.49 % and 4.31 % of full scale | Measured on hardware (WIDTH=8) | 3.3 |
| C4 | The binary-to-stochastic and stochastic-to-binary converters, not the multiplier, dominate area | Measured (sky130 standard-cell area); reproduces Alaghi and Hayes 2013 | 3.4 |
| C5 | A hardened converter tile replaces roughly 6 to 10 LUT4AB tiles of soft logic | Measured as synthesis cell counts (not placed) | 3.5 |
| C6 | Adding a custom tile to a FABulous fabric needs three non-obvious rules (dummy carry, `.sv` glob patch, edge-IO block order) | Measured (each rule found from a failed LVS or lint run) | 3.6 |
| C7 | The fabric with BTS and STB tiles hardens LVS, DRC and antenna clean | Measured on the earlier 2026-09-14 run; **re-run pending** | 3.7 |

## 2. Test setup

| Item | Value |
|---|---|
| RTL source of truth | `~/Repos/Microarch_Lib` (cocotb and Verilator) |
| Hardware | Zybo Z7-10 (xc7z010), Vivado 2024.1, 125 MHz, ILA and VIO over JTAG |
| Test width | WIDTH=8 (the width planned for use) |
| ASIC flow | LibreLane v3.0.3, sky130A, FABulous v2.0.0b5 |
| Standalone hardening clock | 10 ns (100 MHz) |
| Fabric | `fabric_sc_proj`: 14 rows by 10 columns, BTS in column 2, STB in column 9, `W_IO` and `E_IO` at the edges |

## 3. Findings

### 3.1 Hardware validation of every stochastic block (C1)

**Method.** Record the stimulus and expected outputs in cocotb, replay them from an on-chip ROM, capture with an ILA,
and diff against the simulation. Each block also has a negative control (one corrupted expected word must be detected).
Statistical checks apply to the chains.
**Result.** 0 mismatches in all 18 configurations: LFSR (807 cycles), counter (796), BTS (2630), STB (1812), multiplier,
adder and decorrelator (1558 each), loopback (2585), multiply and add chains (2055 each), their synchronous-reset twins,
and the FABulous BTS wrapper. All 18 negative controls fired. Worst post-route setup slack at 125 MHz: +1.38 ns (multiply
chain).
**Means.** The RTL is functionally correct when mapped to a real FPGA, which is stronger evidence than simulation alone.
**Does not mean.** The sky130 and FABulous netlists are validated. This tested the 7-series mapping of the RTL only.
Timing numbers here are for the whole bench including ILA, VIO and ROM and must not be used as block cost.
**Source.** `FPGA_hw_validation/docs/per-block-results.md`; waveforms in `FPGA_hw_validation/waveforms/<block>/`.
**Regenerate.** `FPGA_hw_validation/scripts/run_hw_regression.sh` (needs the board and the SSH tunnel).

### 3.2 Seed decorrelation failure (C2)

**Method.** Python golden model, WIDTH=8 (period 255), five strategies for sourcing two operand streams, AND-multiply,
N up to 65536. Averaged over four (p1, p2) pairs.

| Strategy | Mean absolute error vs true product |
|---|---|
| True random (control) | 0.0016 |
| Same seed | 0.131 |
| Seeds 1 and 2 (the integration-test default) | 0.038 |
| Half-period seed lag | 0.0052 |
| Different LFSR polynomial | 0.0077 |

For (0.3, 0.7), seeds 1 and 2 stop improving once N passes the LFSR period (error 0.0869 at N=512, 0.0841 at N=65536).
**Means.** The error is a fixed structural bias that more samples cannot average away. This is a real design constraint
for any LFSR-based stochastic computing hardware, and the existing "seeds differ" checks do not catch it.
**Does not mean.** The numbers come from the Python model, not a fresh RTL run. The model's LFSR convention was
cross-validated against the RTL in Microarch_Lib earlier, but these exact figures were not re-run through cocotb.
**Source.** `Stochastic_Blocks/results/README.md` and the CSVs beside it.

### 3.3 Chain accuracy on hardware (C3)

Criterion: decoded value within 10 % of full scale (255) of the ideal. Encoder seeds 1 and 204 (chosen from 3.2).

| Chain | Ideal | Max error (% full scale) | Worst case |
|---|---|---|---|
| Multiply | a·b/255 | 0.49 | a=128, b=128: decoded 63, ideal 64.3 |
| Add | (a+b)/2 | 4.31 | a=51, b=153: decoded 113, ideal 102.0 |

**Means.** With separated seeds the multiplier is accurate to well under 1 %. The adder's worst error is about nine times larger in
the same test. The cause was not investigated.
**Does not mean.** Eight input pairs were tested, not a sweep. The decoded values are what the chip produced because the
hardware trace equals the simulated trace bit for bit.
**Source.** `FPGA_hw_validation/docs/per-block-results.md`, chain tables.

### 3.4 Conversion logic dominates area (C4)

**Method.** Each block hardened standalone with LibreLane on sky130A at a 10 ns clock. Values are
`design__instance__area__stdcell` and `power__total` from `runs/<run>/final/metrics.json`.

| Block | Std-cell area (µm²) | Sequential cells | Total power (mW) |
|---|---|---|---|
| `stochastic_multiplier` | 233 | 0 | 0.007 |
| `stochastic_adder` | 1007 | 4 | 0.106 |
| `stochastic_to_binary` (STB) | 1575 | 10 | 0.321 |
| `binary_stochastic_converter` (BTS) | 1948 (earlier runs 1649 to 1655) | 15 | 0.507 |
| `sc_multiply_chain` | 4707 | 40 | 1.095 |
| `sc_add_chain` | 4949 | 45 | 1.108 |

One BTS plus one STB is 3523 µm², about 15 times the multiplier. Two BTS plus one STB, which is what one multiply
operation needs at its boundary, is about 5471 µm², about 23 times.
**Means.** This reproduces the survey's observation (Alaghi and Hayes 2013, Section 4, Table III: more than 80 % of the
stochastic design was SNGs and converters, and the complete system was larger than binary for the gamma function). The
cheap multiplier is not where the cost is.
**Does not mean.** Power is from default switching activity, not a measured workload. The BTS rows differ between runs
(1649 to 1948 µm²) because the config was tightened to `MAX_FANOUT_CONSTRAINT: 4` after a slow-corner slew violation
(see 3.8). Take the last run as current. The area is of the logic alone, not of any fabric around it.
**Source.** `Stochastic_Blocks/librelane/<block>/runs/*/final/metrics.json` (git-ignored). **Regenerate** with the
recipe in each `Stochastic_Blocks/librelane/<block>/config.yaml`.

### 3.5 Hard tile versus soft LUT mapping (C5)

**Method.** The same BTS and STB RTL synthesized with `synth_fabulous` for the classic LUT fabric, and counted.

| Block | LUT2 | LUT3 | LUT4 | LUT+FF | Total cells |
|---|---|---|---|---|---|
| BTS (WIDTH=8) | 11 | 9 | 31 | 27 | 81 |
| STB (WIDTH=6) | 6 | 10 | 11 | 14 | 42 |

A `LUT4AB` tile holds 8 LUT/flop slots, so ideal packing needs about 10 tiles for BTS and 6 for STB. The hard versions
occupy one standard 246 by 245 µm tile each and use no LUTs.
**Means.** Hardening the converters turns roughly 6 to 10 tiles of soft logic into one tile. That is the fabric-level
argument for hardening them, in the same units (LUTs) as the survey's Table III.
**Does not mean.** These are synthesis cell counts. Packing in a placed design is worse, and routing between LUTs adds
switch-matrix hops. No Fmax or power was compared. STB is WIDTH=6, not 8, because FABulous limits a tile to 8 outputs.
The comparison against a hardened binary INT4 MAC tile, which is the planned headline comparison, has not been made.
**Pending:** a placed Flow A mapping on the 8x8 fabric to get placed LUT counts and Fmax.
**Regenerate.** `yosys -p "read_verilog -sv Tile/<T>/<file>.sv; synth_fabulous -top <module> -json out.json; stat"`,
run in `fabric_sc_proj`.

### 3.6 Custom-tile integration rules (C6)

Three failures found while adding BTS, STB and E_IO, each with a root cause and a tracked fix:

1. A tile with no carry chain has one fewer real pin than its neighbours, which shifts `UserCLK` out of alignment and
   fails fabric-stitch LVS with no earlier symptom. Fix: a dummy `CARRY` in/out pair. (`docs/issue-22/bts-carry-chain-fix/`)
2. The tile-hardening flow globbed only `**/*.v`, silently dropping `.sv` BELs, which fails as a Verilator
   `MODMISSING`. Fix: a +5/−2 patch. (`docs/issue-22/tile-macro-sv-glob-fix/`)
3. An edge-IO tile mirrored from `W_IO` by name substitution shorted two drivers, because a pin's Y-slot comes from
   the CSV direction-line block order, not from the `WEST`/`EAST` keyword. Fix: reorder the blocks.
   (`docs/issue-22/stb-eio-fabric-integration/`)

The SMUL and SADD tiles, added afterwards using these rules, hardened clean on the first attempt.
**Means.** The rules are a reusable methodology contribution, and the clean first-time SMUL/SADD result is the evidence
they are sufficient.
**Does not mean.** The rules are proven general. They were derived on one fabric and one FABulous version (v2.0.0b5).

### 3.7 Fabric-level results (C7)

- **Earlier run (2026-09-14):** the 10-column fabric with BTS, STB, SMUL, SADD and E_IO hardened with all LVS, DRC and
  antenna metrics at 0 and `Circuits match uniquely`. Source: `docs/issue-22/*/README.md`.
- **Classic 8x8 fabric (June 2026):** the shrunk Caravel fabric (no stochastic tiles) hardened clean at
  1989.96 by 2457.52 µm (4.89 mm²), within 0.2 % of the area model's prediction. Source: wiki
  `shrunk-caravel-fabric-harden-2026-06-15.md`.
- **Functional simulation (2026-10-21):** the regenerated `fabric_sc_proj` RTL fabric (14 by 10, BTS and STB only, SMUL
  and SADD removed) passed a behavioural simulation of `bts_test`: all 256 input values matched the reference RTL across
  full 255-bit bursts. This is an RTL-level zero-delay model, not a simulation of the hardened macro. The test bench
  needed its pin mapping fixed because E_IO had doubled the IO count to 56 and interleaved the west and east pins; the
  RTL was not at fault.
- **Re-run on the reduced project: pending.** `gen_all_tile_macros` and `gen_fabric_macro` were started on
  2026-10-21 and results go in this section when they finish.

**Means.** The fabric is manufacturable-clean (earlier run) and functionally correct for BTS (this run).
**Does not mean.** Timing is closed. The `.lib` timing models for the hardened macros are tracked in issue #21 and do
not exist yet. No STB fabric simulation exists, and no gate-level simulation of the final netlist has been run.

### 3.8 Timing and slew lesson (supporting)

BTS passed manufacturability but failed max slew at the slow-slow corner: a reset-fanout buffer met the default
`MAX_FANOUT_CONSTRAINT` of 10 (a load-count limit) without the drive strength to swing that load at the worst corner.
Neither `DESIGN_REPAIR_MAX_SLEW_PCT` nor `RUN_POST_GRT_DESIGN_REPAIR` fixed it. Tightening the constraint to 4 did.
**Means.** A clean LVS, DRC and antenna result does not imply timing closure at every corner, so the STA report must
be checked at the worst corner directly.
**Source.** Wiki `reusable_lessons/max-fanout-constraint-vs-max-slew-at-worst-corner.md`.

## 4. What this work does not yet show

| Gap | Why it matters |
|---|---|
| Energy per operation | Efficiency claims need power under a real workload, not default activity |
| Hard SC tile versus hard binary INT4 MAC tile | The planned headline comparison; only SC-versus-soft-LUT exists |
| Placed soft mapping (Fmax, routing) | 3.5 is synthesis counts only |
| Timing closure at fabric level | Needs the macro `.lib` models (issue #21) |
| Gate-level simulation or equivalence check of the sky130 and FABulous netlists | Hardware validation covered 7-series only |
| Operations per conversion needed to break even | Table III and our 3.4 show the overhead; the break-even point is not measured |
| Accuracy over a sweep of inputs on hardware | 3.3 used eight input pairs |
| Result at widths other than 8 | Deliberately out of scope |

## 5. Reproducing

| What | Command or file |
|---|---|
| Hardware validation of all blocks | `FPGA_hw_validation/scripts/run_hw_regression.sh` (`docs/runbook.md` there) |
| Seed and correlation study | `Stochastic_Blocks/tb/accuracy_and_correlation_sweep.py` |
| Standalone sky130 hardening | `Stochastic_Blocks/librelane/<block>/config.yaml` |
| New tile to full fabric | `docs/rtl-to-gdsii-runbook.md`, Flow E |
| Fabric functional simulation | `make sim DESIGN=bts_test TOP_WRAPPER=top_wrapper_bts` in `fabric_sc_proj/Test` |

## 6. Reference

A. Alaghi and J. P. Hayes, "Survey of Stochastic Computing," ACM Trans. Embedded Computing Systems 12(2s), Article 92,
May 2013. Section 4 and Table III (LUT counts on a Xilinx Virtex-II Pro, from Qian et al. 2011) are the comparison
point for 3.4 and 3.5.
