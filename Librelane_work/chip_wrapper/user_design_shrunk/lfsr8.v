`default_nettype none

// lfsr8 — fit-for-purpose user design for the shrunk Caravel eFPGA (issue #16, V1).
//
// 8-bit maximal-length Fibonacci LFSR (taps x^8+x^6+x^5+x^4, i.e. bits 7,5,4,3).
// On-theme for this project: an LFSR is the canonical stochastic-bitstream source.
// Tiny (8 FFs + a 3-input XOR), so it maps trivially onto the 8x8 fabric and uses
// far fewer than the 16 available user-IO pins.
//
// Pin map (bidirectional fabric IO; inputs and outputs use DISTINCT pins):
//   io_in[0]  = rst  (sync, seeds state to 0x01 so the sequence is nonzero)
//   io_in[1]  = en   (advance enable)
//   io_out[9:2] = lfsr state[7:0]
//   io_oeb: 1 = input/Hi-Z (T), 0 = output (driven). bits[1:0]+[15:10] in, [9:2] out.
module lfsr8 (
    input  wire        clk,
    input  wire [15:0] io_in,
    output wire [15:0] io_out,
    output wire [15:0] io_oeb
);
    wire rst = io_in[0];
    wire en  = io_in[1];
    reg  [7:0] state;
    wire fb = state[7] ^ state[5] ^ state[4] ^ state[3];

    always @(posedge clk)
        if (rst)      state <= 8'h01;
        else if (en)  state <= {state[6:0], fb};

    assign io_out = {6'b0, state, 2'b0};
    assign io_oeb = 16'b1111_1100_0000_0011;
endmodule
`default_nettype wire
