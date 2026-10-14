# FPGA_hw_validation

On-hardware validation of RTL blocks on a Zybo Z7-10 (xc7z010) through the
remote-JTAG tunnel in `~/Programs/AMD/remote_fpga_jtag/` (hw_server on
`localhost:3121`). Tracking issue: #27. RTL and cocotb benches live in
`~/Repos/Microarch_Lib` (see Microarch_Lib#13 for why this harness is here).

## Record/replay flow
`scripts/run_replay_block.sh <block>` runs record (cocotb/Verilator, golden-model asserted) -> build -> run on board -> compare ILA vs simulation -> negative control. Vectors are replayed on-chip from a ROM (`rtl/hwb_core.sv`); ILA captures `dut_in/dut_out/run` each cycle. New block = `record.py`, `Makefile`, `*_hw_top.sv`, `block.tcl` (copy `blocks/counter/`).

## Usage
```bash
scripts/hw_session.sh scripts/hw_check.tcl            # health check (needs tunnel up)
scripts/hw_session.sh scripts/build_block.tcl <block> # synth+impl+bit/ltx -> build/<block>/
scripts/hw_session.sh scripts/run_block.tcl   <block> # program, capture ILA -> waveforms/<block>/capture.{ila,csv,vcd}
python3 blocks/<block>/check.py results/<block>/ila.csv
```
Each block directory holds `block.tcl` (sources, VIO/ILA widths), `run.tcl`
(stimulus + capture) and a checker. ILA/VIO probe names follow the RTL net
names, so keep them stable.

## Status (2026-10-14, Zybo Z7-10, all bit-exact vs simulation, negative control FAILs as required)
| block | config | cycles | result |
|---|---|---|---|
| heartbeat (tooling bring-up) | counter + VIO/ILA | 4096 | PASS |
| galois_lfsr / _sync | WIDTH=8, seed 1 | 807 | PASS / PASS |
| counter / _sync | UPTO=100 | 796 | PASS / PASS |
| binary_stochastic_converter (BTS) / _sync | WIDTH=8 | 2630 | PASS / PASS |
| fabulous_bts_sync (FABulous wrapper) | WIDTH=8 | 2630 | PASS |
| stochastic_to_binary (STB) / _sync | WIDTH=8 | 1812 | PASS / PASS |
| stochastic_multiplier | combinational | 1558 | PASS |
| stochastic_adder / _sync | select LFSR width 5 | 1558 | PASS / PASS |
| stochastic_decorrelator | FS=4 | 1558 | PASS |
| sc_loopback / _sync | WIDTH=8, decoded == encoded | 2585 | PASS / PASS |
| sc_multiply_chain / _sync | WIDTH=8, seeds 1/204; max err 0.49% FS | 2055 | PASS / PASS |
| sc_add_chain / _sync | WIDTH=8, seeds 1/204; max err 4.31% FS | 2055 | PASS / PASS |

Run everything: `scripts/run_hw_regression.sh` (no args = every block with a `record.py`).

Scope limits: only the replayed vectors are covered; one configuration per block (WIDTH=8 / project defaults, not a
parameter sweep -- sweeps belong in simulation); this validates the RTL on 7-series, not the sky130 or FABulous netlists
(those still need gate-level simulation or an equivalence check). `_sync` chain/loopback tops are derived from the
Microarch_Lib test tops by `scripts/make_sync_top.sh`; the FABulous wrapper uses vectors recorded from the plain `_sync` BTS
(it only renames `clk` to `UserCLK`). The decorrelator and multiplier have no `_sync` twin in Microarch_Lib.

## Waveforms
Every run saves its ILA capture to `waveforms/<block>/capture.{ila,csv,vcd}` and these are
tracked in git. `.ila` reopens in Vivado (`read_hw_ila_data`), `.vcd` in GTKWave, `.csv` feeds the checkers.
A later run overwrites the files; history is in git.
