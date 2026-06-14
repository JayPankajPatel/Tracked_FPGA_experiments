# Issue #12 — Fabric-stitch LVS blocker: root cause

**Status:** Root cause localized from on-disk evidence (PR #11 run
`RUN_2026-06-13_22-57-46`); mechanism corrected by the Phase-2 two-pass review (see end). **Not PDN.**
Fix in progress.
**Env (inherited #7/#10, unchanged):** FABulous `v2.0.0b5` `4a2047b`, LibreLane `v3.0.3`,
sky130A `FAB_PDK_HASH=8afc8346…`.

## TL;DR

**Every one of the ~1581 top-level fabric IO pins is physically disconnected from its tile terminal.**
The fabric-stitch flow disables routing and connects by abutment; the custom IO-placement step
(`fabric_io_place.py`) slams each top-level BPin to the **die edge** with **no wire**, while every tile
is inset by the `FABULOUS_HALO_SPACING` (1 µm) — so the pin metal never overlaps the tile pin metal.
netgen matches all 151 tile instances ("device classes equivalent") then fails **top-level port matching
only**, uniformly across all top ports. It is **not** a PDN power-island problem (the wiki
`pdn-lvs-fix.md` matches the fingerprint *shape* but **zero** unmatched nets are power) and **not** a
tile defect (tiles are 13/13 LVS-clean and their blackboxes matched).

> **Correction (Phase-2 review):** an earlier draft claimed this was *global-only* and that per-tile IO
> (`A_I_top`) *matched*. That was wrong — `Tile_X0Y10_A_I_top` is in the unmatched set
> (`lvs.netgen.rpt` lines 8878/9812/12105), and even its perimeter `W_IO` tile sits 1 µm inside the die
> edge, so its edge-placed pin floats too. The failure is **uniform across all top ports**; the global
> buses are just the largest families. The fix is unchanged in direction (overlap pin↔terminal) and is
> actually simpler for being uniform.

## Evidence

netgen step `49-netgen-lvs` compares (see `evidence/lvs_script.lvs`):

| circuit | source | nets | note |
|---|---|---|---|
| 1 | `47-magic-spiceextraction/eFPGA.spice` (Magic-extracted layout) | 34837 | **1581 disconnected pins** |
| 2 | `22-openroad-globalplacementskipio/eFPGA.pnl.v` (source powered netlist), tiles `-blackbox` | 34828 | — |

Both have **151 devices** = the tile macro instances (84 LUT4AB + 14×{RegFile,RAM_IO,W_IO} + 7 DSP +
terminators). Result: `Top level cell failed pin matching` (+9 nets, 1581 unmatched pins).

The 1581 unmatched top-level pins span **all** top-port families (largest first):

| signal | role |
|---|---|
| `FrameData[511:0]` (512), `FrameStrobe[199:0]` (200) | global configuration data / strobe |
| `Tile_X*Y*_{FAB2RAM,RAM2FAB}_*` | BRAM column signals |
| `Tile_X*Y*_*_config_C_bit*`, `Config_accessC_bit*` | per-tile config |
| `Tile_X*Y*_{A,B}_{I,O,T}_top` (incl. `A_I_top`, `A_O_top`) | per-tile / BRAM-block IO |
| `UserCLK` | global user clock |

Per-tile external IO is **in** the failing set, not absent (corrected in Phase 2) — the break is
uniform, not global-only. netlist fanout per top net: FrameData/FrameStrobe bits → 1 tile each
(matching the source `pnl.v`, so realizing it is **not** a cosmetic pass); `UserCLK` → 10 tiles.

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
(`.FrameData({FrameData[351], FrameData[383], …})`). Net correspondence breaks at the boundary for
every top port the same way (the buses are just the most visible).

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

### Uniform gap — even the best-case perimeter port floats

| net | connected tile | tile placement | pin box (met3) | gap |
|---|---|---|---|---|
| `Tile_X0Y10_A_I_top` (perimeter) | `Tile_X0Y10_W_IO` | x≈1.38µm (west perimeter) | x∈[0, 0.6]µm | ~0.78µm (halo inset) → **split** |
| `FrameData[0]` (interior) | `Tile_X1Y0_N_term_single` | x≈247µm (interior col 1) | x∈[0, 0.6]µm | ~247µm → **split** |

`FABULOUS_HALO_SPACING: [1,1,1,1]` insets **every** tile 1 µm from the die edge, while
`fabric_io_place.py` slams every BPin to the exact die boundary with `--hor-extension 0 / --ver-extension
0` and draws **no wire**. So *no* tile terminal reaches the boundary — every top pin floats, perimeter
(~1 µm) and interior (up to ~247 µm) alike. That is why all ~1581 ports fail uniformly.

## Mechanism

The fabric flow (`fabulous/fabric_generator/gds_generator/flows/fabric_macro_flow.py`) is **macro
abutment with no router** — it substitutes out `OpenROAD.GlobalPlacement / DetailedPlacement /
DetailedRouting / RCX` (`subs = {…: None}`) and connects tiles purely by abutting pins. Top-level
external pins are placed by the custom step `Odb.FABulousFabricIOPlacement` →
`script/fabric_io_place.py`.

`fabric_io_place.py` (per top-level BTerm): takes `iterm = net.getITerms()[0]`, derives the die-edge
*side* from the master's mTerm, places the BPin **at the die edge** aligned only in the cross-axis to the
iterm centre, and creates **no wire** — relying on the BPin geometrically overlapping tile pin metal.
Because every tile is halo-inset, that overlap never happens → all top ports disconnect at extraction.

Upstream CI (`.github/workflows/gds-flow-ci.yml`, `fabric-stitching` job: real gate — `fail-fast: false`,
no `continue-on-error`, exit-1 on LVS) runs this for `ihp-sg13g2`/`gf180mcuD` but **excludes sky130A**
("will get kill by github" — resources), so sky130A fabric LVS is an **unvalidated upstream path**. The
script is PDK-agnostic, so this gap is *likely* present on the other PDKs too unless their tile geometry
happens to reach the die edge — **not yet verified** (would need a green run on those PDKs).

## Fix direction (validated by the Phase-2 two-pass review)

The break is **physical** (pin metal genuinely does not touch the tile terminal), so an
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

## Phase-2 two-pass review — reconciliation

Two independent agents (optimistic / pessimistic) reviewed the fix on the same evidence.

- **Default recommendation:** patch `fabric_io_place.py` so each BPin's metal **overlaps its iterm**
  (place the pin box on the iterm geometry on the iterm's own layer), uniformly for all top ports. The
  iterm centre (`cx,cy`) is already computed; the connection needs **no router**.
- **Fallback:** if an interior BPin trips a "pins on die edge" expectation or DRC, keep the pin on the
  edge and add a minimal connecting shape, or place the pin at the nearest on-net boundary point.
- **Evidence still missing:** (1) whether the same flow actually passes fabric LVS on
  `ihp-sg13g2`/`gf180mcuD` (CI gate is real but a green run was not observed); (2) whether an interior
  BPin is acceptable to later checks. Both are resolved empirically by the cheap loop below.
- **Minimum health-check (seconds, no full re-stitch):** re-run only the preserved step-23 command
  (`23-odb-fabulousfabricioplacement/COMMANDS`: `openroad -python fabric_io_place.py … 22-…/eFPGA.odb`)
  to a scratch dir, then grep the new DEF to confirm each PIN box now overlaps its iterm. Then resume
  steps 23→49 (IO-place → extract → netgen-LVS) for the real LVS verdict, reusing steps 01-22 on disk.
- **Non-goals / do-not-copy:** OpenLane-classic PDN/core-ring values (not power); tile re-harden
  (13/13 clean); changing the v2.0.0b5 ref; mole99/external backend.
- **Deliverable hygiene (load-bearing):** `FABulous_work/fabulous-v2/` is gitignored. The fix must be a
  **tracked patch** (`docs/issue-12/patches/`) + before/after evidence, not just an in-place edit — an
  in-place green run is signal, not a deliverable.

### Key correction from the review
The earlier "global-only / per-tile-IO-matches" framing was **wrong**: all ~1581 top ports fail
uniformly (per-tile `A_I_top` included) because of the halo inset + edge-slam + no-wire, not a
high-fanout/`iterms[0]`-ordering effect. The fix direction is unchanged and is simpler for being uniform.

## Before/after fingerprint (to fill in Phase 3)

- **Before:** 1591 LVS errors · devices 151=151 · nets 34837 vs 34828 (+9) · 1581 disconnected pins ·
  `Top level cell failed pin matching`.
- **After:** _TBD_.

## Artifacts
- Preserved text evidence: `docs/issue-12/evidence/` (rpt, json, lvs_script, netlist headers, log tail).
- Full failing run (gitignored): `FABulous_work/fabulous-v2/fabric_baseline_proj/Fabric/macro/runs/RUN_2026-06-13_22-57-46/`.
- Flow source: `fabulous/fabric_generator/gds_generator/flows/fabric_macro_flow.py`,
  `steps/fabric_IO_placement.py`, `script/fabric_io_place.py`.
