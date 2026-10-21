set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     stochastic_decorrelator_hw_top
set BLOCK(sources) [list $M/stochastic_decorrelator.sv $root/blocks/$block/stochastic_decorrelator_hw_top.sv]
source $root/scripts/replay_block_common.tcl
