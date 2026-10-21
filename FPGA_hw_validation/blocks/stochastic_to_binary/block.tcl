set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     stochastic_to_binary_hw_top
set BLOCK(sources) [list $M/stochastic_binary_converter.sv $root/blocks/$block/stochastic_to_binary_hw_top.sv]
source $root/scripts/replay_block_common.tcl
