# Per-block build description consumed by build_block.tcl.
set BLOCK(top)        hw_heartbeat_top
set BLOCK(sources)    [list $root/rtl/hw_heartbeat_top.sv]
set BLOCK(n_vio_in)   1
set BLOCK(vio_in)     [list 8]
set BLOCK(n_vio_out)  1
set BLOCK(vio_out)    [list 1]
set BLOCK(ila_probes) [list 16 1]
set BLOCK(ila_depth)  4096
