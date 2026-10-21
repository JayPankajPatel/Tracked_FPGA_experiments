// Synchronous-reset variant of stochastic_binary_converter.sv (module
// stochastic_to_binary), for targets whose flip-flop primitive has no
// async reset input (e.g. FABulous fabric BELs -- see docs/adr/0020 and
// ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// fabric-ff-primitive-sync-reset-only.md). Identical logic; only the
// always_ff sensitivity list changes -- the combinational
// `rst_n && ...` gates on valid_binary_out/ready_stochastic_in already
// force outputs low the instant rst_n drops regardless of the internal
// FF's own reset timing, so external behavior is unaffected either way.
// Kept as a parallel file: stochastic_binary_converter.sv (module
// stochastic_to_binary) stays the verified async-reset default.
//
// Vendored from Stochastic_Blocks/rtl/stochastic_binary_converter_sync.sv
// into this tile directory (self-contained, per the FABulous tile-hardening
// file-discovery scoping -- see docs/issue-22/tile-macro-sv-glob-fix/). The
// `MA_ASSERT_ELABOR` elaboration check from the source file (WIDTH inside
// [2:64]) is intentionally omitted here: a standalone tile BEL file cannot
// reach the shared `ma_assert.svh` include used elsewhere in the repo.
module stochastic_to_binary_sync #(
    parameter int WIDTH = 4
) (
    input logic clk,
    input logic rst_n,
    input logic stochastic_in,
    input logic valid_stochastic_in,
    // Explicit window-boundary pulse from the producer, meaningful only on
    // a cycle a sample is actually transferred (valid_stochastic_in &&
    // ready_stochastic_in): tells this module "the sample being accepted
    // this cycle is the last one of its window," instead of this module
    // inferring completion from a locally-counted cycle_count reaching a
    // fixed target. See docs/adr/0017 for why: matching burst/window
    // lengths on both sides only guarantees alignment if both sides also
    // happen to reset their counters on the same real-transfer index --
    // any transient skew (or, more generally, any topology where there's
    // no single well-defined upstream "burst length" to match against,
    // e.g. downstream of a join composing two independently-timed
    // producers) turns into a silent, permanent window/value misalignment.
    // A boundary pulse from the actual producer-side event makes this
    // module's notion of "window" externally synchronized by construction
    // rather than by coincidence.
    input logic boundary_in,
    input logic ready_binary_out,
    output logic ready_stochastic_in,
    output logic valid_binary_out,
    output logic [WIDTH-1:0] binary_out
);
  localparam int n = WIDTH;

  // A real transfer happens exactly when both sides of this module's own
  // input handshake are true this cycle -- this is what boundary_in must
  // be sampled against (a boundary_in asserted on a cycle with no real
  // transfer means nothing).
  logic accept_this_cycle;
  assign accept_this_cycle = valid_stochastic_in && ready_stochastic_in;

  typedef struct packed {
    logic [n-1:0] ones_count;
    logic [n-1:0] binary_out_d;
    logic valid_binary_out;
    // Latched the cycle a boundary-flagged sample was accepted; takes over
    // cycle_count==MAX_CYCLES's old role of "the window is done, waiting to
    // announce/reopen" -- see docs/adr/0017.
    logic last_sample_seen;
  } bin_to_sto_t;
  bin_to_sto_t r, rin;

  always_comb begin
    rin = r;
    if (r.last_sample_seen && !r.valid_binary_out) begin
      // window just finished -- latch and announce
      rin.binary_out_d = r.ones_count;
      rin.valid_binary_out = 1'b1;
      if (ready_binary_out) begin
        // consumer already ready -- reopen in the same transition, zero bubble
        rin.ones_count = '0;
        rin.last_sample_seen = 1'b0;
      end
    end else if (r.last_sample_seen && ready_binary_out) begin
      // slow path: was already showing valid from a prior cycle, consumer
      // just became ready now -- consume and reopen
      rin.ones_count = '0;
      rin.last_sample_seen = 1'b0;
      rin.valid_binary_out = 1'b0;
    end else if (r.valid_binary_out && !r.last_sample_seen) begin
      // fast-path aftermath: already reopened (last_sample_seen cleared,
      // unlike the still-holding slow-path case above) but still showing
      // last cycle's valid pulse -- clear it now
      rin.valid_binary_out = 1'b0;
    end else if (accept_this_cycle) begin
      rin.ones_count = r.ones_count + (stochastic_in == 1'b1);
      rin.last_sample_seen = boundary_in;
    end
  end
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      r.ones_count <= '0;
      r.binary_out_d <= '0;
      r.valid_binary_out <= '0;
      r.last_sample_seen <= '0;
    end else begin
      r <= rin;
    end
  end

  assign binary_out = r.binary_out_d;
  assign valid_binary_out = rst_n && r.valid_binary_out;
  assign ready_stochastic_in = rst_n && !r.last_sample_seen;

endmodule : stochastic_to_binary_sync

module FABulous_stochastic_to_binary_sync #(
    // Capped at 6, not matching BTS's binary_in WIDTH=8: FABulous's automated
    // switch-matrix generator (fabric_automation.py:generateSwitchmatrixList)
    // caps total non-carry/non-shared BEL OUTPUTS at 8 (counted per-bit); this
    // wrapper's other two real outputs (ready_stochastic_in, valid_binary_out)
    // leave only 6 bits of budget for binary_out. Inputs allow up to 32, which
    // is why BTS's 8-bit binary_in (an input) hit no such limit.
    parameter int WIDTH = 6
) (
    (* FABulous, EXTERNAL, SHARED_PORT *) input logic UserCLK,
    input logic rst_n,
    input logic stochastic_in,
    input logic valid_stochastic_in,
    input logic boundary_in,
    input logic ready_binary_out,
    output logic ready_stochastic_in,
    output logic valid_binary_out,
    output logic [WIDTH-1:0] binary_out,
    // STB has no arithmetic/carry logic of its own. This dummy carry pair
    // exists solely so `generate_custom_tile_config` (FABulous's documented
    // automated tile-scaffolding command) auto-declares a real NORTH Co/Ci
    // jump wire and correct switch-matrix wiring for STB, matching every
    // carry-capable tile (LUT4AB etc.). Without a real carry pin here, the
    // fabric's pin-placement step allocates one pin's worth less track
    // space before UserCLKo/UserCLK than every other tile type, silently
    // misaligning those tile-to-tile abutment pins at fabric stitch time
    // (see ~/wiki/fpga_stochastic_blocks/reusable_lessons/
    // fabulous-custom-tile-authoring-methodology.md, found via the BTS
    // tile's own version of this same issue). Tied through
    // (dummy_carry_out = dummy_carry_in) so the column's carry chain isn't
    // left dangling by STB's presence.
    (* CARRY="dummy" *) input logic dummy_carry_in,
    (* CARRY="dummy" *) output logic dummy_carry_out
);
  assign dummy_carry_out = dummy_carry_in;

  stochastic_to_binary_sync #(
      .WIDTH(WIDTH)
  ) BEL (
      .clk(UserCLK),
      .rst_n(rst_n),
      .stochastic_in(stochastic_in),
      .valid_stochastic_in(valid_stochastic_in),
      .boundary_in(boundary_in),
      .ready_binary_out(ready_binary_out),
      .ready_stochastic_in(ready_stochastic_in),
      .valid_binary_out(valid_binary_out),
      .binary_out(binary_out)
  );
endmodule : FABulous_stochastic_to_binary_sync
