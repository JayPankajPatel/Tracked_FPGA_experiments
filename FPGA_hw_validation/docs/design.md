# Design: record-in-simulation / replay-on-chip hardware validation

## Goal
Show, with measured evidence, that each stochastic RTL block works on real silicon, individually, with reusable scripts,
using the ILA to observe behavior. (Issue #27.)

## Architecture
```
 cocotb + Verilator (Microarch_Lib pixi env)                       Zybo Z7-10 (xc7z010)
 ------------------------------------------                        -------------------------------------------
 record.py: fixed-seed stimulus                                    hwb_core
   | assert every cycle vs golden model                              ROM(vectors.mem) --addr--> registered dut_in --> DUT
   v                                                                 VIO: go (out), done (in)                          |
 gen/vectors.mem  (packed inputs, 1/cycle)  --$readmemh-->           ILA probes: dut_in, dut_out, run  <---------------+
 gen/expected.mem (packed pre-edge outputs)                                |
 gen/meta.{json,tcl}, hwb_params.svh                                       v
                                                                  waveforms/<block>/capture.{ila,csv,vcd}
                          verif/compare_trace.py  <----- diff ---- capture.csv
```

## Conventions that make the comparison exact
- **Cycle k** is the clock cycle in which the DUT sees vector k. In simulation the recorder drives inputs on the falling
  edge, samples outputs in the read-only phase *before* the next rising edge, then steps the clock. On hardware the ILA
  samples at the rising edge, so it sees the same pre-edge values, including combinational paths.
- **Registered DUT inputs.** `hwb_core` loads `dut_in` from a register, so inputs change right after a clock edge and are
  glitch-free. This matters for async-reset DUTs: a glitch on a combinationally decoded `rst_n` would reset the DUT.
- **Reset is part of the vector.** Bit 0 of every packed input word is the active-low reset, so the idle word `0` holds
  the DUT in reset before and after a run, and mid-run resets are replayed exactly.
- **Pre-roll.** Before recording, the recorder runs unrecorded idle reset cycles, mirroring the cycles hwb_core holds the
  DUT in reset before `go`; this removes any dependence on power-up state, which matters for sync-reset DUTs (they react to
  reset one edge late and power up in state 0).
- **Run alignment.** The ILA trigger is `run` rising (position 0), so sample 0 is vector 0. The checker finds the first
  `run == 1` sample and compares N cycles from there, checking both `dut_in == vectors` (the replay path) and
  `dut_out == expected`.
- **Probes.** Chains sample internal decoder signals (`u_decoder.*`) in simulation only, to derive the golden window
  popcounts; they are not part of the replayed or captured data.

## Golden models (reused, not rewritten)
| Block | Golden used at record time |
|---|---|
| galois_lfsr | pylfsr Galois reference via Microarch_Lib's `fpoly_for` / `state_to_int` |
| counter | simple model: `clr` beats `en`, wraps at 2^clog2(UPTO), reset to 0 |
| BTS | `golden_model()` from `test_binary_stochastic.py` (bit-for-bit burst), plus valid/ready/last_cycle rules |
| STB | `golden_model()` popcount per boundary-delimited window; in-order delivery, hold-while-stalled, no spurious/dropped results |
| multiplier | AND + join handshake |
| adder | MUX with select bits from `golden_select_bits()`, advancing once per fired bit, restarting on reset |
| decorrelator | `SegmentBasedGolden` scoreboard from `test_stochastic_decorrelator.py` + output-hold stability |
| loopback | identity: decoded value == encoded value |
| chains | decoded value == popcount of the bits the decoder accepted in that window; ideal value (a*b/255 or (a+b)/2) recorded for the statistical table |

## Decisions and alternatives considered
| Decision | Alternative rejected | Why |
|---|---|---|
| Record in simulation, replay from ROM | Drive inputs live from VIO over JTAG | JTAG writes are ~ms; per-cycle control and cycle-exact comparison are impossible. |
| Same cocotb golden models as the existing benches | Re-implement models in the harness | Avoids a second source of truth; a golden mismatch stops the flow before anything runs on the board. |
| Bit-exact compare | Statistical-only compare | Deterministic LFSR streams make bit-exact checks possible and far stricter; statistics are added on top for the chains. |
| ILA captures every replayed cycle (depth up to 4096) | Capture a window / compare on chip | Full waveform evidence is saved and reviewable; every vector set here fits in <= 4096 samples. |
| One generated hardware top per block | Generic parameterized top with the DUT passed in | SystemVerilog cannot pass a module type as a parameter portably in Vivado; per-block tops are small and explicit. |
| Harness lives in Tracked_FPGA_experiments | In Microarch_Lib | Microarch_Lib#13 is moving board/flow-specific code out of that library. |
| `_sync` twins reuse the base `record.py` with `HWB_SYNC=1` | Separate recorders | Same stimulus and golden; only reset-timing expectations differ. |

## Known limits
- RTL on 7-series only; sky130/FABulous netlists need gate-level simulation or LEC.
- One configuration per block; parameter sweeps stay in simulation/formal.
- Build utilization numbers include the ILA/VIO/ROM/debug hub and must not be used as block costs.
- Only the replayed vectors are covered; a passing block is "matches simulation on N vectors", not "proven correct".
