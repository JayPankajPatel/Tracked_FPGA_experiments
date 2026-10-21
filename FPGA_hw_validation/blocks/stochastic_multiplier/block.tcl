set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     stochastic_multiplier_hw_top
set BLOCK(sources) [list $M/stochastic_multiplier.sv $root/blocks/$block/stochastic_multiplier_hw_top.sv]
source $root/scripts/replay_block_common.tcl
