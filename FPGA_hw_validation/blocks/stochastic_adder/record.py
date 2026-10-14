"""Record vectors for stochastic_adder; golden: out = MUX(select, A, B) with the
select-LFSR MSB sequence from Microarch_Lib test_stochastic_adder.golden_select_bits,
advancing once per fired bit (valid && ready) and restarting on reset."""
import os
import sys

import cocotb

sys.path.insert(0, os.path.join(os.environ["MICROARCH_LIB"], "blocks/stochastic/verif/tb/test_stochastic_adder"))
from test_stochastic_adder import golden_select_bits  # noqa: E402
from hwrecord import Recorder  # noqa: E402
from twoin import IN_FIELDS, OUT_FIELDS, run_phases  # noqa: E402


@cocotb.test()
async def record(dut):
    width = len(dut.select_lfsr_out)
    seed = int(dut.SELECT_RNG.INIT_SEED.value)
    sel = golden_select_bits(width, seed, 4000)
    fires = 0
    rec = Recorder(dut, IN_FIELDS, OUT_FIELDS)

    def on_reset():
        nonlocal fires
        fires = 0

    def check(o, i):
        nonlocal fires
        va, vb, ro = i["valid_stochastic_in_a"], i["valid_stochastic_in_b"], i["ready_stochastic_out"]
        if not i["rst_n"]:
            return
        assert o["valid_stochastic_out"] == (va & vb)
        assert o["ready_stochastic_in_a"] == (ro & vb)
        assert o["ready_stochastic_in_b"] == (ro & va)
        if va and vb:
            exp = i["stochastic_in_b"] if sel[fires] else i["stochastic_in_a"]
            assert o["stochastic_out"] == exp, f"fire {fires}: out={o['stochastic_out']} exp={exp} sel={sel[fires]}"
            if ro:
                fires += 1

    await run_phases(rec, check, on_reset)
    cocotb.log.info("recorded %d cycles", rec.finalize(
        "stochastic_adder", {"SELECT_LFSR_WIDTH": width, "SELECT_INIT_SEED": f"{width}'h{seed:x}"}))
