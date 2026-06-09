# FABulous Version / Ref Decision

**Issue:** #1 — Choose FABulous version/ref for this project
**Branch:** `feature/1-choose-fabulous-version`
**Date:** 2026-06-08
**Status:** ⏳ **Recommendation PENDING USER SIGN-OFF** (evidence complete; final ref is the user's call)
**Canonical upstream:** `https://github.com/FPGA-Research/FABulous` (the older `FPGA-Research-Manchester/FABulous` URL redirects here)

---

## TL;DR

**Recommended default ref: `v2.0.0b5`** (latest tagged release), *pending sign-off*.

The decision is fundamentally a **timeline choice**, not a quality ranking:

- **Adopt `v2.0.0b5` now** — accept beta status to align with where all active development, multi-PDK support, and the production-GDSII framing live. Avoids a forced migration later.
- **Stay on stable `v1.3.1`** — the only non-prerelease tag; fully adequate for near-term RTL / simulation / fabric-generation work; migrate to v2.0 when the GDS / tapeout phase actually begins.

`main` is **not** recommended as a tracked ref (moving target; violates upstream's "use tagged releases" guidance). If used at all, pin a commit: `main@20d9df6` (HEAD on 2026-06-08).

> **Headline risk (read before signing off):** the project's existing *known-good* sky130 hardening backend is an **external** stack (`mole99/librelane_plugin_fabulous` 1.10.2 + `mole99/fabulous-tiles` + LibreLane v3.0.0), decoupled from the FABulous tool. v2.0.0b5 artifact compatibility with that backend is **unverified**, and "FABulous built-in v2.0 GDS flow vs. external plugin backend" is an **open decision this issue does not resolve.**

---

## 1. Local checkout state (context only — NOT the reference setup)

Per the issue, recorded only as context; its dirty/Nix state must **not** define the project setup.

- Path: `/home/jay/Repos/FABulous` (read-only reference only)
- Detached at tag `v2.0.0b4`, HEAD `b857480`
- Remote: `https://github.com/FPGA-Research-Manchester/FABulous` → redirects to `FPGA-Research/FABulous`
- Dirty: 6 modified files including `flake.lock` and `docs/uv.lock` (local experiment/Nix state)

This checkout is a `v2.0.0b4` beta, one release behind the latest prerelease. It is not evidence for any version's suitability.

## 2. Candidate-ref landscape (GitHub evidence)

`gh release list` / `gh api .../tags` (as of 2026-06-08):

| Ref | Type | Date | Commit pin |
|-----|------|------|-----------|
| `v1.3.1` | **Latest** (stable, non-prerelease) | 2025-10-30 | tag `v1.3.1` |
| `v2.0.0b4` | Pre-release (= local checkout) | 2025-12-01 | `b857480` |
| `v2.0.0b5` | Pre-release (newest tag) | 2026-05-13 | `4a2047b` |
| `main` | Default branch (moving) | pushed 2026-06-08 | `20d9df6` |

Commit distance (`gh api .../compare`): `v1.3.1→v2.0.0b4` = **253**; `v1.3.1→v2.0.0b5` = **377**; `v2.0.0b4→v2.0.0b5` = **124**; `v2.0.0b5→main` = **55**. All strictly ahead (no divergence). `v2.0.0b5` therefore **strictly dominates** the local `v2.0.0b4` (superset + 124 commits, including the GDS-flow CI and its fixes).

## 3. Comparison table

Stable-release confidence and beta/dev feature availability are kept as **separate axes** (they pull in opposite directions here):

| Axis | `v1.3.1` (stable) | `v2.0.0b4` (local) | `v2.0.0b5` (rec.) | `main` |
|------|-------------------|--------------------|--------------------|--------|
| **Stable-release confidence** | ✅ Highest — the only non-prerelease "Latest" tag | ⚠️ Beta | ⚠️ Beta (but newest, most-fixed) | ❌ Unreleased, moves daily |
| **Beta/dev feature availability** | ❌ v1.x line; lacks the entire v2.0 feature set | ◐ Has "all librelane steps" (#499) but pre-GDS-CI | ✅ Fullest tagged feature set | ✅ +55 commits beyond b5 |
| **Built-in GDS / LibreLane flow** | ❌ None (workflows: `build_docs`, `fabric_gen`, `release_please`) | ◐ Introduced, not yet CI-tested | ✅ `gds-flow-ci.yml`, `gen_all_tile_macros`/`gen_fabric_macro`, LibreLane flows (#500) | ✅ Same as b5 |
| **Multi-PDK / sky130 / PDK handling** | ❌ | ◐ partial | ✅ sky130A + ihp-sg13g2 + gf180mcuD matrix; auto-PDK setup (#606) | ✅ |
| **Fabric generation** | ✅ `fabric_gen` flow | ✅ | ✅ | ✅ |
| **Simulation** | basic | improved | ✅ NVC default + GHDL fallback (#714); flexible sim cmd | ✅ |
| **Timing model** | old | old | ✅ "Timing model V4" (#562); multilayer PDN (#696) | ✅ |
| **Reproducibility** | ✅ fixed tag | ✅ fixed tag | ✅ fixed tag | ❌ unless pinned to a SHA |
| **Honors maintainer "use tagged releases"** | ✅ | ✅ (tag) | ✅ (tag) | ❌ |
| **"Silicon-proven" framing in README** | ❌ absent | ✅ (lineage) | ✅ (lineage) | ✅ (lineage) |

## 4. Verified discriminator: where the GDS/LibreLane/sky130 flow lands

This was **verified against primary sources**, not assumed:

- **`v1.3.1`** CI workflows are `build_docs.yml`, `fabric_gen.yml`, `release_please.yml` — **no GDS/LibreLane workflow**. Its release notes are documentation fixes only; it is a patch on the old v1.x line.
- **`v2.0.0b4`** release notes introduce *"feat: all librelane steps (#499)"* — the integrated LibreLane flow **starts** here, but the GDS-flow CI does not yet exist.
- **`v2.0.0b5`** adds `gds-flow-ci.yml` + `docker-image.yml` and a large body of GDS work: *"Librelane flows and commands (#500)"*, gds helpers/tests (#565/#570/#571), *"add CI for gds-flow (#667)"*, *"auto pdk set up (#606)"*, *"multilayer pdn (#696)"*, LVS/klayout fixes (#593/#671), *"Timing model V4 (#562)"*.
- **`main`** carries the same workflow set as b5.

The integrated FABulous→LibreLane→sky130 GDS flow is therefore a **v2.0-line feature that matures at `v2.0.0b5`**. (Dates line up: b5 released 2026-05-13, the same window as the project's own `librelane-fabulous-*` wiki notes.)

## 5. Maintainer guidance (primary source)

From the upstream README (`v2.0.0b5`):

> **"Active Development — Use Tagged Releases for Production"** … **"For production use, please use [tagged releases](https://github.com/FPGA-Research/FABulous/releases) or reach out to us for further advice."**

Reading: among the candidates, `v1.3.1` and `v2.0.0b5` are both **tagged releases** (the guidance is satisfied by either); `main` is **not**. This is the actual maintainer guidance — note that `~/wiki/fpga_tapeout/mentor-mir-outreach.md` is about an unrelated SJSU applications mentor (Prof. Mir), **not** FABulous maintainer advice, and is deliberately *not* cited as such.

## 6. "Silicon-proven" framing — lineage-level, not ref-level

The README attributes silicon-proven status to the **framework's tapeout history**, not to any candidate ref:

> "silicon-proven through **multiple successful tapeouts** across TSMC 180nm, Skywater 130nm, IHP SG13G2, GF180MCU, and 28nm CMOS" … "### Silicon Proven — validated through **12+ successful tapeouts**" … (disclaimer) "we make no guarantees regarding functional correctness, timing closure, physical design quality, or manufacturing compliance … Silicon-proven status does not imply that FABulous-generated designs can be used without rigorous verification."

So: **the FABulous *framework* is silicon-proven (notably the SOFA series on sky130); the specific candidate refs — including `v2.0.0b5` — are not independently taped out, and v2.0 is explicitly "active development."** The decision doc and any downstream claims must not imply otherwise. (The v1.3.1 README does not even carry the silicon-proven/production-GDSII framing — that story is itself new to the v2.0 line.)

## 7. Recommendation and tradeoffs

**Recommended: `v2.0.0b5`** — on grounds that survive the external-backend finding (§8), in priority order:

1. **It is the latest *tagged* release** → honors the maintainer's "use tagged releases for production" while `main` does not.
2. **It is where active development, multi-PDK, and the production-GDSII framing live** — the project's long-term direction (FABulous→LibreLane→sky130 tapeout) is a v2.0-line story.
3. **It strictly dominates the local `v2.0.0b4`** (= b4 + 124 commits, incl. the GDS-flow CI and fixes) — there is no reason to prefer the older beta.
4. **Adopting now avoids a later migration** across 377 commits of API/CLI churn (v2.0 has breaking renames: `feat!`/`chore!` commits).

**Argument *against* the recommendation (v1.3.1 at full strength):** `v1.3.1` is the only non-prerelease tag and the safest choice for *current* work, which is RTL / simulation / fabric generation — all of which `v1.3.1`'s `fabric_gen` flow supports. If the project's near-term priority is stability over feature alignment, "stay on `v1.3.1`, migrate at the GDS/tapeout phase" is fully defensible and lower-risk **today**. The cost is a larger, later migration and divergence from upstream's active branch.

**Decision axis for sign-off → timeline:** *adopt v2.0 now (accept beta, align with active development)* **vs.** *stay on stable v1.3.1 and migrate when the GDS/tapeout phase arrives.*

## 8. Risks and unknowns

1. **[HEADLINE] Existing-backend compatibility is unverified.** The known-good sky130 hardening backend is external and decoupled from the FABulous tool: `mole99/librelane_plugin_fabulous` 1.10.2 + a `mole99/fabulous-tiles` submodule + LibreLane v3.0.0 (it pins **no** FABulous tool version — confirmed by reading its `flake.nix`/`.gitmodules`). That backend produced a **manufacturability-clean** `LUT4x8_ha` tile (antenna/LVS/DRC all pass) per `~/wiki/fpga_tapeout/decision_logs/librelane-fabulous-known-good-backend-2026-05-16.md`. **Open decision (not resolved here):** continue the external plugin backend, or migrate to FABulous's built-in v2.0 GDS flow. Risk: v2.0.0b5-generated tile/fabric artifacts (switch-matrix CSV, ConfigMem, geometry, Verilog) may not drop cleanly into the `mole99/fabulous-tiles`-based backend; this needs a verification experiment before committing the GDS path.
2. **Beta API churn.** v2.0 carries breaking changes (`feat!`/`chore!` renames, e.g. `getTile` generalization #564, LHQD1 rename, file renames). Any scripts written now must be re-checked against the pinned tag.
3. **Beta, not silicon-proven at this ref.** v2.0's integrated GDS flow has CI manufacturability checks but no published tapeout *through this exact built-in flow* (the silicon-proven lineage predates it).
4. **sky130 fabric-stitch is resource-heavy.** Upstream's own `gds-flow-ci.yml` **skips sky130A for fabric stitching** ("will get kill by github") — relevant to what the follow-up CI can actually run.
5. **`v2.0.0b6`/`v2.1` may land soon.** b5 is 55 commits behind main; a newer tag could supersede this recommendation. Re-evaluate at the next release.

## 9. Evidence index

- GitHub: `gh release list/view`, `gh api .../compare/...`, `gh api .../contents/.github/workflows?ref=<ref>`, `gh api .../contents/README.md?ref=<ref>` on `FPGA-Research/FABulous`.
- Release notes: v1.3.1 (doc fixes); v2.0.0b4 (#499 librelane steps); v2.0.0b5 (#500/#565/#570/#571/#667/#606/#696/#562/#714 …).
- Upstream README @ v2.0.0b5: silicon-proven framing + "use tagged releases" guidance + disclaimer.
- Local wiki (paths only; summarized): `~/wiki/fpga_tapeout/decision_logs/librelane-fabulous-known-good-backend-2026-05-16.md`, `~/wiki/fpga_tapeout/handoffs/librelane-fabulous-container-handoff-2026-05-24.md`, `~/wiki/fpga_tapeout/openlane/fabulous_flat_smoke_2026_05_15.md`, `~/wiki/fpga_tapeout/openlane/fabulous-experiment-repo-migration.md`.

## 10. Decision record (to be completed at sign-off)

- [ ] **Chosen ref:** ________ (`v2.0.0b5` recommended / `v1.3.1` stable-first / other)
- [ ] **Chosen on (date):** ________
- [ ] **Rationale (timeline stance):** ________
- [ ] Setup guide (`docs/fabulous-setup-guide.md`) updated to the chosen ref.
