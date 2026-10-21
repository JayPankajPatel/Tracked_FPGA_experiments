// Vendored from Stochastic_Blocks/rtl/galois_lfsr_sync.sv and
// stochastic_adder_sync.sv into this tile directory (self-contained, per the
// FABulous tile-hardening file-discovery scoping -- see
// docs/issue-22/tile-macro-sv-glob-fix/). The `include "ma_assert.svh"` and
// `MA_ASSERT_ELABOR` elaboration checks from both source files are
// intentionally omitted here: a standalone tile BEL file cannot reach the
// shared ma_assert.svh include used elsewhere in the repo (same omission as
// STB's vendored stochastic_to_binary_sync -- see that tile's wrapper for
// precedent). The `ifdef FORMAL` block from galois_lfsr_sync.sv is likewise
// omitted: irrelevant for synthesis and unreachable without the shared
// formal harness.
module galois_lfsr_sync #(
    parameter int WIDTH = 4,
    parameter bit [WIDTH-1:0] INIT_SEED = WIDTH'(1)
) (
    input logic clk,
    input logic en,
    input logic rst_n,
    output logic [WIDTH-1:0] out
);

  // Synthesizable TAPS Look-Up "Table" (0-Indexed, aligned for i-1 checks).
  // Low-Hamming-weight (sparse) masks; see
  // docs/adr/0005-taps-lut-sparse-vs-dense-ppa.md for the PPA comparison and
  // primitivity verification, and docs/adr/0008-taps-lut-yosys-frontend-encoding.md
  // for why this is a function instead of a `localparam` array.
  function automatic bit [63:0] taps(int n);
    case (n)
      0: taps = 64'h0;
      1: taps = 64'h0;
      2: taps = 64'h1;
      3: taps = 64'h1;
      4: taps = 64'h4;  // q[2]
      5: taps = 64'h4;  // q[2]
      6: taps = 64'h10;  // q[4]
      7: taps = 64'h20;  // q[5]
      8: taps = 64'h38;  // q[5], q[4], q[3]
      9: taps = 64'h10;  // q[4]
      10: taps = 64'h40;  // q[6]
      11: taps = 64'h100;  // q[8]
      12: taps = 64'h29;
      13: taps = 64'h241;
      14: taps = 64'h409;
      15: taps = 64'h2000;  // q[13]
      16: taps = 64'h406;
      17: taps = 64'h2000;  // q[13]
      18: taps = 64'h400;  // q[10]
      19: taps = 64'h1101;
      20: taps = 64'h10000;  // q[16]
      21: taps = 64'h40000;  // q[18]
      22: taps = 64'h100000;  // q[20]
      23: taps = 64'h20000;  // q[17]
      24: taps = 64'h104001;
      25: taps = 64'h200000;  // q[21]
      26: taps = 64'h142;
      27: taps = 64'h13;
      28: taps = 64'h1000000;  // q[24]
      29: taps = 64'h4000000;  // q[26]
      30: taps = 64'h4020001;
      31: taps = 64'h8000000;  // q[27]
      32: taps = 64'h200003;
      33: taps = 64'h1000;  // q[12]
      34: taps = 64'hC02;
      35: taps = 64'h2;  // q[1]
      36: taps = 64'h400;  // q[10]
      37: taps = 64'hA02;  // q[11], q[9], q[1]
      38: taps = 64'h14002000;
      39: taps = 64'h8;  // q[3]
      40: taps = 64'h140002;  // q[20], q[18], q[1]
      41: taps = 64'h4;  // q[2]
      42: taps = 64'h4020000040;
      43: taps = 64'h38;  // q[5], q[3], q[2]
      44: taps = 64'h32;  // q[5], q[4], q[1]
      45: taps = 64'h40080040000;
      46: taps = 64'hC00001;
      47: taps = 64'h10;  // q[4]
      48: taps = 64'h400002001000;
      49: taps = 64'h100;  // q[8]
      50: taps = 64'h10080002000;
      51: taps = 64'h1200010;
      52: taps = 64'h4;  // q[2]
      53: taps = 64'h400100200;
      54: taps = 64'h20000010080;
      55: taps = 64'h800000;  // q[23]
      56: taps = 64'h4024000;
      57: taps = 64'h40;  // q[6]
      58: taps = 64'h40000;  // q[18]
      59: taps = 64'h300002;  // q[21], q[20], q[1]
      60: taps = 64'h1;
      61: taps = 64'h200000040001000;
      62: taps = 64'h8000010000040;
      63: taps = 64'h1;
      64: taps = 64'h4040000000000020;
      default: taps = 64'h0;
    endcase
  endfunction

  localparam n = WIDTH;
  localparam bit [63:0] tap_mask = taps(n);
  logic [n-1:0] q;
  logic feedback;
  assign feedback = q[n-1];
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      q <= INIT_SEED;
    end else if (en) begin
      q[0] <= feedback;
      for (int i = 1; i < n; i = i + 1) begin
        // tap_mask bit b always means polynomial term x^(b+1) (ascending
        // degree with bit index). This Galois circuit needs the tap for
        // degree k injected at stage (n-k) -- see docs/adr/0006.
        q[i] <= (q[i-1]) ^ (feedback & tap_mask[n-1-i]);
      end
    end
  end

  assign out = q;

endmodule : galois_lfsr_sync

module stochastic_adder_sync #(
    parameter int SELECT_LFSR_WIDTH = 4,
    parameter bit [SELECT_LFSR_WIDTH-1:0] SELECT_INIT_SEED = SELECT_LFSR_WIDTH'(1)
) (
    input logic clk,
    input logic rst_n,
    input logic stochastic_in_a,
    input logic valid_stochastic_in_a,
    output logic ready_stochastic_in_a,
    input logic stochastic_in_b,
    input logic valid_stochastic_in_b,
    output logic ready_stochastic_in_b,
    input logic ready_stochastic_out,
    output logic valid_stochastic_out,
    output logic stochastic_out
);
  // Textbook stochastic addition: MUX(select, A, B), scaling the true sum
  // to (A+B)/2 since a stochastic bitstream can't represent p>1. select
  // must be an independent-of-A-and-B random bit, freshly drawn per output
  // bit -- reusing A's or B's own LFSR (or a correlated one: same taps,
  // same phase) would make this MUX not actually random relative to its
  // inputs, silently producing a biased/wrong result instead of a loud
  // failure. SELECT_LFSR_WIDTH/SELECT_INIT_SEED default away from
  // galois_lfsr's own default (WIDTH picked by the operand encoder,
  // INIT_SEED=1) but a caller composing this with encoders that already
  // use WIDTH=4/INIT_SEED=1 must override at least one of these two
  // parameters, or independence isn't real, just assumed.
  logic [SELECT_LFSR_WIDTH-1:0] select_lfsr_out;
  logic select_bit;
  logic select_en;

  galois_lfsr_sync #(
      .WIDTH(SELECT_LFSR_WIDTH),
      .INIT_SEED(SELECT_INIT_SEED)
  ) SELECT_RNG (
      .clk(clk),
      .en(select_en),
      .rst_n(rst_n),
      .out(select_lfsr_out)
  );

  // Pure combinational join (two-producer-into-one-consumer) plus a MUX --
  // no registered state of its own beyond the select LFSR, since there's
  // nothing to accumulate across cycles.
  assign valid_stochastic_out = valid_stochastic_in_a && valid_stochastic_in_b;
  assign ready_stochastic_in_a = ready_stochastic_out && valid_stochastic_in_b;
  assign ready_stochastic_in_b = ready_stochastic_out && valid_stochastic_in_a;

  // Advance the select LFSR only on cycles a bit is actually produced
  // (valid && ready) -- one fresh random draw per real output bit.
  assign select_en = valid_stochastic_out && ready_stochastic_out;
  assign select_bit = select_lfsr_out[SELECT_LFSR_WIDTH-1];
  assign stochastic_out = select_bit ? stochastic_in_b : stochastic_in_a;

endmodule : stochastic_adder_sync

module FABulous_stochastic_adder_sync #(
    parameter int SELECT_LFSR_WIDTH = 4,
    parameter bit [SELECT_LFSR_WIDTH-1:0] SELECT_INIT_SEED = SELECT_LFSR_WIDTH'(1)
) (
    (* FABulous, EXTERNAL, SHARED_PORT *) input logic UserCLK,
    input logic rst_n,
    input logic stochastic_in_a,
    input logic valid_stochastic_in_a,
    output logic ready_stochastic_in_a,
    input logic stochastic_in_b,
    input logic valid_stochastic_in_b,
    output logic ready_stochastic_in_b,
    input logic ready_stochastic_out,
    output logic valid_stochastic_out,
    output logic stochastic_out,
    // SADD has no arithmetic/carry logic of its own (the select-RNG state
    // is not a carry chain). This dummy carry pair exists solely so
    // `generate_custom_tile_config` (FABulous's documented automated
    // tile-scaffolding command) auto-declares a real NORTH Co/Ci jump wire
    // and correct switch-matrix wiring for SADD, matching every
    // carry-capable tile (LUT4AB etc.). Without a real carry pin here, the
    // fabric's pin-placement step allocates one pin's worth less track
    // space before UserCLKo/UserCLK than every other tile type, silently
    // misaligning tile-to-tile abutment pins at fabric stitch time (see
    // ~/wiki/fpga_stochastic_blocks/reusable_lessons/
    // fabulous-custom-tile-authoring-methodology.md, step 2). Tied through
    // (dummy_carry_out = dummy_carry_in) so the column's carry chain isn't
    // left dangling by SADD's presence.
    (* CARRY="dummy" *) input logic dummy_carry_in,
    (* CARRY="dummy" *) output logic dummy_carry_out
);
  assign dummy_carry_out = dummy_carry_in;

  stochastic_adder_sync #(
      .SELECT_LFSR_WIDTH(SELECT_LFSR_WIDTH),
      .SELECT_INIT_SEED(SELECT_INIT_SEED)
  ) BEL (
      .clk(UserCLK),
      .rst_n(rst_n),
      .stochastic_in_a(stochastic_in_a),
      .valid_stochastic_in_a(valid_stochastic_in_a),
      .ready_stochastic_in_a(ready_stochastic_in_a),
      .stochastic_in_b(stochastic_in_b),
      .valid_stochastic_in_b(valid_stochastic_in_b),
      .ready_stochastic_in_b(ready_stochastic_in_b),
      .ready_stochastic_out(ready_stochastic_out),
      .valid_stochastic_out(valid_stochastic_out),
      .stochastic_out(stochastic_out)
  );
endmodule : FABulous_stochastic_adder_sync
