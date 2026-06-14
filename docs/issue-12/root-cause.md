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

## Logically connected, physically split (the decisive evidence)

OpenROAD's `32-odb-reportdisconnectedpins` reports **0 disconnected pins** — the logical netlist is
complete. The DEF feeding Magic extraction (`36-odb-cellfrequencytables/eFPGA.def`,
`UNITS … 1000`, `DIEAREA 0 0 2482160 3930400`) shows each global net **is** defined with its pin and
its tile terminal:

```
NETS: - FrameData[0] ( PIN FrameData[0] ) ( Tile_X1Y0_N_term_single FrameData[0] ) ;
PINS: - FrameData[0] … + LAYER met3 (…) + PLACED ( 300 3701580 ) N ;   # x≈0.3µm  (WEST die edge)
COMP: - Tile_X1Y0_N_term_single … FIXED ( 247480 3683560 ) N ;          # x≈247µm  (interior col 1)
```

So the pin and the tile terminal are the same *logical* net, but the pin metal sits on the die edge
~247µm from the interior tile terminal. **Routing is disabled**, so no wire bridges the gap; Magic's
geometric extraction therefore yields two separate nodes. This reconciles the `+9` net count vs `1581`
disconnected pins: the netlist intent is correct (few net-count delta), the break is purely
physical→extraction (1581 unbridged top pins).

### Contrast: a matched per-tile IO vs a failed global net

| net | connected tile | tile placement | pin placement | outcome |
|---|---|---|---|---|
| `Tile_X0Y10_A_I_top` ✅ | `Tile_X0Y10_W_IO` | x≈1.38µm (**west perimeter**) | west edge x≈0.3µm | pin overlaps tile terminal → merged |
| `FrameData[0]` ❌ | `Tile_X1Y0_N_term_single` | x≈247µm (**interior col 1**) | west edge x≈0.3µm | ~247µm gap, no wire → split |

`fabric_io_place.py` chooses the die-edge *side* from the master tile's mTerm and aligns only the
cross-axis to the iterm centre — it ignores whether the connected **instance** is on the die perimeter.
Perimeter IO terminals reach the boundary, so the edge pin overlaps; interior/global-net terminals do
not, so the edge pin floats.

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

The break is **physical** (pin metal genuinely does not touch the interior tile terminal), so an
extraction/label-only change cannot fix it — the geometry must connect. Make the top-level IO pin
physically reach its tile terminal, inside the official flow. Candidate, smallest-first:

1. **IO-placement fix (root cause, PDK-agnostic)** — in `fabric_io_place.py`, place / extend the BPin so
   it overlaps the connected iterm's metal instead of slamming it to the far die edge. Either (a) place
   the pin shape at the iterm location, or (b) extend the pin from the die edge inward to the iterm
   (a `met2`/`met3` stub), or (c) draw a guide-route/special-wire pin→iterm. Must stay DRC-clean and not
   break neighbouring abutment.
2. **Confirm PDK-specificity first** — upstream gates fabric LVS on `ihp-sg13g2`/`gf180mcuD` (excludes
   sky130A). If those genuinely pass, diff what differs (IO layers met2/met3, the no-router abutment
   geometry) to converge on the intended connection mechanism rather than inventing one.
3. **If the fix belongs upstream** (Task D) — produce a minimal reproducer + patch note for
   `fabric_io_place.py`; the gitignored checkout means the patch must be tracked (patch file applied in
   CI) to be a real deliverable.

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
