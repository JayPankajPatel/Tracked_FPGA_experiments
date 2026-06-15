# HANDOFF

## 2026-06-15 — Issue #16: MPW-portable chip wrapper — planning + scaffold

**Branch:** `feature/16-chip-wrapper-efpga` (off `main`; do not push/merge `main`)

**Goal:** chip/top-level wrapper around the #12 LVS-clean `eFPGA` macro so it integrates into a
pad-limited sky130 shuttle design. User steered the scope to: an **MPW-portable** approach (one
fixed interface contract + fabric size as a knob), seed **Caravel + standalone** profiles, and use
**FABulous's own simulator as the functional oracle**.

**Process:** CLAUDE.md two-pass review run as two independent agents (opt + pess). Reconciled in
`docs/issue-16/wrapper-architecture-decision.md`. Incorporated the FABulous-upstream config note
from Dirk Koch (issue #16 comment, 2026-06-15): preserve the existing 2-cycle / address-before-frame
frame protocol; keep the wrapper a thin adapter; no backpressure.

**Key findings (primary-source):**
- **Caravel is geometrically impossible for the current macro.** eFPGA macro = 2482.16 x 3930.40 um
  (`final_views/lef/eFPGA.lef` SIZE); Caravel user area = 2920 x 3520 um. 3930 > 3520 (and rotated,
  3930 > 2920) -> no orientation fits, before PDN/halo/controller. The optimistic pass's "fits" was
  a pad-count argument (wrong axis).
- **FABulous already generated the integration layer:** `eFPGA_top.v` wraps `eFPGA`, ties 448 BRAM
  ports to 7 internal `BlockRAM_1KB` (which blackbox OpenRAM `sram_1rw1r_32_256_8` -> 7 hard SRAM
  macros, NOT soft logic), drives the 712-bit config net from its own controller, and exposes a
  small interface (CLK/resetn/SelfWrite*/UART Rx/serial s_clk,s_data + 28 bidir user IO + 168
  config_C monitors).
- **FABulous-sim oracle exists on disk:** `fabric_baseline_proj/Test/` (`make sim`/`FAB_sim`):
  yosys -> nextpnr -> bit_gen -> iverilog TB; `user_design/top_wrapper.v` exposes io_in/io_out/io_oeb.
- **open_eFPGA prior art is a 12-row fabric** (ours is 14) -> mapping pattern only, do NOT port its loader.
- **Reproducibility gap:** all macro/controller artifacts are gitignored under `FABulous_work/`;
  committed deliverable must stay clean-room + ship a regeneration script.

### Changes made (this branch)
- `docs/issue-16/`: `port-inventory.md`, `wrapper-architecture-decision.md` (two-pass reconciliation),
  `mpw-validation-plan.md` (layered validation pyramid + decisions).
- `Librelane_work/chip_wrapper/`: parametrized RTL (`chip_top.v`, `config_adapter.v`, `io_mux.v`,
  clean-room `efpga_top_bb.v` stub), `profiles/{caravel,standalone}.yml`, `fabrics/baseline14.yml`,
  `tools/check_conformance.py` (validation layer 2), `shims/chip_top_standalone.v`, `README.md`.

### Validation run (no PDK / no P&R)
- `iverilog -g2012 -Wall` elaboration of chip_top + standalone shim: **exit 0**.
- `verilator --lint-only` (blackbox warnings suppressed): **exit 0**.
- `python3 tools/check_conformance.py --all`: **standalone CONFORMANT; Caravel NOT CONFORMANT**
  (area fail) — the checker mechanically reproduces the two-pass area finding.
- Not run: functional/shim-replay sim against the FABulous oracle (needs regenerated `eFPGA_top` +
  real bitstream); reference hardening (later milestone).

### Next recommended action
1. **User:** review `feature/16-chip-wrapper-efpga` direction (MPW-portable + standalone-first).
   Decide the remaining fork: standalone-now vs also shrink-fabric-for-Caravel as a follow-up.
2. Next increment: drive `fabric_baseline_proj/Test/` to emit a golden bitstream + reference
   `io_out`; wire the functional + shim-replay testbench (validation layers 3-4) against `chip_top`.
3. Write the clean-room regeneration script (pinned FABulous v2.0.0b5 + LibreLane) so the wrapper's
   gitignored dependencies are reproducible.
4. Later: reference hardening (LibreLane P&R + DRC/LVS/Antenna) for the standalone target.

---

## 2026-06-14 — Issue #12: fabric-stitch LVS blocker RESOLVED (manufacturability-clean fabric)

**Branch:** `feature/12-fabric-lvs-rootcause` (off `feature/10-fabric-baseline`; do not push/merge `main`)

**Goal:** Root-cause the PR #11 / issue #10 sky130A fabric-stitch LVS blocker and drive the standard
FABulous `v2.0.0b5` example fabric to **manufacturability-clean** (Antenna/LVS/DRC) on the official flow.

**Result: GREEN.** Fabric LVS/DRC/Antenna all pass (`RUN_2026-06-14_08-12-05`); netgen
`Circuits match uniquely`; nets 34828 = 34828 (was 34837 vs 34828); `eFPGA.gds` 52 MB; ~4.5 min, ~19 GB.

**Root cause (NOT PDN).** The fabric stitch flow has no router and connects tiles by abutment;
`fabulous/fabric_generator/gds_generator/script/fabric_io_place.py` placed every top-level IO BPin on
the **die edge** while every tile is 1 µm halo-inset (`FABULOUS_HALO_SPACING`), with no wire — so all
~1581 top ports floated off their terminals and netgen failed top-level pin matching. The wiki PDN
notes matched the fingerprint *shape* (151=151 devices, +9 nets) but **zero** unmatched nets are power.
Localized entirely from the on-disk PR #11 run (no re-run needed). Two-pass review corrected an initial
"global-only" mis-read → it was uniform across all top ports.

**Fix.** Place a pin shape over **every** iterm of each top-level port, on the terminal's own layer:
single-driver ports get one shape; fan-out globals (`UserCLK` → 10 column terminators) get one each so
they unify at extraction. Tiles/PDN/grid floorplan untouched.

### Changes made (this branch)
- `docs/issue-12/` (new) — `root-cause.md` (diagnosis + two-pass + before/after), `README.md`,
  `patches/fabric_io_place-overlap-iterm.patch` (the fix; +37/−83, applies cleanly on `v2.0.0b5`),
  `apply-fix.sh` (idempotent), `evidence/` (failing run), `evidence-after/` (green run).
- `.github/workflows/fabulous-v2-smoke.yml` — `gds-fabric-stitch` job now checks out this repo, applies
  the patch, and **asserts** manufacturability when reached (still non-failing on stock-runner OOM).
  actionlint clean; YAML parses (5 jobs).
- `docs/fabric-gds-baseline.md` — §C blocker marked RESOLVED with cross-reference.

### Validation
- Local sky130A re-stitch with the patch: **Antenna/LVS/DRC Passed**, `Circuits match uniquely`, exit 0.
- Patch applies cleanly to pristine `v2.0.0b5` blob `41d9a13`; `apply-fix.sh` idempotent.
- `nix run nixpkgs#actionlint` + `yaml.safe_load` on the workflow → clean.
- Not run: cold-runner CI dispatch (stock 4c/16 GB still OOMs at ~19 GB peak — documented, non-failing).

### Next recommended action
1. **User:** review `feature/12-fabric-lvs-rootcause`; PR is being opened linking #12. Only the user
   merges `main`.
2. Follow-up (separate issue): macro `.lib`/SPEF generation + timing closure (still out of scope here;
   tiles black-boxed for timing, generic fallback SDC).
3. Consider upstreaming the `fabric_io_place.py` fix to FABulous (sky130A fabric-stitch is excluded from
   upstream CI for resources, so this path was unvalidated upstream).
4. Promote the root cause to `~/wiki/fpga_stochastic_blocks/experiments/`.

---

## 2026-06-14 — Issue #10: standard example fabric → sky130A GDSII baseline

**Branch:** `feature/10-fabric-baseline` (off `main`; do not push/merge `main`)

**Goal:** Issue #10 — take the standard FABulous `v2.0.0b5` example fabric through the official
hierarchical GDS flow on sky130A (RTL → all tile macros → fabric stitch) and record a reproducible
baseline. (#10 title says "no-DSP" but body was relaxed to the standard demo fabric, which is the
only shipped example and **contains DSP** — DSP tiles harden as ordinary macros.)

**Result:**
- **Tiles (A+B) = PASS.** All **13/13** demo tiles hardened to GDS; manufacturability **13/13**
  Antenna/LVS/DRC. ~**15 min** wall (warm), **2.1 GB** peak RSS. Per-tile GDS/LEF/def/nl/pnl/sdc/spef/
  metrics. **No `*.lib`** emitted (no macro timing model); DRC verdict is KLayout (Magic DRC skipped).
- **Fabric stitch (C) = GDSII produced, signoff FAILS.** `gen_fabric_macro` on sky130A **was NOT
  resource-killed** on this 24c/29 GB host (upstream skips sky130A as "killed by github" = stock
  4c/16 GB limit): it streamed `eFPGA.gds` (~52 MB, die ≈9.76 mm²) in **4 min 29 s**, **~18.8 GB peak
  RSS**, then `FlowError` — **1591 LVS errors**. LVS fingerprint: devices 151=151, nets differ by 9,
  "failed pin matching" on inter-tile routing ports — a reproducible *signoff* blocker.
- **Wiki check (user-requested):** `~/wiki/fpga_tapeout/synthesis/{pdn-lvs-fix,core-ring-lvs-fix,
  opensta-write-lib-bug}.md` document the **same top-level-LVS signature** from a prior OpenLane-classic
  FPGA assembly (drove 155→0 via met5-crossing + `FP_PDN_CORE_RING`). Recorded as **prior-art
  hypotheses, NOT adopted** (different flow; FABulous already uses dense PDN). See baseline §C.2.

### Changes made (this branch)
- `docs/fabric-gds-baseline.md` (new) — full #10 baseline: pins, commands, tile manufacturability
  table, artifact inventory, disk/cache, fabric-stitch outcome + LVS fingerprint + prior-art fixes.
- `.github/workflows/fabulous-v2-smoke.yml` — new dispatch-only `gds-fabric-stitch` job (Task C;
  `needs: t2-sky130-tile-hardening`, never-fails, documents the sky130A stitch boundary). actionlint
  clean; YAML parses (5 jobs).
- `docs/gds-toolchain-bootstrap.md` §9 — deferred→done cross-reference to the #10 baseline.
- `docs/followup-issue-gds-generation.md` — carried the stray `main` working-tree edit onto this
  branch (records #10 was posted); committed here so `main` stays clean.

### Validation run
- Local sky130A flow (warm): tile harden PASS (13/13 manufacturability); fabric stitch GDSII +
  documented LVS blocker. All outputs under gitignored `FABulous_work/fabulous-v2/` (clean-room intact).
- `nix run nixpkgs#actionlint` + `yaml.safe_load` on the workflow → clean.
- Not run: cold-runner CI dispatch of `t2-sky130-tile-hardening` / `gds-fabric-stitch` (needs user push
  + dispatch) — confirms #7 falsifier #3 (10 GB cache cap) and the stock-runner stitch boundary.

### Next recommended action
1. **User:** review `feature/10-fabric-baseline`; (optionally) push + `workflow_dispatch` the two
   sky130A jobs to capture cold-runner timing/disk. Agent will not push/PR without approval.
2. Open a **fabric-stitch LVS** follow-up issue: diagnose the ~9 unmatched nets (PDN islands vs tile
   boundary-pin/abstract) per baseline §C.2; then macro `.lib` generation + timing.
3. Promote the #10 baseline (tile timings, stitch RAM ceiling, LVS signature) to
   `~/wiki/fpga_stochastic_blocks/experiments/`.

---

## 2026-06-13 — Issue #7: GDS toolchain bootstrap (OFFICIAL FABulous v2 flow)

**Branch:** `feature/7-gds-toolchain-bootstrap` (off `main`; do not push/merge `main`)

**Current goal:** Issue #7 — reproducible bootstrap of the GDS toolchain via the **official FABulous v2.0.0b5 built-in GDS/LibreLane flow** (issue #7 was rewritten to mandate this; `mole99` demoted to prior art). Bootstrap = prove the flow installs + runs **through synthesis**; finished GDS is the follow-up.

**Process:** Plan re-evaluated with the new CLAUDE.md **Optimistic/Pessimistic two-pass run as two independent agents** (agA optimistic, agB pessimistic). CLAUDE.md clause clarified to require two separate agents.

**Result — bootstrap validated locally (through synthesis): PASS.**
- Fresh FABulous `v2.0.0b5` (`4a2047b`) Nix devshell; `FAB_PDK='sky130A'`; `gen_all_tile_macros`.
- **LibreLane `v3.0.3`** (flake.lock rev `1e4f4d5b`). sky130A PDK **auto-resolved to ciel `8afc8346`** (OpenLane-format → LibreLane-readable), fetched fresh into an isolated `PDK_ROOT`; **`~/.ciel` untouched**.
- `Yosys.Synthesis` → `DFFLIBMAP` clean (no `Missing -liberty`) → `OpenROAD.Floorplan` (die 250×491 µm) → CTS. **No `LIB={}`.** ~2.5 min warm through synthesis.
- Pin the PDK explicitly with **`FAB_PDK_HASH=8afc8346…`** (FABulous `pdk_hash`) to kill ciel-default drift.

**Falsifiers (from the two-agent review):** #2 (LIB={}) FALSE; #4 (dev-string version) FALSE (reports v3.0.3); #5 (only local 0fe599b2) FALSE; #1 (commit drift) mitigated by pinning `FAB_PDK_HASH`; **#3 (CI Nix-store + PDK vs 10 GB cap) OPEN — confirm on a cold runner.**

### Changes made
- `docs/gds-toolchain-bootstrap.md` (new) — official-path bootstrap guide: pinned inventory, clean-env setup, PDK pin, through-synthesis health check + local result, cold/warm + disk, falsifier table, **labeled "Prior art (mole99) — lessons, not adopted"** section.
- `docs/followup-issue-gds-generation.md` (new) — drafted follow-up ramp (A: one tile → GDS macro + manufacturability; B: example FPGA fabric). Not posted.
- `.github/workflows/fabulous-v2-smoke.yml` — new `gds-bootstrap-synth-check` job (`workflow_dispatch`): checkout+guard+Nix-composite (reused from #2), `FAB_PDK_HASH` pinned, runs `gen_all_tile_macros` time-bounded, **asserts synthesis resolved liberty + entered OpenROAD** (fails on `LIB={}`). `t2` full-harden job left for the follow-up.
- `.gitignore` (new) — ignore the official/testchip clones, PDK stores, logs, local smoke scripts.
- `CLAUDE.md` — clarified §Optimistic/Pessimistic Rubber-Ducking to require **two separate independent agents** (separate concern; can split to its own `update/` branch).

### Validation run
- Local: official smoke through synthesis = PASS (above). Workflow YAML: `yaml.safe_load` OK (jobs: smoke, uv-lean-path, t2-sky130-tile-hardening, gds-bootstrap-synth-check).
- Not run: cold-runner CI of `gds-bootstrap-synth-check` (needs user push + dispatch) — confirms falsifier #3 (disk).

### mole99 prior art (this session, NOT adopted)
Earlier hardened a clean `LUT4x8_ha` tile via the mole99 plugin — reclassified as prior art per the rewritten #7. Key transferable lesson (now in the guide): LibreLane reads liberty via `pdk_compat` from **OpenLane-format** PDKs; a `CELL_LIBS`-format PDK gives `LIB={}`. The official auto-resolved `8afc8346` is OpenLane-format, hence it works.

### Next recommended action
1. **User:** review the docs + workflow on `feature/7`; push the branch and `workflow_dispatch` `gds-bootstrap-synth-check` to confirm the through-synthesis check + disk (falsifier #3) on a clean runner (agent will not push/dispatch without approval).
2. Fold any CI findings (timing, disk) back into `docs/gds-toolchain-bootstrap.md` §6/§7.
3. On close, open the follow-up issue(s) from `docs/followup-issue-gds-generation.md`.
4. (Optional) split the CLAUDE.md clarification to its own `update/` branch.

---

## 2026-06-08 — Issue #2: FABulous v2.0.0b5 smoke-validation CI workflow

**Branch:** `feature/2-fabulous-v2-smoke-ci` (off `main`; do not push/merge `main`)

**Goal:** Issue #2 — prove `docs/fabulous-setup-guide.md` is reproducible from a clean GitHub-hosted
runner by implementing the FABulous `v2.0.0b5` smoke workflow + a findings report. Pin `4a2047b`.

**State:** PR **#5** open; **all gates validated across 4 CI runs.** Summary:
- **Required `smoke` gate GREEN** on runs #1, #3, #4: T0 (toolchain) + required T1 (fabric gen + artifact
  gate verifying `eFPGA.v`/`LUT4AB.v`/`LUT4AB_switch_matrix.v`).
- **Cold vs warm:** first run ~55 min (Nix prep ~54 min: 507 FOSSi cache hits + 252 source builds);
  **warm run #4 = 3 min 33 s** (Nix prep 176 s) after the store cache persisted — ~18× faster.
- **Fix applied during validation:** **`actions: write`** so `cache-nix-action` can save the Nix store
  (was failing → every run cold; now warm).
- **uv-lean-path: optional, non-gating CI job** (re-added — more signal). Green (run #3, 35 s); with
  `uv sync --frozen` + `fetch-depth:0` → `FABulous CLI 2.0.0`. Needs `setup-uv@v8.2.0` (no `v8` alias) +
  `python3-tk` (tkinter). **Limits (findings A11):** installs the current FABulous *frontend* only — **no
  EDA backend** (yosys/openroad/…); Nix remains the reproducible-backend path.
- **Findings:** `docs/fabulous-setup-guide-validation.md` §B has all timings, cache analysis, and suggested
  guide edits (FABulous `--version`→`0.0.0`; cold bring-up is tens of min; consumer needs `actions: write`;
  uv path needs `python3-tk`).
- **Remaining (optional):** T2 sky130 tile hardening (`workflow_dispatch`, not a gate) not yet run.
- **Issue #2:** real CI results recorded — **ready to close on merge** (leave to user; only the user merges `main`).

### Changes made
- `.github/workflows/fabulous-v2-smoke.yml` (new) — `smoke` job: **T0 (required gate)** = FABulous/yosys/
  openroad/fab-yosys version checks in the Nix devshell, **T1 (required gate)** = fabric gen **plus a
  generated-artifact gate** asserting the *generated* (non-template) RTL exists/non-empty:
  `Fabric/eFPGA.v`, `Tile/LUT4AB/LUT4AB.v`, `Tile/LUT4AB/LUT4AB_switch_matrix.v` (+ `module` content check on
  the fabric top). Filenames pinned from v2.0.0b5 source (CLI `setWriterOutputFile` paths; `Fabric` default
  name `eFPGA`; default Verilog writer → `.v`), corroborated by quickstart §5 — not guessed. `uv-lean-path`
  (optional, non-gating) = `uv sync` + `FABulous --version`; `t2-sky130-tile-hardening` (optional,
  `workflow_dispatch`-only, not a gate, 360-min timeout) = sky130A tile hardening mirroring upstream
  `gds-flow-ci.yml` with its manufacturability parser. Pinned to the **full SHA** `4a2047b…68a` with a SHA+tag guard.
- `docs/fabulous-setup-guide-validation.md` (new) — findings report: §A authoring-stage findings (known now),
  §B post-CI-run placeholders.

### Central authoring finding
Upstream's `prepare_nix_environment` is a **repo-local composite action**; a consumer can't reference
`./.github/actions/...` (resolves to *our* repo). **Chosen fix (Option A):** check FABulous out as the
**workspace root**, so the composite action + `flake.nix` + `hashFiles` resolve verbatim at the pin. Plain
`nix develop` works (FOSSi cache trusted via the composite's `nix_conf`; no `--accept-flake-config` needed).
Full list + suggested guide edits in `docs/fabulous-setup-guide-validation.md` §A.

### Validation run (local, pre-push)
- `actionlint` + `shellcheck` (downloaded static binaries) on the workflow → **clean (exit 0)** after fixing
  one SC2295 (quoted inner expansion in the ref-guard prefix match).
- `python3 -c "yaml.safe_load(...)"` → OK.
- Note: lint validates syntax/expressions/bash only — **Nix/FABulous semantics are validated only by the CI run.**

### Next recommended action
1. **User:** push `feature/2-fabulous-v2-smoke-ci` and open a PR linking issues #1 and #2 (agent will not
   push/PR without explicit approval). PR body must state findings are provisional until the first CI run.
2. After the first run: fill `docs/fabulous-setup-guide-validation.md` §B (T0 green?, T1 timing, T2 feasibility,
   cache timings); fold any improvised steps + guide edits (§A1/A2/A4) back into `docs/fabulous-setup-guide.md`.
3. Optionally trigger T2 via `workflow_dispatch` to assess sky130A tile-hardening feasibility on a stock runner.

---

## 2026-06-09 — Issue #1 merged; sim/verification toolchain notes follow-up

**Branch:** `update/fabulous-sim-toolchain-notes` (off `main`; do not push/merge `main`)

**State:** PR #3 (issue #1) **merged** into `main` (merge `c73468e`, 2026-06-09); issue #1 **closed**.
Issue #2 (CI validation) remains **open**. This follow-up captures verification-toolchain decisions made
during PR #3 review that were not in the merge.

### Changes made
- `docs/fabulous-setup-guide.md` — reframe uv as the lean RTL-iteration path; new §5 "Simulation &
  verification strategy (tool-agnostic)"; renumbered Caveats→§6, References→§7.

### Decisions recorded
- **Verification = pytest + cocotb** (directed + Python golden-model over a random pool). Constrained-random
  (Hypothesis) and functional coverage (cocotb-coverage) **deferred** — they layer on the same base, no rework.
- **Sims tool-agnostic** via cocotb `SIM=` (Questa/VCS/Xcelium); bundled iverilog/NVC/GHDL are defaults, not locks.
- **uv now** (lean RTL-gen iteration) / **Nix later** (tapeout/GDS).

### Next recommended action
1. Review & merge the `update/fabulous-sim-toolchain-notes` PR (only the user merges `main`).
2. Issue #2: a separate agent implements the clean-room CI validation workflow.
3. (Optional) delete the merged `feature/1-choose-fabulous-version` branch.

---

## 2026-06-08 — Issue #1: Choose FABulous version/ref

**Branch:** `feature/1-choose-fabulous-version` (off `main`; do not push/merge `main`)

**Current goal:** Complete issue #1 — documented FABulous ref recommendation + clean-environment
setup guide + minimal smoke-test sequence + a drafted follow-up GitHub Actions validation issue.
Research/docs only: no install, no smoke-test run, no generated project, no CI workflow in this issue.

**State:** ✅ Issue #1 complete; **PR #3 merged 2026-06-09** (merge `c73468e`), issue #1 closed.
Decision **`v2.0.0b5`**. **Issue #2** open (…/issues/2). Follow-up notes in `update/fabulous-sim-toolchain-notes`.

### Changes made
- `docs/fabulous-version-decision.md` (new) — full evidence, comparison table, decision record
  (chosen ref `v2.0.0b5`), headline risk (external backend), §8 risks/unknowns.
- `docs/fabulous-setup-guide.md` (new) — clean-room contract, Nix/uv/Docker install paths for `v2.0.0b5`,
  tiered smoke T0/T1/T2 (sourced from upstream `.github/workflows`). Clean-room grep audit: PASS.
- `docs/followup-issue-2-ci-validation.md` (new) — issue #2 (CI validation) source/record; **posted as GitHub #2**.
- Created triage labels: `fabric`, `sky130`, `experiment`, `needs-review`.
- `HANDOFF.md` (this file).

### Key evidence (verified)
- Canonical upstream: `https://github.com/FPGA-Research/FABulous` (`-Manchester` URL redirects).
- Candidate pins: `v1.3.1` (stable "Latest"), `v2.0.0b4`=`b857480` (local checkout), `v2.0.0b5`=`4a2047b`
  (newest tag), `main`=`20d9df6` (moving, 2026-06-08).
- Verified discriminator: integrated GDS/LibreLane/sky130 flow is a **v2.0-line** feature, maturing at
  `v2.0.0b5` (`gds-flow-ci.yml`, `gen_all_tile_macros`/`gen_fabric_macro`, multi-PDK). `v1.3.1` has none.
- Maintainer guidance = README "use tagged releases for production" (both v1.3.1 and v2.0.0b5 qualify; `main` does not).
- "Silicon-proven" = framework lineage (12+ tapeouts, SOFA/sky130), NOT any candidate ref. v2.0 = "active development".
- **Headline risk:** existing known-good sky130 backend is external (`mole99/librelane_plugin_fabulous` 1.10.2 +
  `mole99/fabulous-tiles` + LibreLane v3.0.0); pins **no** FABulous tool ref. v2.0.0b5 artifact compatibility unverified.

### Commands run (read-only research)
`gh release list/view`, `gh api .../compare/...`, `gh api .../contents/.github/workflows?ref=<ref>`,
`gh api .../contents/README.md?ref=<ref>`; `git -C /home/jay/Repos/FABulous ...` (read-only);
read `~/wiki/fpga_tapeout/...` notes; `grep` of `/home/jay/Repos/sky130-fabulous-testchip` flake/.gitmodules (read-only).

### Open questions
1. ~~Ref sign-off~~ → **RESOLVED: `v2.0.0b5`** (2026-06-08).
2. ~~Issue #2 draft review~~ → **RESOLVED: posted as #2** (2026-06-08).
3. Built-in v2.0 GDS flow vs external `librelane_plugin_fabulous` backend (separate decision; not resolved in #1).

### Next recommended action
1. **PR open** against `main` linking #1/#2 — user reviews & merges (only the user merges/pushes `main`).
2. After merge, the issue #2 agent implements the clean-room CI validation workflow.
3. (Optional) promote decision to `~/wiki/fpga_stochastic_blocks/decision_logs/` + update its index.
