"""Record vectors for counter; golden model = Microarch_Lib counter semantics
(clr beats en; async active-low reset; wraps at 2**clog2(UPTO))."""
import random

import cocotb
from hwrecord import Recorder


@cocotb.test()
async def record(dut):
    width = len(dut.out)
    upto = int(dut.UPTO.value)
    rec = Recorder(dut, [("rst_n", 1), ("en", 1), ("clr", 1)], [("out", width)])
    rng = random.Random(99)
    state = 0

    async def cycle(rst_n, en, clr):
        nonlocal state
        out = await rec.step(rst_n=rst_n, en=en, clr=clr)
        if not rst_n:
            state = 0
        assert out["out"] == state, f"golden mismatch: dut={out['out']} ref={state}"
        if rst_n:
            if clr:
                state = 0
            elif en:
                state = (state + 1) % (1 << width)

    for _ in range(4):
        await cycle(0, 0, 0)
    for _ in range(3 * (1 << width) + 5):  # enough to wrap at least twice
        await cycle(1, 1, 0)
    for _ in range(300):
        await cycle(1, rng.randint(0, 1), 1 if rng.random() < 0.05 else 0)
    for _ in range(3):
        await cycle(0, 1, 0)
    for _ in range(100):
        await cycle(1, 1, 0)
    n = rec.finalize("counter", {"UPTO": upto})
    cocotb.log.info("recorded %d cycles", n)
