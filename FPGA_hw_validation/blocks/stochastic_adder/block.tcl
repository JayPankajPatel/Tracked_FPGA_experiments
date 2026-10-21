set M $MICROARCH/blocks/stochastic/rtl
set BLOCK(top)     stochastic_adder_hw_top
set BLOCK(sources) [list $M/galois_lfsr.sv $M/stochastic_adder.sv $root/blocks/$block/stochastic_adder_hw_top.sv]
source $root/scripts/replay_block_common.tcl
