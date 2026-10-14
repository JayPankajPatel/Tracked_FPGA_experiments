# Generic replay run: arm ILA on run rising, pulse VIO go, save the capture.
source $root/blocks/$block/gen/meta.tcl
proc run_block {dev vio ila out_dir} {
  global META
  vio_set $vio u_core/go 0
  set_property CONTROL.TRIGGER_POSITION 0 $ila
  set_property CONTROL.DATA_DEPTH $META(ila_depth) $ila
  set_property TRIGGER_COMPARE_VALUE eq1'bR [get_hw_probes u_core/run -of_objects $ila]
  run_hw_ila $ila
  vio_set $vio u_core/go 1
  wait_on_hw_ila $ila -timeout 30
  refresh_hw_vio $vio
  puts "REPLAY done=[get_property INPUT_VALUE [get_hw_probes u_core/done -of_objects $vio]]"
  ila_save $ila $out_dir capture
  vio_set $vio u_core/go 0
  puts "RUN_DONE $out_dir"
}
