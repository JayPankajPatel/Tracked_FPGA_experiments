# Issue #16 — Caravel (ChipFoundry CC2509) integration plan

Target: modern ChipFoundry `caravel_user_project` (tag **CC2509**, sky130A,
LibreLane "1-Macro-First" flow). User area **2920×3520 µm (10.28 mm²)**, wrapper
interface verified identical to the pinned repo. Cloned (gitignored) at
`Librelane_work/caravel_user_project/`.

## Flow shape (1-Macro-First)
`user_project_wrapper` is hardened with `SYNTH_ELABORATE_ONLY: true` — it does
**not** synthesize user logic; it **places one pre-hardened user macro** + PDN +
routing against the fixed `user_project_wrapper.def` template. So we need TWO
hardens:

**Harden A — the user macro = `chip_top`.** Embeds:
- the LVS-clean shrunk `eFPGA` macro (1989.96×2457.52 µm) — placed as a sub-macro,
- 4× `sram_1rw1r_32_256_8_sky130` OpenRAM macros (the BlockRAM_1KB cells),
- soft logic: `eFPGA_top` controller (Frame_Data_Reg×?, Frame_Select×?, FSM),
  `config_adapter`, `io_mux`.
Ports = the MPW-neutral contract (`clk, rst_n, cfg_sclk, cfg_sdata, cfg_busy,
cfg_done, uio_out/oeb/in[15:0]`). Output: gds/lef/nl/lib/spef for `chip_top`.
This is a multi-macro harden (5 sub-macros: 1 eFPGA + 4 SRAM) — the intricate step.

**Harden B — `user_project_wrapper`.** Our shim `shims/user_project_wrapper.v`
(lint-clean) places the `chip_top` macro via the `MACROS{}` block (replacing the
stock `user_proj_example`), wires the contract to `io_*`/Wishbone/LA, and runs
PDN + routing + signoff (DRC/LVS/Antenna).

**Then precheck** — `make run-precheck` (the submission gate).

## Macro-placement / area budget
- chip_top die: pick ≥ eFPGA(1990×2457) + halo + the 4 SRAM (376×446 each) +
  controller channel. ~2400×2900 µm leaves room; sits inside the 2920×3520
  user area with the core ring. Confirmed by the SRAM-inclusive budget
  (~6.15 mm² need vs ~8.74 mm² usable).
- PDN must cover eFPGA + 4 SRAM (PDN_MACRO_CONNECTIONS), matching the stock
  wrapper's `mprj vccd1 vssd1 …` pattern.

## What to reuse from the modern repo (not the 2021 prior art)
- `openlane/user_project_wrapper/config.json` MACROS{}/PDN/fixed section — adapt.
- `fixed_dont_change/user_project_wrapper.def`, `pin_order.cfg`, `signoff.sdc`.
- LibreLane (meta v2) — same family as our FABulous harden.
- Do NOT reuse open_eFPGA/eFPGA_v3 OpenLane-classic configs (stale; efabless mpw-5b).

## Open / risks (to validate before/with the harden)
- Multi-macro PDN over eFPGA + 4 SRAM inside chip_top (most likely failure mode).
- `chip_top` needs a generated `.lib`/`.nl`/`.spef` for Harden B — produced by Harden A.
- The shrunk fabric's own functional bitstream (16-IO design) for post-layout sim
  is still TODO (separate from layout signoff).
- Confirm CC2509 PDK commit (open_pdks 3e0e31d / LVS 6d4d117) vs our FABulous
  PDK hash (8afc8346) — align so macro LEF/abstracts match.

## PDK provenance check (advisor gate #1) — LOW RISK ✅
Our macros were hardened on ciel `8afc8346`; CC2509 uses open_pdks `3e0e31d`.
Verified the `sram_1rw1r_32_256_8_sky130` macro across two local PDK versions:
- **GDS byte-identical** (md5 `c95b3a73…`) — LVS extracts from GDS, so it matches.
- LEF abstract differs (cosmetic: antenna/pin metadata) — low risk for P&R.
Both flows use sky130A / `sky130_fd_sc_hd`. Decision: harden against a single
PDK consistently (prefer the eFPGA macro's `8afc8346` for A, align B/precheck to
CC2509's `3e0e31d`; GDS-identical SRAM makes the mix safe).
Target committed: **digital Caravel (10.28 mm²)** per "continue with the modern
one". Analog/Caravan (larger area) remains a later option to grow the fabric.

## Status
- [x] Clone modern CC2509, diff vs prior art, confirm interface + area.
- [x] `user_project_wrapper` shim (CC2509) written + lint-clean.
- [x] PDK/macro provenance check (SRAM GDS identical) — low risk.
- [ ] Harden A: chip_top macro (eFPGA + 4 SRAM + controller).
- [ ] Harden B: user_project_wrapper placement + signoff.
- [ ] run-precheck.
