`default_nettype none

// Fused SC multiply tile exercised through fabric IO.
// io[7:0] = a, io[15:8] = b (inputs)    io[16] = rst_n, io[17] = valid_in, io[18] = ready_out (inputs)
// io[19]  = valid_out, io[26:20] = product[6:0] (outputs)   io[27] unused.
module scmul_test (
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);
    wire valid_out;
    wire [6:0] product;

    FABulous_sc_multiply_fused u_scmul (
        .CLK       (clk),
        .a0(io_in[0]), .a1(io_in[1]), .a2(io_in[2]), .a3(io_in[3]),
        .a4(io_in[4]), .a5(io_in[5]), .a6(io_in[6]), .a7(io_in[7]),
        .b0(io_in[8]), .b1(io_in[9]), .b2(io_in[10]), .b3(io_in[11]),
        .b4(io_in[12]), .b5(io_in[13]), .b6(io_in[14]), .b7(io_in[15]),
        .rst_n     (io_in[16]),
        .valid_in  (io_in[17]),
        .ready_out (io_in[18]),
        .valid_out (valid_out),
        .product0(product[0]), .product1(product[1]), .product2(product[2]), .product3(product[3]),
        .product4(product[4]), .product5(product[5]), .product6(product[6])
    );

    assign io_out = {1'b0, product, valid_out, 19'b0};
    assign io_oeb = {1'b1, 8'b00000000, 19'b1111111111111111111};
endmodule

`default_nettype wire
