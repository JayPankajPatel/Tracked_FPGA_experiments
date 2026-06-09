# FABulous Clean-Environment Setup Guide — `v2.0.0b5`

**Target ref:** `v2.0.0b5` (commit `4a2047b`) — chosen in `docs/fabulous-version-decision.md` (issue #1).
**Canonical upstream:** `https://github.com/FPGA-Research/FABulous`
**Scope:** This guide is a *reference*. Issue #1 does **not** run any of it — execution (install + smoke
test in CI) is the job of the follow-up validation issue (`docs/followup-issue-2-ci-validation.md`).

---

## 0. Clean-room contract

A separate agent must be able to follow this guide using **only**:

- this guide,
- upstream FABulous docs / releases / PRs / `.github/workflows/*` at the pinned ref,
- files committed to this project repo,
- public package sources (Nix, PyPI/uv, Docker Hub / GHCR).

It must **not** rely on: any personal `$HOME` checkout path (e.g. a local `…/Repos/FABulous`), that
checkout's dirty `flake.lock` / `docs/uv.lock`, local Docker/Nix state, shell history, or private email.

> Note on Nix/uv/Docker: these *are* FABulous's own sanctioned clean install paths (the repo ships
> `flake.nix`, `pyproject.toml`+`uv.lock`, `.devcontainer`). Using them from a clean checkout is correct;
> only reuse of the *local machine's existing* state is forbidden.

**Workspaces created from this guide live under `FABulous_work/`** in this project repo — never under
`…/Repos/FABulous` (that is read-only reference context only).

## 1. Prerequisites

The GDS / LibreLane flow **requires Nix** (upstream documents this as a hard prerequisite — PR #595).
Pick one environment path:

| Path | Provides | Use when |
|------|----------|----------|
| **Nix flake devshell** (canonical) | FABulous + Yosys + nextpnr + OpenROAD + GHDL/NVC | Full flow incl. GDS/tile hardening |
| **uv / PyPI** | FABulous Python tool + CLI only (no EDA tools) | Fabric definition / generation / CLI / tests |
| **Docker image** (nix-based, added in b5) | Encapsulated all-in-one | Reproducible runs without host Nix |
| **Devcontainer / Codespaces** | VS Code dev env | Cloud / onboarding |

System baseline: Linux x86-64 (CI uses `ubuntu-latest` / `ubuntu-22.04`), `git`, and **Nix with flakes
enabled** (`experimental-features = nix-command flakes`). Install Nix via the official or Determinate
installer. `iverilog` is an extra system package for the simulation tests (per `pytest_testing.yml`).

## 2. Step 1 — Clean clone + pinned checkout

```sh
# From this repo's FABulous_work/ directory:
git clone https://github.com/FPGA-Research/FABulous.git
cd FABulous
git checkout v2.0.0b5          # commit 4a2047b
git describe --tags            # expect: v2.0.0b5
```

(Shallow alternative: `git clone --branch v2.0.0b5 --depth 1 https://github.com/FPGA-Research/FABulous.git`.)

## 3. Step 2 — Enter the environment

### 3a. Nix devshell (canonical, required for GDS)

```sh
nix develop                    # builds/enters the flake devshell with FABulous + EDA tools
# or run a single command without an interactive shell:
nix develop --command bash -c "FABulous --version"
```

The upstream CI reference for this path is `.github/workflows/nix-env.yml` (uses the composite action
`.github/actions/prepare_nix_environment`, then `nix develop --command …`).

### 3b. uv / PyPI (Python tool only — no EDA stack, no GDS)

```sh
uv sync                        # installs from pyproject.toml + uv.lock
uv run FABulous --version
```

Reference: `.github/workflows/pytest_testing.yml` (`uv run pytest …`, `additional_system_packages: iverilog`).

### 3c. Docker (optional, encapsulated)

b5 adds a nix-based image (`.github/workflows/docker-image.yml`). Pull/run the published image and invoke
`FABulous --version` inside it. (Tag/registry: confirm from the workflow + release at the pinned ref.)

## 4. Step 3 — Tiered smoke test

Run in order; stop at the tier that matches your goal. T0–T1 are light; T2 is heavy (EDA P&R).

### T0 — Toolchain present (seconds–minutes)
Straight from `nix-env.yml`; proves the devshell exposes the toolchain.
```sh
nix develop --command bash -c "FABulous --version"
nix develop --command bash -c "yosys --version"
nix develop --command bash -c "openroad -version"
nix develop --command bash -c "fab-yosys -m ghdl -p help"
```
**Pass:** all four print versions / help without error.

### T1 — Fabric generation (minutes)
Proves the core FABulous tool generates a fabric (no EDA hardening).
```sh
nix develop --command bash -c "
  set -e
  FABulous create-project test_project
  FABulous --project-dir test_project run 'run_FABulous_fabric'
"
```
**Pass:** project scaffold + generated fabric artifacts (HDL, geometry, switch-matrix CSVs) under
`test_project/`, exit 0. *(Equivalent uv path: `uv run FABulous create-project …` — fabric gen does not need Nix.)*

### T2 — sky130 tile hardening (stretch; tens of minutes–hours, needs Nix + PDK)
Proves the integrated GDS flow on one PDK. Mirrors `gds-flow-ci.yml` (tile-hardening job).
```sh
nix develop --command bash -c "
  set -e
  FABulous create-project test_project
  sed -i \"s/FAB_PDK=.*/FAB_PDK='sky130A'/\" test_project/.FABulous/.env
  FABulous --project-dir test_project run 'run_FABulous_fabric'
  FABulous --project-dir test_project run 'gen_all_tile_macros'
"
```
**Pass:** tile macros produced; the manufacturability report (`Report Manufacturability` section) shows
**Antenna / LVS / DRC = Passed** for the hardened tiles. PDK is auto-fetched (auto-PDK setup, #606).

> Fabric stitching (`run 'gen_fabric_macro'`) is the next step but is **resource-heavy**: upstream's own
> `gds-flow-ci.yml` **skips sky130A fabric stitching** on GitHub runners ("will get kill by github").
> Run sky130 fabric stitching on a larger machine (e.g., HPC), not stock CI.

## 5. Caveats / known risks (see decision doc §8)

- **Nix is mandatory for the GDS flow.** The uv path stops at fabric generation.
- **sky130 fabric-stitch is too heavy for stock GitHub runners** (tile hardening is OK; lighter PDKs
  `ihp-sg13g2` / `gf180mcuD` complete fabric stitch in upstream CI).
- **Beta API churn:** v2.0 has breaking renames; re-verify commands against the pinned tag if upgrading.
- **External backend is separate:** the project's known-good sky130 hardening backend
  (`mole99/librelane_plugin_fabulous` + `mole99/fabulous-tiles` + LibreLane v3.0.0) is *not* exercised by
  this guide. Whether v2.0.0b5 artifacts feed that backend is unverified (decision doc §8.1).

## 6. Authoritative upstream references (at the pinned ref)

- `.github/workflows/nix-env.yml` — T0 env smoke (canonical).
- `.github/workflows/gds-flow-ci.yml` — T2 tile-hardening + fabric-stitching flow and PDK matrix.
- `.github/workflows/pytest_testing.yml` — uv-based install + test path.
- `docs/source/getting_started/` — `installation/`, `quickstart.md`, `codespaces.md`, `index.md`.
- Root: `flake.nix`, `pyproject.toml`, `uv.lock`, `Taskfile.yml`, `.devcontainer/`, `README.md`.
- Hosted docs: `https://fabulous.readthedocs.io/`.
