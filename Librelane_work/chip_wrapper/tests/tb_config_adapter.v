// tb_config_adapter.v — PDK-free unit test for config_adapter.
//
// Validates the serial->SelfWriteData/SelfWriteStrobe deserializer (issue #16,
// advisor gate #1): stream known 32-bit words MSB-first over cfg_sclk/cfg_sdata
// and assert the adapter emits exactly those words on efpga_SelfWriteData, each
// with a single-cycle efpga_SelfWriteStrobe pulse. No fabric, no PDK.

`timescale 1ns/1ps
module tb_config_adapter;
    reg clk = 1'b0, rst_n = 1'b0;
    reg cfg_sclk = 1'b0, cfg_sdata = 1'b0;
    wire cfg_busy, cfg_done;
    wire efpga_CLK, efpga_resetn, efpga_SelfWriteStrobe, efpga_s_clk, efpga_s_data, efpga_Rx;
    wire [31:0] efpga_SelfWriteData;

    config_adapter dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_sclk(cfg_sclk), .cfg_sdata(cfg_sdata),
        .cfg_busy(cfg_busy), .cfg_done(cfg_done),
        .efpga_CLK(efpga_CLK), .efpga_resetn(efpga_resetn),
        .efpga_SelfWriteStrobe(efpga_SelfWriteStrobe),
        .efpga_SelfWriteData(efpga_SelfWriteData),
        .efpga_s_clk(efpga_s_clk), .efpga_s_data(efpga_s_data), .efpga_Rx(efpga_Rx),
        .efpga_ComActive(1'b0), .efpga_ReceiveLED(1'b0)
    );

    always #5 clk = ~clk;            // 100 MHz

    // capture emitted words on each strobe
    reg [31:0] got [0:7];
    integer ngot = 0;
    always @(posedge clk) if (efpga_SelfWriteStrobe) begin
        got[ngot] = efpga_SelfWriteData;
        ngot = ngot + 1;
    end

    // send one 32-bit word MSB-first; cfg_sclk much slower than clk
    task send_word(input [31:0] w);
        integer i;
        begin
            for (i = 31; i >= 0; i = i - 1) begin
                cfg_sdata = w[i];
                #20 cfg_sclk = 1'b1;   // rising edge
                #20 cfg_sclk = 1'b0;
            end
        end
    endtask

    integer errors = 0;
    reg [31:0] w0, w1;
    initial begin
        w0 = 32'hDEAD_BEEF;
        w1 = 32'h0123_4567;
        #20 rst_n = 1'b1;
        #50;
        send_word(w0);
        #100;
        send_word(w1);
        #200;

        if (ngot !== 2) begin
            $display("FAIL: expected 2 strobed words, got %0d", ngot);
            errors = errors + 1;
        end else begin
            if (got[0] !== w0) begin
                $display("FAIL: word0 = %h expected %h", got[0], w0); errors = errors + 1;
            end
            if (got[1] !== w1) begin
                $display("FAIL: word1 = %h expected %h", got[1], w1); errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: adapter emitted %h, %h on SelfWriteData with strobes", got[0], got[1]);
        else
            $display("RESULT: %0d error(s)", errors);
        $finish;
    end
endmodule
