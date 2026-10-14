# Common build description for record/replay blocks. A block's block.tcl sets
# BLOCK(top) and BLOCK(sources) (DUT RTL + its *_hw_top.sv), then sources this.
# Requires <block>/gen/meta.tcl and <block>/gen/vectors.mem from the recorder.
source $root/blocks/$block/gen/meta.tcl
lappend BLOCK(sources) $root/rtl/hwb_core.sv $root/blocks/$block/gen/vectors.mem
set BLOCK(include_dirs) [list $root/blocks/$block/gen $MICROARCH/common/rtl]
set BLOCK(defines)    [list SYNTHESIS]
set BLOCK(n_vio_in)   1
set BLOCK(vio_in)     [list 1]
set BLOCK(n_vio_out)  1
set BLOCK(vio_out)    [list 1]
set BLOCK(ila_probes) [list $META(in_w) $META(out_w) 1]
set BLOCK(ila_depth)  $META(ila_depth)
