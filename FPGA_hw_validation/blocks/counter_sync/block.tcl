set BLOCK(top)     counter_sync_hw_top
set BLOCK(sources) [list $MICROARCH/blocks/basic/rtl/counter_sync.sv $root/blocks/$block/counter_sync_hw_top.sv]
source $root/scripts/replay_block_common.tcl
