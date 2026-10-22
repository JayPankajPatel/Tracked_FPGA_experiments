// Equivalence: fused SC multiply core vs the validated sc_multiply_chain_top_sync.
// Expect fused.product == chain.binary_out >> 1 for every operand pair.
`timescale 1ns/1ps
module tb_fused_equiv;
  logic clk = 0, rst_n = 0;
  always #4 clk = ~clk;
  logic [7:0] a, b;
  logic start;
  logic ref_valid, fus_valid, ref_rdy_a, ref_rdy_b;
  logic [7:0] ref_out;
  logic [6:0] fus_out;

  sc_multiply_chain_top_sync ref_dut (
      .clk(clk), .rst_n(rst_n), .binary_in_a(a), .valid_binary_in_a(start),
      .binary_in_b(b), .valid_binary_in_b(start), .ready_binary_out(1'b1),
      .ready_binary_in_a(ref_rdy_a), .ready_binary_in_b(ref_rdy_b),
      .valid_binary_out(ref_valid), .binary_out(ref_out));
  sc_multiply_fused_core fus_dut (
      .clk(clk), .rst_n(rst_n), .a(a), .b(b), .valid_in(start), .ready_out(1'b1),
      .valid_out(fus_valid), .product(fus_out));

  int errors = 0, n = 0;
  logic got_ref, got_fus;
  logic [7:0] r_ref;
  logic [6:0] r_fus;
  always @(posedge clk) begin
    if (ref_valid && !got_ref) begin got_ref <= 1; r_ref <= ref_out; end
    if (fus_valid && !got_fus) begin got_fus <= 1; r_fus <= fus_out; end
  end

  task automatic run(input [7:0] ia, input [7:0] ib);
    int t;
    begin
      @(negedge clk); a = ia; b = ib; got_ref = 0; got_fus = 0; start = 1;
      @(negedge clk); start = 0;
      t = 0;
      while (!(got_ref && got_fus) && t < 2000) begin @(negedge clk); t++; end
      if (!(got_ref && got_fus) || r_fus !== r_ref[7:1]) begin
        errors++;
        $display("MISMATCH a=%0d b=%0d ref=%0d fused=%0d (got %0b %0b)", ia, ib, r_ref, r_fus, got_ref, got_fus);
      end
      n++;
      repeat (3) @(negedge clk);
    end
  endtask

  initial begin
    start = 0; a = 0; b = 0; got_ref = 0; got_fus = 0;
    repeat (4) @(negedge clk); rst_n = 1; repeat (2) @(negedge clk);
    run(0, 0); run(255, 255); run(255, 0); run(0, 255); run(128, 128); run(51, 153);
    for (int i = 0; i < 400; i++) run($urandom_range(255, 0), $urandom_range(255, 0));
    $display("DONE pairs=%0d errors=%0d", n, errors);
    $finish;
  end
endmodule
