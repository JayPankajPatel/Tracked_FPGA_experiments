# Fused SC multiply tile (SCMUL) - fabric files, issue #33

`FABulous_work/` is gitignored, so these are the files that live outside `Stochastic_Blocks/rtl/fused/`.

- `SCMUL.csv`, `gds_config.yaml` - tile definition and standard 246x245 footprint.
- `scmul_test.v`, `top_wrapper_scmul.v` - user design and IO wrapper (a = io[7:0], b = io[15:8],
  rst_n/valid_in/ready_out = io[16..18], valid_out = io[19], product = io[26:20]).
- `scmul_test_tb.v` - fabric testbench, compares the fabric against the RTL cycle for cycle.

Reproduce (from `FABulous_work/fabulous-v2`, pinned v2.0.0b5; do NOT put oss-cad-suite first on PATH
for hardening, its yosys lacks `-y`):

```bash
Stochastic_Blocks/rtl/fused/build_tile_bel.sh fabric_sc_proj/Tile/SCMUL/FABulous_sc_multiply_fused.sv
cp docs/issue-33-fused-tile/gds_config.yaml fabric_sc_proj/Tile/SCMUL/
# generate_custom_tile_config needs an ABSOLUTE tile path, and the tile must NOT be in fabric.csv yet
FABulous --project-dir fabric_sc_proj run "generate_custom_tile_config $PWD/fabric_sc_proj/Tile/SCMUL"
# then add `Tile,./Tile/SCMUL/SCMUL.csv` to fabric.csv
FABulous --project-dir fabric_sc_proj run "gen_tile SCMUL"
FABulous --project-dir fabric_sc_proj run "gen_tile_macro SCMUL"      # ~2 min
```

Fabric sim: copy the project without `macro/`, `gds/`, `gen_macro/`, put SCMUL in the grid, run
`run_FABulous_fabric`, copy the static `Fabric/*.v` helpers, then in `Test/`:
`make sim DESIGN=scmul_test TOP_WRAPPER=top_wrapper_scmul`.
