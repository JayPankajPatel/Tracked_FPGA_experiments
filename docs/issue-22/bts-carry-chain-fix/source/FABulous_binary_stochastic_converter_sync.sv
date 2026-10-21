// Synchronous-reset variant of binary_stochastic_converter.sv, for targets
// whose flip-flop primitive has no async reset input (e.g. FABulous
// fabric BELs -- see docs/adr/0020 and ~/wiki/fpga_stochastic_blocks/
// reusable_lessons/fabric-ff-primitive-sync-reset-only.md). Identical
// logic; only the always_ff sensitivity list changes, and it instantiates
// counter_sync/galois_lfsr_sync instead of counter/galois_lfsr so the
// whole reset domain stays consistently synchronous. Kept as a parallel
// file: binary_stochastic_converter.sv stays the verified async-reset
// default.
// Synchronous-reset variant of counter.sv, for targets whose flip-flop
// primitive has no async reset input (e.g. FABulous fabric BELs -- see
// docs/adr/0020 and ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// fabric-ff-primitive-sync-reset-only.md). Identical logic to counter.sv;
// the only change is the always_ff sensitivity list (no `or negedge rst_n`)
// -- `if (!rst_n)` now reads synchronously instead of asynchronously, which
// is correct and sufficient for this module's existing reset/clear
// structure. Kept as a parallel file, not a replacement: counter.sv stays
// the verified async-reset default for every ASIC-target use.
module counter_sync #(
    /* verilator lint_off WIDTHEXPAND */
    // See counter.sv's identical comment: `int` (32-bit signed) can't hold
    // UPTO=2^64-1 and silently reinterprets values >= 2^31 as negative.
    parameter longint unsigned UPTO = 100
) (
    input logic clk,
    input logic en,
    input logic clr,
    input logic rst_n,
    output logic [$clog2(UPTO)-1:0] out
);
  // clr takes priority over en so a caller can synchronously restart a
  // count window on the same cycle it would otherwise have incremented
  // (e.g. reusing this counter across back-to-back windows without
  // depending on its natural bit-width wraparound landing back on 0 --
  // that only happens to line up when UPTO is itself a power of 2).
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      out <= '0;
    end else if (clr) begin
      out <= '0;
    end else if (en) begin
      out <= out + 1'b1;
    end
  end
endmodule : counter_sync

// Synchronous-reset variant of galois_lfsr.sv, for targets whose flip-flop
// primitive has no async reset input (e.g. FABulous fabric BELs -- see
// docs/adr/0020 and ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// fabric-ff-primitive-sync-reset-only.md). Identical logic; the only
// change is the always_ff sensitivity list. Kept as a parallel file, not a
// replacement: galois_lfsr.sv stays the verified async-reset default.
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
  // Argument bounds [0:64] match the LFSR WIDTH parameter directly.
  //
  // Expressed as a constant function (case statement) rather than a
  // `localparam` array of indexed-assignment-pattern entries: the array
  // form doesn't parse under Yosys's native Verilog frontend (used by the
  // SymbiYosys formal flow in verif/formal/), which supports only a small
  // subset of SystemVerilog. `automatic` here only affects simulation
  // local-variable storage (per-call, not shared/static) -- with no
  // recursion and a compile-time-constant argument (`n = WIDTH` below),
  // this synthesizes to pure constant folding, not a runtime call stack.
  //
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
  // Yosys's native frontend doesn't support bit-selecting a function call's
  // return value directly (`taps(n)[...]`); precompute it into a localparam
  // once instead, which also avoids calling `taps(n)` on every loop
  // iteration below.
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
        // degree k injected at stage (n-k) -- descending degree as stages
        // move away from the feedback re-entry point at q[n-1] -- so reading
        // the mask at [n-1-i] (not [i]) corrects for that ascending-vs-
        // descending mismatch. See docs/adr/0006.
        q[i] <= (q[i-1]) ^ (feedback & tap_mask[n-1-i]);
      end
    end
  end

  assign out = q;

endmodule : galois_lfsr_sync

module binary_stochastic_converter_sync #(
    parameter int WIDTH = 4,
    // Two encoder instances sharing the default seed (or any identical
    // seed+WIDTH pair) drive their internal galois_lfsr in lockstep --
    // fully correlated random streams. Composing multiple encoders whose
    // outputs feed a shared consumer (e.g. stochastic_multiplier) requires
    // giving each instance a distinct INIT_SEED, or the multiplier's AND
    // silently computes min(a,b) instead of a*b -- a well-known
    // stochastic-computing correctness trap that looks protocol-correct
    // (valid handshakes, plausible-looking bits) while being numerically
    // wrong. See docs/adr/0015.
    parameter bit [WIDTH-1:0] INIT_SEED = WIDTH'(1)
) (
    input logic clk,
    input logic [WIDTH-1:0] binary_in,
    input logic rst_n,
    input logic valid_binary_in,
    input logic ready_stochastic_out,
    output logic ready_binary_in,
    output logic valid_stochastic_out,
    output logic stochastic_out,
    output logic last_cycle
);
  localparam int n = WIDTH;
  // Burst is 2^N-1 bits, not 2^N: one full clean galois_lfsr period (per
  // ADR 0005/0006, the LFSR's all-zero state is unreachable, so its real
  // period is 2^N-1, not 2^N). Matches stochastic_to_binary's MAX_CYCLES
  // window size on the decode side -- see GitHub issue #2, which this
  // fixes: out_counter previously ran 0..2^N-1 inclusive (2^N distinct
  // values), one more than a clean LFSR period, so the last bit of every
  // burst duplicated the first bit's LFSR state (pigeonhole) and each
  // burst left the LFSR one extra state past a clean period, corrupting
  // both intra-burst independence and burst-to-burst phase alignment.
  // Computed as (all-n-bits-one) - 1 rather than (1 << n) - 2: `1` is an
  // unsized literal (32-bit `int` by default), so `1 << n` silently
  // overflows to 0 for n>=32 (a 32-bit value shifted left by 32+ bit
  // positions shifts every bit out, per the LRM) -- independent-audit
  // finding. `'1` self-sizes to this declaration's own width (n bits) with
  // no explicit power-of-two computation to overflow, at any WIDTH this
  // module's own elaboration check allows. `$clog2((1 << n))` was always
  // mathematically equal to n itself (ceil(log2(2^n)) == n for n>=1), so
  // sizing this declaration as plain [n-1:0] is equivalent, not an
  // approximation -- and never produces the ascending-range collapse the
  // old $clog2(0)-1 computation could.
  localparam logic [n-1:0] target_cycle_count = '1 - 1'b1;
  logic [n-1:0] random_number;
  logic [n-1:0] out_counter;
  logic en;
  // out_counter is shared across bursts (never reset by rst_n mid-run) and
  // is compared against target_cycle_count as an absolute value each cycle
  // -- it must be explicitly cleared at the cycle a burst actually retires,
  // or the next burst inherits whatever residual value was left over.
  // Previously this was masked by target_cycle_count+1 always being a power
  // of 2 (target_cycle_count == 2^n-1), so out_counter's own natural
  // bit-width wraparound happened to land back on 0 for free every burst;
  // that stopped holding once target_cycle_count became 2^n-2 (fixing
  // GitHub issue #2), which is why this clear is now required, not optional.
  logic burst_complete;

  typedef struct packed {
    logic [n-1:0] binary_in_d;
    logic ready_binary_in;
    logic valid_stochastic_out;
    logic busy;
  } state_t;

  state_t r, rin;

  counter_sync #(
      // UPTO sizes counter's output port via $clog2(UPTO) -- it wants the
      // number of distinct states out_counter ranges over (0..target_cycle_
      // count inclusive), not target_cycle_count itself. These coincided
      // when target_cycle_count was 2^n-1 ($clog2(2^n-1) == $clog2(2^n) ==
      // n for all n), which is why the pre-existing off-by-one here was
      // invisible; target_cycle_count == 2^n-2 breaks that coincidence
      // exactly at n=2 (2^n-2 == 2, a power of 2, so $clog2 underestimates
      // by one bit) -- confirmed via verilator WIDTHTRUNC at the default
      // WIDTH=2 elaboration.
      .UPTO(target_cycle_count + 1)
  ) counter (
      .clk(clk),
      .en(en),
      .clr(burst_complete),
      .rst_n(rst_n),
      .out(out_counter)
  );
  galois_lfsr_sync #(
      .WIDTH(WIDTH),
      .INIT_SEED(INIT_SEED)
  ) RNG (
      .clk(clk),
      .en(en),
      .rst_n(rst_n),
      .out(random_number)
  );

  always_comb begin
    rin = r;  // default: hold every field unless overridden below

    if (!r.busy) begin
      // Starting a burst depends only on this module's own state and its
      // own input (valid_binary_in) -- never on ready_stochastic_out.
      // ready_stochastic_out gates whether an *already-presented* bit gets
      // consumed (mid-burst advance/completion, below), not whether a new
      // burst is allowed to begin. Gating the accept itself on
      // ready_stochastic_out being already high is the same "VALID
      // implicitly waits for READY" AMBA violation stochastic_to_binary's
      // completion branch had (see docs/adr/0013's confirmation section and
      // the original decoder fix this session) -- it's just inert as long
      // as every consumer's readiness happens to be independent of this
      // encoder's own valid. Composing two encoders into
      // stochastic_multiplier's join (whose ready_stochastic_in_a depends
      // on valid_stochastic_in_b, and vice versa) turns that latent
      // violation into a real mutual-startup deadlock: neither encoder's
      // accept condition can ever fire, because each is waiting on a
      // ready signal that only becomes true once the OTHER encoder is
      // already valid. See docs/adr/0016.
      if (valid_binary_in) begin
        rin.binary_in_d = binary_in;
        rin.busy = 1'b1;
        rin.ready_binary_in = 1'b0;
        rin.valid_stochastic_out = 1'b1;
      end
    end else begin
      if (burst_complete) begin
        // last bit is being consumed this cycle
        rin.ready_binary_in = 1'b1;
        rin.valid_stochastic_out = 1'b0;
        rin.busy = 1'b0;
      end else begin
        rin.ready_binary_in = 1'b0;
        rin.valid_stochastic_out = 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      r.binary_in_d <= '0;
      r.ready_binary_in <= '1;
      r.valid_stochastic_out <= '0;
      r.busy <= '0;
    end else begin
      r <= rin;
    end
  end

  assign burst_complete = r.busy && (out_counter == target_cycle_count) && ready_stochastic_out;
  // last_cycle must track burst_complete exactly, not merely out_counter's
  // value -- during a downstream stall at the burst boundary, out_counter
  // holds at target_cycle_count for the whole stall while the burst hasn't
  // actually retired (counter isn't cleared, LFSR hasn't advanced past this
  // bit). A version of this signal that only checked out_counter would
  // assert for that entire stall instead of the one real retiring cycle --
  // exactly the kind of "true by coincidence, not by construction" gap
  // docs/adr/0013 exists to eliminate. No current consumer, but this is the
  // public "last bit of the burst" signal future chain-mode wiring would use.
  assign last_cycle = burst_complete;
  assign en = (r.busy && ready_stochastic_out);
  assign ready_binary_in = r.ready_binary_in;
  assign valid_stochastic_out = r.valid_stochastic_out;
  // See binary_stochastic_converter.sv's identical comment: `<` under-
  // encoded every positive value by exactly one 1-bit per burst (the LFSR
  // never visits its all-zero state, so random_number ranges over
  // {1,...,2^WIDTH-1}); `<=` gives the correct x ones out of a
  // (2^WIDTH-1)-bit burst for every x, including the x=0/all-zero and
  // x=2^WIDTH-1/all-ones extremes (independent-audit finding).
  assign stochastic_out = ((random_number <= r.binary_in_d) ? 1'b1 : 1'b0);
endmodule : binary_stochastic_converter_sync
// Synchronous-reset variant of binary_stochastic_converter.sv, for targets
// whose flip-flop primitive has no async reset input (e.g. FABulous
// fabric BELs -- see docs/adr/0020 and ~/wiki/fpga_stochastic_blocks/
// reusable_lessons/fabric-ff-primitive-sync-reset-only.md). Identical
// logic; only the always_ff sensitivity list changes, and it instantiates
// counter_sync/galois_lfsr_sync instead of counter/galois_lfsr so the
// whole reset domain stays consistently synchronous. Kept as a parallel
// file: binary_stochastic_converter.sv stays the verified async-reset
// default.
module FABulous_binary_stochastic_converter_sync #(
    parameter int WIDTH = 8,
    // Two encoder instances sharing the default seed (or any identical
    // seed+WIDTH pair) drive their internal galois_lfsr in lockstep --
    // fully correlated random streams. Composing multiple encoders whose
    // outputs feed a shared consumer (e.g. stochastic_multiplier) requires
    // giving each instance a distinct INIT_SEED, or the multiplier's AND
    // silently computes min(a,b) instead of a*b -- a well-known
    // stochastic-computing correctness trap that looks protocol-correct
    // (valid handshakes, plausible-looking bits) while being numerically
    // wrong. See docs/adr/0015.
    parameter bit [WIDTH-1:0] INIT_SEED = WIDTH'(1)
) (
    (* FABulous, EXTERNAL, SHARED_PORT *) input logic UserCLK,
    input logic [WIDTH-1:0] binary_in,
    // Keep reset normally routable. If the containing tile deliberately
    // provides one reset shared by all of its BELs, this port and the
    // corresponding tile JUMP may instead be marked SHARED_RESET.
    input logic rst_n,
    input logic valid_binary_in,
    input logic ready_stochastic_out,
    output logic ready_binary_in,
    output logic valid_stochastic_out,
    output logic stochastic_out,
    output logic last_cycle,
    // BTS has no arithmetic/carry logic of its own. This dummy carry pair
    // exists solely so `generate_custom_tile_config` (FABulous's documented
    // automated tile-scaffolding command) auto-declares a real NORTH Co/Ci
    // jump wire and correct switch-matrix wiring for BTS, matching every
    // carry-capable tile (LUT4AB etc.). Without a real carry pin here, the
    // fabric's pin-placement step allocates one pin's worth less track
    // space before UserCLKo/UserCLK than every other tile type, silently
    // misaligning those tile-to-tile abutment pins at fabric stitch time
    // (found via issue-22 fabric-stitch LVS debugging). Tied through
    // (dummy_carry_out = dummy_carry_in) so the column's carry chain isn't
    // left dangling by BTS's presence.
    (* CARRY="dummy" *) input logic dummy_carry_in,
    (* CARRY="dummy" *) output logic dummy_carry_out
);
  assign dummy_carry_out = dummy_carry_in;

  // There is deliberately no FABulous SHARED_ENABLE port. The wrapped
  // converter derives its internal counter/LFSR advance enable from its
  // busy state and ready_stochastic_out, so the ready/valid handshake must
  // remain visible to the normal routing fabric.
  binary_stochastic_converter_sync #(
      .WIDTH(8),
      .INIT_SEED(INIT_SEED)
  ) BEL (
      .clk(UserCLK),
      .binary_in(binary_in),
      .rst_n(rst_n),
      .valid_binary_in(valid_binary_in),
      .ready_stochastic_out(ready_stochastic_out),
      .ready_binary_in(ready_binary_in),
      .valid_stochastic_out(valid_stochastic_out),
      .stochastic_out(stochastic_out),
      .last_cycle(last_cycle)
  );

endmodule : FABulous_binary_stochastic_converter_sync
