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

## B. First-CI-run results (run #1 — cold cache)

**Run:** Actions run `27186515258` (PR #5, `pull_request` on `feature/2-fabulous-v2-smoke-ci`),
ubuntu-latest. **Result: `smoke` job GREEN** (T0 + required T1 both passed). 2026-06-09.

### Per-step timing (run #1, cold)

| Step | Duration | Note |
|------|----------|------|
| Checkout FABulous @ full SHA + reproducibility guard | ~10 s | guard passed (HEAD `4a2047b…`, `git describe` = `v2.0.0b5`) |
| **Prepare Nix environment** | **~3262 s (≈54 min)** | dominates wall-clock; see cache analysis below |
| **T0** toolchain present (required) | **7 s** | |
| **T1** fabric generation (required) | **19 s** | pure Python RTL generation — trivially fast |
| **T1** artifact verification (required) | **<1 s** | |

**Total wall-clock ≈ 55 min**, of which **~98 % is the one-time cold Nix build**; actual FABulous
functionality (T1) is **19 s**.

### ✅ T0 result (PASS)
Printed in the devshell: `FABulous CLI 0.0.0`, `Yosys 0.62` (`yosys --version`), and
`fab-yosys -m ghdl -p help` listed the `ghdl` + `synth_fabulous` plugins (Yosys 0.65). `openroad -version`
ran clean (step exit 0). **Finding:** `FABulous --version` reports **`0.0.0`** (version not stamped in the
build) — so the **checkout SHA/tag guard is what actually pins the ref**, not the tool's self-report. The
guide should not suggest verifying the version via `FABulous --version`.

### ✅ T1 result (PASS) — artifact paths were correct
The pinned artifact paths matched the real v2.0.0b5 output exactly:
```
OK: test_project/Fabric/eFPGA.v (12792 lines)
OK: test_project/Tile/LUT4AB/LUT4AB.v (2299 lines)
OK: test_project/Tile/LUT4AB/LUT4AB_switch_matrix.v (4278 lines)
T1 artifact verification passed
```
Default writer is Verilog (`.v`) as predicted (A8); the fabric top is a real 12.8k-line netlist. T1 is
**fast (19 s)** and stays a **required** gate — no evidence it is too slow/flaky (the slowness is entirely
in environment prep, not in FABulous).

### Nix setup time + FOSSi cache (the real cost) — *hidden assumption surfaced*
The `Prepare Nix environment` step was a **mix of cache hits and source builds**: **507** `copying path …
from nix-cache.fossi-foundation.org` (cache hits) **+ 252** `building '/nix/store/…drv'` (source builds).
The FOSSi cache served the heavy base but **not the exact pinned versions** in v2.0.0b5's `flake.lock` —
source-built packages included `ghdl-bin-6.0.0` (cache had `5.1.1`), `klayout-0.30.8`, `nextpnr-unstable`,
`fab-yosys`, the `openroad-…-python3-env` wrapper, and FABulous's own wheels (`fabulous-bit-gen`,
`fabulous-fasm`). Those 252 builds are why run #1 (~54 min) **exceeded upstream `nix-env.yml`'s own
partial-cold baseline (~25 min)** and warm baseline (2–4 min).

**Self-healing — DID NOT happen on run #2; root cause found (run #2).** The store cache was **never
saved**: run #1's `Post Prepare Nix environment` took ~1 s and emitted only
`##[warning] Resource not accessible by integration - …/actions/cache`, with no upload. Confirmed via the
REST API: repo Actions caches **`total_count: 0`**. Consequently **run #2 (`27188827744`) was cold again**
and re-paid the full ~54-min build. **Cause:** `cache-nix-action@v7` (inside `prepare_nix_environment`)
saves/purges the store via the Actions cache **REST API**, which requires **`actions: write`** — but the
workflow granted only `permissions: contents: read` (mirrored from upstream `nix-env.yml`). **Fix applied:**
add `actions: write` to the workflow `permissions`. **Caveat (still open):** the composite caps the saved
store at `gc-max-store-size-linux: 10G`; if the EDA closure exceeds that, even a *saved* cache may not fully
warm subsequent runs. **Suggested guide edit:** state that (a) the first clean Nix bring-up is ~tens of
minutes (cold, with some source builds), not "minutes"; and (b) a consumer mirroring the composite **must
grant `actions: write`** or the store cache never persists and every run is cold.

### uv-lean-path (non-gating): two sequential failures, both fixed
- **Run #1:** `astral-sh/setup-uv@v8` failed to resolve in ~3 s (*"unable to find version `v8`"*) — the
  action publishes **no floating `v8` major alias** (highest is `v7`; latest release `v8.2.0`). **Fix:** pin
  the exact release `@v8.2.0`. *(Lesson: don't assume a `vN` major alias exists for a marketplace action.)*
- **Run #2:** with `setup-uv` resolved, **`uv sync` failed: `ModuleNotFoundError: No module named 'tkinter'`**
  — the FABulous Python env needs the `python3-tk` system package. **Fix:** add `python3-tk` to the apt
  install (alongside `iverilog`). **Suggested guide edit:** §3b's uv path needs `iverilog` **and**
  `python3-tk` as extra system packages.

### Cache persistence — FIXED and confirmed (run #3, `27189437632`)
With `actions: write` added, run #3's `Post Prepare Nix environment` **saved the store cache**: the purge
step now succeeds (no "Resource not accessible by integration"), and the repo's Actions caches went
**`total_count: 0 → 4`** — the Nix store cache `nix-Linux-c4b7f70b…` persisted at **3.01 GB compressed**
(uncompressed store **9.36 GB**, just under the composite's `gc-max-store-size-linux: 10G` cap) under both
`refs/pull/5/merge` and `refs/heads/feature/2-fabulous-v2-smoke-ci` (plus the small `setup-uv` cache). Run #3
itself was still cold (~54 min) because it created the cache; the warm benefit lands on the next run.
**Caveat:** the store is 9.36 GB against a 10 GB cap — close, so future closure growth (or a heavier PDK)
could exceed it and force cold runs again.

### Still pending
- [ ] **Warm restore (run #4):** confirm the saved store restores and drops `Prepare Nix environment` to
      single-digit minutes. *(Triggered by the commit recording this section.)*
- [x] **uv-lean-path green (run #3, `27189437632`):** ✅ with `python3-tk` the job is green in **35 s** —
      `Resolved 109 packages`, `Installed 106 packages`, `FABulous CLI 0.1`. (Note: uv reports `0.1`, the
      Nix devshell reports `0.0.0` — different build provenance; neither reflects the `v2.0.0b5` tag, so the
      checkout guard remains the real pin.)
- [ ] **T2 feasibility:** trigger sky130A tile hardening via `workflow_dispatch`; record wall-clock and
      Antenna/LVS/DRC counts, or document infeasibility within `timeout-minutes: 360`.
- [ ] **Recommended guide edits:** consolidated list — A1, A2, A4, A8, plus run-#1/#2 findings (FABulous
      reports `0.0.0`; first cold Nix bring-up is tens of minutes with source builds; mirroring the Nix
      composite needs `actions: write` for cache persistence; uv path needs `python3-tk`) — for a follow-up
      `docs` PR.

### Triage note (carried): if a future run fails, do not reflexively weaken T1
Diagnose first as one of: real guide/setup bug · incorrect artifact-path assumption · FABulous v2.0.0b5
behavior mismatch · GitHub runner resource/time issue. Run #1 evidence shows T1 itself is 19 s, so a future
red is far more likely an environment/runner issue than a T1-functionality problem.
