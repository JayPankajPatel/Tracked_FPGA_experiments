// efpga_top_bb.v — black-box stub of the FABulous-generated eFPGA_top.
//
// CLEAN-ROOM NOTE: the real eFPGA_top.v (and the hardened eFPGA macro it
// wraps) are generated artifacts under the gitignored FABulous_work/. This stub
// exists only so the wrapper RTL elaborates/lints with the macro as a black
// box. Its parameter list, port list, and PORT WIDTHS are copied VERBATIM from
// the generated baseline 14-row demo `eFPGA_top.v` header — do not add
// synthetic parameters here, or the wrapper will fail to bind against the real
// module. Widths are hardcoded by FABulous per fabric size: a different fabric
// size means REGENERATING eFPGA_top (new fixed widths), not overriding params.
//   config_C / Config_accessC : [55:0]  (= NumberOfRows*4 - 1 : 0, 14 rows)
//   user IO triples           : [27:0]

(* blackbox *)
module eFPGA_top #(
    parameter include_eFPGA    = 1,
    parameter NumberOfRows     = 14,
    parameter NumberOfCols     = 10,
    parameter FrameBitsPerRow  = 32,
    parameter MaxFramesPerCol  = 20,
    parameter desync_flag      = 20,
    parameter FrameSelectWidth = 5,
    parameter RowSelectWidth   = 5
) (
    // External user IO (O=in from pad, I=out to pad, T=oe; note IO cell does T_top=~T)
    output [55:0] A_config_C,
    output [55:0] B_config_C,
    output [55:0] Config_accessC,
    output [27:0] I_top,
    input  [27:0] O_top,
    output [27:0] T_top,
    // Config-related ports (FABulous standard front-ends)
    input         CLK,
    input         resetn,
    input         SelfWriteStrobe,
    input  [31:0] SelfWriteData,
    input         Rx,
    output        ComActive,
    output        ReceiveLED,
    input         s_clk,
    input         s_data
);
endmodule
