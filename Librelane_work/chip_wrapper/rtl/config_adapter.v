// config_adapter.v — thin MPW-neutral config front-end adapter.
//
// Per Dirk Koch (issue #16, FABulous upstream): preserve the existing FABulous
// frame protocol. The protocol's two-cycle strobe and address-before-frame
// sequencing already live INSIDE eFPGA_top's config controller. This adapter
// therefore stays deliberately thin: it presents one technology-neutral serial
// interface (cfg_sclk/cfg_sdata) and routes it to eFPGA_top's native serial
// front-end (s_clk/s_data). It does NOT re-implement frame addressing/strobing
// and adds NO backpressure (upstream intentionally avoids it).
//
// The parallel (SelfWriteData/SelfWriteStrobe) and UART (Rx) front-ends are
// left idle here; a Wishbone variant can bridge into SelfWriteData later
// without touching the fabric or this contract.

`default_nettype none
module config_adapter (
    input  wire        clk,        // chip clock (config + fabric)
    input  wire        rst_n,      // active-low reset

    // MPW-neutral contract: serial config in
    input  wire        cfg_sclk,
    input  wire        cfg_sdata,
    output wire        cfg_busy,   // observability: config front-end active
    output wire        cfg_done,   // observability: ready/idle

    // to eFPGA_top native front-ends
    output wire        efpga_CLK,
    output wire        efpga_resetn,
    output wire        efpga_s_clk,
    output wire        efpga_s_data,
    output wire        efpga_SelfWriteStrobe,
    output wire [31:0] efpga_SelfWriteData,
    output wire        efpga_Rx,
    input  wire        efpga_ComActive,
    input  wire        efpga_ReceiveLED
);
    // Serial path: straight wiring to the native FABulous serial loader.
    assign efpga_CLK    = clk;
    assign efpga_resetn = rst_n;
    assign efpga_s_clk  = cfg_sclk;
    assign efpga_s_data = cfg_sdata;

    // Parallel + UART front-ends idle.
    assign efpga_SelfWriteStrobe = 1'b0;
    assign efpga_SelfWriteData   = 32'b0;
    assign efpga_Rx              = 1'b1;   // UART idle line = high

    // Observability mapped from the controller's own status.
    assign cfg_busy = efpga_ComActive;
    assign cfg_done = ~efpga_ComActive;
endmodule
`default_nettype wire
