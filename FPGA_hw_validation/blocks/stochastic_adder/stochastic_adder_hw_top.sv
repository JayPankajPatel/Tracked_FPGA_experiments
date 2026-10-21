`include "hwb_params.svh"
// Input (LSB first): {ready_stochastic_out, valid_b, b, valid_a, a, rst_n}.
// Output (LSB first): {stochastic_out, valid_stochastic_out, ready_b, ready_a}.
module stochastic_adder_hw_top (
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

  stochastic_adder #(.SELECT_LFSR_WIDTH(`P_SELECT_LFSR_WIDTH), .SELECT_INIT_SEED(`P_SELECT_INIT_SEED))  dut (
      .clk(clk),
      .rst_n(dut_in[0]),
      .stochastic_in_a(dut_in[1]),
      .valid_stochastic_in_a(dut_in[2]),
      .stochastic_in_b(dut_in[3]),
      .valid_stochastic_in_b(dut_in[4]),
      .ready_stochastic_out(dut_in[5]),
      .ready_stochastic_in_a(dut_out[0]),
      .ready_stochastic_in_b(dut_out[1]),
      .valid_stochastic_out(dut_out[2]),
      .stochastic_out(dut_out[3])
  );
  assign led = dut_out;
endmodule
