// chip_top_standalone.v — standalone sky130 pad shim for chip_top.
//
// The MPW-neutral half is chip_top; this shim is the only per-MPW piece. It
// resolves the tri-state-friendly {uio_out,uio_oeb,uio_in} contract into real
// bidirectional pads and presents the standalone chip's top-level ports. A
// Caravel shim would instead map the same chip_top contract onto io_in/io_out/
// io_oeb + Wishbone (deferred: Caravel is area-non-conformant for baseline14 —
// see tools/check_conformance.py; needs a shrunk fabric).

`default_nettype none
module chip_top_standalone #(
    parameter N_USER_IO = 28
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 cfg_sclk,
    input  wire                 cfg_sdata,
    output wire                 cfg_busy,
    output wire                 cfg_done,
    inout  wire [N_USER_IO-1:0] uio          // bidirectional user pads
);
    wire [N_USER_IO-1:0] uio_out, uio_oeb, uio_in;

    // Resolve inout pads: oeb active-low (drive when oeb==0).
    genvar i;
    generate
        for (i = 0; i < N_USER_IO; i = i + 1) begin : g_pad
            assign uio[i]    = (uio_oeb[i] == 1'b0) ? uio_out[i] : 1'bz;
            assign uio_in[i] = uio[i];
        end
    endgenerate

    chip_top #(.N_USER_IO(N_USER_IO)) u_core (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .uio_out(uio_out), .uio_oeb(uio_oeb), .uio_in(uio_in),
        .dbg_config_c()
    );
endmodule
`default_nettype wire
