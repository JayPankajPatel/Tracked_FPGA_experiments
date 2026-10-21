# Health check: connect to hw_server and require the Zybo Z7-10 (xc7z010).
# Usage: hw_session.sh hw_check.tcl
set url [expr {[info exists ::env(HW_URL)] ? $::env(HW_URL) : "localhost:3121"}]
open_hw_manager
if {[catch {connect_hw_server -url $url} err]} { puts "HW_CHECK FAIL: $err"; exit 1 }
if {[catch {open_hw_target} err]} { puts "HW_CHECK FAIL: no target: $err"; exit 1 }
set parts {}
foreach d [get_hw_devices] { lappend parts [get_property PART $d] }
puts "HW_CHECK devices: $parts"
if {[lsearch -glob $parts "xc7z010*"] < 0} { puts "HW_CHECK FAIL: xc7z010 not found"; exit 1 }
puts "HW_CHECK PASS"
close_hw_manager
exit 0
