# Runbook: hardware validation on the Zybo Z7-10

## 1. Topology
```
[machine with the board]                         [this machine: runs Vivado + the harness]
 Zybo Z7-10 --USB/JTAG-- hw_server :3121  ==ssh -R==>  localhost:3121  <-- vivado -mode batch
```
`hw_server` runs where the USB cable is; an SSH *reverse* tunnel exposes it as `localhost:3121` here. Source of the
tunnel scripts: `~/Programs/AMD/remote_fpga_jtag/` (`RUNBOOK.md`, `start_hw_tunnel.sh`). Do not use `ssh -L`.

## 2. One-time prerequisites
- Vivado 2024.1 here (`~/Programs/AMD/Vivado/2024.1/settings64.sh`); `vivado -mode tcl` must start (no `libtinfo.so.5` error).
- `~/Repos/Microarch_Lib` checked out with its pixi environment installed (`pixi install` there). The harness calls
  `pixi run --manifest-path ~/Repos/Microarch_Lib/pixi.toml make` and never writes into that repo.
- Zybo Z7-10 powered, jumper set so it is not waiting on boot media you care about (JTAG works regardless).

## 3. Every session
1. On the board's machine: `~/Programs/AMD/remote_fpga_jtag/start_hw_tunnel.sh <user@this-host>`; keep it open.
2. Here: `scripts/hw_session.sh scripts/hw_check.tcl` -> expect
   `HW_CHECK devices: arm_dap xc7z010` and `HW_CHECK PASS`.
3. Run blocks (below). Only **one** Vivado hardware session can use the JTAG chain at a time: run blocks sequentially
   (`run_hw_regression.sh` does).

## 4. Running
| Goal | Command |
|---|---|
| Health check | `scripts/hw_session.sh scripts/hw_check.tcl` |
| One block, everything | `scripts/run_replay_block.sh <block>` |
| Selected blocks + table | `scripts/run_hw_regression.sh <block> [block ...]` |
| All blocks | `scripts/run_hw_regression.sh` (about 4-5 min per block, dominated by implementation) |
| Only re-record vectors | `cd blocks/<block> && pixi run --manifest-path ~/Repos/Microarch_Lib/pixi.toml make` |
| Only build | `scripts/hw_session.sh scripts/build_block.tcl <block>` |
| Only run on board | `scripts/hw_session.sh scripts/run_block.tcl <block>` |
| Only re-compare | `python3 verif/compare_trace.py blocks/<block>/gen waveforms/<block>/capture.csv` |
| Different parameters | pass make variables, e.g. `scripts/run_replay_block.sh galois_lfsr WIDTH=16 SEED=0xACE1` (parameters reach the hardware top through the generated `gen/hwb_params.svh`) |

Pass criterion printed by the flow: `... mismatches=0 -> PASS`, then `negative control OK`, then `BLOCK <name>: PASS`.
Chains additionally print a per-window statistical table.

Viewing captures: `waveforms/<block>/capture.vcd` in GTKWave, or in the Vivado hardware manager
(`open_hw_manager; read_hw_ila_data waveforms/<block>/capture.ila; display_hw_ila_data`).
Signals: `dut_in` (packed inputs), `dut_out` (packed outputs), `run` (high while vectors are replayed). Packing is documented in
each `*_hw_top.sv` header and in `blocks/<name>/gen/meta.json` after recording.

## 5. Adding a block
1. Copy the closest existing directory (e.g. `blocks/counter/` for a single-DUT block, `blocks/stochastic_multiplier/` for a
   two-input block, `blocks/sc_multiply_chain/` for a chain).
2. `record.py`: build a `Recorder(dut, in_fields, out_fields)`. **First input field must be the active-low reset**
   (the all-zero idle word holds the DUT in reset). Call `await rec.preroll(...)` once with reset low, then drive cycles with
   `await rec.step(**inputs)`, which returns the pre-edge outputs for golden assertions, and finish with `rec.finalize(name, params)`.
   Params that appear as `` `P_<NAME> `` in the hardware top must be passed here (plain scalars; lists/dicts are metadata only).
3. `Makefile`: set `VERILOG_SOURCES`, `COCOTB_TOPLEVEL`, `-G` parameters; export `HWB_SYNC := 1` for sync-reset DUTs.
4. `<name>_hw_top.sv`: instantiate `hwb_core` and the DUT; map `dut_in`/`dut_out` bits in the same order as the fields.
   The top **must** have ports `clk` and `led[3:0]` (the constraints file references them).
5. `block.tcl`: set `BLOCK(top)` and `BLOCK(sources)`, then `source $root/scripts/replay_block_common.tcl`.
6. `scripts/run_replay_block.sh <name>`; fix until PASS; commit the block directory and `waveforms/<name>/`.

## 6. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| `ERROR: nothing listening on localhost:3121` | Tunnel not running. Restart `start_hw_tunnel.sh` on the board's machine. |
| `HW_CHECK FAIL: no target` / `xc7z010 not found` | Board unpowered, USB cable disconnected, or another Vivado session holds the cable. Replug, then re-run the health check. **Do not interpret a run that failed while the board was unplugged as an RTL failure**; rerun the block. |
| Run errors with `RUN_ERROR:` | Message is printed by `run_block.tcl`; check `build/<block>.run.log`. A hung batch Vivado can be killed by PID; avoid `pkill -f <pattern>` from a tool shell, it can match and kill the shell itself. |
| `No matching hw_probes were found` | Probe names are hierarchical and follow the RTL nets (`u_core/go`, `u_core/run`, `u_core/dut_in`). If you rename nets in `hwb_core.sv`, update `scripts/replay_run.tcl`/`verif/compare_trace.py`. |
| `MISMATCH cycle N` | A real discrepancy until proven otherwise. The checker prints the decoded input/output fields. Compare `waveforms/<block>/capture.vcd` against `gen/expected.mem`; confirm the board was not disturbed; rerun to check repeatability. |
| `golden mismatch` / assertion in `record` | The simulation disagrees with the golden model (the RTL or the recorder's expectation is wrong). Nothing is replayed until this is fixed. |
| Verilator `%Error: ... WIDTHTRUNC` on a `-G` override | An unsized decimal override to a narrow parameter; add `-Wno-WIDTHTRUNC` (already done for the chains). |
| Build fails with a missing `.mem` | Run the record step first; `gen/` is generated and git-ignored. |
| Timing violation | Lower the clock (edit the period in `constraints/zybo_z7_10.xdc`) or pipeline the bench; all current builds meet 125 MHz with >= 1.38 ns slack. |
