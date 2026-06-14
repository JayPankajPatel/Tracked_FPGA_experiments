# Issue #12 — Fabric-stitch LVS blocker: root cause

**Status:** Root cause localized from on-disk evidence (PR #11 run
`RUN_2026-06-13_22-57-46`). **Not PDN.** Fix in progress.
**Env (inherited #7/#10, unchanged):** FABulous `v2.0.0b5` `4a2047b`, LibreLane `v3.0.3`,
sky130A `FAB_PDK_HASH=8afc8346…`.

## TL;DR

The stitched fabric's **top-level IO pins for the high-fanout global nets are not electrically
unified with the fabric-spanning internal (abutment) net.** netgen matches every tile and simple
per-tile IO, then fails **top-level port matching only**, on exactly the global config/clock/BRAM
signals. It is **not** a PDN power-island problem (the wiki `pdn-lvs-fix.md` matches the fingerprint
*shape* but **zero** unmatched nets are power) and **not** a tile defect (tiles are 13/13 LVS-clean and
their blackboxes matched: *"Device classes eFPGA and eFPGA are equivalent"*).

## Evidence

netgen step `49-netgen-lvs` compares (see `evidence/lvs_script.lvs`):

| circuit | source | nets | note |
|---|---|---|---|
| 1 | `47-magic-spiceextraction/eFPGA.spice` (Magic-extracted layout) | 34837 | **1581 disconnected pins** |
| 2 | `22-openroad-globalplacementskipio/eFPGA.pnl.v` (source powered netlist), tiles `-blackbox` | 34828 | — |

Both have **151 devices** = the tile macro instances (84 LUT4AB + 14×{RegFile,RAM_IO,W_IO} + 7 DSP +
terminators). Result: `Top level cell failed pin matching` (+9 nets, 1581 unmatched pins).

The 1581 unmatched top-level pins are a **structured, global-only** set:

| signal | width | role |
|---|---|---|
| `FrameData[511:0]` | 512 | global configuration data bus |
| `FrameStrobe[199:0]` | 200 | global configuration strobe |
| `UserCLK` | 1 | global user clock |
| `Tile_X*Y*_{FAB2RAM,RAM2FAB}_*` | many | BRAM column signals (span the RAM column) |
| `Tile_X*Y*_*_config_C_bit*`, `*_{A,B}_{I,O,T}_top` | many | per-tile config / BRAM-block IO |

Plain per-tile external IO (`Tile_X*Y*_A_I_top`, `A_O_top`, …) **matched** — they are absent from the
unmatched list.

### The asymmetry that names the mechanism (`lvs.netgen.rpt`)

```
(no pin, node is Tile_X0Y14_W_IO/FrameStrobe… | FrameStrobe[12]      <- source port; layout has only an INTERNAL node
FrameData[0]                                   | (no matching pin)    <- layout TOP PIN; not unified with the internal net
```

In the Magic-extracted layout body, each abutment net is named after a **tile-internal node**, e.g.
`Tile_X3Y4_RegFile/FrameData[0]` — the global FrameData net *is* connected across tiles by abutment, but
its canonical name is an internal node, **not** the top-level port `FrameData[0]`. The top-level pin
`FrameData[0]` (placed by the fabric IO-placement step) is a **separate node** that never merges with
that internal net. Source `pnl.v` instead wires tiles from bit-shuffled slices of the real port bus
(`.FrameData({FrameData[351], FrameData[383], …})`). Net correspondence therefore breaks at the boundary
for these buses only.

## Why global nets break but per-tile IO doesn't

The fabric flow (`fabulous/fabric_generator/gds_generator/flows/fabric_macro_flow.py`) is **macro
abutment with no router** — it substitutes out `OpenROAD.GlobalPlacement / DetailedPlacement /
DetailedRouting / RCX` (`subs = {…: None}`) and connects tiles purely by abutting pins. Top-level
external pins are placed by the custom step `Odb.FABulousFabricIOPlacement` →
`script/fabric_io_place.py`.

`fabric_io_place.py` (per top-level BTerm):
1. `iterm = net.getITerms()[0]` — picks the **first** instance terminal on the net.
2. Places the BPin **at the die edge**, aligned in the cross-axis to that one iterm’s centre, on the
   side derived from the master tile’s mTerm.
3. Creates **no wire** — it relies on the BPin geometrically **overlapping** tile pin metal.

- **Per-tile IO** → net has **one** iterm, on a perimeter tile whose pin sits at the die edge → the
  edge BPin overlaps it → connected → LVS matches.
- **Global buses** (FrameData/FrameStrobe/UserCLK/BRAM) → net has **many** iterms; `iterms[0]` is
  arbitrary (often interior). The edge BPin aligns to that interior iterm and overlaps **no** boundary
  metal of the spanning net → top pin stays electrically isolated → 1581 disconnected pins.

This fragility is **net-ordering dependent and high-fanout-only**, which exactly matches the failure
set. Upstream CI (`.github/workflows/gds-flow-ci.yml`) **gates fabric LVS/DRC/antenna** for
`ihp-sg13g2` and `gf180mcuD` but **excludes sky130A** ("will get kill by github" — resources), so
sky130A fabric LVS is an **unvalidated upstream path**.

## Fix direction (to validate in Phase 2 two-pass review before applying)

Make the top-level IO pin for every global net **electrically unify** with its internal abutment net,
inside the official flow. Candidate, smallest-first:

1. **IO-placement fix** — in `fabric_io_place.py`, for a multi-iterm net, choose the iterm whose pin
   actually sits on the die boundary (or place the BPin over a boundary point of the net), so the BPin
   overlaps real net metal. (Root-cause fix; PDK-agnostic.)
2. **Extraction unification** — Magic label/port preference so the top-level port label and the internal
   spanning net merge (note fabric config already sets `MAGIC_EXT_UNIQUE: notopports`). Only viable if
   the BPin geometry already touches the net.
3. **Confirm PDK-specificity** — run `gen_fabric_macro` on `ihp-sg13g2`/`gf180mcuD` to see whether the
   same LVS passes there; if so, diff what makes sky130A break (IO layers met2/met3, PDN met4/met5).

**Out:** copying OpenLane-classic PDN/core-ring values (ruled out — not power); re-hardening tiles
(13/13 clean, blackboxes matched); changing the v2.0.0b5 ref; adopting mole99.

## Before/after fingerprint (to fill in Phase 3)

- **Before:** 1591 LVS errors · devices 151=151 · nets 34837 vs 34828 (+9) · 1581 disconnected pins ·
  `Top level cell failed pin matching`.
- **After:** _TBD_.

## Artifacts
- Preserved text evidence: `docs/issue-12/evidence/` (rpt, json, lvs_script, netlist headers, log tail).
- Full failing run (gitignored): `FABulous_work/fabulous-v2/fabric_baseline_proj/Fabric/macro/runs/RUN_2026-06-13_22-57-46/`.
- Flow source: `fabulous/fabric_generator/gds_generator/flows/fabric_macro_flow.py`,
  `steps/fabric_IO_placement.py`, `script/fabric_io_place.py`.
