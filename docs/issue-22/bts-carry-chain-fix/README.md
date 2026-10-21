# BTS tile carry-chain / pin-alignment fix — tracked source backup

`FABulous_work/fabulous-v2/` (this project's FABulous checkout, including every project under it
such as `fabric_sc_proj/`) is entirely gitignored, clean-room. The fix that makes the `BTS`
custom tile stitch cleanly into the fabric (Antenna/LVS/DRC all Passed, `Circuits match uniquely`)
therefore has no tracked copy anywhere else — this directory is that backup.

**Full root-cause writeup:**
`~/wiki/fpga_stochastic_blocks/experiments/bts-tile-carry-chain-pin-alignment-fix-2026-09-14.md`
(evidence, dead ends, why the fix works, results). This README only covers restoring the files.

## What's here

- `source/BTS.csv` — the tile definition, including the auto-generated
  `NORTH,Co0,0,-1,Ci0,1,CARRY="dummy"` jump declaration.
- `source/FABulous_binary_stochastic_converter_sync.sv` — the BEL wrapper, including the dummy
  `(* CARRY="dummy" *)` input/output pass-through pair that makes BTS's switch-matrix pin ordering
  match every carry-capable tile in the fabric (`LUT4AB` etc.).
- `restore-tile-files.sh` — copies both back into a FABulous project's `Tile/BTS/` directory.

## One-line root cause

BTS was the only tile in the fabric with no carry chain, so its switch matrix had one real pin
fewer than every neighboring tile on the North/South sides — silently shifting `UserCLKo`/`UserCLK`
one pin-width out of alignment with the rest of the fabric, breaking fabric-stitch LVS. Fix: give BTS
a functionally-unused carry pin pair via FABulous's documented `(* CARRY="..." *)` BEL attribute +
`generate_custom_tile_config`, matching how every other tile actually gets its carry ports.

## Restore

```sh
docs/issue-22/bts-carry-chain-fix/restore-tile-files.sh \
  FABulous_work/fabulous-v2/fabric_sc_proj/Tile/BTS

cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  FABulous --project-dir fabric_sc_proj run "generate_custom_tile_config Tile/BTS"
  FABulous --project-dir fabric_sc_proj run "run_pyscript $(pwd)/fabric_sc_proj/build_fabric.py"
  FABulous --project-dir fabric_sc_proj run "gen_tile_macro BTS"
'
# => Report Manufacturability: Antenna/LVS/DRC Passed
```

## Applies to StoB / adder / multiplier too

Any new custom tile without a carry chain will hit the same misalignment the moment it's added
next to carry-capable tiles. Give each one the same dummy-carry attribute pattern
(`(* CARRY="dummy" *)` on an unused input/output pair, tied through) from the start.
