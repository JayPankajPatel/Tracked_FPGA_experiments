`include "ma_assert.svh"
// Synchronous-reset variant of sc_multiply_chain_top.sv, composed entirely
// from _sync submodules, for mapping onto fabric targets whose FF BEL has
// no async reset input (see Microarch_Lib docs/adr/0020 and
// ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// fabric-ff-primitive-sync-reset-only.md). Identical structure/logic to
// sc_multiply_chain_top.sv; only the submodule instantiations change
// (encoder/LFSR _sync variants) plus this module's own name. Default
// WIDTH/seeds are set to the fabric-verified WIDTH=8 pair
// (INIT_SEED_A=1, INIT_SEED_B=204, phase_lag=127 -- exactly half the
// 255-state period) rather than the async top's WIDTH=4 protocol-only
// defaults, since this variant exists specifically to feed the fabric
// mapping attempt that needs numerically-trustworthy output. stochastic_multiplier
// itself has no _sync variant (pure combinational, see ADR 0012/0020) --
// it's reused unmodified here.
//
//   binary_in_a -> [encoder A sync] --stochastic_a--\
//                                                     +--> [multiplier] --stochastic_product--> [decoder sync] -> binary_out
//   binary_in_b -> [encoder B sync] --stochastic_b--/
module sc_multiply_chain_top_sync #(
    parameter int WIDTH = 8,
    parameter bit [WIDTH-1:0] INIT_SEED_A = 8'd1,
    parameter bit [WIDTH-1:0] INIT_SEED_B = 8'd204
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] binary_in_a,
    input  logic             valid_binary_in_a,
    input  logic [WIDTH-1:0] binary_in_b,
    input  logic             valid_binary_in_b,
    input  logic             ready_binary_out,
    output logic             ready_binary_in_a,
    output logic             ready_binary_in_b,
    output logic             valid_binary_out,
    output logic [WIDTH-1:0] binary_out
);
  `MA_ASSERT_ELABOR(DistinctEncoderSeeds, INIT_SEED_A != INIT_SEED_B)

  logic stochastic_a, valid_stochastic_a, ready_stochastic_a, last_cycle_a;
  /* verilator lint_off UNUSEDSIGNAL */
  logic stochastic_b, valid_stochastic_b, ready_stochastic_b, last_cycle_b;
  /* verilator lint_on UNUSEDSIGNAL */
  logic stochastic_product, valid_stochastic_product, ready_stochastic_product;

  binary_stochastic_converter_sync #(
      .WIDTH(WIDTH),
      .INIT_SEED(INIT_SEED_A)
  ) u_encoder_a (
      .clk(clk),
      .rst_n(rst_n),
      .binary_in(binary_in_a),
      .valid_binary_in(valid_binary_in_a),
      .ready_stochastic_out(ready_stochastic_a),
      .ready_binary_in(ready_binary_in_a),
      .valid_stochastic_out(valid_stochastic_a),
      .stochastic_out(stochastic_a),
      .last_cycle(last_cycle_a)
  );

  binary_stochastic_converter_sync #(
      .WIDTH(WIDTH),
      .INIT_SEED(INIT_SEED_B)
  ) u_encoder_b (
      .clk(clk),
      .rst_n(rst_n),
      .binary_in(binary_in_b),
      .valid_binary_in(valid_binary_in_b),
      .ready_stochastic_out(ready_stochastic_b),
      .ready_binary_in(ready_binary_in_b),
      .valid_stochastic_out(valid_stochastic_b),
      .stochastic_out(stochastic_b),
      .last_cycle(last_cycle_b)
  );

  stochastic_multiplier u_multiplier (
      .clk(clk),
      .rst_n(rst_n),
      .stochastic_in_a(stochastic_a),
      .valid_stochastic_in_a(valid_stochastic_a),
      .ready_stochastic_in_a(ready_stochastic_a),
      .stochastic_in_b(stochastic_b),
      .valid_stochastic_in_b(valid_stochastic_b),
      .ready_stochastic_in_b(ready_stochastic_b),
      .ready_stochastic_out(ready_stochastic_product),
      .valid_stochastic_out(valid_stochastic_product),
      .stochastic_out(stochastic_product)
  );

  stochastic_to_binary_sync #(
      .WIDTH(WIDTH)
  ) u_decoder (
      .clk(clk),
      .rst_n(rst_n),
      .stochastic_in(stochastic_product),
      .valid_stochastic_in(valid_stochastic_product),
      .boundary_in(last_cycle_a),
      .ready_binary_out(ready_binary_out),
      .ready_stochastic_in(ready_stochastic_product),
      .valid_binary_out(valid_binary_out),
      .binary_out(binary_out)
  );
endmodule : sc_multiply_chain_top_sync
