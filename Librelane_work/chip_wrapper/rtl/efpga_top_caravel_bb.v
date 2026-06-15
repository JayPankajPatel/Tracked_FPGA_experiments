// efpga_top_caravel_bb.v — black-box stub of the SHRUNK eFPGA_top (Caravel).
//
// CLEAN-ROOM NOTE: header copied verbatim from the FABulous-generated shrunk
// fabric (8 cols x 8 functional rows, DSP kept) — see chip_wrapper/fabric/
// caravel_shrunk.fabric.csv + tools/regen_caravel_fabric.sh. Widths are fixed
// by FABulous per fabric size: config_C [31:0] (=8 rows*4), user IO [15:0].
// 4x BlockRAM_1KB internally. Used to lint/bind chip_top for the Caravel
// target; the real module is generated (gitignored).

(* blackbox *)
module eFPGA_top #(
    parameter include_eFPGA    = 1,
    parameter NumberOfRows     = 8,
    parameter NumberOfCols     = 8,
    parameter FrameBitsPerRow  = 32,
    parameter MaxFramesPerCol  = 20,
    parameter desync_flag      = 20,
    parameter FrameSelectWidth = 5,
    parameter RowSelectWidth   = 5
) (
    output [31:0] A_config_C,
    output [31:0] B_config_C,
    output [31:0] Config_accessC,
    output [15:0] I_top,
    input  [15:0] O_top,
    output [15:0] T_top,
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
