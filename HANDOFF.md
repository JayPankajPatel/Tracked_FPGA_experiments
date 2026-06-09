# HANDOFF

## 2026-06-08 — Issue #2: FABulous v2.0.0b5 smoke-validation CI workflow

**Branch:** `feature/2-fabulous-v2-smoke-ci` (off `main`; do not push/merge `main`)

**Goal:** Issue #2 — prove `docs/fabulous-setup-guide.md` is reproducible from a clean GitHub-hosted
runner by implementing the FABulous `v2.0.0b5` smoke workflow + a findings report. Pin `4a2047b`.

**State:** PR **#5** open; **all gates validated across 4 CI runs.** Summary:
- **Required `smoke` gate GREEN** on runs #1, #3, #4: T0 (toolchain) + required T1 (fabric gen + artifact
  gate verifying `eFPGA.v`/`LUT4AB.v`/`LUT4AB_switch_matrix.v`).
- **Cold vs warm:** first run ~55 min (Nix prep ~54 min: 507 FOSSi cache hits + 252 source builds);
  **warm run #4 = 3 min 33 s** (Nix prep 176 s) after the store cache persisted — ~18× faster.
- **Fixes applied during validation:** (1) `setup-uv@v8`→`@v8.2.0` (no `v8` alias); (2) `python3-tk` for
  `uv sync` (tkinter); (3) **`actions: write`** so `cache-nix-action` can save the Nix store
  (was failing → every run cold). uv-lean-path now green (35 s).
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
