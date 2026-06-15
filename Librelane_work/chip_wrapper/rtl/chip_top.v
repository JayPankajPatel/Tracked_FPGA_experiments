// chip_top.v — parametrized, MPW-neutral chip wrapper for the eFPGA macro.
//
// Issue #16. Presents a single FIXED interface contract independent of fabric
// size; per-MPW integration is a thin pad shim (see shims/) that maps this
// contract onto a specific harness (Caravel user_project_wrapper, standalone
// pad ring, ...). Fabric size is a parameter set, so the SAME wrapper retargets
// any MPW by changing size + shim — see docs/issue-16/mpw-validation-plan.md.
//
// Internally instantiates eFPGA_top (config controller + BRAM models + the
// hardened eFPGA macro). config_C readback monitors are observability-only and
// are dropped here by default (DROP_CONFIG_C=1); a small debug subset can be
// exposed via DBG_CONFIG_C_W if a profile asks for it.

`default_nettype none
module chip_top #(
    // --- fabric size knobs (defaults = baseline 14-row demo fabric) ---
    // These size chip_top's own internal nets and the io_mux; they must MATCH
    // the (hardcoded) widths of the generated eFPGA_top for the chosen fabric.
    // A different fabric size means REGENERATING eFPGA_top, not just changing
    // these — eFPGA_top has no width parameters (see efpga_top_bb.v).
    parameter NumberOfRows    = 14,
    parameter NumberOfCols    = 10,
    parameter FrameBitsPerRow = 32,
    parameter MaxFramesPerCol = 20,
    parameter USERIO_W        = 28,           // fabric user-IO triples (eFPGA_top [27:0])
    parameter CONFIG_C_W      = 56,           // config_C monitors (eFPGA_top [55:0])
    // --- MPW knobs ---
    parameter N_USER_IO       = 28,           // chip user pins exposed (<= USERIO_W)
    parameter DROP_CONFIG_C   = 1,            // 1 = config_C monitors not exposed
    parameter DBG_CONFIG_C_W  = 0             // optional debug monitor bits (<= CONFIG_C_W)
) (
    input  wire                       clk,
    input  wire                       rst_n,
    // config (MPW-neutral serial contract)
    input  wire                       cfg_sclk,
    input  wire                       cfg_sdata,
    output wire                       cfg_busy,
    output wire                       cfg_done,
    // user IO (tri-state-friendly view; shim resolves the pad)
    output wire [N_USER_IO-1:0]       uio_out,
    output wire [N_USER_IO-1:0]       uio_oeb,
    input  wire [N_USER_IO-1:0]       uio_in,
    // optional debug monitors (width 0 => absent)
    output wire [(DBG_CONFIG_C_W>0?DBG_CONFIG_C_W:1)-1:0] dbg_config_c
);
    // ---- internal nets to eFPGA_top ----
    wire [CONFIG_C_W-1:0] A_config_C, B_config_C, Config_accessC;
    wire [USERIO_W-1:0]   I_top, O_top, T_top;
    wire efpga_CLK, efpga_resetn, efpga_s_clk, efpga_s_data;
    wire efpga_SelfWriteStrobe; wire [31:0] efpga_SelfWriteData;
    wire efpga_Rx, efpga_ComActive, efpga_ReceiveLED;

    // ---- config adapter (thin; serial -> SelfWriteData/SelfWriteStrobe, the
    //      path the FABulous oracle drives; preserves the frame protocol) ----
    config_adapter u_cfg (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .efpga_CLK(efpga_CLK), .efpga_resetn(efpga_resetn),
        .efpga_SelfWriteStrobe(efpga_SelfWriteStrobe),
        .efpga_SelfWriteData(efpga_SelfWriteData),
        .efpga_s_clk(efpga_s_clk), .efpga_s_data(efpga_s_data),
        .efpga_Rx(efpga_Rx),
        .efpga_ComActive(efpga_ComActive), .efpga_ReceiveLED(efpga_ReceiveLED)
    );

    // ---- user IO mux ----
    io_mux #(.USERIO_W(USERIO_W), .N_USER_IO(N_USER_IO)) u_iomux (
        .uio_out(uio_out), .uio_oeb(uio_oeb), .uio_in(uio_in),
        .O_top(O_top), .I_top(I_top), .T_top(T_top)
    );

    // ---- fabric (macro + controller + BRAM) ----
    // Only the real eFPGA_top parameters are passed; widths are fixed in the
    // generated module per fabric size (no CONFIG_C_W/USERIO_W params exist).
    eFPGA_top #(
        .NumberOfRows(NumberOfRows), .NumberOfCols(NumberOfCols),
        .FrameBitsPerRow(FrameBitsPerRow), .MaxFramesPerCol(MaxFramesPerCol)
    ) u_efpga (
        .A_config_C(A_config_C), .B_config_C(B_config_C),
        .Config_accessC(Config_accessC),
        .I_top(I_top), .O_top(O_top), .T_top(T_top),
        .CLK(efpga_CLK), .resetn(efpga_resetn),
        .SelfWriteStrobe(efpga_SelfWriteStrobe), .SelfWriteData(efpga_SelfWriteData),
        .Rx(efpga_Rx), .ComActive(efpga_ComActive), .ReceiveLED(efpga_ReceiveLED),
        .s_clk(efpga_s_clk), .s_data(efpga_s_data)
    );

    // ---- config_C monitor disposition ----
    // Expose a small debug subset only if a profile both asks for it
    // (DBG_CONFIG_C_W>0) and does not drop monitors (DROP_CONFIG_C==0).
    generate
        if (DBG_CONFIG_C_W > 0 && DROP_CONFIG_C == 0) begin : g_dbg
            assign dbg_config_c = A_config_C[DBG_CONFIG_C_W-1:0];
        end else begin : g_nodbg
            assign dbg_config_c = {(DBG_CONFIG_C_W>0?DBG_CONFIG_C_W:1){1'b0}};
        end
    endgenerate

    // Drop unused monitors explicitly (observability-only; not chip-facing).
    wire _unused_ok = |{A_config_C, B_config_C, Config_accessC, efpga_ReceiveLED};
endmodule
`default_nettype wire
