# Follow-up issue draft — Generate a standard FABulous example GDSII (official v2 flow)

**Status:** draft / source record for a GitHub issue. Not yet posted — post only after user review.
**Depends on:** #7 (GDS toolchain bootstrap — proves the official flow installs + runs *through synthesis*).
**Ramp:** tile-first, then fabric (each is its own issue).

---

## Part A — One tile to a finished GDS macro (sky130A)

### Goal
Using the bootstrapped official FABulous `v2.0.0b5` GDS flow from #7, harden **one tile to a finished GDS macro** on sky130A and capture signoff status. This is the part #7 deliberately deferred (#7 stops at synthesis).

### Pinned environment (from #7, `docs/gds-toolchain-bootstrap.md`)
- FABulous `v2.0.0b5` = `4a2047b…`; LibreLane `v3.0.3` (flake.lock `1e4f4d5b`); nix-eda `6.11.0`.
- sky130A PDK pinned: `FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (OpenLane-format; LibreLane-readable).

### Tasks
- [ ] Run `gen_all_tile_macros` to **completion** for the default-fabric tiles on sky130A.
- [ ] Capture per-tile artifacts: GDS, LEF, gate-level netlist, SDC, SPEF, metrics.
- [ ] Record manufacturability: **antenna / LVS / DRC** pass/fail (reuse the `t2-sky130-tile-hardening` job's parser).
- [ ] Record runtime + disk (cold/warm; Nix store vs 10 GB cap; PDK fetch size).
- [ ] Note any missing macro-level Liberty `.lib` / timing model.

### Acceptance
- At least one tile produces a GDS macro with antenna/LVS/DRC results recorded.
- Failures documented as **reproducible flow bugs** (with the exact pinned env), not setup ambiguity.
- CI: the existing `t2-sky130-tile-hardening` job (`workflow_dispatch`) green, or a recorded reproducible blocker.

### Out of scope
- Fabric stitching; full FPGA GDSII; timing closure; final signoff.

---

## Part B — Standard example FPGA fabric (sky130A)

### Goal
Stitch a **standard example fabric** to GDSII via `gen_fabric_macro`, building on Part A's tiles.

### Known constraints (primary source)
- Upstream `gds-flow-ci.yml` **skips sky130A fabric stitching** on GitHub runners ("will get kill by github"); lighter PDKs (`ihp-sg13g2`, `gf180mcuD`) complete. → Plan sky130A fabric stitch on a **larger machine / HPC**, not stock CI.

### Tasks
- [ ] Select a standard example fabric.
- [ ] Run `gen_fabric_macro` (tiles-first, per the ordering lesson); capture the stitched GDS + reports.
- [ ] Record DRC/LVS/manufacturability if feasible; document resource needs.

### Acceptance
- A stitched example-fabric GDSII (or a documented, reproducible resource/flow blocker).

---

## References
- `docs/gds-toolchain-bootstrap.md` (#7 bootstrap + pinned inventory + falsifier status)
- `.github/workflows/fabulous-v2-smoke.yml` (`t2-sky130-tile-hardening` full run; `gds-bootstrap-synth-check` through-synthesis)
- Upstream `FPGA-Research/FABulous@v2.0.0b5`: `.github/workflows/gds-flow-ci.yml`, `fabulous/fabulous_settings.py`
