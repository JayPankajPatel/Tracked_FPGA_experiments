set M $MICROARCH/blocks
set TB $M/stochastic/verif/tb
set BLOCK(top)     sc_multiply_chain_sync_hw_top
set BLOCK(sources) [list $M/basic/rtl/counter_sync.sv $M/stochastic/rtl/galois_lfsr_sync.sv $M/stochastic/rtl/binary_stochastic_converter_sync.sv \
                         $M/stochastic/rtl/stochastic_binary_converter_sync.sv $M/stochastic/rtl/stochastic_multiplier.sv $root/blocks/$block/gen/top_sync.sv \
                         $root/blocks/$block/sc_multiply_chain_sync_hw_top.sv]
source $root/scripts/replay_block_common.tcl
