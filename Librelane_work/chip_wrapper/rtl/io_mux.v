// io_mux.v — maps N_USER_IO chip pins onto the fabric's bidirectional user IO.
//
// Fabric convention (FABulous, confirmed from eFPGA LEF directions and the
// FABulous top_wrapper): O_top = input to fabric (driven from pad),
// I_top = output from fabric (to pad), T_top = output-enable_bar (oe active-low,
// matches Caravel io_oeb). We expose a tri-state-friendly {out,oeb,in} view so
// each MPW shim resolves the actual pad (inout, or harness io_* bus) itself.
//
// N_USER_IO may be <= USERIO_W. Unmapped fabric inputs (O_top) are tied 0;
// unmapped fabric outputs (I_top/T_top) are left unconnected at this level.

`default_nettype none
module io_mux #(
    parameter USERIO_W   = 28,   // fabric user-IO triples available
    parameter N_USER_IO  = 28    // chip pins exposed (<= USERIO_W)
) (
    // chip-facing (to shim/pad)
    output wire [N_USER_IO-1:0] uio_out,   // value fabric drives out
    output wire [N_USER_IO-1:0] uio_oeb,   // output-enable_bar (active low)
    input  wire [N_USER_IO-1:0] uio_in,    // value sampled from pad

    // fabric-facing (to eFPGA_top)
    output wire [USERIO_W-1:0]  O_top,      // -> fabric inputs
    input  wire [USERIO_W-1:0]  I_top,      // <- fabric outputs
    input  wire [USERIO_W-1:0]  T_top       // <- fabric oe_bar
);
    genvar i;
    generate
        for (i = 0; i < USERIO_W; i = i + 1) begin : g_map
            if (i < N_USER_IO) begin : g_exposed
                assign O_top[i]   = uio_in[i];
                assign uio_out[i] = I_top[i];
                assign uio_oeb[i] = T_top[i];
            end else begin : g_tied
                assign O_top[i] = 1'b0;      // unexposed fabric input
            end
        end
    endgenerate
endmodule
`default_nettype wire
