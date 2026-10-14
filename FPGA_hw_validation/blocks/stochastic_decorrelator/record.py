"""Record vectors for stochastic_decorrelator. Golden: Microarch_Lib's
SegmentBasedGolden scoreboard (accepted input pairs -> expected output pairs,
checked on every real output handshake), plus output-hold stability."""
import os
import sys
from collections import deque

import cocotb

sys.path.insert(0, os.path.join(os.environ["MICROARCH_LIB"], "blocks/stochastic/verif/tb/test_stochastic_decorrelator"))
from test_stochastic_decorrelator import SegmentBasedGolden  # noqa: E402
from hwrecord import Recorder  # noqa: E402
from twoin import IN_FIELDS, run_phases  # noqa: E402


@cocotb.test()
async def record(dut):
    fs = int(dut.FS.value)
    out_fields = [("ready_stochastic_in_a", 1), ("ready_stochastic_in_b", 1), ("valid_stochastic_out", 1),
                  ("stochastic_out_a", 1), ("stochastic_out_b", 1)]
    rec = Recorder(dut, IN_FIELDS, out_fields)
    st = {"golden": SegmentBasedGolden(fs), "q": deque(), "prev": None, "consumes": 0}

    def on_reset():
        st.update(golden=SegmentBasedGolden(fs), q=deque(), prev=None)

    def check(o, i):
        if not i["rst_n"]:
            st["prev"] = None
            return
        va, vb, ro = i["valid_stochastic_in_a"], i["valid_stochastic_in_b"], i["ready_stochastic_out"]
        slot = (not o["valid_stochastic_out"]) or ro
        assert o["ready_stochastic_in_a"] == int(slot and vb)
        assert o["ready_stochastic_in_b"] == int(slot and va)
        accept = va and vb and slot
        consume = o["valid_stochastic_out"] and ro
        prev = st["prev"]
        if prev is not None and not prev["accept"] and not prev["consume"]:
            assert o["valid_stochastic_out"] == prev["valid"], "valid changed with neither accept nor consume"
            if prev["valid"]:
                assert (o["stochastic_out_a"], o["stochastic_out_b"]) == prev["data"], "held output changed"
        if consume:
            assert st["q"], "output consumed but scoreboard empty"
            exp = st["q"].popleft()
            assert (o["stochastic_out_a"], o["stochastic_out_b"]) == exp, f"out={o} expected {exp}"
            st["consumes"] += 1
        if accept:
            r = st["golden"].accept(i["stochastic_in_a"], i["stochastic_in_b"])
            if r is not None:
                st["q"].append(r)
        st["prev"] = dict(accept=accept, consume=consume, valid=o["valid_stochastic_out"],
                          data=(o["stochastic_out_a"], o["stochastic_out_b"]))

    await run_phases(rec, check, on_reset)
    assert st["consumes"] > 50, "run did not exercise enough output handshakes"
    cocotb.log.info("recorded %d cycles (%d consumed outputs)", rec.finalize("stochastic_decorrelator", {"FS": fs}),
                    st["consumes"])
