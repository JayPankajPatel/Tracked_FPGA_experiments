# GitHub issue draft - Generate a no-DSP FABulous example FPGA GDSII

**Status:** Posted as GitHub issue **#10** on 2026-06-13:
https://github.com/JayPankajPatel/Tracked_FPGA_experiments/issues/10
**Title:** Generate a no-DSP FABulous example FPGA GDSII via the official v2 flow
**Labels:** `fabric`, `sky130`, `experiment`, `needs-review`
**Depends on:** #7 (GDS toolchain bootstrap - proves the official flow installs + runs *through synthesis*).
**Workflow:** generate RTL -> harden individual tile/block macros -> compose/harden the fabric macro.
**DSP scope:** this issue is for an example FPGA **without DSPs**. A later issue should repeat the same flow with DSP-enabled tiles/blocks.

---

## Goal

Use the bootstrapped official FABulous `v2.0.0b5` GDS flow from #7 to take a standard **no-DSP** example FPGA through the intended hierarchical physical-design sequence on sky130A:

1. Generate RTL for the selected example fabric.
2. Harden the individual generated tile/block macros into physical macros.
3. Compose those hardened macros into the fabric and run the fabric-level hardening/composition flow.

This is the work #7 deliberately deferred. #7 proved the official toolchain can install and begin tile hardening through synthesis; this issue attempts real macro completion and fabric composition for a no-DSP baseline before adding DSP complexity.

## Background

Issue #7 established the official path:

- FABulous `v2.0.0b5` / commit `4a2047b...`
- official built-in FABulous GDS / LibreLane flow
- sky130A through-synthesis health check passed locally
- `mole99` remains prior art only, not a dependency

The next useful milestone is not a DSP fabric yet. First, prove the simpler hierarchical path works for an example FPGA without DSPs. That gives us a baseline for runtime, artifacts, manufacturability checks, and resource limits before introducing DSP-specific hardening problems.

## Pinned environment

- FABulous `v2.0.0b5` = `4a2047b...`; LibreLane `v3.0.3` (flake.lock `1e4f4d5b`); nix-eda `6.11.0`.
- sky130A PDK pinned: `FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (OpenLane-format; LibreLane-readable).
- Work under `FABulous_work/`; do not rely on `/home/jay/Repos/FABulous`, local Nix state, local PDK state, or external personal repos.

## Tasks

### A. Select and generate the no-DSP RTL

- [ ] Select the smallest standard FABulous example fabric that excludes DSP tiles/blocks.
- [ ] Confirm no DSP tiles/blocks are present in the selected example.
- [ ] Run `FABulous --project-dir <proj> run 'run_FABulous_fabric'`.
- [ ] Capture generated RTL artifacts, including the fabric top and tile/block RTL.
- [ ] Record the exact fabric definition/config used so the run is reproducible.

### B. Harden individual tile/block macros

- [ ] Run `FABulous --project-dir <proj> run 'gen_all_tile_macros'` to completion for the no-DSP example.
- [ ] Capture per-macro artifacts: GDS, LEF, gate-level netlist, SDC, SPEF, metrics.
- [ ] Record manufacturability: **antenna / LVS / DRC** pass/fail (reuse the `t2-sky130-tile-hardening` parser where possible).
- [ ] Record runtime + disk (cold/warm; Nix store vs 10 GB cap; PDK fetch size).
- [ ] Note any missing macro-level Liberty `.lib` / timing model.

### C. Compose and harden the fabric macro

- [ ] Run `FABulous --project-dir <proj> run 'gen_fabric_macro'` using the hardened no-DSP tile/block macros.
- [ ] Capture the stitched fabric artifacts and reports.
- [ ] Record whether sky130A fabric stitching needs a larger machine/HPC; upstream `gds-flow-ci.yml` skips sky130A fabric stitching on stock GitHub runners ("will get kill by github").
- [ ] Record DRC/LVS/manufacturability if the flow reaches those stages.

### D. Document results

- [ ] Record the exact commands, commit pins, PDK hash, runtime, disk usage, and machine/runner class.
- [ ] Summarize generated artifacts and where they live.
- [ ] Document failures as reproducible flow/resource blockers with logs, not as setup ambiguity.
- [ ] Update the project docs with the no-DSP baseline results.

## Acceptance criteria

- A no-DSP example fabric is selected and its generated RTL is captured.
- At least one generated tile/block macro produces a GDS macro with antenna/LVS/DRC results recorded, or a reproducible blocker is documented.
- The fabric-level composition/hardening command is run, with either a stitched GDSII artifact or a reproducible resource/flow blocker.
- Failures are documented as reproducible flow bugs with the exact pinned environment, not setup ambiguity.
- Runtime, disk, PDK fetch behavior, and cache behavior are recorded.
- The result creates a clean baseline for the later DSP-enabled issue.

## Out of scope

- DSP-enabled fabrics, DSP hardening, or DSP-specific timing/physical-design work.
- Timing closure.
- Tapeout readiness or final signoff.
- Adopting external `mole99` infrastructure.
- Changing the project default FABulous ref away from `v2.0.0b5`.
- Treating uv as the reproducible backend path for GDS work.

## Expected DSP follow-up

The next issue should repeat this flow with a DSP-enabled FABulous example:

- select or define a standard example fabric with DSP tiles/blocks,
- generate RTL,
- harden DSP and non-DSP tile/block macros,
- compose and harden the fabric macro,
- compare DSP-specific failures, runtime, disk, artifact set, and manufacturability against the no-DSP baseline.

---

## References

- `docs/gds-toolchain-bootstrap.md` (#7 bootstrap + pinned inventory + falsifier status)
- `.github/workflows/fabulous-v2-smoke.yml` (`t2-sky130-tile-hardening` full run; `gds-bootstrap-synth-check` through-synthesis)
- Upstream `FPGA-Research/FABulous@v2.0.0b5`: `.github/workflows/gds-flow-ci.yml`, `fabulous/fabulous_settings.py`
