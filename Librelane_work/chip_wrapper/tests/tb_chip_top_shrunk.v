// tb_chip_top_shrunk.v — end-to-end chip_top sim at SHRUNK (8x8 Caravel) params
// (issue #16, V2). Shrunk-fabric analogue of tb_chip_top_efpga.v:
// serialize a real bitstream into chip_top's cfg_sclk/cfg_sdata contract,
// config_adapter emits SelfWriteData/SelfWriteStrobe into the REAL behavioral
// eFPGA_top (8x8), run the programmed design, compare against the golden.
//
// Select the design under test at compile time (same knobs as tb_shrunk_oracle):
//   -DDUT_MODULE=lfsr8 -DSTIM_LFSR8      (rst/en stimulus)
//   -DDUT_MODULE=shiftreg8               (en/serial-in stimulus; default)
// Pass the actual .bin byte count with +nbytes= (default 5784, the shrunk size).

`timescale 1ps/1ps
`default_nettype none

`ifndef DUT_MODULE
`define DUT_MODULE shiftreg8
`endif

module tb_chip_top_shrunk;
    localparam integer N = 16;            // shrunk USERIO_W
    reg clk = 1'b0, rst_n = 1'b0;
    reg cfg_sclk = 1'b0, cfg_sdata = 1'b0;
    wire cfg_busy, cfg_done;
    wire [N-1:0] uio_out, uio_oeb;
    reg  [N-1:0] uio_in = 0;

    // DUT: the MPW-neutral wrapper at shrunk-fabric params (matches the
    // generated 8x8 eFPGA_top: config_C[31:0], I/O/T_top[15:0]).
    chip_top #(
        .NumberOfRows(8), .NumberOfCols(8),
        .FrameBitsPerRow(32), .MaxFramesPerCol(20),
        .USERIO_W(16), .CONFIG_C_W(32),
        .N_USER_IO(N)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .uio_out(uio_out), .uio_oeb(uio_oeb), .uio_in(uio_in),
        .dbg_config_c()
    );

    // Behavioral golden (same RTL as the programmed design).
    wire [N-1:0] gold_out, gold_oeb;
    `DUT_MODULE gold_i (
        .clk(clk), .io_in(uio_in), .io_out(gold_out), .io_oeb(gold_oeb)
    );

    always #5000 clk = (clk === 1'b0);    // 10 ns period, as the oracle

    localparam integer MAX_BITBYTES = 16384;
    reg [7:0] bitstream [0:MAX_BITBYTES-1];
    integer i, errors = 0, nbytes;
    reg [31:0] word;
    reg [31:0] pat = 32'hA5C3_5A3C;
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

    // Watchdog: serial load is ~185k clk (~1.9 ms); fail loudly on hangs.
    initial begin
        #4_000_000_000;
        $display("FAIL: watchdog timeout");
        $fatal;
    end

    initial begin
        if (!$value$plusargs("bitstream_hex=%s", hexarg)) begin
            $display("FAIL: no bitstream_hex"); $fatal;
        end
        $readmemh(hexarg, bitstream);
        if (!$value$plusargs("nbytes=%d", nbytes)) nbytes = 5784;  // shrunk .bin length

        #100 rst_n = 1'b0; #10000 rst_n = 1'b1; #10000;
        repeat (20) @(posedge clk);

        // load the bitstream serially (adapter -> SelfWriteData/Strobe)
        for (i = 0; i + 3 < nbytes; i = i + 4) begin
            word = {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            send_word(word);
        end

        repeat (100) @(posedge clk);

        // Drive all user-input changes at the NEGEDGE (half-period setup):
        // writing inputs in the sampling-posedge timestep is a scheduling race
        // between the golden model and the fabric (see tb_shrunk_oracle.v).
`ifdef STIM_LFSR8
        @(negedge clk);
        uio_in = 16'h0003;                // rst+en: seed 0x01
        repeat (5) @(negedge clk);
        uio_in = 16'h0002;                // en: free-run
`else
        @(negedge clk);
        uio_in = 16'h0001;                // en; flush X with 24 defined shifts
        for (i = 0; i < 24; i = i + 1) begin
            uio_in[1] = pat[i % 32];
            @(negedge clk);
        end
`endif
        repeat (2) @(negedge clk);

        for (i = 0; i < 200; i = i + 1) begin
`ifndef STIM_LFSR8
            uio_in[1] = pat[(i + 7) % 32];  // negedge+delta: half-period setup
`endif
            @(negedge clk);
            if (uio_out !== gold_out)  errors = errors + 1;
            if (uio_oeb !== ~gold_oeb) errors = errors + 1;
        end

        $display("chip_top(uio_out)=0x%04x gold=0x%04x ; uio_oeb=0x%04x ~oeb_gold=0x%04x",
                 uio_out, gold_out, uio_oeb, ~gold_oeb);
        if (errors == 0) $display("PASS: chip_top serial-config matches behavioral golden");
        else             $display("FAIL: %0d mismatch(es)", errors);
        $finish;
    end
endmodule
`default_nettype wire
