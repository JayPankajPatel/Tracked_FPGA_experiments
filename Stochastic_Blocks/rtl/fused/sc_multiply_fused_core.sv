// Fused SC multiply BEL core: BTS(a) + BTS(b) + AND + STB in one block, for one
// fabric tile (issue #33). Handshakes between the sub-blocks are internal, so the
// tile only exposes data, start and result. Wraps the same *_sync modules the
// validated sc_multiply_chain_top_sync uses (seeds 1 and 204).
//
// Output is the top 7 bits of the 8-bit ones-count: a FABulous tile allows at
// most 8 BEL outputs, and valid_out takes one.
module sc_multiply_fused_core (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic       valid_in,
    input  logic       ready_out,
    output logic       valid_out,
    output logic [6:0] product
);
  logic sa, va, ra, la;
  logic sb, vb, rb;
  /* verilator lint_off UNUSEDSIGNAL */
  logic ready_in_a, ready_in_b, lb;
  logic [7:0] count;
  /* verilator lint_on UNUSEDSIGNAL */
  logic sp, vp, rp;

  binary_stochastic_converter_sync #(.WIDTH(8), .INIT_SEED(8'd1)) u_a (
      .clk(clk), .rst_n(rst_n), .binary_in(a), .valid_binary_in(valid_in),
      .ready_stochastic_out(ra), .ready_binary_in(ready_in_a),
      .valid_stochastic_out(va), .stochastic_out(sa), .last_cycle(la));

  binary_stochastic_converter_sync #(.WIDTH(8), .INIT_SEED(8'd204)) u_b (
      .clk(clk), .rst_n(rst_n), .binary_in(b), .valid_binary_in(valid_in),
      .ready_stochastic_out(rb), .ready_binary_in(ready_in_b),
      .valid_stochastic_out(vb), .stochastic_out(sb), .last_cycle(lb));

  // AND join, same ready/valid cross-gating as stochastic_multiplier.
  assign vp = va && vb;
  assign ra = rp && vb;
  assign rb = rp && va;
  assign sp = sa && sb;

  stochastic_to_binary_sync #(.WIDTH(8)) u_dec (
      .clk(clk), .rst_n(rst_n), .stochastic_in(sp), .valid_stochastic_in(vp),
      .boundary_in(la), .ready_binary_out(ready_out),
      .ready_stochastic_in(rp), .valid_binary_out(valid_out), .binary_out(count));

  assign product = count[7:1];
endmodule : sc_multiply_fused_core
