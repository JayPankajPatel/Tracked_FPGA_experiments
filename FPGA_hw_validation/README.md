# FPGA_hw_validation

On-hardware validation of the stochastic-computing RTL blocks on a **Zybo Z7-10 (xc7z010clg400-1)**, driven from
Vivado 2024.1 over a remote-JTAG tunnel. Tracking issue: [#27](https://github.com/JayPankajPatel/Tracked_FPGA_experiments/issues/27).

**Outcome (2026-10-14):** every stochastic block and its sync-reset twin (18 configurations) matches the cocotb-derived
simulation cycle-for-cycle on the real chip, with a working negative control for each. Details:
[`docs/per-block-results.md`](docs/per-block-results.md). Method and rationale: [`docs/design.md`](docs/design.md).
Step-by-step usage and troubleshooting: [`docs/runbook.md`](docs/runbook.md).

## What this proves (and does not)
| Proves | Does not prove |
|---|---|
| The RTL, as mapped by Vivado onto 7-series, behaves exactly like the verified simulation on the replayed vectors, including reset, handshake backpressure, and the clocked/async-reset behavior. | That the sky130 or FABulous *netlists* are correct: those still need gate-level simulation or a logic-equivalence check (LEC). |
| Chains reach the expected numerical accuracy on hardware (multiply max error 0.49 % FS, add 4.31 % FS at WIDTH=8, seeds 1/204). | Behavior on vectors/configurations that were not replayed (one configuration per block; sweeps belong in simulation). |
| Timing is met at 125 MHz on every build (worst slack +1.38 ns). | Anything about silicon area/power: build utilization figures include ILA/VIO/ROM overhead and are not block costs. |

## How it works (one paragraph)
Per block, a cocotb simulation (Verilator, in `~/Repos/Microarch_Lib`'s pixi environment) applies a fixed-seed stimulus,
asserts every cycle against the block's existing golden model, and records the packed input vectors and the pre-clock-edge
outputs. On the board, a generic core (`rtl/hwb_core.sv`) replays the vectors from a ROM one per clock into the DUT; an ILA
captures `{dut_in, dut_out, run}` each cycle; a VIO starts the run. A Python checker diffs the ILA capture against the
recorded expectation. A corrupted expectation must make the checker fail (negative control).

## Quick start
```bash
# 0. on the machine that has the FPGA: start the tunnel (see docs/runbook.md)
~/Programs/AMD/remote_fpga_jtag/start_hw_tunnel.sh <user@this-host>

# 1. on this machine: health check (must print HW_CHECK PASS)
scripts/hw_session.sh scripts/hw_check.tcl

# 2a. one block, full flow: record -> build -> run -> compare -> negative control
scripts/run_replay_block.sh galois_lfsr

# 2b. everything (or name blocks), PASS/FAIL table at the end
scripts/run_hw_regression.sh
scripts/run_hw_regression.sh counter counter_sync
```
Outputs: `waveforms/<block>/capture.{ila,csv,vcd}` (tracked), `build/<block>/` (bitstream, ltx, reports; gitignored),
`build/<block>.flow.log` (gitignored).

## Layout
| Path | Purpose |
|---|---|
| `scripts/hw_session.sh` | Entry point: sources Vivado settings, checks the tunnel port, runs a Tcl script in batch. |
| `scripts/hw_check.tcl` | Health check: connect, require an `xc7z010`. |
| `scripts/hw_lib.tcl` | Tcl helpers: `hw_open` (program + attach probes), `vio_set`, `ila_save` (writes .ila/.csv/.vcd). |
| `scripts/build_block.tcl` | Project-mode batch build: synth, impl, bitstream, `.ltx`, timing + utilization reports. Generates the `vio_0`/`ila_0` IP from the block description. |
| `scripts/run_block.tcl`, `scripts/replay_run.tcl` | Program the board and run one replay: arm the ILA on `run` rising, pulse VIO `go`, save the capture. |
| `scripts/replay_block_common.tcl` | Shared block-description boilerplate (ILA/VIO widths from the recorder's `meta.tcl`). |
| `scripts/run_replay_block.sh` | Whole flow for one block, including the negative control. |
| `scripts/run_hw_regression.sh` | Runs many blocks sequentially (single JTAG chain), prints a PASS/FAIL table. |
| `scripts/make_sync_top.sh` | Derives a `_sync` variant of a Microarch_Lib test top by renaming the instantiated modules. |
| `rtl/hwb_core.sv` | Generic replay core: ROM, address counter, registered DUT inputs, ILA + VIO. |
| `rtl/hw_heartbeat_top.sv` | Tooling bring-up design (counter + VIO + ILA). |
| `constraints/zybo_z7_10.xdc` | 125 MHz clock (K17) + 4 LEDs. |
| `verif/hwrecord.py` | cocotb `Recorder`: cycle convention, packing, writes `vectors.mem`/`expected.mem`/`meta.*`/`hwb_params.svh`. |
| `verif/twoin.py`, `verif/chain.py` | Shared stimulus/golden helpers for the two-input blocks and for the multiply/add chains. |
| `verif/compare_trace.py` | ILA CSV vs recorded vectors/expectation, plus the chains' statistical table. |
| `blocks/<name>/` | One directory per tested configuration (see below). |
| `waveforms/<name>/` | Latest saved ILA capture for each block (`.ila` Vivado, `.vcd` GTKWave, `.csv`). |
| `docs/` | `runbook.md`, `design.md`, `per-block-results.md`. |

Each `blocks/<name>/` contains `record.py` (cocotb recorder + golden asserts), `Makefile` (simulation sources/params),
`<name>_hw_top.sv` (maps the packed words onto the DUT ports), `block.tcl` (Vivado sources), and a git-ignored `gen/`
(generated vectors and parameters). `*_sync` directories are generated twins for the synchronous-reset RTL variants.

## Status (2026-10-14, all bit-exact vs simulation; negative control FAILs as required)
| block | config | cycles | result | worst slack @125 MHz |
|---|---|---|---|---|
| heartbeat (tooling bring-up) | counter + VIO/ILA | 4096 | PASS | +1.93 ns |
| galois_lfsr / _sync | WIDTH=8, seed 1 | 807 | PASS / PASS | +2.25 / +2.25 |
| counter / _sync | UPTO=100 | 796 | PASS / PASS | +2.21 / +2.39 |
| binary_stochastic_converter (BTS) / _sync | WIDTH=8 | 2630 | PASS / PASS | +1.89 / +2.31 |
| fabulous_bts_sync (FABulous wrapper) | WIDTH=8 | 2630 | PASS | +2.31 |
| stochastic_to_binary (STB) / _sync | WIDTH=8 | 1812 | PASS / PASS | +2.05 / +1.68 |
| stochastic_multiplier | combinational | 1558 | PASS | +1.90 |
| stochastic_adder / _sync | select LFSR width 5 | 1558 | PASS / PASS | +1.96 / +1.96 |
| stochastic_decorrelator | FS=4 | 1558 | PASS | +2.24 |
| sc_loopback / _sync | WIDTH=8, decoded == encoded | 2585 | PASS / PASS | +1.85 / +1.80 |
| sc_multiply_chain / _sync | WIDTH=8, seeds 1/204 | 2055 | PASS / PASS | +1.38 / +1.63 |
| sc_add_chain / _sync | WIDTH=8, seeds 1/204 | 2055 | PASS / PASS | +1.68 / +1.42 |

The decorrelator and multiplier have no `_sync` twin in Microarch_Lib (the multiplier is combinational; the decorrelator
has only an async-reset implementation).

## Dependencies
Vivado 2024.1 (`~/Programs/AMD/Vivado/2024.1`), a Digilent-cabled Zybo Z7-10 reachable via `hw_server` on
`localhost:3121`, and `~/Repos/Microarch_Lib` (RTL, cocotb helpers, pixi environment with Verilator + cocotb + pylfsr).
Override locations with `VIVADO_SETTINGS`, `HW_URL`, `MICROARCH_LIB`. Microarch_Lib is **referenced, never modified**.
