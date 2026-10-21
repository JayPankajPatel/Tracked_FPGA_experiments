"""Record vectors for galois_lfsr; asserts the sim against the pylfsr golden
model used by Microarch_Lib's test_galois_lfsr before saving."""
import os
import random
import sys

import cocotb
from pylfsr import LFSR

sys.path.insert(0, os.path.join(os.environ["MICROARCH_LIB"], "blocks/stochastic/verif/tb/test_galois_lfsr"))
from test_galois_lfsr import fpoly_for, state_to_int  # noqa: E402
from hwrecord import Recorder  # noqa: E402


@cocotb.test()
async def record(dut):
    width = len(dut.out)
    seed = int(dut.INIT_SEED.value)
    rec = Recorder(dut, [("rst_n", 1), ("en", 1)], [("out", width)])
    rng = random.Random(1234)

    def fresh_ref():
        init = [(seed >> (width - 1 - j)) & 1 for j in range(width)]
        return LFSR(fpoly=fpoly_for(width), initstate=init, conf="galois", verbose=False)

    ref, state = fresh_ref(), seed  # state == value DUT should show in a cycle
    await rec.preroll(rst_n=0, en=0)

    async def cycle(rst_n, en):
        nonlocal ref, state
        out = await rec.step(rst_n=rst_n, en=en)
        if not rst_n:
            # async reset shows the seed immediately; sync reset shows the old state this
            # cycle and the seed from the next one. Either way the ref restarts at the seed.
            exp = state if rec.SYNC else seed
            ref, state = fresh_ref(), seed
        else:
            exp = state
        assert out["out"] == exp, f"golden mismatch: dut=0x{out['out']:x} ref=0x{exp:x} (rst_n={rst_n} en={en})"
        if rst_n and en:  # state advances at the clock edge ending this cycle
            ref.next()
            state = state_to_int(ref.state, width)

    for _ in range(4):
        await cycle(0, 0)
    for _ in range(300):
        await cycle(1, 1)
    for _ in range(300):
        await cycle(1, rng.randint(0, 1))
    for _ in range(3):
        await cycle(0, 1)  # mid-run reset
    for _ in range(200):
        await cycle(1, 1)
    n = rec.finalize("galois_lfsr", {"WIDTH": width, "INIT_SEED": f"{width}'h{seed:x}"})
    cocotb.log.info("recorded %d cycles", n)
