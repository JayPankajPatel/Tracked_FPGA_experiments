# SMUL + SADD fabric integration — tracked source backup

`FABulous_work/fabulous-v2/` (this project's FABulous checkout, including every project under it
such as `fabric_sc_proj/`) is entirely gitignored, clean-room. The `SMUL` (stochastic
multiplier) and `SADD` (stochastic adder) tiles built into the fabric this session therefore have
no tracked copy anywhere else — this directory is that backup.

**Full writeup:**
`~/wiki/fpga_stochastic_blocks/experiments/smul-sadd-tile-integration-2026-09-14.md` (setup,
results, why this run needed no debugging unlike the BTS/E_IO incidents). This README only covers
restoring the files.

## What's here

- `source/SMUL/SMUL.csv`, `source/SMUL/FABulous_stochastic_multiplier.sv`,
  `source/SMUL/gds_config.yaml` — the stochastic multiplier tile: a pure combinational AND-join BEL
  (no clock, no internal state), same dummy-`CARRY` pattern as `BTS`/`STB`.
- `source/SADD/SADD.csv`, `source/SADD/FABulous_stochastic_adder_sync.sv`,
  `source/SADD/gds_config.yaml` — the stochastic adder tile: a select-RNG-driven MUX BEL with one
  internal `galois_lfsr_sync`, same dummy-`CARRY` pattern.
- `source/fabric.csv` — the final 10-column fabric grid, now
  `W_IO,BTS,LUT4AB,RegFile,SMUL,LUT4AB,SADD,LUT4AB,STB,E_IO`, with the tile-inclusion list updated.
- `restore-tile-files.sh` — copies all of the above back into a FABulous project checkout.

## Result

Both tiles built using the dummy-`CARRY`-from-the-start methodology (established from the earlier
`BTS`/`STB`/`E_IO` incidents — see the methodology page) hardened clean at both the tile level and
the full-fabric level on the first attempt, no pin-alignment debugging needed. Full fabric netgen
LVS: `Circuits match uniquely`, all LVS/DRC/Antenna metrics zero.

## Restore

```sh
docs/issue-22/smul-sadd-fabric-integration/restore-tile-files.sh \
  FABulous_work/fabulous-v2/fabric_sc_proj

cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  cd fabric_sc_proj
  FABulous --project-dir . run "gen_fabric"
  FABulous --project-dir . run "gen_all_tile_macros --parallel"
  FABulous --project-dir . run "gen_fabric_macro"
'
# => Final result: Circuits match uniquely. All LVS/DRC/Antenna metrics 0.
```

## Applies to future stochastic-compute tiles too

Individual multiply/add tiles were chosen over a fused MAC this round (user decision, "let's try
individual ones at first" — fused-MAC comparison against a binary INT4 MAC tile is a possible
follow-up once area/timing data exists for these standalone tiles).
