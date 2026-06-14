# FABulous → GDS Toolchain Bootstrap (sky130A) — Issue #7

**Issue:** #7 — reproducible FABulous-to-GDS toolchain bootstrap.
**Scope:** the **toolchain/bootstrap layer only** — prove the official GDS stack installs, pins, and can *begin* a tile-hardening flow **through synthesis** from a clean environment. Producing a finished GDS macro + manufacturability signoff is **deferred to the follow-up issue**.
**Chosen path:** the **official FABulous `v2.0.0b5` built-in GDS / LibreLane flow** (per issue #1 ref decision + the rewritten #7). The `mole99` external backend is **prior art only** — see the clearly-labeled section at the end; it is not a dependency.

> Status: **bootstrap validated through synthesis locally** on 2026-06-13 (see §Health check). Cold-runner CI confirmation is the remaining step.

---

## 1. Selected path (and why)

The official flow is `FABulous --project-dir <proj> run 'gen_all_tile_macros'`, with the PDK selected in `<proj>/.FABulous/.env`. It is the path FABulous's own nightly `gds-flow-ci.yml` exercises for sky130A tile hardening, it reuses the single FABulous Nix devshell already validated in issue #2 (T0/T1), and it is multi-contributor upstream. `mole99` is treated as prior art (lessons only), per the "working prior art is evidence, not authority" rule.

## 2. Pinned inventory (all reproducible from upstream, no local state)

| Component | Pin | Source of truth |
|-----------|-----|-----------------|
| FABulous | **`v2.0.0b5`** = `4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a` | issue #1 / `docs/fabulous-version-decision.md` |
| LibreLane | **`v3.0.3`** (self-reported) = flake input `github:librelane/librelane` lock-pinned rev **`1e4f4d5b`** | FABulous `flake.lock` |
| nix-eda | **`6.11.0`** = `8f990fb77529` (followed by FABulous) | FABulous `flake.lock` |
| ciel (PDK mgr) | **`>=2.4.0`** (pinned via flake.lock) | FABulous `pyproject.toml` + `flake.lock` |
| **sky130A PDK** | **ciel commit `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`** (OpenLane-format; LibreLane-readable via `pdk_compat`) | resolved by ciel default; **pin explicitly** — see §4 |
| EDA tools | yosys / openroad / nextpnr / ghdl-nvc / klayout / magic / netgen — all from the FABulous devshell | issue #2 T0 |

**Reproducibility caveats (recorded, not blockers):**
- LibreLane is a **floating flake input** (`url` has no ref); reproducibility rests on FABulous's committed `flake.lock` (rev `1e4f4d5b`, which builds/reports as **v3.0.3**). Do not `nix flake update` the project's pin without re-validating. nixpkgs + nix-eda `follow` LibreLane.
- The sky130A PDK commit is **ciel's default** for this pin unless pinned explicitly (§4).

## 3. Clean-environment setup

Requires **Nix with flakes** and the **FOSSi binary cache trusted at the system level** (otherwise the EDA closure source-builds for hours). On this machine that is Determinate Nix with `/etc/nix/nix.custom.conf` adding `nix-cache.fossi-foundation.org` as a trusted substituter — see [[nix-environment-state]] (wiki).

```sh
# under FABulous_work/ (never /home/jay/Repos/FABulous)
git clone https://github.com/FPGA-Research/FABulous.git fabulous-v2
cd fabulous-v2 && git checkout 4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a
nix develop          # builds/fetches the devshell (FABulous + LibreLane v3.0.3 + EDA tools)
```

In CI, reuse issue #2's pattern: check FABulous out as the workspace root, use its `prepare_nix_environment` composite (Nix install + FOSSi cache + disk-free), grant `actions: write` for Nix-store cache persistence.

## 4. PDK setup

FABulous auto-installs/activates the PDK via **ciel** (`fabulous/fabulous_settings.py`): with `pdk` set and `pdk_root` unset for a ciel-supported family, it auto-resolves and enables the PDK. The `pdk_hash` setting pins the exact version (auto-resolved from ciel's default when omitted).

```sh
# in the devshell, from the project dir:
sed -i "s/FAB_PDK=.*/FAB_PDK='sky130A'/" smoke_proj/.FABulous/.env
# RECOMMENDED — pin the PDK commit explicitly (eliminates ciel-default drift):
export PDK_ROOT="$PWD/.pdk"                 # isolated; do not reuse ~/.ciel
export FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71   # FABulous `pdk_hash` setting
```

ciel downloads the PDK (`common`, `sky130_fd_io/pr/sc_hd/sc_hvl`, `ml_xx_hd`, `sram_macros`) into `PDK_ROOT/sky130/sky130A` — a **separate multi-GB fetch, not in the Nix store**. The resolved `8afc8346` is **OpenLane-format**, which LibreLane 3.0.3 ingests via `pdk_compat.py` (this is why synthesis resolves `LIB` and `dfflibmap` succeeds — see §Prior art for the failure mode to avoid).

## 5. Health check — "through synthesis" (bootstrap bound)

The bootstrap health check proves the flow **begins and completes synthesis** (PDK + liberty resolve, cells map through `dfflibmap`), then stops before full P&R/GDS. Commands:

```sh
nix develop --command bash -c '
  FABulous --version            # -> FABulous CLI 0.0.0 (nix-build version fallback)
  librelane --version           # -> LibreLane v3.0.3
  FABulous create-project smoke_proj
  sed -i "s/FAB_PDK=.*/FAB_PDK=\x27sky130A\x27/" smoke_proj/.FABulous/.env
  FABulous --project-dir smoke_proj run "run_FABulous_fabric"
  FABulous --project-dir smoke_proj run "gen_all_tile_macros"   # observe synthesis; stop after
'
```

**Pass criteria:** `Yosys.Synthesis` runs, `DFFLIBMAP` executes **without** "Missing -liberty", `LIB` is non-empty / cells map, and the flow proceeds to `OpenROAD.*` (floorplan). **Finished GDS + manufacturability are NOT required here.**

**Local result (2026-06-13, warm caches):**
- Clone + devshell ready ~51 s; `run_FABulous_fabric` ~41 s; synthesis reached ~3 s into `gen_all_tile_macros`.
- `LibreLane v3.0.3`; sky130A auto-resolved + fetched fresh to `8afc8346` (OpenLane-format).
- `Yosys.Synthesis` → `DFFLIBMAP` (no error) → `OpenROAD.Floorplan` (die 250.24 × 490.96 µm) → GlobalPlacement/CTS. **Through-synthesis: PASS.** No `LIB={}`.

## 6. Cold/warm + disk expectations

- **Nix devshell:** warm ~tens of seconds; **cold ~tens of minutes** (issue #2: ~54 min cold, ~3 min warm; FOSSi cache miss source-builds dominate cold).
- **Nix store:** ~9.36 GB (issue #2) vs the 10 GB GitHub Actions cache cap — **tight**; grant `actions: write` and watch closure growth.
- **PDK:** a **separate** ~few-GB ciel fetch into `PDK_ROOT` (not the Nix store) — cache/time it independently in CI.

## 7. Falsifier status (from the two-agent plan review)

| # | Falsifier | Status |
|---|-----------|--------|
| 1 | two runs resolve different sky130A commits | **Mitigated** — pin `FAB_PDK_HASH=8afc8346` (deterministic, no ciel-default drift) |
| 2 | through-synthesis reproduces `LIB={}` | **FALSE** — synthesis passed, `dfflibmap` clean |
| 3 | Nix store + PDK exceeds 10 GB cache cap | **Open for CI** — PDK is a separate fetch; store near cap; confirm on the runner |
| 4 | `librelane --version` is a dev string, not a tag | **FALSE** — reports `LibreLane v3.0.3` |
| 5 | only local `0fe599b2` makes cell mapping work | **FALSE** — `8afc8346` fetched fresh into an isolated root; `~/.ciel` untouched |

## 8. Prior art (mole99) — lessons, NOT adopted

`mole99/librelane_plugin_fabulous` + `mole99/fabulous-tiles` produced a manufacturability-clean sky130A `LUT4x8_ha` tile in a prior local experiment. **Not a dependency, not trusted infrastructure.** Lessons carried over (to ask better questions, not to copy):
- **Tile-first ramp** before fabric stitching; sky130 manufacturability checks = **antenna / LVS / DRC**; expected macro artifacts = GDS / LEF / netlist / SDC / SPEF / metrics; possible missing macro-level `.lib`.
- **Decisive PDK lesson:** LibreLane reads PDK liberty via `pdk_compat.py` from **OpenLane-format** PDKs. A newer **librelane-format** PDK (sets `CELL_LIBS`) yields `LIB={}` → `dfflibmap` fails. The official flow's auto-resolved `8afc8346` is OpenLane-format, which is why it works. **Do not pin a CELL_LIBS-format sky130A under LibreLane 3.0.3.**
- The mole99 result depended on a PDK commit (`0fe599b2`) taken from local `~/.ciel` — convenient local state, deliberately **not** adopted as the project pin.

## 9. Deferred to the follow-up issue(s)

- Finish **one tile** to a GDS macro + manufacturability (antenna/LVS/DRC) via the official flow.
- Then a **standard example FPGA** fabric (fabric stitching — note upstream skips sky130A fabric stitch on stock runners).
- Macro `.lib`/timing-model generation; timing closure; final signoff.

## 10. References

- `docs/fabulous-version-decision.md`, `docs/fabulous-setup-guide.md`, `docs/fabulous-setup-guide-validation.md`
- `.github/workflows/fabulous-v2-smoke.yml` (issue #2 CI; `t2-sky130-tile-hardening` is the basis for the #7 health-check job)
- Upstream `FPGA-Research/FABulous@v2.0.0b5`: `flake.nix`, `flake.lock`, `.github/workflows/gds-flow-ci.yml`, `fabulous/fabulous_settings.py`
- Official LibreLane documentation (PDK management, flow concepts, outputs)
