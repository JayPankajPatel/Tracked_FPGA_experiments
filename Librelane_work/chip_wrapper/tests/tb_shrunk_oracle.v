// tb_shrunk_oracle.v — FABulous-oracle TB for the shrunk 8x8 Caravel fabric
// (issue #16, V2 behavioral / V3 gate-level).
//
// Mirrors upstream Test/sequential_16bit_en_tb.v: loads a real bitstream into
// eFPGA_top via the parallel SelfWriteData/SelfWriteStrobe path, runs the
// programmed design, and compares fabric user IO against the behavioral golden
// (the same RTL instantiated directly). 16-bit IO (shrunk fabric widths).
//
// The SAME TB serves V2 and V3: compile it against the behavioral fabric files
// for V2, or against the post-layout gate netlists (eFPGA.nl.v + tile .nl.v +
// sky130 functional cell models) for V3.
//
// Select the design under test at compile time:
//   -DDUT_MODULE=lfsr8 -DSTIM_LFSR8      (rst/en stimulus)
//   -DDUT_MODULE=shiftreg8               (en/serial-in stimulus; default)

`timescale 1ps / 1ps
`default_nettype none

`ifndef DUT_MODULE
`define DUT_MODULE shiftreg8
`endif

// Clock half-period in ps. Behavioral runs use the default 5000 (10 ns period,
// as upstream). GATE-LEVEL runs must slow the clock (e.g. -DHALF_PERIOD_PS=50000
// -> 100 ns period): with -DUNIT_DELAY='#1' every sky130 cell adds 1 ns, so a
// deep fabric routing path needs far more than 10 ns to settle. The watchdog
// scales with the period automatically.
`ifndef HALF_PERIOD_PS
`define HALF_PERIOD_PS 5000
`endif

module tb_shrunk_oracle ();
    wire [15:0] I_top;
    wire [15:0] T_top;
    reg  [15:0] O_top = 16'b0;
    wire [31:0] A_cfg, B_cfg;

    reg         CLK               = 1'b0 ;
    reg         resetn            = 1'b1 ;
    reg         self_write_strobe = 1'b0 ;
    reg  [31:0] self_write_data   = 32'b0;
    reg         rx                = 1'b1 ;
    wire        com_active               ;
    wire        receive_led              ;
    reg         s_clk             = 1'b0 ;
    reg         s_data            = 1'b0 ;

    // Fabric under test (shrunk 8x8: generated defaults are already 8/8/32/20).
    eFPGA_top top_i (
        .I_top          (I_top            ),
        .T_top          (T_top            ),
        .O_top          (O_top            ),
        .A_config_C     (A_cfg            ),
        .B_config_C     (B_cfg            ),
        .CLK            (CLK              ),
        .resetn         (resetn           ),
        .SelfWriteStrobe(self_write_strobe),
        .SelfWriteData  (self_write_data  ),
        .Rx             (rx               ),
        .ComActive      (com_active       ),
        .ReceiveLED     (receive_led      ),
        .s_clk          (s_clk            ),
        .s_data         (s_data           )
    );

    // Behavioral golden: the identical user RTL, driven with the same inputs.
    wire [15:0] gold_out, gold_oeb;
    `DUT_MODULE gold_i (
        .clk   (CLK     ),
        .io_in (O_top   ),
        .io_out(gold_out),
        .io_oeb(gold_oeb)
    );
    // IO cell inverts: fabric T_top = ~io_oeb (see baseline oracle TB).
    wire [15:0] T_top_gold = ~gold_oeb;

    localparam integer MAX_BITBYTES = 16384;
    reg [7:0] bitstream [0:MAX_BITBYTES-1];

    always #(`HALF_PERIOD_PS) CLK = (CLK === 1'b0);

    integer i, errors = 0;
    reg [31:0] pat = 32'hA5C3_5A3C;      // defined serial pattern (shiftreg8)
    reg [2047:0] bitstream_hex_arg, output_waveform_arg;

    // Watchdog: bitstream load is ~24.6k clk; ~80k periods of margin, scaled
    // with the configured clock (800 us at the default 10 ns period).
    initial begin
        #(160000 * (`HALF_PERIOD_PS));
        $display("FAIL: watchdog timeout");
        $fatal;
    end

    initial begin
        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, tb_shrunk_oracle);
        end

        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            $readmemh(bitstream_hex_arg, bitstream);
        end else begin
            $display("FAIL: no bitstream_hex plusarg"); $fatal;
        end

        #100;   resetn = 1'b0;
        #10000; resetn = 1'b1;
        #10000;
        repeat (20) @(posedge CLK);
        #2500;
        // Parallel SelfWrite load, upstream cadence (2 clk data, 1 clk strobe, 2 clk gap).
        for (i = 0; i < MAX_BITBYTES; i = i + 4) begin
            self_write_data <= {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            repeat (2) @(posedge CLK);
            self_write_strobe <= 1'b1;
            @(posedge CLK);
            self_write_strobe <= 1'b0;
            repeat (2) @(posedge CLK);
        end

        repeat (100) @(posedge CLK);
`ifdef DBG_PROGRESS
        $display("dbg post-config: I_top=%b T_top=%b", I_top, T_top);
`endif

        // All stimulus changes below happen at the NEGEDGE: writing inputs in
        // the same timestep as the sampling posedge is a scheduling race, and
        // the behavioral golden vs the gate netlist can legally sample opposite
        // sides of it (observed as a single wrong bit entering the shift chain).
`ifdef STIM_LFSR8
        // lfsr8: io_in[0]=rst (seeds 0x01), io_in[1]=en.
        @(negedge CLK);
        O_top = 16'h0003;                 // rst+en: seed
        repeat (5) @(negedge CLK);
        O_top = 16'h0002;                 // en: free-run
`else
        // shiftreg8: io_in[0]=en, io_in[1]=sin. Flush power-up X with 24
        // defined shifts before comparing (no reset by design).
        @(negedge CLK);
        O_top = 16'h0001;
        for (i = 0; i < 24; i = i + 1) begin
            O_top[1] = pat[i % 32];
            @(negedge CLK);
        end
`endif
        repeat (2) @(negedge CLK);   // stay on negedge phase: all writes mid-cycle
`ifdef DBG_PROGRESS
        $display("dbg post-flush : I_top=%b T_top=%b gold=%b", I_top, T_top, gold_out);
`endif

        for (i = 0; i < 200; i = i + 1) begin
`ifndef STIM_LFSR8
            O_top[1] = pat[(i + 7) % 32]; // negedge+delta: half-period setup
`endif
            @(negedge CLK);
            if (I_top !== gold_out) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  mismatch @i=%0d I_top=%b gold=%b", i, I_top, gold_out);
            end
            if (T_top !== T_top_gold) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  T mismatch @i=%0d T_top=%b gold=%b", i, T_top, T_top_gold);
            end
        end

        $display("fabric(I_top)=0x%04x gold=0x%04x ; fabric(T_top)=0x%04x gold=0x%04x",
                 I_top, gold_out, T_top, T_top_gold);
        if (errors == 0) $display("PASS: fabric matches behavioral golden (200 cycles)");
        else begin
            // bit-level detail: X bits map to W_IO rows via the top_wrapper BEL
            // map (io15=X0Y1.A, io14=X0Y1.B, ... io1=X0Y8.A, io0=X0Y8.B)
            $display("FAIL: %0d mismatch(es) over 200 cycles", errors);
            $display("  I_top=%b", I_top);
            $display("  gold =%b", gold_out);
            $display("  T_top=%b", T_top);
        end
        $finish;
    end
endmodule
`default_nettype wire
