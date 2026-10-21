`default_nettype none

// int4_multiply_fabric -- plain binary 4x4->8-bit multiplier, fit-for-purpose
// user design for the shrunk 8x8 Caravel eFPGA, built as a fair same-node
// (sky130, this exact fabric) baseline against sc_multiply_chain_fabric.v
// (the stochastic-computing multiply chain mapped onto the same fabric).
//
// The earlier Zybo Z7 area/power comparison (Microarch_Lib
// blocks/stocastic/fpga/rtl/) mixed process node AND fabric architecture
// (a commercial Xilinx part vs. this project's own sky130 soft fabric),
// confounding the SC-vs-binary comparison. Mapping both designs onto the
// identical fabric removes that confound: any resource/frequency
// difference here is attributable to the SC vs. binary approach itself,
// not to a different vendor's FPGA fabric or process node.
//
// Purely combinational -- a 4x4 binary multiply needs no clock, no
// pipeline, no bit-serial encoding at all. clk is present only because
// every design on this fabric shares the same top_wrapper skeleton
// (Global_Clock instance); it's unused here.
//
// Pin map (fits exactly in the fabric's 16 bidirectional IO pins, no
// free-running-generator trick needed, unlike the SC design):
//   io_in[3:0]   = a (input)
//   io_in[7:4]   = b (input)
//   io_out[15:8] = product = a * b (output, 8 bits: 4x4 multiply needs up
//                  to 8 bits to represent 15*15=225)
//   io_oeb: 1 = input/Hi-Z (T), 0 = output (driven).
module int4_multiply_fabric (
    input  wire        clk,
    input  wire [15:0] io_in,
    output wire [15:0] io_out,
    output wire [15:0] io_oeb
);
    wire [3:0] a = io_in[3:0];
    wire [3:0] b = io_in[7:4];
    wire [7:0] product = a * b;

    assign io_out = {product, 8'b0};
    assign io_oeb = 16'b0000_0000_1111_1111;
endmodule
`default_nettype wire
