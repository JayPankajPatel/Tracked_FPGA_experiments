# FPGA_hw_validation

On-hardware validation of RTL blocks on a Zybo Z7-10 (xc7z010) through the
remote-JTAG tunnel in `~/Programs/AMD/remote_fpga_jtag/` (hw_server on
`localhost:3121`). Tracking issue: #27. RTL and cocotb benches live in
`~/Repos/Microarch_Lib` (see Microarch_Lib#13 for why this harness is here).

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

## Status
| block | result |
|---|---|
| heartbeat (tooling bring-up) | PASS 2026-10-14 (4096-sample ILA capture; negative control FAILs) |

## Waveforms
Every run saves its ILA capture to `waveforms/<block>/capture.{ila,csv,vcd}` and these are
tracked in git. `.ila` reopens in Vivado (`read_hw_ila_data`), `.vcd` in GTKWave, `.csv` feeds the checkers.
A later run overwrites the files; history is in git.
