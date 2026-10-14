# Heartbeat: hold reset, release via VIO, trigger ILA on counter, verify the
# captured counter is a monotonically increasing sequence (step 1 per sample).
proc run_block {dev vio ila out_dir} {
  vio_set $vio rst_n 0          ;# reset asserted (rst_n=0)
  set_property CONTROL.TRIGGER_POSITION 16 $ila
  set_property CONTROL.DATA_DEPTH 4096 $ila
  # Trigger when rst_n (probe1) rises
  set_property TRIGGER_COMPARE_VALUE eq1'bR [get_hw_probes rst_n_1 -of_objects $ila]
  run_hw_ila $ila
  vio_set $vio rst_n 1          ;# release reset
  wait_on_hw_ila $ila -timeout 10
  ila_save $ila $out_dir capture
  puts "RUN_DONE $out_dir"
}
