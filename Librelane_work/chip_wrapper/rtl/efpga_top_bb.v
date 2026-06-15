// efpga_top_bb.v — black-box stub of the FABulous-generated eFPGA_top.
//
// CLEAN-ROOM NOTE: the real eFPGA_top.v (and the hardened eFPGA macro it
// wraps) are generated artifacts living under the gitignored FABulous_work/.
// This stub exists only so the wrapper RTL elaborates/lints/synthesizes with
// the macro treated as a black box, exactly as the chip-level P&R flow sees
// it. Port list + widths mirror the baseline 14-row demo fabric
// (NumberOfRows=14, NumberOfCols=10, FrameBitsPerRow=32, MaxFramesPerCol=20).
// Regenerate the real module via the issue-16 regeneration script before sim
// against the FABulous oracle or before hardening.
//
// Width relationships (parametrized by fabric size in the wrapper):
//   config_C / Config_accessC width = NumberOfRows*4   (=56 for 14 rows)
//   user IO triple width            = N_USER_IO_FABRIC  (=28 for the demo)

(* blackbox *)
module eFPGA_top #(
    parameter include_eFPGA   = 1,
    parameter NumberOfRows    = 14,
    parameter NumberOfCols    = 10,
    parameter FrameBitsPerRow = 32,
    parameter MaxFramesPerCol = 20,
    parameter desync_flag     = 20,
    parameter FrameSelectWidth= 5,
    parameter RowSelectWidth  = 5,
    parameter CONFIG_C_W      = 56,   // = NumberOfRows*4
    parameter USERIO_W        = 28    // bidirectional user IO triples
) (
    // External user IO (bidirectional triples: O=in from pad, I=out to pad, T=oe_bar)
    output [CONFIG_C_W-1:0] A_config_C,
    output [CONFIG_C_W-1:0] B_config_C,
    output [CONFIG_C_W-1:0] Config_accessC,
    output [USERIO_W-1:0]   I_top,
    input  [USERIO_W-1:0]   O_top,
    output [USERIO_W-1:0]   T_top,
    // Config-related ports (FABulous standard front-ends)
    input                   CLK,
    input                   resetn,
    input                   SelfWriteStrobe,
    input  [31:0]           SelfWriteData,
    input                   Rx,
    output                  ComActive,
    output                  ReceiveLED,
    input                   s_clk,
    input                   s_data
);
endmodule
