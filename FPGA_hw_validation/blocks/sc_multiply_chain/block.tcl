set M $MICROARCH/blocks
set TB $M/stochastic/verif/tb
set BLOCK(top)     sc_multiply_chain_hw_top
set BLOCK(sources) [list $M/basic/rtl/counter.sv $M/stochastic/rtl/galois_lfsr.sv $M/stochastic/rtl/binary_stochastic_converter.sv \
                         $M/stochastic/rtl/stochastic_binary_converter.sv $M/stochastic/rtl/stochastic_multiplier.sv $TB/test_b_mult_s_integration/top.sv \
                         $root/blocks/$block/sc_multiply_chain_hw_top.sv]
source $root/scripts/replay_block_common.tcl
