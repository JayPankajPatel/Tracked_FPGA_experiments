# DRAFT — Follow-up Issue #2 (for review)

> **Status:** Draft for user review. Becomes GitHub issue #2 once approved. **Not yet created on GitHub.**
> Iterate on this file; when agreed, it is posted via `gh issue create` and linked to issue #1.

---

## Proposed title

`Validate the FABulous v2.0.0b5 clean-environment setup guide in GitHub Actions`

## Proposed labels

`fabric`, `sky130`, `experiment`, `needs-review`

## Proposed milestone

`fabric-integration-v0`

---

## Body

### Goal

Prove that `docs/fabulous-setup-guide.md` is **complete and reproducible from a clean environment** by
implementing a GitHub Actions workflow that sets up FABulous `v2.0.0b5` and runs its smoke test — then
**report every gap, missing step, or hidden assumption** discovered while doing so.

This is the execution counterpart to issue #1: issue #1 deliberately produced *only* the guide (no install,
no smoke run). This issue is where the install + smoke test actually run, in clean CI.

### Inputs you may use (and only these)

- `docs/fabulous-setup-guide.md` and `docs/fabulous-version-decision.md` in this repo,
- upstream FABulous docs / releases / PRs / `.github/workflows/*` at the pinned ref `v2.0.0b5` (`4a2047b`),
- files committed to this project repo,
- public package sources (Nix, PyPI/uv, Docker Hub / GHCR, GitHub Actions marketplace).

### Hard constraints

- Do **not** rely on any local-machine state: no personal `$HOME` FABulous checkout, no local `flake.lock`/
  `uv.lock`, no local Docker/Nix images, no shell history, no private email.
- Pin the FABulous ref to `v2.0.0b5` (tag, commit `4a2047b`). Do not track `main`.
- Work on a branch and open a PR; do not commit or push to `main`.
- Treat the guide as the **spec**. Every time you must improvise a step the guide doesn't state, record it
  as a finding (that is the point — it surfaces the guide's hidden assumptions).

### Scope — what to build

1. A workflow in this repo, e.g. `.github/workflows/fabulous-v2-smoke.yml`, that:
   - checks out / clones FABulous at `v2.0.0b5`,
   - establishes the Nix flake devshell on the runner (install Nix with flakes; a public Nix-setup Action is
     acceptable — record which one you chose, since the guide does not pin one),
   - runs **T0 (toolchain present)** as the **required** gate:
     `FABulous --version`, `yosys --version`, `openroad -version`, `fab-yosys -m ghdl -p help`,
   - runs **T1 (fabric generation)** if feasible on a stock runner:
     `FABulous create-project …` + `run 'run_FABulous_fabric'`.
2. **T2 (sky130 tile hardening)** — attempt as an *optional* / `workflow_dispatch` job and assess
   feasibility on GitHub-hosted runners (it is heavy: EDA P&R). Do **not** make the required gate depend on it.
3. A short **findings report** (PR description or `docs/fabulous-setup-guide-validation.md`) listing: every
   step you had to add/guess, anything in the guide that was wrong or under-specified, observed timings, and
   recommended guide edits.

### Tasks

- [ ] Add the smoke workflow pinned to `v2.0.0b5`, using only the allowed inputs.
- [ ] Make T0 the required, green gate.
- [ ] Add T1 (fabric gen); mark optional if it exceeds free-runner limits.
- [ ] Attempt T2 (sky130 tile hardening) as `workflow_dispatch`; record feasibility/time, or document why skipped.
- [ ] Produce the findings report (guide gaps + hidden assumptions + suggested edits).
- [ ] Open a PR linking issues #1 and #2; do not merge to `main`.

### Acceptance criteria

- A workflow runs green on **T0** (and **T1** where feasible) from a clean runner, using only the allowed inputs.
- The findings report enumerates any missing steps / hidden assumptions, or states explicitly that none were found.
- The workflow pins `v2.0.0b5`; it does not depend on `main` or any local-machine state.
- **sky130 fabric stitching is NOT required** (see caveat) and T2 is not a required gate.

### Resource caveats (carried from the guide / upstream CI)

- Upstream `gds-flow-ci.yml` **skips sky130A fabric stitching** on GitHub runners ("will get kill by github").
  Do not attempt sky130 fabric stitching as a required CI step; lighter PDKs (`ihp-sg13g2`, `gf180mcuD`)
  complete fabric stitch upstream, but sky130 is this project's target — keep heavy sky130 P&R for a larger
  machine / HPC.
- T2 tile hardening may approach GitHub job time/resource limits; treat it as best-effort signal, not a gate.

### Out of scope

- Choosing the FABulous version (settled in issue #1: `v2.0.0b5`).
- Resolving built-in v2.0 GDS flow vs. the external `librelane_plugin_fabulous` backend (decision doc §8.1).
- Full sky130 fabric/chip-top hardening or tapeout.

### References

- `docs/fabulous-setup-guide.md` (the spec under test) · `docs/fabulous-version-decision.md` (rationale, §8 risks)
- Upstream `v2.0.0b5` workflows: `nix-env.yml` (T0), `gds-flow-ci.yml` (T1/T2), `pytest_testing.yml` (uv path)
- Canonical upstream: `https://github.com/FPGA-Research/FABulous`
