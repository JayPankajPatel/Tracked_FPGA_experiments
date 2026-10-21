// Vendored from Stochastic_Blocks/rtl/stochastic_multipler.sv into this tile
// directory (self-contained, per the FABulous tile-hardening file-discovery
// scoping -- see docs/issue-22/tile-macro-sv-glob-fix/). No _sync variant
// needed: the module has no always_ff of its own (clk/rst_n are unused by
// the pure combinational join, kept only to match this repo's convention).
module stochastic_multiplier (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic clk,
    input  logic rst_n,
    /* verilator lint_on  UNUSEDSIGNAL */
    input  logic stochastic_in_a,
    input  logic valid_stochastic_in_a,
    output logic ready_stochastic_in_a,
    input  logic stochastic_in_b,
    input  logic valid_stochastic_in_b,
    output logic ready_stochastic_in_b,
    input  logic ready_stochastic_out,
    output logic valid_stochastic_out,
    output logic stochastic_out
);
  // Stochastic multiplication is just AND -- no registered state needed,
  // this is a pure combinational join of two independent producers into one
  // consumer. Each producer's ready is gated on the *other* producer's
  // valid (not its own), so a bit is only ever consumed from A when B has
  // one ready that same cycle, and vice versa; valid_out only asserts when
  // both do.
  assign valid_stochastic_out   = valid_stochastic_in_a && valid_stochastic_in_b;
  assign ready_stochastic_in_a  = ready_stochastic_out && valid_stochastic_in_b;
  assign ready_stochastic_in_b  = ready_stochastic_out && valid_stochastic_in_a;
  assign stochastic_out         = stochastic_in_a && stochastic_in_b;

endmodule : stochastic_multiplier

module FABulous_stochastic_multiplier (
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
    // SMUL has no arithmetic/carry logic of its own. This dummy carry pair
    // exists solely so `generate_custom_tile_config` (FABulous's documented
    // automated tile-scaffolding command) auto-declares a real NORTH Co/Ci
    // jump wire and correct switch-matrix wiring for SMUL, matching every
    // carry-capable tile (LUT4AB etc.). Without a real carry pin here, the
    // fabric's pin-placement step allocates one pin's worth less track
    // space before UserCLKo/UserCLK than every other tile type, silently
    // misaligning tile-to-tile abutment pins at fabric stitch time (see
    // ~/wiki/fpga_stochastic_blocks/reusable_lessons/
    // fabulous-custom-tile-authoring-methodology.md, step 2). Tied through
    // (dummy_carry_out = dummy_carry_in) so the column's carry chain isn't
    // left dangling by SMUL's presence.
    (* CARRY="dummy" *) input logic dummy_carry_in,
    (* CARRY="dummy" *) output logic dummy_carry_out
);
  assign dummy_carry_out = dummy_carry_in;

  stochastic_multiplier BEL (
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
endmodule : FABulous_stochastic_multiplier
