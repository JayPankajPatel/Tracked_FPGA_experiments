`include "hwb_params.svh"
// Input word (LSB first): {clr, en, rst_n}.  Output word: out.
module counter_sync_hw_top (
    input  logic       clk,
    output logic [3:0] led
);
  logic [`HWB_IN_W-1:0] dut_in;
  logic [`HWB_OUT_W-1:0] dut_out;

  hwb_core #(
      .IN_W (`HWB_IN_W),
      .OUT_W(`HWB_OUT_W),
      .DEPTH(`HWB_DEPTH),
      .MEM  ("vectors.mem")
  ) u_core (
      .clk(clk),
      .dut_in(dut_in),
      .dut_out(dut_out)
  );

  counter_sync #(
      .UPTO(`P_UPTO)
  ) dut (
      .clk(clk),
      .en(dut_in[1]),
      .clr(dut_in[2]),
      .rst_n(dut_in[0]),
      .out(dut_out)
  );
  assign led = dut_out[3:0];
endmodule
