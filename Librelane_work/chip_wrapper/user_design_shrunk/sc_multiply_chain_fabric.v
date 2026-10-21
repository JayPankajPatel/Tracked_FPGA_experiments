`default_nettype none

// sc_multiply_chain_fabric — fit-for-purpose user design for the shrunk
// Caravel eFPGA (Flow A mapping of Microarch_Lib's SC multiply chain).
//
// Wraps sc_multiply_chain_top_sync (sync-reset variant: 2x
// binary_stochastic_converter_sync encoders -> stochastic_multiplier ->
// stochastic_to_binary_sync decoder) at WIDTH=8, using the same verified
// decorrelation seed pair as the accuracy/correlation characterization
// (INIT_SEED_A=1, INIT_SEED_B=204 -- phase_lag=127, exactly half of the
// WIDTH=8 LFSR's 255-state period; see
// ~/wiki/fpga_stochastic_blocks/decision_logs/
// stochastic-v0-evidence-and-v1-candidate-2026-09-06.md). The _sync chain
// (Microarch_Lib docs/adr/0020) is required here, not just preferred: this
// fabric's only FF BEL (LUT4c_frame_config_dffesr) has no async reset
// input -- see ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// fabric-ff-primitive-sync-reset-only.md. This wrapper's own operand
// generator registers below are sync-reset for the same reason.
//
// Same pin-budget trick as the Zybo Z7 area/power comparison
// (Microarch_Lib blocks/stocastic/fpga/rtl/sc_multiply_top.sv): operands
// are driven by free-running counters internal to this wrapper, not
// external pins -- this fabric only exposes 16 bidirectional IO pins
// total, and the full valid/ready protocol at WIDTH=8 would need 19 pins
// if externalized. Only the result (binary_out + valid_binary_out, 9 bits)
// is observable externally; ready_binary_out is tied permanently high
// (no backpressure exercised in this bring-up).
//
// IMPORTANT: the free-running generators must NOT be the same width as the
// encoder's own operand (8 bits) -- confirmed via a real functional
// simulation run (FABulous emulation testbench,
// ~/wiki/fpga_stochastic_blocks/reusable_lessons/
// free-running-generator-period-lock-with-encoder-width.md) that an 8-bit
// generator period-locks with the encoder: one encoder burst is exactly
// 2^WIDTH=256 clock cycles (255 busy + 1 idle before the next accept, since
// valid_binary_in is tied high), which exactly matches an 8-bit counter's
// own 256-cycle wraparound -- every accept then samples the *same* phase
// forever, freezing the operand at its first post-reset value (0 and 37
// respectively) for the life of the simulation, silently degenerating the
// whole demo into a constant `0 * const` multiply. Using a WIDER
// free-running counter and exposing its upper 8 bits as the operand avoids
// this: the exposed byte only advances roughly once per encoder period
// instead of wrapping in lockstep with it, sweeping through the full 0-255
// range across bursts instead of freezing.
//
// Pin map (bidirectional fabric IO; inputs and outputs use DISTINCT pins,
// matching top_wrapper_lfsr8.v's convention):
//   io_in[0]    = rst (sync-released active-high; internally inverted to
//                 this module's active-low rst_n convention)
//   io_out[9:1] = {valid_binary_out, binary_out[7:0]}
//   io_oeb: 1 = input/Hi-Z (T), 0 = output (driven).
module sc_multiply_chain_fabric (
    input  wire        clk,
    input  wire [15:0] io_in,
    output wire [15:0] io_out,
    output wire [15:0] io_oeb
);
    // WIDTH is fixed at 8 for this fit-for-purpose design (not a generic
    // parameter) -- plain 8-bit literals throughout instead of a
    // parameterized sized-cast (`WIDTH'(...)`, SystemVerilog-only syntax
    // this fabric's Yosys frontend may not parse; lfsr8.v, the known-
    // working reference design, deliberately avoids all SV-only syntax).

    wire rst = io_in[0];
    wire rst_n = ~rst;

    // 16-bit free-running generators (twice the encoder's own WIDTH) so
    // their period doesn't commensurate with the encoder's 256-cycle burst
    // period -- see the period-lock note above. Only the upper byte is
    // exposed as the operand.
    reg [15:0] free_run_a, free_run_b;
    always @(posedge clk) begin
        if (!rst_n) free_run_a <= 16'h0000;
        else free_run_a <= free_run_a + 16'h0001;
    end
    always @(posedge clk) begin
        if (!rst_n) free_run_b <= 16'd37;
        else free_run_b <= free_run_b + 16'd7;
    end
    wire [7:0] binary_in_a = free_run_a[15:8];
    wire [7:0] binary_in_b = free_run_b[15:8];

    wire [7:0] binary_out;
    wire valid_binary_out;
    wire ready_binary_in_a, ready_binary_in_b;

    sc_multiply_chain_top_sync #(
        .WIDTH(8),
        .INIT_SEED_A(8'd1),
        .INIT_SEED_B(8'd204)
    ) chain_i (
        .clk(clk),
        .rst_n(rst_n),
        .binary_in_a(binary_in_a),
        .valid_binary_in_a(1'b1),
        .binary_in_b(binary_in_b),
        .valid_binary_in_b(1'b1),
        .ready_binary_out(1'b1),
        .ready_binary_in_a(ready_binary_in_a),
        .ready_binary_in_b(ready_binary_in_b),
        .valid_binary_out(valid_binary_out),
        .binary_out(binary_out)
    );

    assign io_out = {6'b0, valid_binary_out, binary_out, 1'b0};
    assign io_oeb = 16'b1111_1100_0000_0001;
endmodule
`default_nettype wire
