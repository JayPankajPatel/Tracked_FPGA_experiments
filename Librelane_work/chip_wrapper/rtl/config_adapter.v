// config_adapter.v — thin MPW-neutral config front-end adapter.
//
// Per Dirk Koch (issue #16, FABulous upstream): preserve the existing FABulous
// frame protocol; receive COMPACT external writes and emit them into the
// existing controller; add no backpressure. The two-cycle strobe and
// address-before-frame sequencing live INSIDE eFPGA_top's controller — this
// adapter does not re-implement them.
//
// Verified against the FABulous-sim oracle (fabric_baseline_proj/Test/
// sequential_16bit_en_tb.v): the bitstream is loaded over the PARALLEL
// SelfWriteData[31:0] + SelfWriteStrobe path, NOT the serial s_clk/s_data path.
// The oracle drives one 32-bit word every ~5 CLKs:
//     self_write_data <= word; repeat(2)@CLK; strobe=1; @CLK; strobe=0; repeat(2)@CLK;
//
// To stay pad-limited, this adapter takes a compact serial input (cfg_sclk/
// cfg_sdata, SPI-like, MSB-first, 32 bits/word) and deserializes it into that
// SelfWriteData/SelfWriteStrobe sequence in the CLK domain. The external host
// streams each SelfWrite word MSB-first. cfg_sclk is assumed slower than clk.
//
// NOTE: the exact strobe cadence vs the controller must be confirmed in the
// functional sim against the oracle (validation layer 3) before claiming
// bit-accurate config load.

`default_nettype none
module config_adapter (
    input  wire        clk,        // chip clock (config + fabric, -> eFPGA_top CLK)
    input  wire        rst_n,      // active-low reset

    // MPW-neutral contract: compact serial config in
    input  wire        cfg_sclk,
    input  wire        cfg_sdata,
    output wire        cfg_busy,   // a word is mid-load
    output reg         cfg_done,   // a word was just committed (1-clk pulse)

    // to eFPGA_top native parallel front-end (the oracle path)
    output wire        efpga_CLK,
    output wire        efpga_resetn,
    output reg         efpga_SelfWriteStrobe,
    output reg  [31:0] efpga_SelfWriteData,
    // unused native front-ends held idle
    output wire        efpga_s_clk,
    output wire        efpga_s_data,
    output wire        efpga_Rx,
    input  wire        efpga_ComActive,
    input  wire        efpga_ReceiveLED
);
    assign efpga_CLK    = clk;
    assign efpga_resetn = rst_n;
    assign efpga_s_clk  = 1'b0;
    assign efpga_s_data = 1'b0;
    assign efpga_Rx     = 1'b1;     // UART idle line = high

    // --- CDC: synchronize cfg_sclk/cfg_sdata into the clk domain ---
    reg [2:0] sclk_sync;
    reg [1:0] sdat_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            sdat_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], cfg_sclk};
            sdat_sync <= {sdat_sync[0],  cfg_sdata};
        end
    end
    wire sclk_rise = (sclk_sync[2:1] == 2'b01);
    wire sdat_q    =  sdat_sync[1];

    // --- 32-bit MSB-first shift register + bit counter ---
    reg [31:0] shifter;
    reg [5:0]  bitcnt;          // 0..32
    assign cfg_busy = (bitcnt != 6'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shifter               <= 32'b0;
            bitcnt                <= 6'd0;
            efpga_SelfWriteData   <= 32'b0;
            efpga_SelfWriteStrobe <= 1'b0;
            cfg_done              <= 1'b0;
        end else begin
            efpga_SelfWriteStrobe <= 1'b0;   // default: 1-clk strobe
            cfg_done              <= 1'b0;
            if (sclk_rise) begin
                shifter <= {shifter[30:0], sdat_q};
                if (bitcnt == 6'd31) begin
                    // 32nd bit just arrived -> commit the word
                    efpga_SelfWriteData   <= {shifter[30:0], sdat_q};
                    efpga_SelfWriteStrobe <= 1'b1;
                    cfg_done              <= 1'b1;
                    bitcnt                <= 6'd0;
                end else begin
                    bitcnt <= bitcnt + 6'd1;
                end
            end
        end
    end
endmodule
`default_nettype wire
