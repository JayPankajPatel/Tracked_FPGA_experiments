module FABulous_sc_multiply_fused (
    (* FABulous, EXTERNAL, SHARED_PORT *) input logic UserCLK,
    input logic [7:0] a,
    input logic [7:0] b,
    input logic rst_n,
    input logic valid_in,
    input logic ready_out,
    output logic valid_out,
    output logic [6:0] product,
    // Dummy carry pair so generate_custom_tile_config allocates the same pin
    // track as every other tile (see FABulous_binary_stochastic_converter_sync.sv).
    (* CARRY="dummy" *) input logic dummy_carry_in,
    (* CARRY="dummy" *) output logic dummy_carry_out
);
  assign dummy_carry_out = dummy_carry_in;

  sc_multiply_fused_core BEL (
      .clk(UserCLK), .rst_n(rst_n), .a(a), .b(b), .valid_in(valid_in),
      .ready_out(ready_out), .valid_out(valid_out), .product(product));
endmodule : FABulous_sc_multiply_fused
