`include "hwb_params.svh"
// Input (LSB first): {ready_binary_out, valid_b, b[W-1:0], valid_a, a[W-1:0], rst_n}.
// Output (LSB first): {binary_out[W-1:0], valid_binary_out, ready_b, ready_a}.
module sc_multiply_chain_hw_top (
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

  top #(
      .WIDTH(W),
      .INIT_SEED_A(`P_INIT_SEED_A),
      .INIT_SEED_B(`P_INIT_SEED_B)
  ) dut (
      .clk(clk),
      .rst_n(dut_in[0]),
      .binary_in_a(dut_in[1+:W]),
      .valid_binary_in_a(dut_in[1+W]),
      .binary_in_b(dut_in[2+W+:W]),
      .valid_binary_in_b(dut_in[2+2*W]),
      .ready_binary_out(dut_in[3+2*W]),
      .ready_binary_in_a(dut_out[0]),
      .ready_binary_in_b(dut_out[1]),
      .valid_binary_out(dut_out[2]),
      .binary_out(dut_out[3+:W])
  );
  assign led = dut_out[3:0];
endmodule
