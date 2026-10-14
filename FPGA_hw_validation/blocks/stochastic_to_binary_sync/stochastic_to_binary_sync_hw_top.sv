`include "hwb_params.svh"
// Input (LSB first): {ready_binary_out, boundary_in, stochastic_in, valid_stochastic_in, rst_n}.
// Output (LSB first): {binary_out[W-1:0], valid_binary_out, ready_stochastic_in}.
module stochastic_to_binary_sync_hw_top (
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

  stochastic_to_binary_sync #(
      .WIDTH(`P_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(dut_in[0]),
      .valid_stochastic_in(dut_in[1]),
      .stochastic_in(dut_in[2]),
      .boundary_in(dut_in[3]),
      .ready_binary_out(dut_in[4]),
      .ready_stochastic_in(dut_out[0]),
      .valid_binary_out(dut_out[1]),
      .binary_out(dut_out[2+:`P_WIDTH])
  );
  assign led = dut_out[3:0];
endmodule
