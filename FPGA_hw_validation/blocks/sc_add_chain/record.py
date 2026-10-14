"""Record vectors for the b->s add->s->b chain (Microarch_Lib test_b_add_s_integration/top.sv)
at WIDTH=8, decorrelated encoder seeds (1, 204), select LFSR width 5 seed 1."""
import cocotb
from chain import PROBES, fields, record_chain
from hwrecord import Recorder

PAIRS = [(0, 0), (255, 255), (255, 0), (0, 255), (100, 200), (51, 153), (128, 128), (10, 240)]


@cocotb.test()
async def record(dut):
    ins, outs = fields(len(dut.binary_in_a))
    rec = Recorder(dut, ins, outs, probes=PROBES)
    w = await record_chain(rec, PAIRS, lambda a, b, n: (a + b) / 2,
                           ready_pattern=lambda c: 0 if 700 <= c < 760 else 1)
    n = rec.finalize("sc_add_chain", {"WIDTH": len(dut.binary_in_a), "INIT_SEED_A": "8'd1", "INIT_SEED_B": "8'd204",
                                      "SELECT_LFSR_WIDTH": 5, "SELECT_INIT_SEED": "5'd1", "windows": w,
                                      "tol_fs": 0.10})
    cocotb.log.info("recorded %d cycles; windows=%s", n, w)
