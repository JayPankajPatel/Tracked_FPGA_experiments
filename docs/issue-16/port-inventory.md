# Issue #16 — eFPGA macro port inventory & classification

**Purpose:** classify every port of the #12 LVS-clean `eFPGA` hard macro and decide its
chip-level disposition. This is acceptance-criterion #1 and the evidence base for the
wrapper architecture decision. Decision-independent (no architecture committed here).

**Source of truth (local, gitignored artifacts):**
- Hard macro (LVS/DRC/Antenna clean, #12): `FABulous_work/fabulous-v2/fabric_baseline_proj/Fabric/macro/final_views/{gds,lef,nl}/eFPGA.*`
  — module is **`eFPGA`** (the raw stitched fabric), die ≈ 9.76 mm².
- FABulous-generated integration top: `.../Fabric/eFPGA_top.v` (wraps `eFPGA` + config controller + BRAM).

## 1. Raw `eFPGA` macro interface (the hardened block) — 871 port lines

| Family | Width | Dir | Meaning | Chip disposition |
|---|---|---|---|---|
| `FrameData` | [511:0] | in | Parallel config frame data (`FrameBitsPerRow*16`) | **Internal** — driven by config controller, never a pad |
| `FrameStrobe` | [199:0] | in | Config frame strobe (`MaxFramesPerCol*10`) | **Internal** — driven by config controller |
| `UserCLK` | 1 | in | Fabric user clock | Pad / chip clock tree |
| `Tile_*_{A,B}_{O,I,T}_top` | 14 tiles ×6 = 84 | mixed | User IO termination (28 bidir triples: O=in, I=out, T=tristate-en) | **User IO** → muxed to pads (28 bidir) |
| `Tile_*_{A,B}_config_C_bit*` | 112 | out | Per-tile config readback bits | Config-state monitor → logic-analyzer / drop |
| `Tile_X9Y*_Config_accessC_bit*` | 56 | out | RAM-column config access | Config monitor → logic-analyzer / drop |
| `Tile_X9Y*_RAM2FAB_D*_I*` | 224 | in | BRAM→fabric data | **Internal** — driven by on-chip BRAM model |
| `Tile_X9Y*_FAB2RAM_{D,A,C}*_O*` | 224 | out | Fabric→BRAM data/addr/ctrl | **Internal** — consumed by on-chip BRAM model |

**Net chip-facing requirement after integration:** ~28 bidirectional user IO + clock/reset +
a small config-load interface. Everything else is internal (config network, BRAM).

## 2. `eFPGA_top.v` — FABulous already provides the integration layer

`eFPGA_top` instantiates `eFPGA` and **resolves the large interface automatically**:

- **Config network (712 bits) → small front-end.** Internally instantiates `Frame_Data_Reg` ×28,
  `Frame_Select` ×20 and the config FSM, exposing only:
  - `CLK`, `resetn`
  - `SelfWriteStrobe`, `SelfWriteData[31:0]` — parallel/bus config write
  - `Rx`, `ComActive`, `ReceiveLED` — UART config front-end
  - `s_clk`, `s_data` — serial (SPI-like) config front-end
- **BRAM (448 ports) → internal models.** Ties all `RAM2FAB`/`FAB2RAM` to 7× `BlockRAM_1KB`
  instances. Not chip-facing.
- **User IO → compact buses:** `O_top[27:0]` (in), `I_top[27:0]` (out), `T_top[27:0]` (tristate en),
  `A_config_C[55:0]`, `B_config_C[55:0]`, `Config_accessC[55:0]` (config monitors).

So the dominant integration work the issue anticipated (config serialization + IO reduction) is
**largely solved by FABulous's own generated top**. The remaining design problem is narrower:
choose a chip target + config front-end, map 28 user IO + clock/reset to pads, and decide
whether config_C monitors reach pads/logic-analyzer or are dropped.

## 3. Key constraint: the hardened macro is `eFPGA`, not `eFPGA_top`

The #12 clean GDS/LEF is for **`eFPGA`** (raw fabric). Two hardening paths follow:
- **(P-controller-soft)** chip wrapper instantiates the `eFPGA` hard macro + re-synthesizes the
  config controller (`Frame_Data_Reg`/`Frame_Select`/FSM) + `BlockRAM_1KB` as soft logic/macros
  around it (mirror `eFPGA_top` structure with `eFPGA` black-boxed).
- **(P-reharden-top)** harden `eFPGA_top` as a new macro (re-runs P&R; controller+BRAM+fabric
  in one block) — discards the #12-clean `eFPGA` macro reuse.

This is one of the decisions for the two-pass review.

## 4. Pad-budget reference
- **Caravel `user_project_wrapper`:** ~38 `io_*[37:0]` GPIO + `la_data_*[127:0]` logic analyzer +
  Wishbone (`wbs_*`) + `user_clock2` + `user_irq[2:0]`. 28 user IO + config_C monitors fit easily.
- **Standalone sky130 chip:** pad ring sized by us; minimal = 28 user IO + CLK + reset + ~4 config pins.

## 5. Programmed-design smoke-test vector source (note for later)
The "simple programmed-design smoke test" (acceptance criterion) needs a real FABulous-generated
bitstream for this exact fabric to drive the config front-end, plus a trivial mapped design
(e.g. a LUT pass-through) to observe at `I_top`/`O_top`. Bitstream generation is a FABulous
`run_FABulous_fabric` + `genBitStream` step on the baseline project; flagged now so it is not a
surprise at verification time.
