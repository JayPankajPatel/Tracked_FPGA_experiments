set M $MICROARCH/blocks
set BLOCK(top)     binary_stochastic_converter_hw_top
set BLOCK(sources) [list $M/basic/rtl/counter.sv $M/stochastic/rtl/galois_lfsr.sv $M/stochastic/rtl/binary_stochastic_converter.sv \
                         $root/blocks/$block/binary_stochastic_converter_hw_top.sv]
source $root/scripts/replay_block_common.tcl
