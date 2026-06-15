// tb_chip_top_efpga.v — end-to-end functional sim (issue #16, advisor gate).
//
// Proves the FULL wrapper path: serialize a real FABulous bitstream into
// chip_top's compact cfg_sclk/cfg_sdata contract, let config_adapter emit the
// SelfWriteData/SelfWriteStrobe sequence into the REAL behavioral eFPGA_top,
// run the programmed design, and compare user IO to the behavioral golden.
// Equivalence target: chip_top-via-serial == oracle's parallel-SelfWrite result.
//
// Compiled against the generated baseline (14-row) behavioral fabric files +
// user_design/sequential_16bit_en.v. Confirms: (a) adapter strobe cadence is
// accepted by ConfigFSM, (b) T_top/uio_oeb polarity, (c) the bitstream loads.

`timescale 1ps/1ps
`default_nettype none
module tb_chip_top_efpga;
    localparam integer N = 28;            // baseline USERIO_W
    reg clk = 1'b0, rst_n = 1'b0;
    reg cfg_sclk = 1'b0, cfg_sdata = 1'b0;
    wire cfg_busy, cfg_done;
    wire [N-1:0] uio_out, uio_oeb;
    reg  [N-1:0] uio_in = 0;

    // DUT: the MPW-neutral wrapper around the real eFPGA_top (baseline params).
    chip_top #(.N_USER_IO(N)) dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .uio_out(uio_out), .uio_oeb(uio_oeb), .uio_in(uio_in),
        .dbg_config_c()
    );

    // Behavioral golden (same as the oracle TB).
    wire [N-1:0] I_top_gold, oeb_gold;
    sequential_16bit_en gold_i (
        .clk(clk), .io_out(I_top_gold), .io_oeb(oeb_gold), .io_in(uio_in)
    );

    always #5000 clk = (clk === 1'b0);    // match oracle 10 ns period

    localparam integer MAX_BITBYTES = 16384;
    reg [7:0] bitstream [0:MAX_BITBYTES-1];
    integer i, errors = 0, nbytes;
    reg [31:0] word;
    reg [2047:0] hexarg;

    // serialize one 32-bit word MSB-first into the cfg serial contract
    task send_word(input [31:0] w);
        integer b;
        begin
            for (b = 31; b >= 0; b = b - 1) begin
                cfg_sdata = w[b];
                @(posedge clk); @(posedge clk); cfg_sclk = 1'b1;  // high >=2 clk
                @(posedge clk); @(posedge clk); cfg_sclk = 1'b0;  // low  >=2 clk
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("bitstream_hex=%s", hexarg)) begin
            $display("FATAL: no bitstream_hex"); $fatal;
        end
        $readmemh(hexarg, bitstream);
        if (!$value$plusargs("nbytes=%d", nbytes)) nbytes = 12024;  // .bin length

        #100 rst_n = 1'b0; #10000 rst_n = 1'b1; #10000;
        repeat (20) @(posedge clk);

        // load the bitstream serially (adapter -> SelfWriteData/Strobe)
        for (i = 0; i + 3 < nbytes; i = i + 4) begin
            word = {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            send_word(word);
        end

        repeat (100) @(posedge clk);
        // enable + reset counter, then release reset (same stimulus as oracle)
        uio_in = 28'h0000003;
        repeat (5) @(posedge clk);
        uio_in = 28'h0000002;

        for (i = 0; i < 100; i = i + 1) begin
            @(negedge clk);
            if (uio_out  !== I_top_gold) errors = errors + 1;
            if (uio_oeb  !== ~oeb_gold)  errors = errors + 1;
        end

        $display("chip_top(uio_out)=0x%07x gold=0x%07x ; uio_oeb=0x%07x ~oeb_gold=0x%07x",
                 uio_out, I_top_gold, uio_oeb, ~oeb_gold);
        if (errors == 0) $display("PASS: chip_top serial-config matches behavioral golden");
        else             $display("FAIL: %0d mismatch(es)", errors);
        $finish;
    end
endmodule
`default_nettype wire
