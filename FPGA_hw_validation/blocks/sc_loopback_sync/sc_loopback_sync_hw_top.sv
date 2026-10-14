`include "hwb_params.svh"
// Input (LSB first): {ready_binary_out, valid_binary_in, binary_in[W-1:0], rst_n}.
// Output (LSB first): {binary_out[W-1:0], valid_binary_out, ready_binary_in}.
module sc_loopback_sync_hw_top (
    input  logic       clk,
    output logic [3:0] led
);
  localparam int W = `P_WIDTH;
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

  loopback_top #(
      .WIDTH(W)
  ) dut (
      .clk(clk),
      .rst_n(dut_in[0]),
      .binary_in(dut_in[1+:W]),
      .valid_binary_in(dut_in[1+W]),
      .ready_binary_out(dut_in[2+W]),
      .ready_binary_in(dut_out[0]),
      .valid_binary_out(dut_out[1]),
      .binary_out(dut_out[2+:W])
  );
  assign led = dut_out[3:0];
endmodule
