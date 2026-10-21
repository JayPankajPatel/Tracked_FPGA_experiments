// Generic record/replay bench core. A ROM (initialised from vectors.mem, made
// by the cocotb recorder) feeds a DUT one vector per clock; an ILA captures
// {dut_in, dut_out, run} every cycle. VIO: `go` starts a replay, `done` reports end.
//
// Cycle k (run==1) is the cycle in which the DUT sees vector k; the ILA sample
// for that cycle holds the DUT inputs (dut_in==vector k) and the DUT outputs as
// seen pre-clock-edge, which is what the recorder samples in simulation.
// DUT inputs come from a register (glitch-free, safe for async resets).
// Idle vector is all-zeros, so every vector bit that is an active-low reset
// must be bit 0 of the packed input word (rst_n=0 while idle).
module hwb_core #(
    parameter int IN_W = 2,
    parameter int OUT_W = 4,
    parameter int DEPTH = 1024,
    parameter string MEM = "vectors.mem"
) (
    input  logic             clk,
    output logic [ IN_W-1:0] dut_in,
    input  logic [OUT_W-1:0] dut_out
);
  localparam int AW = $clog2(DEPTH + 1);

  (* rom_style = "distributed" *) logic [IN_W-1:0] rom[DEPTH];
  initial $readmemh(MEM, rom);

  logic          go;
  logic          done = 1'b0;
  logic          run = 1'b0;
  logic [AW-1:0] addr = '0;

  initial dut_in = '0;

  always_ff @(posedge clk) begin
    if (!go) begin
      addr   <= '0;
      run    <= 1'b0;
      done   <= 1'b0;
      dut_in <= '0;
    end else if (addr < AW'(DEPTH)) begin
      dut_in <= rom[addr[$clog2(DEPTH)-1:0]];
      addr   <= addr + 1'b1;
      run    <= 1'b1;
    end else begin
      run    <= 1'b0;
      done   <= 1'b1;
      dut_in <= '0;
    end
  end

  vio_0 u_vio (
      .clk(clk),
      .probe_in0(done),
      .probe_out0(go)
  );
  ila_0 u_ila (
      .clk(clk),
      .probe0(dut_in),
      .probe1(dut_out),
      .probe2(run)
  );
endmodule
