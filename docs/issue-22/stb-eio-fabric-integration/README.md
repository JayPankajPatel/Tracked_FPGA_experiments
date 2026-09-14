# STB + E_IO fabric integration — tracked source backup

`FABulous_work/fabulous-v2/` (this project's FABulous checkout, including every project under it
such as `fabric_btos_only_proj/`) is entirely gitignored, clean-room. The fix that makes `STB`
(Stochastic-to-Binary) and its new `E_IO` east-edge tile stitch cleanly into the fabric
(Antenna/LVS/DRC all Passed, `Circuits match uniquely`) therefore has no tracked copy anywhere
else — this directory is that backup.

**Full root-cause writeup:**
`~/wiki/fpga_stochastic_blocks/experiments/stb-eio-mirrored-tile-pin-slot-fix-2026-09-14.md`
(evidence, the false-start netgen-symmetry hypothesis and why it was wrong, the fix, results).
This README only covers restoring the files.

## What's here

- `source/STB/STB.csv`, `source/STB/FABulous_stochastic_to_binary_sync.sv`,
  `source/STB/gds_config.yaml` — the STB tile (same dummy-`CARRY` pattern as `BTS`; `WIDTH=6`
  to fit FABulous's 8-output switch-matrix-generation limit).
- `source/E_IO/E_IO.csv`, `source/E_IO/E_IO_switch_matrix.list`, `source/E_IO/gds_config.yaml` —
  the new east-edge IO tile, hand-mirrored from `W_IO` with the direction-line block order
  **corrected** (see root cause below — this is the fixed version, not the original mirror).
- `source/fabric.csv` — the final 10-column fabric grid
  (`W_IO,BTS,LUT4AB,RegFile,LUT4AB,LUT4AB,LUT4AB,LUT4AB,STB,E_IO`), with the tile-inclusion list
  updated (added `STB`/`E_IO`, removed the unused `RAM_IO`/`N_term_RAM_IO`/`S_term_RAM_IO` entries).
- `restore-tile-files.sh` — copies all of the above back into a FABulous project checkout.

## One-line root cause

A tile's edge-pin Y-slot is assigned by CSV direction-line **declaration order**, not by port name
or the `WEST`/`EAST` keyword. Mirroring `W_IO` into `E_IO` by token-substituting line *content*
preserved the wrong *block order* (output block first, input block second — backwards from
`W_IO`), so `E_IO`'s output pins landed in the same Y-slot as `STB`'s own output pins instead of
`STB`'s input pins — two drivers shorted together. Fixed by reordering (not renaming) the two
direction-line blocks in `E_IO.csv`.

## Restore

```sh
docs/issue-22/stb-eio-fabric-integration/restore-tile-files.sh \
  FABulous_work/fabulous-v2/fabric_btos_only_proj

cd FABulous_work/fabulous-v2                      # pinned v2.0.0b5
nix develop --command bash -c '
  export PDK_ROOT="$PWD/.pdk"
  FABulous --project-dir fabric_btos_only_proj run "gen_fabric"
  FABulous --project-dir fabric_btos_only_proj run "gen_all_tile_macros --parallel"
  FABulous --project-dir fabric_btos_only_proj run "gen_fabric_macro"
'
# => Final result: Circuits match uniquely. All LVS/DRC/Antenna metrics 0.
```

## Applies to future mirrored edge-IO tiles too

Any tile mirrored from an existing edge-IO tile for a different fabric edge needs the same
direction-line block-order check against the reference tile — not just a name/prefix mirror. See
step 9 of the methodology page for the general procedure.
