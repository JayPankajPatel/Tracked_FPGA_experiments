"""Record vectors for stochastic_multiplier; golden: AND + join handshake
(Microarch_Lib test_stochastic_multiplier.golden_model)."""
import cocotb
from hwrecord import Recorder
from twoin import IN_FIELDS, OUT_FIELDS, run_phases


@cocotb.test()
async def record(dut):
    rec = Recorder(dut, IN_FIELDS, OUT_FIELDS)

    def check(o, i):
        va, vb, ro = i["valid_stochastic_in_a"], i["valid_stochastic_in_b"], i["ready_stochastic_out"]
        assert o["valid_stochastic_out"] == (va & vb)
        assert o["ready_stochastic_in_a"] == (ro & vb)
        assert o["ready_stochastic_in_b"] == (ro & va)
        assert o["stochastic_out"] == (i["stochastic_in_a"] & i["stochastic_in_b"])

    await run_phases(rec, check, lambda: None)
    cocotb.log.info("recorded %d cycles", rec.finalize("stochastic_multiplier"))
