`include "hwb_params.svh"
// Input word (LSB first): {en, rst_n}.  Output word: out.
module galois_lfsr_hw_top (
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

  galois_lfsr #(
      .WIDTH(`P_WIDTH),
      .INIT_SEED(`P_INIT_SEED)
  ) dut (
      .clk(clk),
      .en(dut_in[1]),
      .rst_n(dut_in[0]),
      .out(dut_out)
  );
  assign led = dut_out[3:0];
endmodule
