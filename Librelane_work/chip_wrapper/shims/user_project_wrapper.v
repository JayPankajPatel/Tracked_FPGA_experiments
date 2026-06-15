// user_project_wrapper.v — Caravel (ChipFoundry CC2509) shim for issue #16.
//
// Maps the MPW-neutral chip_top contract onto the modern ChipFoundry Caravel
// harness (tag CC2509, sky130A, user area 2920x3520 um). chip_top is
// instantiated at SHRUNK fabric params (8x8, USERIO_W=16) so the hardened
// caravel_shrunk eFPGA macro (1989.96x2457.52 um, LVS/DRC/Antenna clean) fits
// the user area with room for the 4 SRAM macros + soft controller + PDN.
//
// Config is the thin serial contract over GPIO (Dirk Koch note: preserve the
// FABulous frame protocol, no heavy bus). Wishbone/LA left as tie-offs here;
// a Wishbone->SelfWrite bridge can be added later without changing the contract.
//
// Pin map (GPIO, MPRJ_IO_PADS=38):
//   io[8]=cfg_sclk(in)  io[9]=cfg_sdata(in)  io[10]=cfg_busy(out) io[11]=cfg_done(out)
//   io[27:12]=user_io[15:0] (bidir)          others: input/hi-z

`default_nettype none
module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1, inout vdda2, inout vssa1, inout vssa2,
    inout vccd1, inout vccd2, inout vssd1, inout vssd2,
`endif
    input  wb_clk_i,
    input  wb_rst_i,
    input  wbs_stb_i,
    input  wbs_cyc_i,
    input  wbs_we_i,
    input  [3:0]  wbs_sel_i,
    input  [31:0] wbs_dat_i,
    input  [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,
    input  [37:0] io_in,
    output [37:0] io_out,
    output [37:0] io_oeb,
    inout  [28:0] analog_io,
    input  user_clock2,
    output [2:0] user_irq
);
    localparam integer NU = 16;          // shrunk fabric USERIO_W
    localparam integer UBASE = 12;       // user_io occupies io[27:12]

    wire [NU-1:0] uio_out, uio_oeb, uio_in;

    // --- contract <- harness ---
    wire clk   = wb_clk_i;
    wire rst_n = ~wb_rst_i;
    wire cfg_sclk  = io_in[8];
    wire cfg_sdata = io_in[9];
    wire cfg_busy, cfg_done;
    assign uio_in = io_in[UBASE +: NU];

    chip_top #(
        .NumberOfRows(8), .NumberOfCols(8), .USERIO_W(16), .CONFIG_C_W(32),
        .N_USER_IO(NU)
    ) u_chip (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .uio_out(uio_out), .uio_oeb(uio_oeb), .uio_in(uio_in),
        .dbg_config_c()
    );

    // --- harness <- contract --- (explicit part-selects; no overlap, 38 bits)
    // io_out: status on [11:10], user out on [27:12], 0 elsewhere.
    assign io_out[9:0]         = 10'b0;                   // io[9:0]
    assign io_out[10]          = cfg_busy;
    assign io_out[11]          = cfg_done;
    assign io_out[UBASE +: NU] = uio_out;                // [27:12] user out
    assign io_out[37:UBASE+NU] = {(38-UBASE-NU){1'b0}};  // [37:28]

    // io_oeb: 0 = output-enabled (active low). Outputs: cfg_busy/done + user
    // pins whose uio_oeb is asserted-low; everything else input (1).
    assign io_oeb[9:0]         = 10'h3FF;                 // io[9:0] inputs
    assign io_oeb[10]          = 1'b0;                    // cfg_busy out
    assign io_oeb[11]          = 1'b0;                    // cfg_done out
    assign io_oeb[UBASE +: NU] = uio_oeb;                // user IO oe (active low)
    assign io_oeb[37:UBASE+NU] = {(38-UBASE-NU){1'b1}};  // [37:28] inputs

    // --- unused harness ports: safe tie-offs ---
    assign wbs_ack_o   = 1'b0;
    assign wbs_dat_o   = 32'b0;
    assign la_data_out = 128'b0;
    assign user_irq    = 3'b0;

    // silence unused
    wire _unused = &{1'b0, wb_clk_i, wbs_stb_i, wbs_cyc_i, wbs_we_i, wbs_sel_i,
                     wbs_dat_i, wbs_adr_i, la_data_in, la_oenb, user_clock2,
                     io_in[37:28], io_in[7:0], 1'b0};
endmodule
`default_nettype wire
