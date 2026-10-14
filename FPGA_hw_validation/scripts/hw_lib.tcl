# Shared helpers for run_*.tcl: connect, program, locate debug cores.
proc hw_open {bit ltx} {
  set url [expr {[info exists ::env(HW_URL)] ? $::env(HW_URL) : "localhost:3121"}]
  open_hw_manager
  connect_hw_server -url $url
  open_hw_target
  set dev [lindex [get_hw_devices xc7z010*] 0]
  if {$dev eq ""} { error "xc7z010 not found" }
  current_hw_device $dev
  set_property PROGRAM.FILE $bit $dev
  set_property PROBES.FILE  $ltx $dev
  set_property FULL_PROBES.FILE $ltx $dev
  program_hw_devices $dev
  refresh_hw_device $dev
  return $dev
}
# Set a VIO output probe by name pattern to a value (hex string, no 0x).
proc vio_set {vio name hexval} {
  set p [get_hw_probes $name -of_objects $vio]
  if {$p eq ""} { error "VIO probe $name not found" }
  set_property OUTPUT_VALUE $hexval $p
  commit_hw_vio $p
}
proc vio_get {vio name} {
  refresh_hw_vio $vio
  return [get_property INPUT_VALUE [get_hw_probes $name -of_objects $vio]]
}
