# Issue #16 — MPW-portable validation plan

**Goal:** prove the chip wrapper "works across any requested MPW" without hardening every MPW.
**Decisions locked (user, 2026-06-15):**
- Approach: **parametrized, MPW-neutral wrapper** — one fixed interface contract + fabric size as a knob.
- Seed profiles: **Caravel** and **standalone** sky130.
- Functional oracle: **FABulous's own simulator** (the baseline project `Test/` flow), not a hand-written model.

## Why layered (the core idea)
Every MPW shares the *identical* internal block (eFPGA macro + FABulous config controller + BRAM
models + IO mux + the fixed interface contract). Only the **pad shim** (contract → that harness's
pins) changes per MPW. So **functional correctness is proven once, MPW-independent**, and per-MPW we
only prove the shim mapped the contract correctly — which is cheap (no P&R).

## The fixed interface contract (the portable artifact)
Size-independent, technology-neutral. Per-MPW = a thin shim mapping these to that harness:
```
clk, rst_n                     // clock + reset
cfg_sclk, cfg_sdata            // serial config in -> existing FABulous controller
cfg_busy / cfg_done            //   (2-cycle, address-before-frame protocol; Dirk Koch note)
user_io[N-1:0] (in/out/oe)     // N bidirectional user pins behind a mux (N per profile)
vdd, vss                       // power
```
Internally the adapter deserializes the compact serial input into `eFPGA_top`'s
`SelfWriteData[31:0]`/`SelfWriteStrobe` parallel front-end — **the path the FABulous oracle TB
actually drives** (verified: `Test/sequential_16bit_en_tb.v` loads the bitstream as 32-bit words
on `SelfWriteData`+`SelfWriteStrobe`, two-cycle cadence; `s_clk`/`s_data` are left idle). The
contract never changes; the fabric size (and thus FrameData/FrameStrobe widths, BRAM count, and
the *hardcoded* `eFPGA_top` port widths) is regenerated, not parameter-overridden.

## The FABulous-sim oracle (already on disk)
`fabric_baseline_proj/Test/Makefile` provides the full reference flow:
`run_yosys` (synth user design + `top_wrapper`) → `run_nextpnr` (P&R on fabric) →
`run_bitgen` (real `.bin`/`.hex` bitstream) → `run_simulation` (iverilog TB loads bitstream).
`user_design/top_wrapper.v` already instantiates `eFPGA_top` and exposes the fabric on an
`io_in`/`io_out`/`io_oeb` bus. **The bitstream + the FABulous TB's observed `io_out` behavior are
the golden vectors.** Our wrapper must reproduce the same `user_io` behavior under the same bitstream.

## Validation pyramid

| # | Layer | Scope | Cost | Proves |
|---|---|---|---|---|
| 1 | **MPW target profile** | per-MPW descriptor (`profiles/*.yml`): pins/buses, pin budget, user-area W×H, power, harness signal names | authoring | makes "any MPW" concrete; new MPW = new profile |
| 2 | **Static conformance check** | `tools/check_conformance.py profile shim` + `yosys hierarchy`/Verilator elaborate | seconds | every contract signal bound; pins ≤ budget; **area(fabric@size)+overhead ≤ area budget** (the check that caught Caravel); power mapped |
| 3 | **Functional test (MPW-independent)** | cocotb/iverilog: load real FABulous bitstream over `cfg_*`, run programmed design, check `user_io` vs FABulous-sim golden | once | logic correct for ALL MPWs (shared block) |
| 4 | **Shim-replay test (per-MPW)** | same vectors driven through each profile's harness pins (Caravel `io_in`/Wishbone vs standalone pads) | minutes, sim-only | shim wiring preserved the contract |
| 5 | **Reference hardening (per area class)** | one representative target → LibreLane P&R + DRC/LVS/Antenna; replay vectors on LVS netlist | hours, once | physical recipe closes; small fabric (Caravel-class) + big #12 fabric (standalone) |
| 6 | **Reproducible regression** | all of the above scripted from pinned toolchain | — | the deliverable: add profile → conformance+shim-replay green |

## What this proves — honestly
- **For any MPW (cheap):** logic + interface conformance, pin/area/power fit, functional behavior through the shim.
- **For hardened references only:** physical signoff (timing/DRC/LVS at that size).
- **Caveat:** a non-hardened MPW still needs its own LibreLane run before tapeout — but that's a
  **re-run of a proven recipe at a new size param**, gated by conformance, not new design/debug.
- **Dependency:** bitstream must be generatable for the chosen fabric size (de-risked by the
  smallest-fabric first run).

## Success criterion (measurable)
For profiles {Caravel, standalone}: conformance (2) + shim-replay (4) green; functional (3) green
against the FABulous-sim oracle; ≥1 reference per area class hardened DRC/LVS/Antenna-clean (5);
and a *new* profile passes conformance with **no RTL change**.

## Reproducibility requirement (from two-pass)
All macro/controller artifacts are gitignored under `FABulous_work/`. The committed deliverable
must be clean-room: wrapper RTL + profiles + checks + a **regeneration script** (pinned FABulous
v2.0.0b5 + LibreLane) that recreates the macro + `eFPGA_top` + bitstream from a fresh checkout.

## Honest status (what is and isn't proven so far)
Only **layer 2 (static fit)** has run. That is real and useful — the Caravel FAIL is an external
geometric constraint, not a tuning artifact. But:
- **No function is proven yet.** Layers 3–4 (config-load + behavior vs the oracle) have not run.
  RTL elaboration/lint passing means well-formed + correctly bound, not functionally correct.
- **"standalone CONFORMANT" is partly by construction:** the standalone user-area (3200×4500 µm)
  and the `1.15` overhead factor are chosen estimates, not a P&R result. It proves the macro *can*
  be given a die that fits, not that a hardened standalone closes.
- **Unverified polarity:** the IO cell does `T_top = ~T`; the active sense of the pad output-enable
  (`uio_oeb`) in the standalone shim is assumed active-low and must be confirmed in layer-3 sim.
- **Adapter cadence unconfirmed:** the serial→SelfWrite strobe timing must be checked bit-accurate
  against the oracle controller before claiming a correct config load.

## Sequencing (this issue)
1. Contract + parametrized wrapper RTL (`eFPGA_top` black-boxed) — lint/elaborate. ← scaffolding
2. `profiles/{caravel,standalone}.yml` + `check_conformance.py` — run (layer 2). ← scaffolding
3. Drive FABulous `Test/` flow to emit a golden bitstream + reference `io_out` (layer 3 oracle).
4. Functional + shim-replay TB (layers 3–4).
5. *(later milestone)* reference hardening (layer 5); full regression (layer 6).
