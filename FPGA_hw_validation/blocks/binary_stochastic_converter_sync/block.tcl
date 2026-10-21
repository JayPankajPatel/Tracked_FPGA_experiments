set M $MICROARCH/blocks
set BLOCK(top)     binary_stochastic_converter_sync_hw_top
set BLOCK(sources) [list $M/basic/rtl/counter_sync.sv $M/stochastic/rtl/galois_lfsr_sync.sv $M/stochastic/rtl/binary_stochastic_converter_sync.sv \
                         $root/blocks/$block/binary_stochastic_converter_sync_hw_top.sv]
source $root/scripts/replay_block_common.tcl
