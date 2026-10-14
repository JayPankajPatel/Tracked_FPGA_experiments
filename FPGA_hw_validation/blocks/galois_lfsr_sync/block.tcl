set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     galois_lfsr_sync_hw_top
set BLOCK(sources) [list $M/galois_lfsr_sync.sv $root/blocks/$block/galois_lfsr_sync_hw_top.sv]
source $root/scripts/replay_block_common.tcl
