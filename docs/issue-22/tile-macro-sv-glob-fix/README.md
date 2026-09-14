# Tile-macro flow `.sv`-file-discovery fix

The `BTS` tile (binary-stochastic-converter, issue #22 v1 hardening) now hardens clean on sky130A:
Antenna/LVS/DRC all pass, via the official FABulous / LibreLane flow.

- **[root-cause.md](root-cause.md)** — full diagnosis, evidence, fix, and post-fix validation.
- **[patches/tile_macro_flow-include-sv-files.patch](patches/)** — the fix (tracked; the FABulous
  checkout is gitignored). Globs `**/*.sv` alongside `**/*.v` when building `VERILOG_FILES` for the
  tile-hardening flow. +5/−2; applies cleanly on `v2.0.0b5`.
- **[apply-fix.sh](apply-fix.sh)** — `apply-fix.sh <FABulous-checkout>` (idempotent).

## Reproduce
```sh
cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5 (4a2047b)
../../docs/issue-22/tile-macro-sv-glob-fix/apply-fix.sh .
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  FABulous --project-dir fabric_btos_only_proj run "gen_tile_macro BTS"
'
# => Report Manufacturability: Antenna/LVS/DRC Passed
```

## One-line root cause
`FABulousTileVerilogMacroFlow` built `VERILOG_FILES` for the tile-hardening flow by globbing `**/*.v`
only, silently dropping `Tile/BTS/FABulous_binary_stochastic_converter_sync.sv` (genuine SystemVerilog,
not a misnamed `.v`). `BTS.v` instantiates that module, so `Verilator.Lint` failed `MODMISSING` at
step 1, before floorplan/P&R. The synthesis path already reads `.sv` correctly, so this only surfaced
on the first custom-tile GDS harden. Fix: glob `**/*.sv` too.
