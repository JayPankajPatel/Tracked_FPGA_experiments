`ifndef VERILATOR
`timescale 1ps / 1ps
`default_nettype none

// Functional (non-EMULATION) testbench for sc_multiply_chain_fabric on the
// shrunk 8x8 FABulous fabric. Loads the real generated bitstream via the
// fabric's own self-write config protocol (same mechanism
// sequential_16bit_en_tb.v uses for the default larger demo fabric --
// widths here are re-derived for THIS fabric, not copied: eFPGA_top here
// has [15:0] I_top/O_top/T_top and [31:0] A_config_C/B_config_C, confirmed
// by reading Fabric/eFPGA_top.v directly rather than assuming the other
// testbench's widths apply), then compares the configured fabric's output
// bit-for-bit against sc_multiply_chain_fabric instantiated directly
// (the golden RTL model, bypassing fabric mapping entirely) every cycle.
//
// Bit-index mapping confirmed directly from eFPGA_top.v's own tile
// connections (Tile_X0Y8_B_O_top -> O_top[0], ..., Tile_X0Y1_A_O_top ->
// O_top[15], and the same ordering for I_top/T_top): this is an exact,
// unreversed match to top_wrapper_sc_multiply_chain_fabric.v's own
// io<N>_i BEL numbering (io0_i = X0Y8.B, io15_i = X0Y1.A). So
// O_top[15:0] === io_in[15:0], I_top[15:0] === io_out[15:0], and
// T_top[15:0] === io_oeb[15:0] with no bit reversal needed. Per
// sc_multiply_chain_fabric.v's own pin map, io_in[0] is rst.
module sc_multiply_chain_fabric_tb ();
    wire [15:0] I_top, T_top;
    reg  [15:0] O_top = 0;
    wire [31:0] A_cfg, B_cfg, Config_accessC;

    reg         CLK               = 1'b0;
    reg         resetn            = 1'b1;
    reg         self_write_strobe = 1'b0;
    reg  [31:0] self_write_data   = 32'b0;
    reg         rx                = 1'b1;
    wire        com_active;
    wire        receive_led;
    reg         s_clk             = 1'b0;
    reg         s_data            = 1'b0;

    // Fabric under test, configured via the real generated bitstream below.
    eFPGA_top top_i (
        .I_top          (I_top            ),
        .T_top          (T_top            ),
        .O_top          (O_top            ),
        .A_config_C     (A_cfg            ),
        .B_config_C     (B_cfg            ),
        .Config_accessC (Config_accessC   ),
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

    // Golden model: the exact same RTL source, instantiated directly
    // (never mapped onto the fabric) as the reference the fabric-configured
    // DUT must match cycle-for-cycle.
    wire [15:0] I_top_gold, oeb_gold, T_top_gold;
    sc_multiply_chain_fabric dut_i (
        .clk   (CLK       ),
        .io_out(I_top_gold),
        .io_oeb(oeb_gold  ),
        .io_in (O_top     )
    );
    assign T_top_gold = ~oeb_gold;

    localparam integer       MAX_BITBYTES = 16384;
    reg                [7:0] bitstream    [MAX_BITBYTES];

    always #5000 CLK = (CLK === 1'b0);

    integer i;
    reg     have_errors = 1'b0;
    integer error_count = 0;
    integer sample_count = 0;

    reg [2047:0] bitstream_hex_arg;
    reg [2047:0] output_waveform_arg;
    initial begin
        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, sc_multiply_chain_fabric_tb);
            $display("Output waveform set to %s", output_waveform_arg);
        end

`ifndef EMULATION
        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            $readmemh(bitstream_hex_arg, bitstream);
            $display("Read bitstream hex from %s", bitstream_hex_arg);
        end else begin
            $display("Error: No bitstream provided as $plusargs bitstream_hex.");
            $fatal;
        end

        // Reset the fabric's own self-write config engine, then shift the
        // real bitstream in -- this is infrastructure reset, separate from
        // this design's own io_in[0] functional reset below.
        #100;
        resetn = 1'b0;
        #10000;
        resetn = 1'b1;
        #10000;
        repeat (20) @(posedge CLK);
        #2500;
        for (i = 0; i < MAX_BITBYTES; i = i + 4) begin
            self_write_data <= {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            repeat (2) @(posedge CLK);
            self_write_strobe <= 1'b1;
            @(posedge CLK);
            self_write_strobe <= 1'b0;
            repeat (2) @(posedge CLK);
        end
`endif
        repeat (100) @(posedge CLK);

        // Now drive this design's own functional reset (io_in[0]) -- both
        // the fabric-configured DUT and the golden model see this on the
        // same O_top wire, so both start their internal encoders/LFSRs from
        // INIT_SEED at the same simulated cycle regardless of whatever
        // state config-loading left the fabric's registers in.
        O_top = 16'b0000_0000_0000_0001;  // io_in[0] = rst = 1
        repeat (5) @(posedge CLK);
        O_top = 16'b0000_0000_0000_0000;  // rst = 0, free-run

        // WIDTH=8 bursts are ~255 real-transfer cycles each way; run long
        // enough to see several complete binary_out results from both
        // sides, not just the first one.
        for (i = 0; i < 20000; i = i + 1) begin
            @(negedge CLK);
            if (I_top !== I_top_gold || T_top !== T_top_gold) begin
                have_errors = 1'b1;
                error_count = error_count + 1;
                if (error_count <= 20)
                    $display("MISMATCH @cycle %0d: fabric(I_top)=0x%X gold=0x%X, fabric(T_top)=0x%X gold=0x%X",
                        i, I_top, I_top_gold, T_top, T_top_gold);
            end
            // valid_binary_out is io_out[9] == I_top[9] on the golden side.
            if (I_top_gold[9] === 1'b1) begin
                sample_count = sample_count + 1;
                $display("cycle %0d: valid_binary_out fired, binary_out=%0d (fabric) / %0d (gold), operand_a_captured=%0d operand_b_captured=%0d free_running_a=%0d free_running_b=%0d",
                    i, I_top[8:1], I_top_gold[8:1],
                    dut_i.chain_i.u_encoder_a.r.binary_in_d,
                    dut_i.chain_i.u_encoder_b.r.binary_in_d,
                    dut_i.binary_in_a, dut_i.binary_in_b);
            end
        end

        $display("Total mismatched cycles: %0d / 20000", error_count);
        $display("Total valid_binary_out samples observed: %0d", sample_count);

        if (have_errors) $fatal;
        else $finish;
    end

endmodule
`endif
`default_nettype wire
