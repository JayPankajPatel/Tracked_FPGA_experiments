# Build a block's hardware bench for the Zybo Z7-10: project-mode batch,
# generates vio_0/ila_0 IP from blocks/<name>/block.tcl, writes bit + ltx.
# Usage: vivado -mode batch -source build_block.tcl -tclargs <block> [out_dir]
set block   [lindex $argv 0]
set root    [file normalize [file join [file dirname [info script]] ..]]
set out_dir [expr {[llength $argv] > 1 ? [file normalize [lindex $argv 1]] : "$root/build/$block"}]
set part    xc7z010clg400-1
array set BLOCK {}
source $root/blocks/$block/block.tcl

file delete -force $out_dir
file mkdir $out_dir
create_project -force hwval $out_dir/proj -part $part

set srcs {}
foreach s $BLOCK(sources) { lappend srcs [file normalize $s] }
foreach s $srcs { if {![file exists $s]} { error "missing source $s" } }
add_files -norecurse $srcs
if {[info exists BLOCK(include_dirs)]} { set_property include_dirs $BLOCK(include_dirs) [current_fileset] }
if {[info exists BLOCK(defines)]}      { set_property verilog_define $BLOCK(defines) [current_fileset] }
set_property file_type SystemVerilog [get_files *.sv]
add_files -fileset constrs_1 -norecurse $root/constraints/zybo_z7_10.xdc
set_property top $BLOCK(top) [current_fileset]

# --- VIO ---
create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0
set vp [list CONFIG.C_NUM_PROBE_IN $BLOCK(n_vio_in) CONFIG.C_NUM_PROBE_OUT $BLOCK(n_vio_out)]
for {set i 0} {$i < $BLOCK(n_vio_in)} {incr i}  { lappend vp CONFIG.C_PROBE_IN${i}_WIDTH  [lindex $BLOCK(vio_in) $i] }
for {set i 0} {$i < $BLOCK(n_vio_out)} {incr i} { lappend vp CONFIG.C_PROBE_OUT${i}_WIDTH [lindex $BLOCK(vio_out) $i] }
set_property -dict $vp [get_ips vio_0]
# --- ILA ---
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0
set ip [list CONFIG.C_NUM_OF_PROBES [llength $BLOCK(ila_probes)] CONFIG.C_DATA_DEPTH $BLOCK(ila_depth) CONFIG.C_EN_STRG_QUAL 1 CONFIG.ALL_PROBE_SAME_MU_CNT 2]
set i 0
foreach w $BLOCK(ila_probes) { lappend ip CONFIG.C_PROBE${i}_WIDTH $w; incr i }
set_property -dict $ip [get_ips ila_0]
generate_target all [get_ips]

update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "impl failed" }

set run_dir $out_dir/proj/hwval.runs/impl_1
file copy -force $run_dir/$BLOCK(top).bit $out_dir/$block.bit
file copy -force $run_dir/$BLOCK(top).ltx $out_dir/$block.ltx
open_run impl_1
report_timing_summary -file $out_dir/timing.rpt
report_utilization    -file $out_dir/utilization.rpt
puts "BUILD_DONE $block bit=$out_dir/$block.bit ltx=$out_dir/$block.ltx"
