# Standard FABulous Example Fabric → sky130A GDSII Baseline — Issue #10

**Issue:** #10 — take the standard FABulous `v2.0.0b5` example fabric through the official
hierarchical GDS flow on sky130A (generate RTL → harden all tile macros → compose/harden the fabric
macro) and record a reproducible baseline.
**Builds on:** #7 (`docs/gds-toolchain-bootstrap.md`) — the through-synthesis bootstrap. #7 stopped at
synthesis; this issue completes the macros and attempts fabric composition.
**Status:** **tile hardening = PASS** (13/13 tiles, manufacturability-clean). **Fabric stitch =
GDSII produced (~52 MB) but signoff fails (1591 LVS errors → `FlowError`); not resource-killed.** See §C.
**Update (#12, 2026-06-14): the §C LVS blocker is RESOLVED — fabric LVS/DRC/Antenna now pass.** Root
cause + fix in `docs/issue-12/root-cause.md` (IO-pin↔terminal overlap in `fabric_io_place.py`; not PDN).

> **Scope note (title vs. body).** Issue #10's title says "no-DSP", but the body was edited to drop
> the DSP-exclusion tasks. FABulous v2.0.0b5 ships exactly **one** example fabric — the
> `create-project` demo — and it **contains a DSP supertile** (`DSP_top`/`DSP_bot` + `N_term_DSP`/
> `S_term_DSP`). "Smallest standard example" therefore = that demo fabric, taken as-is (DSP included).
> The DSP tiles harden as ordinary macros and are part of this baseline. A no-DSP variant would
> require editing `fabric.csv`; it was not pursued (the relaxed body targets the standard demo).

---

## 1. Pinned environment (inherited from #7 — do not drift)

| Component | Pin |
|-----------|-----|
| FABulous | `v2.0.0b5` = `4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a` |
| LibreLane | `v3.0.3` (FABulous `flake.lock` rev `1e4f4d5b`) |
| nix-eda | `6.11.0` |
| sky130A PDK | ciel commit `FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (OpenLane-format) |
| Workspace | `FABulous_work/fabulous-v2` (gitignored); isolated `PDK_ROOT=$PWD/.pdk` (never `~/.ciel`) |
| EDA | yosys 0.62, OpenROAD (`dcf36133`), KLayout/Magic/Netgen — all from the FABulous Nix devshell |

**Machine class (local run):** 24 cores / 29 GB RAM / 1.3 TB free, warm Nix store + warm PDK.

## 2. Exact commands (reproducible)

```sh
cd FABulous_work/fabulous-v2          # pinned checkout 4a2047b
git rev-parse HEAD                    # == 4a2047bbb1ff2a73d2bdb3e9f951d9746cfaa68a
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  export FAB_PDK_HASH=8afc8346a57fe1ab7934ba5a6056ea8b43078e71
  FABulous create-project fabric_baseline_proj
  sed -i "s/FAB_PDK=.*/FAB_PDK=\x27sky130A\x27/" fabric_baseline_proj/.FABulous/.env
  FABulous --project-dir fabric_baseline_proj run "run_FABulous_fabric"   # A: RTL
  FABulous --project-dir fabric_baseline_proj run "gen_all_tile_macros"   # B: tile macros
  FABulous --project-dir fabric_baseline_proj run "gen_fabric_macro"      # C: fabric stitch
'
```

## A. RTL generation — `run_FABulous_fabric`

- **Result:** PASS, ~3.4 s (warm).
- Fabric definition = the **demo template**, byte-identical to upstream
  `fabulous/fabric_files/FABulous_project_template_common/fabric.csv`
  (`sha256 c5f6c3d149e00ac735c72e8ed3bc05ae46de4861ba48821735e874feb7fc2a3e`).
- Fabric: 9 columns × 14 rows; tile types: `LUT4AB`, `RegFile`, `RAM_IO`, `DSP` (supertile
  `DSP_top`/`DSP_bot`), `W_IO`, and the N/S terminator tiles (`N_term_single`, `S_term_single`,
  `*_single2`, `*_RAM_IO`, `*_DSP`). **13 unique hardenable tiles.**
- Generated fabric RTL in `fabric_baseline_proj/Fabric/`: `eFPGA.v`, `eFPGA_top.v`, `eFPGA_Config.v`,
  `ConfigFSM.v`, `Frame_Data_Reg.v`, `Frame_Select.v`, `BlockRAM_1KB.v`, `bitbang.v`, `config_UART.v`,
  `models_pack.v`; per-tile RTL under `fabric_baseline_proj/Tile/<tile>/`.

## B. Tile macro hardening — `gen_all_tile_macros`

- **Result:** **PASS — all 13 tiles hardened to GDS, manufacturability-clean.**
- **Runtime:** **14 min 56 s** wall (warm), sequential; CPU 364% (intra-step parallelism);
  **peak RSS 2.12 GB** (`/usr/bin/time -v`).
- **Manufacturability** (parsed with the upstream/`t2` `Report Manufacturability` Antenna/LVS/DRC parser):

  | Check | Result |
  |-------|--------|
  | Antenna | **13/13 Passed** |
  | LVS | **13/13 Passed** |
  | DRC | **13/13 Passed** |

- **Per-tile artifacts** (`Tile/<tile>/macro/final_views/`): `def`, `gds` (+ `klayout_gds`, `mag_gds`),
  `lef`, `mag`, `nl` (netlist), `pnl` (powered netlist), `odb`, `sdc`, `spef` (3 corners), `spice`,
  `vh`, `metrics.csv`/`metrics.json`.
- **Representative tile die areas (µm²):** LUT4AB 60 413, RegFile 63 913, RAM_IO 60 413, DSP 122 858.

### Caveats (recorded, not blockers)
- **No macro-level Liberty.** `*.lib` count = **0** — the tile flow emits no per-macro `.lib`/timing
  model. Fabric-level STA therefore has no tile timing abstraction; the flow logs
  `'PNR_SDC_FILE'/'SIGNOFF_SDC_FILE' is not defined. Using generic fallback SDC`. Timing is **not
  closed** (explicitly out of scope). This is the gap a later timing pass / `.lib` generation must fill.
- **DRC sign-off rests on KLayout.** 26 warnings `magic__drc_error__count not reported. Magic.DRC may
  have been skipped` (2/tile) — the "DRC Passed" verdict is KLayout DRC; Magic DRC was skipped under
  the FABulous tile `gds_config.yaml` (which also disables tap/endcap + fill insertion, CTS, IR-drop;
  `GRT_ALLOW_CONGESTION: True`). These are FABulous's tile-hardening relaxations, not signoff config.

## C. Fabric composition — `gen_fabric_macro`

**Result: GDSII produced, but flow FAILED at signoff (`FlowError`, rc=1) — a reproducible
*signoff* blocker, NOT the expected resource kill.**

Upstream `gds-flow-ci.yml` **excludes sky130A** from its fabric-stitching matrix ("will get kill by
github"), implying a *resource* limit. On this 24c/29 GB host the composition is **not** resource-killed:

- **Runtime:** **4 min 29 s** wall; CPU 341%; **peak RSS 18.8 GB** (`/usr/bin/time -v`); sampler peak
  total system usage **21.4 GB / 29 GB** — comfortable headroom. So "killed by github" is a **stock
  4 vCPU/16 GB runner** limit, not a fundamental one; a ~29 GB host completes the P&R.
- **Stitched GDSII WAS streamed:** `Fabric/macro/runs/RUN_.../final/gds/eFPGA.gds` (**~52 MB**), plus
  magic/klayout variants. **Fabric die area ≈ 9.76 mm²** (`design__die__area` = 9 755 880 µm²,
  ~3.12 mm/side). The flow reached LEF abstract + GDS streamout + extraction.
- **But signoff failed —** `Checker.LVS`: **1591 LVS errors found** (deferred) → `FlowError`. The
  manufacturability report shows LVS failing and antenna flagged (`has (965) input pin(s) without
  antenna gate`; routed-antenna-violation count = 0); Magic DRC again skipped. LVS report:
  `Fabric/macro/runs/RUN_.../49-netgen-lvs/reports/lvs.netgen.rpt`.

**Interpretation (evidence-bounded).** The stitch is *physically* feasible on adequate RAM, but the
composed fabric does **not pass LVS** under the stock FABulous tile/fabric `gds_config.yaml`. This is
consistent with the §B tile caveats — tiles hardened with relaxed checks, **no macro-level `.lib`**,
and generic fallback SDC — so the fabric-level layout-vs-schematic comparison diverges (1591 errors).
This is recorded as a **reproducible flow/signoff blocker** (exact pins + logs), not setup ambiguity;
root-causing the 1591 LVS errors is follow-up work, not in this issue's scope (no timing/signoff).

> **Acceptance:** both branches are satisfied simultaneously — a stitched GDSII artifact **exists**
> *and* a reproducible blocker (LVS/`FlowError`) is documented with logs.

> **RESOLVED in #12.** The 1591 LVS errors were **not** PDN power islands (the §C.2 prior-art
> hypotheses were the *wrong* lead — zero unmatched nets are power). They were top-level IO pins
> floating off their tile terminals: the no-router fabric flow placed every top BPin on the die edge
> while tiles are 1 µm halo-inset. Fix = place a pin shape over every tile terminal in
> `fabric_io_place.py`. Fabric LVS/DRC/Antenna now pass (`RUN_2026-06-14_08-12-05`). Full write-up:
> `docs/issue-12/root-cause.md`.

### C.1 LVS fingerprint (netgen report)

`Fabric/macro/runs/RUN_.../49-netgen-lvs/reports/lvs.netgen.rpt`:

- **Devices: 151 = 151 (match).** **Nets: 34837 vs 34828 — mismatch by 9.** "Top level cell failed
  pin matching." Disconnected nodes are **inter-tile routing ports** (`E1BEG[*]`, `E1END[*]`,
  `E2BEG[*]` …) on tile cells (RegFile, …), not device-level differences. The 1591 "LVS errors" are
  the per-disconnected-node lines from this small (~9-net) top-level connectivity mismatch.

### C.2 Prior-art fixes to investigate (from `~/wiki`, NOT yet adopted)

The local wiki documents a **prior sky130 top-level FPGA assembly** (OpenLane *classic* + OpenFPGA —
a **different flow** from FABulous `gen_fabric_macro`/LibreLane v3) that hit the **same LVS
signature** and drove it to clean. Treat as **lessons to check, not drop-in fixes** (CLAUDE.md:
"working prior art is evidence, not authority"; config knobs and flow differ):

- **`~/wiki/fpga_tapeout/synthesis/pdn-lvs-fix.md`** — diagnostic fingerprint match: *"identical
  pre-merge device counts, different post-merge counts; the net-count difference ≈ number of
  disconnected power islands."* Our run shows exactly that (151=151 devices, +9 nets). Fix lineage:
  met5 PDN stripes must **cross through** macros (`HPITCH` < smallest macro height), not avoid them.
- **`~/wiki/fpga_tapeout/synthesis/core-ring-lvs-fix.md`** — remaining edge islands fixed by
  `FP_PDN_CORE_RING: 1` + slightly wider die (drove 155→29→**0** unmatched nets). **Caveat:** the
  FABulous sky130A `gds_config.yaml` already uses a dense PDN (`FP_PDN_HPITCH: 30`) and
  `PDN_ENABLE_RAILS: False`, so the FABulous knobs differ — validate before assuming PDN is the cause
  vs. tile **boundary-pin/abstract** connectivity (the disconnected nodes here are *signal* routing
  ports, which also points at the missing macro abstraction).
- **`~/wiki/fpga_tapeout/synthesis/opensta-write-lib-bug.md`** — relevant to §B's **0 `*.lib`**
  finding: an OpenSTA `write_timing_model` bit-width bug rejects generated macro `.lib` in top-level
  assembly. A FABulous-flow analogue is worth checking if/when macro Liberty generation is enabled.
- **`~/wiki/fpga_tapeout/openlane/openlane-macro-error-triage.md`** + `top-level-fpga-assembly.md` —
  decision tree for macro density/IO/timing failures and top-level assembly setup.

**Recommended first diagnostic for the LVS follow-up** (its own issue; out of scope here): confirm
whether the ~9 unmatched nets are power islands (check VPWR/VGND continuity per `pdn-lvs-fix.md`) or
tile boundary-pin connectivity (check tile LEF pin abstraction at the stitch boundary). Do **not**
copy OpenLane-classic config values into the FABulous flow without validating.

## 3. Disk / cache behavior

- **Tile macro outputs:** ~2.7 GB (`fabric_baseline_proj/Tile/`).
- **PDK:** ~2.2 GB in the isolated `PDK_ROOT=$PWD/.pdk` (separate ciel fetch, **not** in the Nix store).
- **Nix store:** ~11 GB (warm). Note the GitHub Actions cache cap is 10 GB — the store alone is over
  it, so CI keeps the store warm via `cache-nix-action` + `actions: write` (see #2); the PDK is a
  separate fetch. (#7 falsifier #3 — confirm cold-runner behavior by dispatching the CI jobs.)
- All run outputs live under `FABulous_work/fabulous-v2/` which is **gitignored** — clean-room intact;
  nothing multi-GB is committed.

## 4. Clean-room CI deliverable

`.github/workflows/fabulous-v2-smoke.yml` (dispatch-only, not gates):
- **`t2-sky130-tile-hardening`** — Tasks A+B on a clean runner (already present; mirrors upstream
  `tile-hardening` + the manufacturability parser used above). Dispatch to confirm cold-runner timing
  + the 10 GB cache cap.
- **`gds-fabric-stitch`** (new, issue #10) — Task C: `needs: t2-sky130-tile-hardening`, downloads the
  hardened `tile-project-sky130A` artifact, runs `gen_fabric_macro` on sky130A with the PDK pinned.
  **Never fails the workflow** — it classifies the outcome (stitched-manufacturability vs the
  documented sky130A resource blocker) and always uploads logs. `actionlint` clean; YAML parses.

## 5. Acceptance-criteria mapping

| Criterion | Status |
|-----------|--------|
| Example fabric selected + RTL captured | ✅ standard demo (sha pinned), RTL in `Fabric/` |
| ≥1 tile GDS macro with antenna/LVS/DRC recorded | ✅ **13/13** tiles, all clean |
| Fabric composition command run → GDSII or reproducible blocker | ✅ **both** — `eFPGA.gds` (~52 MB) **and** LVS/`FlowError` blocker |
| Failures documented as reproducible flow/resource blockers | ✅ §C — 1591 LVS errors, exact pins + logs |
| Runtime / disk / PDK / cache recorded | ✅ §B, §3 |
| Clean baseline for the later DSP issue | ✅ this doc |

## 6. References
- `docs/gds-toolchain-bootstrap.md` (#7 bootstrap, pins, falsifier table)
- `.github/workflows/fabulous-v2-smoke.yml` (`t2-sky130-tile-hardening`, `gds-fabric-stitch`)
- Upstream `FPGA-Research/FABulous@v2.0.0b5`: `.github/workflows/gds-flow-ci.yml`,
  `fabulous/fabulous_cli/fabulous_cli.py` (`do_gen_all_tile_macros` L1421, `do_gen_fabric_macro` L1437)
