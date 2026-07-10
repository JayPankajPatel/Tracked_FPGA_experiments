`default_nettype none

// shiftreg8 — gate-sim-robust functional witness for the shrunk Caravel eFPGA
// (issue #16, V3). 8-bit serial-in / parallel-out shift register.
//
// Chosen specifically for GATE-LEVEL simulation: a feed-forward shift register
// becomes fully defined after 8 clocks of a defined serial input, REGARDLESS of
// power-up X — so it does not depend on a reset propagating through LUT logic and
// is immune to the X-pessimism that locks a feedback LFSR at gate level (see the
// lfsr8 companion design, which passes behaviorally but X-locks in gate sim).
// Still exercises fabric FFs + routing + bidirectional IO end to end.
//
// Pin map (distinct input vs output pins):
//   io_in[0]  = en   (advance enable)
//   io_in[1]  = sin  (serial data in)
//   io_out[9:2] = shift state[7:0]   (state[0] = most recent bit)
//   io_oeb: 1 = input/Hi-Z, 0 = output. bits[1:0]+[15:10] in, [9:2] out.
module shiftreg8 (
    input  wire        clk,
    input  wire [15:0] io_in,
    output wire [15:0] io_out,
    output wire [15:0] io_oeb
);
    wire en  = io_in[0];
    wire sin = io_in[1];
    reg  [7:0] sr;

    always @(posedge clk)
        if (en) sr <= {sr[6:0], sin};

    assign io_out = {6'b0, sr, 2'b0};
    assign io_oeb = 16'b1111_1100_0000_0011;
endmodule
`default_nettype wire
