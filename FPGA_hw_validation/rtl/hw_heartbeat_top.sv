// Tooling bring-up design: free-running counter observed by ILA, with VIO
// control of reset and a known-pattern readback. Proves build/program/VIO/ILA.
module hw_heartbeat_top (
    input  logic       clk,
    output logic [3:0] led
);
  logic        rst_n;      // VIO output (default 0 = held in reset)
  logic [31:0] cnt;

  always_ff @(posedge clk) begin
    if (!rst_n) cnt <= '0;
    else cnt <= cnt + 32'd1;
  end
  assign led = cnt[27:24];

  vio_0 u_vio (.clk(clk), .probe_in0(cnt[31:24]), .probe_out0(rst_n));
  ila_0 u_ila (.clk(clk), .probe0(cnt[15:0]), .probe1(rst_n));
endmodule
