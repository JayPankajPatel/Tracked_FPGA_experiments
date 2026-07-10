// sky130_sim_prims_init0.v — INVESTIGATION ARTIFACT (issue #16 V3), not used
// by the validation flow. Sim-only replacement for the sky130_fd_sc_hd
// primitives.v UDPs with DEFINED (0) power-up state on storage primitives.
//
// OUTCOME (recorded so nobody re-treads this): under icarus the fabric gate
// netlist shows a "every '1' correct, every '0' reads X" signature. This shim
// tested the hypothesis that X-init config/storage latches were the source —
// FALSIFIED: with all storage initialized to 0 the X pattern is bit-identical,
// so the retained X enters elsewhere (4-state semantics of the flattened
// routing fabric). The adopted V3 engine is Verilator 2-state zero-delay (see
// tools/run_shrunk_validation.sh and docs/issue-16/shrunk-validation.md).
// Kept because the shim is the reusable starting point if anyone retries
// icarus GL sim on FABulous netlists.
//
// Port names/orders mirror primitives.v at the pinned PDK (ciel 8afc8346);
// only the UDPs the FABulous netlists instantiate are shimmed:
//   dfxtp -> udp_dff$P, dlxtp -> udp_dlatch$P, mux2 -> udp_mux_2to1,
//   mux4 -> udp_mux_4to2. (No reset/set/scan variants in these netlists.)

`timescale 1ns / 1ps
`default_nettype none

module sky130_fd_sc_hd__udp_dff$P (
    output reg Q  ,
    input wire D  ,
    input wire CLK
);
    initial Q = 1'b0;
    always @(posedge CLK) Q <= D;
endmodule

module sky130_fd_sc_hd__udp_dlatch$P (
    output reg Q   ,
    input wire D   ,
    input wire GATE
);
    initial Q = 1'b0;
    always @* if (GATE) Q = D;
endmodule

module sky130_fd_sc_hd__udp_mux_2to1 (
    output wire X ,
    input wire A0,
    input wire A1,
    input wire S
);
    // equal-input optimism, then plain binary select
    assign X = (A0 === A1) ? A0 : (S ? A1 : A0);
endmodule

module sky130_fd_sc_hd__udp_mux_4to2 (
    output wire X ,
    input wire A0,
    input wire A1,
    input wire A2,
    input wire A3,
    input wire S0,
    input wire S1
);
    wire B0 = (A0 === A1) ? A0 : (S0 ? A1 : A0);
    wire B1 = (A2 === A3) ? A2 : (S0 ? A3 : A2);
    assign X = (B0 === B1) ? B0 : (S1 ? B1 : B0);
endmodule

`default_nettype wire
