`include "hwb_params.svh"
// Input word (LSB first): {binary_in[W-1:0], ready_stochastic_out, valid_binary_in, rst_n}.
// Output word (LSB first): {last_cycle, stochastic_out, valid_stochastic_out, ready_binary_in}.
module fabulous_bts_sync_hw_top (
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

  FABulous_binary_stochastic_converter_sync #(
      .WIDTH(`P_WIDTH),
      .INIT_SEED(`P_INIT_SEED)
  ) dut (
      .UserCLK(clk),
      .rst_n(dut_in[0]),
      .valid_binary_in(dut_in[1]),
      .ready_stochastic_out(dut_in[2]),
      .binary_in(dut_in[3+:`P_WIDTH]),
      .ready_binary_in(dut_out[0]),
      .valid_stochastic_out(dut_out[1]),
      .stochastic_out(dut_out[2]),
      .last_cycle(dut_out[3])
  );
  assign led = dut_out;
endmodule
