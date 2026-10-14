# Per-block results (2026-10-14, Zybo Z7-10, Vivado 2024.1, 125 MHz)

All blocks: 0 mismatches over all cycles, `dut_in` matched the recorded vectors, negative control (one corrupted expected
word) was detected. "Worst slack" is the post-route WNS of the full bench (DUT + ROM + ILA + VIO).
Packed word layouts are LSB-first and are repeated in each `*_hw_top.sv` header.

| Block (dirs) | Inputs (bits) | Outputs (bits) | Cycles | Stimulus recorded | Golden / checks |
|---|---|---|---|---|---|
| `galois_lfsr`, `_sync` | rst_n, en (2) | out[8] (8) | 807 | 4 reset cycles; 300 free-running; 300 with random `en`; mid-run reset (3 cycles); 200 free-running | pylfsr reference each cycle; async reset shows seed immediately, sync reset one cycle later |
| `counter`, `_sync` | rst_n, en, clr (3) | out[7] (7) | 796 | reset; >= 3 full wraps of the 7-bit counter; 300 random en/clr (5 % clr); mid-run reset; 100 cycles | model: clr beats en; wraps at 2^7 |
| `binary_stochastic_converter`, `_sync`, `fabulous_bts_sync` | rst_n, valid_binary_in, ready_stochastic_out, binary_in[8] (11) | ready_binary_in, valid_stochastic_out, stochastic_out, last_cycle (4) | 2630 | bursts of 255 bits for values 0, 1, 0x55 (stalls at bits 10 and 100), 0x7F (accepted while consumer not ready), 0x80 (valid held while busy with junk data), 0xAA (stalls on first and last bit), 0xFE, 0xFF, 0x02; a burst abandoned after 40 bits by a reset; 0x3C afterwards | `golden_model()` per burst; valid stays up mid-burst; `last_cycle` only on the retiring bit; accept independent of downstream ready (ADR 0016) |
| `stochastic_to_binary`, `_sync` | rst_n, valid_stochastic_in, stochastic_in, boundary_in, ready_binary_out (5) | ready_stochastic_in, valid_binary_out, binary_out[8] (10) | 1812 | 3 random 255-bit windows with 80 %-valid input; all-ones and all-zeros windows with a slow/blocked consumer; windows of length 1, 7, 3 with the consumer stuck low for 20 cycles; reset 100 samples into a window, then a 200-sample window | popcount per window; results delivered in order, held while stalled, none dropped or spurious |
| `stochastic_multiplier` | rst_n, a, valid_a, b, valid_b, ready_out (6) | ready_a, ready_b, valid_out, out (4) | 1558 | phases: all valid/ready; A or B intermittently invalid; slow consumer; all random; mid-run reset; random | AND of bits; `valid = va & vb`, `ready_a = ro & vb`, `ready_b = ro & va` |
| `stochastic_adder`, `_sync` | same as multiplier (6) | same (4) | 1558 | same phases as multiplier | MUX with `golden_select_bits()`; select advances only on fired bits and restarts on reset |
| `stochastic_decorrelator` | same as multiplier (6) | ready_a, ready_b, valid_out, out_a, out_b (5) | 1558 | same phases (763 output handshakes consumed) | `SegmentBasedGolden` scoreboard; output held stable under backpressure |
| `sc_loopback`, `_sync` | rst_n, binary_in[8], valid_binary_in, ready_binary_out (11) | ready_binary_in, valid_binary_out, binary_out[8] (10) | 2585 | values 0, 1, 2, 0x5A, 0x7F, 0x80, 0xA5, 0xFE, 0xFF, 0x33 with consumer stalls | decoded == encoded for every value |
| `sc_multiply_chain`, `_sync` | rst_n, a[8], valid_a, b[8], valid_b, ready_out (20) | ready_a, ready_b, valid_out, out[8] (11) | 2055 | 8 windows (below), consumer stalled for 60 cycles mid-run; encoder seeds 1 and 204 | decoded == popcount of bits the decoder accepted in that window; statistical table |
| `sc_add_chain`, `_sync` | same as multiply chain (20) | same (11) | 2055 | 8 windows (below); select LFSR width 5 seed 1 | same; ideal = (a+b)/2 |

## Chain statistical tables (hardware values; async and sync twins are identical)
Criterion: |decoded - ideal| <= 10 % of full scale (255). The decoded values are what the chip produced because the hardware
trace equals the simulated trace bit-exactly.

Multiply chain (ideal = a*b/255), max error 0.49 % FS:
| a | b | decoded | ideal | err % FS |
|---|---|---|---|---|
| 255 | 255 | 255 | 255.0 | 0.00 |
| 128 | 128 | 63 | 64.3 | 0.49 |
| 64 | 192 | 48 | 48.2 | 0.07 |
| 200 | 0 | 0 | 0.0 | 0.00 |
| 0 | 200 | 0 | 0.0 | 0.00 |
| 51 | 153 | 31 | 30.6 | 0.16 |
| 255 | 64 | 64 | 64.0 | 0.00 |
| 100 | 100 | 39 | 39.2 | 0.08 |

Add chain (ideal = (a+b)/2), max error 4.31 % FS:
| a | b | decoded | ideal | err % FS |
|---|---|---|---|---|
| 0 | 0 | 0 | 0.0 | 0.00 |
| 255 | 255 | 255 | 255.0 | 0.00 |
| 255 | 0 | 123 | 127.5 | 1.76 |
| 0 | 255 | 133 | 127.5 | 2.16 |
| 100 | 200 | 158 | 150.0 | 3.14 |
| 51 | 153 | 113 | 102.0 | 4.31 |
| 128 | 128 | 132 | 128.0 | 1.57 |
| 10 | 240 | 129 | 125.0 | 1.57 |

Note: encoder seeds (1, 2) at WIDTH=8 are only one LFSR step apart, which makes the multiplier behave like min(a,b)
(see `Stochastic_Blocks/results/README.md`); these chains use (1, 204), as `sc_multiply_chain_top_sync` does.

## Post-route worst setup slack (ns) at 125 MHz
heartbeat 1.93; galois_lfsr 2.25 / sync 2.25; counter 2.21 / 2.39; BTS 1.89 / 2.31; fabulous_bts_sync 2.31; STB 2.05 / 1.68;
multiplier 1.90; adder 1.96 / 1.96; decorrelator 2.24; loopback 1.85 / 1.80; multiply chain 1.38 / 1.63; add chain 1.68 / 1.42.
(Full reports: `build/<block>/timing.rpt`, git-ignored; regenerate with `build_block.tcl`.)

## Evidence files
`waveforms/<block>/capture.{ila,csv,vcd}` for every row above (and `heartbeat`). The latest regression logs are
`build/<block>.flow.log` (git-ignored, reproducible).
