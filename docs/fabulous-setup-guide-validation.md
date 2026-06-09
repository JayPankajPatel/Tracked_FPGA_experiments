# FABulous v2.0.0b5 Setup-Guide Validation — Findings

**Issue:** #2 — Validate the FABulous v2.0.0b5 clean-environment setup guide in GitHub Actions
**Spec under test:** `docs/fabulous-setup-guide.md` · **Rationale:** `docs/fabulous-version-decision.md`
**Pin:** `v2.0.0b5` == commit `4a2047b` · **Canonical upstream:** https://github.com/FPGA-Research/FABulous
**Workflow:** `.github/workflows/fabulous-v2-smoke.yml`

> **Status:** this report has two halves. The **authoring-stage findings** below are known now,
> from implementing the workflow against the guide + upstream `.github/` at the pinned ref. The
> **post-first-CI-run findings** are placeholders — GitHub Actions cannot run locally and only the
> user pushes/opens PRs, so runtime results (T0 green? T1 timing? T2 feasible?) exist only after the
> first CI run on the branch/PR. Treat everything below the divider as provisional until then.

---

## A. Authoring-stage findings (known now)

### A1. The upstream Nix-setup action is repo-local — a consumer cannot reference it directly *(guide gap)*

The guide's §3a and §7 tell a consumer to "mirror `.github/actions/prepare_nix_environment/action.yaml`."
Upstream's own `nix-env.yml` / `gds-flow-ci.yml` invoke it as `uses: ./.github/actions/prepare_nix_environment`.
That `./`-relative path resolves against **the repo running the workflow** — i.e. *this* project repo,
which does not contain that action. There are exactly two ways to reuse it from another repo:

- **Option A (chosen): check FABulous out as the workspace root.** The first step is
  `actions/checkout` with `repository: FPGA-Research/FABulous`, `ref: 4a2047b`. The workspace then
  holds FABulous's whole tree including `.github/actions/`, so `uses: ./.github/actions/prepare_nix_environment`
  resolves verbatim and `nix develop` / `hashFiles('flake.nix','flake.lock')` operate against the root
  where `flake.nix` actually lives. No path surgery; pinned to the action exactly as published at the ref.
  This project's own files are not needed in the smoke jobs (the smoke validates FABulous, not our RTL).
- **Option B (fallback): inline** the composite's steps (`nixbuild/nix-quick-install-action@v34` with
  the FOSSi `nix_conf`, disk-free, `nix-community/cache-nix-action@v7`, warm `nix develop`) with explicit
  `working-directory` on a FABulous subdir and hand-corrected `hashFiles` paths. More bug surface, and
  the `nix_conf` must be reproduced exactly or the interactive flake-config prompt returns.

**Suggested guide edit:** in §3a/§7, state that `prepare_nix_environment` is repo-local and that a
consumer reuses it by checking FABulous out as the workspace root (Option A), or inlines it (Option B).
As written, "mirror this action" reads as if a `uses:` reference would just work.

### A2. Plain `nix develop` is correct — no `--accept-flake-config` needed *(guide nuance)*

The guide (§3a, §4) shows `nix --accept-flake-config develop`. In the composite-action CI path that flag
is unnecessary: the action's `nix_conf` installs the FOSSi cache as a **globally trusted** substituter
(`substituters = … nix-cache.fossi-foundation.org` + `extra-trusted-public-keys = …`), so the flake's
declared cache is already accepted and `nix develop` neither prompts nor rebuilds from source. Upstream's
own `nix-env.yml` uses plain `nix develop` for this reason. The workflow follows upstream.
`--accept-flake-config` remains the right call for an **interactive** clean machine that has *not*
preconfigured the cache (the guide's primary audience), so the guide is not wrong — but it should note
that the CI/composite path does not need it.

### A3. `iverilog` is an extra system package, not in the Nix devshell by default *(confirmed, minor)*

Per `pytest_testing.yml` (`additional_system_packages: iverilog`) and guide §1/§3b, the simulation/test
path needs `iverilog` installed separately. The optional `uv-lean-path` job installs it via `apt`. The
Nix devshell provides `nvc`/`ghdl` (and the guide's §5 sim strategy is tool-agnostic via cocotb `SIM=`),
so T0/T1 do not need `iverilog`; only the uv/pytest path does. Matches the guide — recorded for completeness.

### A4. Pin mechanics: tag + commit, with a guard *(reproducibility hardening)*

The guide pins `v2.0.0b5 (commit 4a2047b)`. For a reproducibility task, the workflow checks out the
**full 40-char commit SHA** `4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a` (`env.FAB_REF`) and adds a guard
step asserting `git rev-parse HEAD` starts with it **and** `git describe --tags` reports `v2.0.0b5`. A
moved tag or wrong ref fails fast. `fetch-depth: 0` is required so `git describe` sees tags.
**Gotcha (recorded):** `actions/checkout` only treats `ref` as a commit when it is the **full** SHA — a
short SHA like `4a2047b` is interpreted as a branch/tag name and may not resolve, failing at checkout
*before* the T0 gate runs. **Suggested guide edit:** for CI, pin to the full commit SHA (not only the
short SHA or the mutable tag).

### A5. T2 mirrors *tile hardening*, which legitimately runs sky130A — do not conflate with fabric stitching

The guide's caveat ("upstream skips sky130A — will get kill by github") applies to **`gen_fabric_macro`
(fabric stitching)**, *not* to **`gen_all_tile_macros` (tile hardening)**. Upstream's nightly
`gds-flow-ci.yml` runs sky130A in the **tile-hardening** matrix and only drops sky130A from the
**fabric-stitching** matrix. So T2 (sky130A tile hardening, `workflow_dispatch`-only, not a gate) mirrors
a real upstream job; the workflow does **not** attempt sky130 fabric stitching. The guide already states
this in §4-T2 vs the §4 blockquote; this note just makes the distinction explicit for the CI reader.

### A6. T1 is REQUIRED — it is the minimum FABulous *functionality* smoke *(policy)*

T0 only proves the Nix toolchain *starts*; it exercises no FABulous logic. **T1 (fabric generation)
is therefore a required hard gate in the `smoke` job** — it is the first step that runs real FABulous
functionality (CSV parse → switch-matrix generation → tile assembly → fabric stitching). T1 should be
demoted to best-effort *only if an actual CI run shows it is too slow/flaky on a stock runner*; no such
run has happened yet, so it is required. T2 (sky130 tile hardening) remains optional/`workflow_dispatch`
and non-gating; the `uv-lean-path` job remains optional/non-gating.

### A7. T1 verifies specific *generated* (non-template) artifacts — exit 0 is not enough *(hardening)*

`run_FABulous_fabric` can exit 0 without writing the generated RTL, so the gate asserts the specific
generated outputs exist and are non-empty, plus a content sanity check (the fabric top must contain a
Verilog `module`). Filenames are **pinned from v2.0.0b5 source, not guessed**:

| Artifact | Path checked | Source of the name |
|----------|--------------|--------------------|
| Fabric top (stitched) | `test_project/Fabric/eFPGA.v` | `do_gen_fabric` writes `Fabric/{fabric.name}.{ext}`; `fabric.name` default `"eFPGA"` (`fabulous/fabric_definition/fabric.py:98`) |
| Logic-tile top | `test_project/Tile/LUT4AB/LUT4AB.v` | `do_gen_tile` writes `Tile/{t}/{t}.{ext}` (`fabulous/fabulous_cli/fabulous_cli.py`) |
| Switch matrix | `test_project/Tile/LUT4AB/LUT4AB_switch_matrix.v` | `do_gen_switch_matrix` writes `Tile/{t}/{t}_switch_matrix.{ext}` |

These are the **minimum meaningful** check: the fabric top proves end-to-end stitching ran; the tile top
+ switch matrix prove per-tile generation (the core CSV→RTL synthesis) actually executed rather than just
scaffolding being copied. `LUT4AB` is the canonical logic tile in the default fabric (`fabric.csv` Tile
list + `Tile/LUT4AB/` in the template). The project template ships only `.csv`/`.list` and primitive
subcells in these directories — never `LUT4AB.v`, `LUT4AB_switch_matrix.v`, or `eFPGA.v` — so their
presence is positive evidence of generation. Corroborated by `quickstart.md` §5 ("Tile RTL files are in
`demo/Tile/`", "Fabric RTL file is in `demo/Fabric/`").

### A8. Default writer is Verilog (`.v`), but the v2.0 sim default is NVC/GHDL (VHDL) *(hidden assumption)*

`create-project` defaults to **Verilog** (`helper.create_project(lang=HDLType.VERILOG)`), so generated
files are `.v` and the artifact gate keys on `.v`. Note the split: the decision doc records the v2.0
*simulation* default as **NVC/GHDL**, which are **VHDL** simulators (#714). So the default *generated HDL*
(Verilog) and the default *bundled simulator* (VHDL-oriented) differ; cocotb's `SIM=`/tool-agnostic
strategy (guide §5) is what bridges them. A project created with `--writer vhdl` would emit `.vhdl` and the
artifact paths above would need the `.vhdl` extension. **Suggested guide edit:** state that `create-project`
defaults to the Verilog writer (`.v`) and call out the Verilog-gen / VHDL-sim-default split explicitly.

### A9. Scope call: full upstream pytest/cocotb suite is out of scope

`pytest_testing.yml` is an 8-way `pytest-split` matrix with a 70% `--cov=fabulous` code-coverage gate —
that replicates upstream CI of the Python tool, not this project's setup smoke. The workflow includes only
a minimal `uv run FABulous --version` (validating guide §3b's lean path); a fuller pytest/cocotb run is
deferred, consistent with guide §5 ("constrained-random / functional coverage deferred").

### A10. Workflow shape (how the guide's tiers map to gates)

- **T0 (required gate):** `FABulous/openroad/yosys/fab-yosys` version-checks in the Nix devshell — job
  fails if any fail.
- **T1 (required gate):** fabric generation + generated-artifact verification (A6/A7) in the same job,
  reusing the warm devshell. A hard gate — it is the minimum FABulous functionality smoke.
- **uv-lean-path (optional, non-gating):** `uv sync` + `FABulous --version`.
- **T2 (optional, dispatch-only, not a gate):** sky130A tile hardening, `timeout-minutes: 360`, upstream
  manufacturability parser reused verbatim.

---

## B. Post-first-CI-run findings (to be filled after the user pushes the branch)

> Fill these in from the first Actions run on `feature/2-fabulous-v2-smoke-ci` / the PR.

- [ ] **T0 result:** green/red; versions printed for FABulous / yosys / openroad / fab-yosys.
- [ ] **Nix setup time:** cold vs warm (cache-nix-action) store-restore timing; any disk-space pressure.
- [ ] **FOSSi cache:** confirmed substituter hit (tools fetched, not rebuilt from source)?
- [ ] **T1 result + timing:** did fabric generation complete on a stock runner? wall-clock. Did the
      artifact gate pass — were `Fabric/eFPGA.v`, `Tile/LUT4AB/LUT4AB.v`, `Tile/LUT4AB/LUT4AB_switch_matrix.v`
      produced at the expected paths/extension (or did the real tree differ, e.g. `.vhdl`)? If T1 proves
      too slow/flaky on a stock runner, this is where we record evidence to demote it to best-effort.
- [ ] **uv-lean-path:** did `uv sync` + `FABulous --version` succeed; time; any extra system packages needed.
- [ ] **T2 feasibility:** on `workflow_dispatch`, did sky130A tile hardening finish within `timeout-minutes`?
      wall-clock; Antenna/LVS/DRC pass counts; or document why infeasible on GitHub-hosted runners.
- [ ] **Improvised steps:** anything added that the guide does not state → fold back into §A and the guide.
- [ ] **Recommended guide edits:** consolidated list (A1, A2, A4, A8 at minimum) for a follow-up `docs` PR.
