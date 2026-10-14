# Program a built block and run it. Per-block capture logic is in
# blocks/<name>/run.tcl (proc run_block {dev vio ila out_dir}).
# Usage: hw_session.sh run_block.tcl <block> [out_dir]
set block   [lindex $argv 0]
set root    [file normalize [file join [file dirname [info script]] ..]]
set out_dir [expr {[llength $argv] > 1 ? [file normalize [lindex $argv 1]] : "$root/waveforms/$block"}]
file mkdir $out_dir
source $root/scripts/hw_lib.tcl
if {[file exists $root/blocks/$block/run.tcl]} {
  source $root/blocks/$block/run.tcl
} else {
  source $root/scripts/replay_run.tcl
}
set bdir $root/build/$block
if {[catch {
set dev [hw_open $bdir/$block.bit $bdir/$block.ltx]
set vio [get_hw_vios -of_objects $dev]
set ila [get_hw_ilas -of_objects $dev]
if {$vio eq "" || $ila eq ""} { error "debug cores not found (vio='$vio' ila='$ila')" }
run_block $dev $vio $ila $out_dir
} err]} { puts "RUN_ERROR: $err"; catch {close_hw_manager}; exit 1 }
close_hw_manager
exit 0
