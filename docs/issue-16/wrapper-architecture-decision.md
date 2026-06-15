# Issue #16 — chip-wrapper architecture decision (two-pass reconciliation)

**Process:** CLAUDE.md optimistic/pessimistic two-pass review, run as two independent agents
(opt + pess) over the same evidence, then reconciled here. Incorporates the FABulous-upstream
config-protocol note from Dirk Koch added to issue #16 on 2026-06-15.

**Status:** architecture recommendation + one user decision required before RTL. No wrapper RTL
written yet (two-pass mandated before architecture code).

---

## Headline finding (primary-source, blocking)

**The #12 LVS-clean `eFPGA` macro does NOT fit a Caravel user_project_wrapper — in any orientation.**

| | width (µm) | height (µm) | area |
|---|---|---|---|
| `eFPGA` macro (`final_views/lef/eFPGA.lef` `SIZE`) | 2482.16 | 3930.40 | 9.756 mm² |
| Caravel user area (`open_eFPGA/def/user_project_wrapper.def` DIEAREA) | 2920 | 3520 | 10.28 mm² |

Un-rotated: macro 3930 µm tall > 3520 µm available (12% over). Rotated 90°: 3930 µm wide >
2920 µm available. **Neither fits**, and that is before PDN halo, routing channels, the config
controller, or 7 BRAM macros. Caravel is geometrically falsified for this macro. The optimistic
pass argued Caravel fits on a *pad-count* basis; that is the wrong axis — the blocker is *area*.

→ **Caravel is only reachable by shrinking the fabric (fewer tiles), which discards the #12
macro and re-opens the entire #12 hardening effort.** This is the user decision below.

---

## Reconciled recommendations

### Decision 1 — Chip target: **standalone sky130 chip wrapper** (default)
Caravel is out (area). Standalone lets us size the die to the existing macro (~3.0 × 4.4 mm class
after halo/PDN/pad ring) and **preserves the #12 LVS-clean macro** — the project's most expensive
asset. Fallback only if a Caravel/shuttle slot is mandatory: shrink the fabric and re-harden
(re-do #12). **This fork is the one question for the user (see below).**

### Decision 2 — Config front-end: **thin adapter over the EXISTING FABulous controller** (high confidence)
Both passes and Dirk's note agree. FABulous already generated the geometry-matched controller in
`eFPGA_top.v` (`Frame_Data_Reg`×28, `Frame_Select`×20, config FSM) exposing a compact interface:
`CLK, resetn, SelfWriteStrobe, SelfWriteData[31:0]` (parallel), `Rx/ComActive/ReceiveLED` (UART),
`s_clk/s_data` (serial).

Per Dirk Koch (issue #16, 2026-06-15): the FABulous config protocol intentionally strobes over
**two cycles** and sends an **address before each frame** to relax timing on the long `FrameStrobe`
/`FrameData` wires. **Preserve these semantics** — they live *inside* the existing FSM. The wrapper
should be a **thin SPI/Wishbone-style adapter** that receives compact external writes and feeds
32-bit words into the existing `SelfWriteData`/`SelfWriteStrobe` (or serial `s_data`) port. **Do
not invent a heavier protocol; do not add backpressure** unless measurement shows it is needed.
**Do NOT port open_eFPGA's loader** — it targets a **12-row** fabric; ours is **14-row**, so its
`Frame_Data_Reg` instance count and `FrameRegister = NumberOfRows*FrameBitsPerRow` geometry are
wrong for us. Use open_eFPGA only as a *mapping pattern* (which signals → which pins).

### Decision 3 — Hardening path: **wrap the `eFPGA` hard macro; controller soft + 7 BRAM macros** (with correction)
Instantiate the #12-clean `eFPGA` as a black box (LEF for P&R, `eFPGA.nl.v` for gate sim/LVS) and
build the controller as soft logic around it. **Correction to the optimistic framing:** the BRAM is
NOT soft — `BlockRAM_1KB.v` instantiates `sram_1rw1r_32_256_8_sky130` (OpenRAM, `(* blackbox *)`).
So this path is a **multi-macro integration**: 1 fabric macro + 7 OpenRAM SRAM macros + soft
controller + multi-macro PDN. Feasible and preserves #12, but harder than "soft logic around a
macro." Re-hardening `eFPGA_top` as one new macro is the fallback (discards #12 reuse, ~hours P&R).

**config_C monitors (168 outputs):** confirmed `DIRECTION OUTPUT` (config readback/observability,
not functional). The smoke test observes `I_top[27:0]`. → **Drop them or mux a small curated subset
to a debug/scan bus. Never route 168 monitors 1:1 to pads** (blows a pad-limited budget).

---

## Cross-cutting risks the passes surfaced (must address, not optional)

1. **Reproducibility gap (blocking for "done").** Every artifact the wrapper binds — the macro
   GDS/LEF/nl, `fabric_baseline_proj`, `eFPGA_top.v`, the controller RTL — is **gitignored** under
   `FABulous_work/` (`git ls-files` on the baseline project = 0 tracked). A clean-room consumer
   cannot regenerate them. The wrapper deliverable **must** ship a regeneration path (pinned
   FABulous v2.0.0b5 + LibreLane + a script that re-creates macro + `eFPGA_top` + controller) and
   commit the wrapper RTL clean-room (per CLAUDE.md clean-room contract / memory note).
2. **Smoke-test bitstream unproven.** The "programmed-design smoke test" acceptance criterion needs
   a real FABulous bitstream for *this exact* 14-row build (`run_FABulous_fabric` → place&route a
   trivial mapped design → `genBitStream`). Never generated yet. This is the highest-value next
   experiment and must be a dry-run before claiming the criterion.

---

## Reconciliation summary (CLAUDE.md required fields)

- **Default recommendation:** standalone sky130 wrapper; thin SPI/Wishbone adapter over the existing
  FABulous controller (preserve two-cycle/address-before-frame); wrap `eFPGA` macro + 7 OpenRAM
  BRAM macros + soft controller; drop/mux config_C monitors.
- **Fallback:** shrink fabric → re-harden → Caravel; or re-harden `eFPGA_top` monolithically.
- **Evidence still missing:** can a bitstream be generated for this build? is a clean-room
  regeneration script reproducible on a fresh checkout? multi-macro PDN feasibility for 1+7 macros.
- **Minimum experiment / health check (cheap → expensive):**
  1. Wrapper RTL elaboration/lint with `eFPGA` black-boxed (Verilator/yosys `hierarchy`) — minutes.
  2. Behavioral config-load sim: drive the adapter with a real bitstream, confirm the FSM walks
     address-before-frame and `FrameData`/`FrameStrobe` settle (uses `eFPGA.nl.v`). Highest value.
  3. Synth smoke of soft controller (macro + SRAM black-boxed) → cell/area estimate.
  4. *(Later milestone, deferred)* full chip P&R with macro placed (~hours, ~19 GB per #12).
- **Explicit non-goals (this issue):** Fmax closure; redesigning the fabric; exposing every macro
  port; requiring CI-runner execution (local reproducible runs OK).
- **Must NOT be trusted/adopted yet:** open_eFPGA loader RTL (12-row, wrong geometry); any
  gitignored local artifact as a *committed* dependency (need regeneration path); Caravel as the
  vehicle for the current macro (area-falsified).
