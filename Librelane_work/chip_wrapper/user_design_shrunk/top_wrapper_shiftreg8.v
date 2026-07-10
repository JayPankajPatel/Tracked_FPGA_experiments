`default_nettype none

// top_wrapper_shiftreg8 — shrunk-Caravel (8x8) FABulous IO harness for shiftreg8
// (issue #16, V1/V3). Same 16-IO BEL map as top_wrapper_lfsr8; see that file.
// synth target: yosys synth_fabulous -top top_wrapper_shiftreg8.
module top_wrapper_shiftreg8;

    wire [15:0] io_in, io_out, io_oeb;

    (* keep, BEL="X0Y1.A" *) IO_1_bidirectional_frame_config_pass io15_i (.O(io_in[15]), .I(io_out[15]), .T(io_oeb[15]));
    (* keep, BEL="X0Y1.B" *) IO_1_bidirectional_frame_config_pass io14_i (.O(io_in[14]), .I(io_out[14]), .T(io_oeb[14]));
    (* keep, BEL="X0Y2.A" *) IO_1_bidirectional_frame_config_pass io13_i (.O(io_in[13]), .I(io_out[13]), .T(io_oeb[13]));
    (* keep, BEL="X0Y2.B" *) IO_1_bidirectional_frame_config_pass io12_i (.O(io_in[12]), .I(io_out[12]), .T(io_oeb[12]));
    (* keep, BEL="X0Y3.A" *) IO_1_bidirectional_frame_config_pass io11_i (.O(io_in[11]), .I(io_out[11]), .T(io_oeb[11]));
    (* keep, BEL="X0Y3.B" *) IO_1_bidirectional_frame_config_pass io10_i (.O(io_in[10]), .I(io_out[10]), .T(io_oeb[10]));
    (* keep, BEL="X0Y4.A" *) IO_1_bidirectional_frame_config_pass io9_i  (.O(io_in[9]),  .I(io_out[9]),  .T(io_oeb[9]));
    (* keep, BEL="X0Y4.B" *) IO_1_bidirectional_frame_config_pass io8_i  (.O(io_in[8]),  .I(io_out[8]),  .T(io_oeb[8]));
    (* keep, BEL="X0Y5.A" *) IO_1_bidirectional_frame_config_pass io7_i  (.O(io_in[7]),  .I(io_out[7]),  .T(io_oeb[7]));
    (* keep, BEL="X0Y5.B" *) IO_1_bidirectional_frame_config_pass io6_i  (.O(io_in[6]),  .I(io_out[6]),  .T(io_oeb[6]));
    (* keep, BEL="X0Y6.A" *) IO_1_bidirectional_frame_config_pass io5_i  (.O(io_in[5]),  .I(io_out[5]),  .T(io_oeb[5]));
    (* keep, BEL="X0Y6.B" *) IO_1_bidirectional_frame_config_pass io4_i  (.O(io_in[4]),  .I(io_out[4]),  .T(io_oeb[4]));
    (* keep, BEL="X0Y7.A" *) IO_1_bidirectional_frame_config_pass io3_i  (.O(io_in[3]),  .I(io_out[3]),  .T(io_oeb[3]));
    (* keep, BEL="X0Y7.B" *) IO_1_bidirectional_frame_config_pass io2_i  (.O(io_in[2]),  .I(io_out[2]),  .T(io_oeb[2]));
    (* keep, BEL="X0Y8.A" *) IO_1_bidirectional_frame_config_pass io1_i  (.O(io_in[1]),  .I(io_out[1]),  .T(io_oeb[1]));
    (* keep, BEL="X0Y8.B" *) IO_1_bidirectional_frame_config_pass io0_i  (.O(io_in[0]),  .I(io_out[0]),  .T(io_oeb[0]));

    wire clk;
    (* keep *) Global_Clock clk_i (.CLK(clk));

    shiftreg8 top_i (
        .clk(clk),
        .io_in(io_in),
        .io_out(io_out),
        .io_oeb(io_oeb)
    );

endmodule
`default_nettype wire
