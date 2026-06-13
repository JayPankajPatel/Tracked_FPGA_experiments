# Hardened Stochastic Computing Blocks for FPGA Fabric

## Goal

This project designs and evaluates silicon-hardened stochastic computing blocks for integration into a custom FPGA fabric.

The objective is to create hardened blocks that can be embedded into the fabric to accelerate workloads where stochastic computing may offer advantages in power, area, or throughput.

The target process is the open-source SkyWater 130nm PDK.

Primary target workloads include:

- Stochastic modeling
- Image processing
- AI inference
- Other FPGA-suitable workloads where stochastic computing may be competitive

The current priority is experimentation and simulation before committing to a specific hardened block architecture or fabric integration strategy.

The long-term goal is to move from simulation and RTL prototypes toward FABulous/OpenFPGA fabric integration, LibreLane/OpenLane physical implementation, and eventual tapeout of the custom FPGA fabric containing these hardened blocks.

## Tools

Primary tools:

- FABulous FPGA
- LibreLane
- OpenFPGA
- OpenLane
- SkyWater 130nm open-source PDK
- GitHub Issues, Projects, Discussions, and Pull Requests
- GitHub Copilot or other coding agents for review, implementation support, and debugging
- Supporting simulation, synthesis, and verification tools

## Useful Directories

- `~/Repos/Tracked_FPGA_experiments/`

Primary working repo for this project. Use this repo as the tracked home for stochastic block experiments, fabric integration work, documentation, branches, issues, and pull requests.

- `~/wiki/fpga/`
- `~/wiki/fpga_stochastic_blocks/`
- `~/wiki/fpga_tapeout/`

`~/wiki/fpga_stochastic_blocks/` is the durable wiki namespace for this project. Use its index as the launchpad for reusable architecture notes, experiment results, decision logs, handoffs, and toolchain lessons.

`~/wiki/fpga/` and `~/wiki/fpga_tapeout/` contain previous FPGA and tapeout work. They may imply an architecture direction, but the current project should validate assumptions through simulation and experiments before implementation.

- `~/Repos/`

Contains local work and experiments involving OpenFPGA, FABulous, OpenLane, LibreLane, and related tooling. Treat this as supporting context, not the main project tracker.

## Project Structure

```text
.
├── CLAUDE.md
├── docs
├── FABulous_work
├── HANDOFF.md
├── Librelane_work
├── README.md
└── Stocastic_Blocks
```

- `CLAUDE.md`: Initial instruction file.
- `docs/`: Setup, teardown, usage notes, fixes, and project documentation.
- `FABulous_work/`: Fabric definition, generation work, clean FABulous checkouts/worktrees, local FABulous environments, generated demo projects, and smoke-test workspaces for this project. Do not use `/home/jay/Repos/FABulous` as the working environment for this project.
- `HANDOFF.md`: Running project log. Read this before starting a session and update it at the end. It should describe project state, changes made, open questions, and next actions.
- `Librelane_work/`: ASIC implementation and flow work targeting SkyWater 130nm.
- `README.md`: General project overview. Currently sparse, but should be populated over time.
- `Stocastic_Blocks/`: RTL, simulations, tests, and supporting files for stochastic computing block development.

Note: `Stocastic_Blocks` appears to use the misspelled directory name currently present in the repo. Consider renaming it to `Stochastic_Blocks` early if scripts and references have not yet accumulated.

## Project Tracking

Use GitHub tracking to make experiments, decisions, failed attempts, and implementation changes visible and recoverable instead of spread across multiple repos and session logs.

Use GitHub Issues to track concrete work items, experiments, bugs, and architecture questions.

Use GitHub Discussions for open-ended design conversations that are not ready to become implementation tasks.

Use GitHub Projects to organize issues and pull requests by status, priority, milestone, and topic.

Use Pull Requests to connect branches, commits, reviews, and completed issues.

Recommended labels:

- `rtl`
- `simulation`
- `fabric`
- `librelane`
- `sky130`
- `docs`
- `experiment`
- `architecture`
- `blocked`
- `needs-review`

Recommended milestones:

- `stochastic-block-v0`
- `fabric-integration-v0`
- `sky130-hardening-pass`
- `tapeout-readiness`

Recommended workflow:

1. Every real task starts as a GitHub issue.
2. Every code or doc change happens on a branch.
3. Every branch normally references the related GitHub issue number.
4. Every branch becomes a pull request.
5. Every pull request links back to the issue.
6. `HANDOFF.md` records session state and next actions.
7. GitHub Projects shows board-level status.
8. Durable findings are promoted into `~/wiki/fpga_stochastic_blocks/`.

## Reference Order

Prefer checked-out project documentation and local source files before relying on general model knowledge.

Use references in this order:

1. Documentation, source files, scripts, configs, examples, and `HANDOFF.md` in the current repo.
2. Documentation, source files, scripts, configs, and examples in checked-out dependency/tool repos, especially FABulous, OpenFPGA, OpenLane, LibreLane, and SkyWater PDK repos. Treat `/home/jay/Repos/FABulous` as read-only reference context only; it may contain local Docker/Nix/experiment state that should not define this project's setup.
3. Current project wiki notes in `~/wiki/fpga_stochastic_blocks/`, starting with `~/wiki/fpga_stochastic_blocks/index.md`.
4. Relevant reusable notes in `~/wiki/fpga/` and `~/wiki/fpga_tapeout/`.
5. Official upstream documentation found through search.
6. General trained model knowledge only as a fallback.

When tool behavior, API behavior, PDK details, commands, or software versions may have changed, verify with local checked-out docs or official documentation instead of relying on memory.

If local checked-out docs conflict with external docs, prefer the local docs for the version actually present on disk unless there is evidence they are stale or incorrect.

## Long-Term Knowledge Capture

Use `HANDOFF.md` for current repo and session state.

Use `~/wiki/fpga_stochastic_blocks/` for durable knowledge specific to this project:

- architecture notes
- decision logs
- experiment results
- reusable lessons
- toolchain notes
- durable handoff snapshots

Use `~/wiki/fpga_tapeout/` for reusable tapeout, SkyWater 130nm, FABulous, LibreLane, OpenLane, OpenROAD, timing, PDN, LVS, DRC, and HPC lessons that should help future projects.

Promote important findings from `HANDOFF.md` into the wiki when they become reusable. Do not let `HANDOFF.md` become the only archive of important knowledge.

## Success Criteria

Prefer measurable progress over broad exploration.

Useful outputs include:

- RTL prototypes with testbenches
- Simulation results with documented metrics
- Synthesis or implementation reports
- Area, power, timing, or routing comparisons
- Clear architecture decisions with tradeoffs recorded
- Reproducible commands and setup notes

## Validation

When making technical changes, run the smallest relevant check available.

Examples include:

- RTL simulation
- linting
- synthesis smoke test
- documentation link or path check
- reproduction command from `docs/` or `HANDOFF.md`

If validation cannot be run, state why and record the missing check.

## Public Repository Hygiene

Assume this repo may become public.

Do not add secrets, private credentials, API keys, SSH material, proprietary code, or sensitive logs.

Before adding generated artifacts, logs, layouts, or large tool outputs, consider whether they belong in git.

## Handoff Format

At the end of a session, update `HANDOFF.md` with:

- Date
- Branch
- Current goal
- Changes made
- Commands run
- Results or failures
- Open questions
- Next recommended action

## Planning Guidance

Be direct and evidence-driven. Before committing to an architecture, prefer small simulations, RTL prototypes, synthesis results, and measurable comparisons.

For major architecture decisions, research-heavy questions, or difficult debugging, use an independent review pass or second model as a rubber duck. Capture important conclusions in `HANDOFF.md`, GitHub Issues, GitHub Discussions, or the relevant docs.

AI tools and coding agents do not make project decisions by default. Prompt them with clear questions, candidate options, expected tradeoffs, and required outputs. For nontrivial decisions, require both an optimistic pass and a pessimistic pass before accepting the recommendation.

### Optimistic / Pessimistic Rubber-Ducking

For research-heavy work, toolchain choices, architecture decisions, external dependencies, or any path based on prior experiments, use an explicit two-pass review before writing implementation docs or code.

The goal is to prevent convenient evidence from becoming trusted infrastructure too early.

Run both passes:

1. **Optimistic pass**
   - Argue why the proposed path should work.
   - Identify evidence that supports it.
   - Identify what can be reused from official docs, upstream workflows, local experiments, or prior project notes.
   - State the fastest useful validation path.

2. **Pessimistic pass**
   - Argue why the proposed path may be wrong.
   - Identify untrusted dependencies, stale docs, accidental local state, hidden assumptions, maintenance risk, missing outputs, or reproducibility gaps.
   - Distinguish official upstream sources from prior art, experiments, personal repos, and local machine history.
   - State what evidence would falsify the plan.

After both passes, reconcile them into:

- default recommendation
- fallback option
- evidence still missing
- minimum experiment or health check
- explicit non-goals
- what must not be copied, trusted, or adopted yet

Important rule: **working prior art is evidence, not authority.** If an old local experiment or third-party repo worked once, use it to learn what to check, not as a default dependency. Official docs, pinned upstream sources, and reproducible validation should define the project path unless there is a deliberate documented decision to adopt something else.

Useful architecture review prompt structure:

```md
Evaluate these candidate approaches:

1. Option A
2. Option B
3. Option C

For each option, analyze:

- Area cost
- Power implications
- Routing and integration cost
- Statistical or functional quality
- Verification complexity
- Failure modes or hidden assumptions

Then argue against your preferred option.

End with:

- Recommended first prototype
- Minimum RTL experiment
- Simulation metrics to collect
- Reasons this recommendation might be wrong
```

## GitHub Copilot and Coding Agents

GitHub Copilot or other coding agents may be used to summarize issues, discussions, pull requests, and repository context. They may also be used as rubber ducks for architecture review, debugging, and experiment planning.

When assigning work to Copilot or another coding agent:

1. Create a clearly scoped issue.
2. Include the goal, relevant files, expected output, and validation steps.
3. Require the agent to work on a feature, fix, or update branch.
4. Require a pull request for review.
5. Do not allow the agent to merge or push to `main`.

Copilot and coding agent output must be reviewed by the user before being treated as correct.

## Tone

Use a professional engineering style:

- Say the most important thing first.
- Be concise.
- Prefer objective, scannable updates.
- Use concrete evidence, commands, files, and results where possible.

## Version Control

Only the user may push to `main`.

Never commit directly to `main` and never push directly to `main`.

Use short-lived branches with one of these prefixes:

- `feature/` for new functionality, experiments, or architecture additions.
- `fix/` for bug fixes, broken flows, or incorrect behavior.
- `update/` for documentation, cleanup, dependency updates, or non-behavioral changes.

Branch names should normally include the related GitHub issue number:

- `feature/12-lfsr-stochastic-generator`
- `fix/18-librelane-config-path`
- `update/24-docs-project-structure`

Use labels on GitHub Issues and Projects instead of encoding labels into branch names.

Before starting work:

1. Check `git status`.
2. Confirm the current branch.
3. Pull or fetch the latest changes when appropriate.
4. Create or switch to a feature, fix, or update branch.
5. Do not overwrite or revert user changes unless explicitly requested.

During work:

- Commit meaningful, working changes.
- Keep commits focused.
- Use clear commit messages.
- Prefer rebasing over merging when bringing a branch up to date.
- Do not rewrite shared branch history unless explicitly approved.
- If a conflict occurs during rebase, pull, or push, stop and let the user handle the conflict.
- Do not attempt to resolve merge or rebase conflicts unless explicitly instructed.

At the end of a session:

1. Update `HANDOFF.md`.
2. Run relevant checks if available.
3. Commit completed work.
4. Rebase on the latest target branch if needed.
5. If a conflict occurs during rebase, pull, or push, stop and let the user handle it.
6. Push the working branch only if it can be pushed cleanly.
7. Do not push directly to `main`.
