set BLOCK(top)     counter_hw_top
set BLOCK(sources) [list $MICROARCH/blocks/basic/rtl/counter.sv $root/blocks/$block/counter_hw_top.sv]
source $root/scripts/replay_block_common.tcl
