set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     stochastic_adder_sync_hw_top
set BLOCK(sources) [list $M/galois_lfsr_sync.sv $M/stochastic_adder_sync.sv $root/blocks/$block/stochastic_adder_sync_hw_top.sv]
source $root/scripts/replay_block_common.tcl
