`ifndef VERILATOR
`timescale 1ps / 1ps
`default_nettype none

module scmul_test_tb ();
    wire [55:0] I_top56  ;
    wire [55:0] T_top56  ;
    reg  [55:0] O_top56 = 0;
    // Logical 28-pin view of the west IO pins (the fabric now also has 28 east
    // pins; raw bit order interleaves W/E, so map explicitly).
    wire [27:0] I_top    ;
    wire [27:0] T_top    ;
    reg  [27:0] O_top = 0;
    wire [55:0] A_cfg, B_cfg;

    reg         CLK                 = 1'b0 ;
    reg         resetn              = 1'b1 ;
    reg         self_write_strobe   = 1'b0 ;
    reg  [31:0] self_write_data     = 32'b0;
    reg         rx                  = 1'b1 ;
    wire        com_active                 ;
    wire        receive_led                ;
    reg         s_clk               = 1'b0 ;
    reg         s_data              = 1'b0 ;

    // Instantiate both the fabric and the reference DUT
    eFPGA_top top_i (
        .I_top          (I_top56        ),
        .T_top          (T_top56        ),
        .O_top          (O_top56        ),
        .A_config_C     (A_cfg          ),
        .B_config_C     (B_cfg          ),
        .CLK            (CLK            ),
        .resetn         (resetn         ),
        .SelfWriteStrobe(self_write_strobe),
        .SelfWriteData  (self_write_data  ),
        .Rx             (rx             ),
        .ComActive      (com_active      ),
        .ReceiveLED     (receive_led     ),
        .s_clk          (s_clk          ),
        .s_data         (s_data         )
    );


    // IO mapping generated from Fabric/eFPGA_top.v (logical bit <- raw bit)
    assign I_top[0] = I_top56[0];
    assign T_top[0] = T_top56[0];
    assign I_top[1] = I_top56[1];
    assign T_top[1] = T_top56[1];
    assign I_top[2] = I_top56[4];
    assign T_top[2] = T_top56[4];
    assign I_top[3] = I_top56[5];
    assign T_top[3] = T_top56[5];
    assign I_top[4] = I_top56[8];
    assign T_top[4] = T_top56[8];
    assign I_top[5] = I_top56[9];
    assign T_top[5] = T_top56[9];
    assign I_top[6] = I_top56[12];
    assign T_top[6] = T_top56[12];
    assign I_top[7] = I_top56[13];
    assign T_top[7] = T_top56[13];
    assign I_top[8] = I_top56[16];
    assign T_top[8] = T_top56[16];
    assign I_top[9] = I_top56[17];
    assign T_top[9] = T_top56[17];
    assign I_top[10] = I_top56[20];
    assign T_top[10] = T_top56[20];
    assign I_top[11] = I_top56[21];
    assign T_top[11] = T_top56[21];
    assign I_top[12] = I_top56[24];
    assign T_top[12] = T_top56[24];
    assign I_top[13] = I_top56[25];
    assign T_top[13] = T_top56[25];
    assign I_top[14] = I_top56[28];
    assign T_top[14] = T_top56[28];
    assign I_top[15] = I_top56[29];
    assign T_top[15] = T_top56[29];
    assign I_top[16] = I_top56[32];
    assign T_top[16] = T_top56[32];
    assign I_top[17] = I_top56[33];
    assign T_top[17] = T_top56[33];
    assign I_top[18] = I_top56[36];
    assign T_top[18] = T_top56[36];
    assign I_top[19] = I_top56[37];
    assign T_top[19] = T_top56[37];
    assign I_top[20] = I_top56[40];
    assign T_top[20] = T_top56[40];
    assign I_top[21] = I_top56[41];
    assign T_top[21] = T_top56[41];
    assign I_top[22] = I_top56[44];
    assign T_top[22] = T_top56[44];
    assign I_top[23] = I_top56[45];
    assign T_top[23] = T_top56[45];
    assign I_top[24] = I_top56[48];
    assign T_top[24] = T_top56[48];
    assign I_top[25] = I_top56[49];
    assign T_top[25] = T_top56[49];
    assign I_top[26] = I_top56[52];
    assign T_top[26] = T_top56[52];
    assign I_top[27] = I_top56[53];
    assign T_top[27] = T_top56[53];
    always @* begin
        O_top56 = 56'b0;
        O_top56[0] = O_top[0];
        O_top56[1] = O_top[1];
        O_top56[4] = O_top[2];
        O_top56[5] = O_top[3];
        O_top56[8] = O_top[4];
        O_top56[9] = O_top[5];
        O_top56[12] = O_top[6];
        O_top56[13] = O_top[7];
        O_top56[16] = O_top[8];
        O_top56[17] = O_top[9];
        O_top56[20] = O_top[10];
        O_top56[21] = O_top[11];
        O_top56[24] = O_top[12];
        O_top56[25] = O_top[13];
        O_top56[28] = O_top[14];
        O_top56[29] = O_top[15];
        O_top56[32] = O_top[16];
        O_top56[33] = O_top[17];
        O_top56[36] = O_top[18];
        O_top56[37] = O_top[19];
        O_top56[40] = O_top[20];
        O_top56[41] = O_top[21];
        O_top56[44] = O_top[22];
        O_top56[45] = O_top[23];
        O_top56[48] = O_top[24];
        O_top56[49] = O_top[25];
        O_top56[52] = O_top[26];
        O_top56[53] = O_top[27];
    end

    // gold: the fused RTL instantiated directly (unsynthesized, unrouted) with
    // identical stimulus. Proves the IO -> switch matrix -> SCMUL tile wiring and
    // that nextpnr/bitstream place it correctly, cycle by cycle.
    wire [27:0] I_top_gold, T_top_gold;
    wire        gold_valid_out;
    wire [6:0]  gold_product;

    FABulous_sc_multiply_fused dut_i (
        .UserCLK   (CLK),
        .a         (O_top[7:0]),
        .b         (O_top[15:8]),
        .rst_n     (O_top[16]),
        .valid_in  (O_top[17]),
        .ready_out (O_top[18]),
        .valid_out (gold_valid_out),
        .product   (gold_product),
        .dummy_carry_in (1'b0),
        .dummy_carry_out ()
    );

    assign I_top_gold = {1'b0, gold_product, gold_valid_out, 19'b0};
    assign T_top_gold = ~{1'b1, 8'b00000000, 19'b1111111111111111111};

    localparam integer       MAX_BITBYTES               = 16384;
    reg                [7:0] bitstream   [MAX_BITBYTES]        ;

    always #5000 CLK = (CLK === 1'b0);

    integer i, n, b, errors_seen, outputs_seen;
    reg     have_errors = 1'b0;
    reg [7:0] pa, pb;

    reg [2047:0] bitstream_hex_arg  ;
    reg [2047:0] output_waveform_arg;
    initial begin
        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, scmul_test_tb);
        end
`ifndef EMULATION
        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            $readmemh(bitstream_hex_arg, bitstream);
            $display("Read bitstream hex from %s", bitstream_hex_arg);
        end else begin
            $display("Error: No bitstream provided as $plusargs bitstream_hex.");
            $fatal;
        end
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

        O_top = 28'b0;                 // reset asserted (rst_n = 0)
        repeat (5) @(posedge CLK);
        O_top[16] = 1'b1;              // release reset
        O_top[18] = 1'b1;              // ready_out: never stall
        repeat (5) @(posedge CLK);

        outputs_seen = 0;
        for (n = 0; n < 24; n = n + 1) begin
            case (n)
                0: begin pa = 8'd0;   pb = 8'd0;   end
                1: begin pa = 8'd255; pb = 8'd255; end
                2: begin pa = 8'd255; pb = 8'd0;   end
                3: begin pa = 8'd128; pb = 8'd128; end
                4: begin pa = 8'd51;  pb = 8'd153; end
                default: begin pa = $urandom_range(255, 0); pb = $urandom_range(255, 0); end
            endcase
            @(negedge CLK);
            O_top[7:0] = pa; O_top[15:8] = pb; O_top[17] = 1'b1;
            @(negedge CLK);
            O_top[17] = 1'b0;
            for (b = 0; b < 300; b = b + 1) begin
                @(negedge CLK);
                if (I_top[26:19] !== I_top_gold[26:19]) have_errors = 1'b1;
                if (T_top !== T_top_gold) have_errors = 1'b1;
                if (I_top_gold[19] === 1'b1) outputs_seen = outputs_seen + 1;
            end
            if (have_errors) begin
                $display("MISMATCH at a=%0d b=%0d (fabric product/valid %b vs gold %b)", pa, pb, I_top[26:19], I_top_gold[26:19]);
                $fatal;
            end
        end
        if (outputs_seen < 24) begin
            $display("FAIL: gold produced only %0d valid_out pulses (expected >= 24)", outputs_seen);
            $fatal;
        end
        $display("All 24 operand pairs matched gold cycle-for-cycle through the fabric (%0d valid pulses).", outputs_seen);
        $finish;
    end

endmodule
`endif
`default_nettype wire
