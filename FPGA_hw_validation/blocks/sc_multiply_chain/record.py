"""Record vectors for the b->s mult->s->b chain (Microarch_Lib test_b_mult_s_integration/top.sv)
at WIDTH=8 with decorrelated seeds (1, 204 -- same as sc_multiply_chain_top_sync)."""
import cocotb
from chain import PROBES, fields, record_chain
from hwrecord import Recorder

PAIRS = [(255, 255), (128, 128), (64, 192), (200, 0), (0, 200), (51, 153), (255, 64), (100, 100)]


@cocotb.test()
async def record(dut):
    ins, outs = fields(len(dut.binary_in_a))
    rec = Recorder(dut, ins, outs, probes=PROBES)
    w = await record_chain(rec, PAIRS, lambda a, b, n: a * b / n,
                           ready_pattern=lambda c: 0 if 700 <= c < 760 else 1)  # consumer stall mid-run
    n = rec.finalize("sc_multiply_chain", {"WIDTH": len(dut.binary_in_a), "INIT_SEED_A": "8'd1",
                                           "INIT_SEED_B": "8'd204", "windows": w, "tol_fs": 0.10})
    cocotb.log.info("recorded %d cycles; windows=%s", n, w)
