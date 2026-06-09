# HANDOFF

## 2026-06-08 — Issue #1: Choose FABulous version/ref

**Branch:** `feature/1-choose-fabulous-version` (off `main`; do not push/merge `main`)

**Current goal:** Complete issue #1 — documented FABulous ref recommendation + clean-environment
setup guide + minimal smoke-test sequence + a drafted follow-up GitHub Actions validation issue.
Research/docs only: no install, no smoke-test run, no generated project, no CI workflow in this issue.

**State:** ✅ Issue #1 work complete. Decision **`v2.0.0b5`** (user-confirmed 2026-06-08).
**Issue #2** posted (…/issues/2). **PR #3** open against `main` (…/pull/3), closes #1 — awaiting user review/merge.
Only the user merges/pushes `main`.

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
