"""Record vectors for stochastic_to_binary (STB). Golden model: Microarch_Lib's
golden_model (popcount of the bits accepted in a boundary-delimited window).
Also checks result hold-while-stalled, in-order delivery and no dropped results."""
import os
import random
import sys

import cocotb

sys.path.insert(0, os.path.join(os.environ["MICROARCH_LIB"], "blocks/stochastic/verif/tb/test_stochastic_to_binary"))
from test_stochastic_to_binary import golden_model  # noqa: E402
from hwrecord import Recorder  # noqa: E402


@cocotb.test()
async def record(dut):
    width = len(dut.binary_out)
    rec = Recorder(
        dut,
        [("rst_n", 1), ("valid_stochastic_in", 1), ("stochastic_in", 1), ("boundary_in", 1), ("ready_binary_out", 1)],
        [("ready_stochastic_in", 1), ("valid_binary_out", 1), ("binary_out", width)],
    )
    rng = random.Random(7)
    pending = []  # expected results, oldest first

    async def cyc(valid=0, bit=0, boundary=0, ready_out=1, rst_n=1):
        o = await rec.step(rst_n=rst_n, valid_stochastic_in=valid, stochastic_in=bit,
                           boundary_in=boundary, ready_binary_out=ready_out)
        if not rst_n:
            return o  # outputs during reset cycles are not part of the contract (sync reset lags one edge)
        if o["valid_binary_out"]:
            assert pending, "valid_binary_out with no completed window (spurious result)"
            assert o["binary_out"] == pending[0], f"binary_out={o['binary_out']} expected {pending[0]}"
            if ready_out:
                pending.pop(0)
        return o

    async def window(bits, p_valid=1.0, ready=lambda: 1):
        i = 0
        while i < len(bits):
            v = int(rng.random() < p_valid)
            o = await cyc(valid=v, bit=bits[i], boundary=int(i == len(bits) - 1), ready_out=ready())
            if v and o["ready_stochastic_in"]:
                i += 1
        pending.append(golden_model(bits))  # result is delivered after the boundary sample

    async def drain():
        for _ in range(60):
            await cyc(ready_out=1)
            if not pending:
                await cyc(ready_out=1)
                return
        raise AssertionError(f"results never delivered: {pending}")

    await rec.preroll(rst_n=0, valid_stochastic_in=0, stochastic_in=0, boundary_in=0, ready_binary_out=1)
    for _ in range(4):
        await cyc(rst_n=0)
    N = (1 << width) - 1
    rnd = lambda n: [rng.randint(0, 1) for _ in range(n)]  # noqa: E731

    # A: random windows, always-ready consumer, gappy producer
    for _ in range(3):
        await window(rnd(N), p_valid=0.8)
    await drain()
    # B: saturated windows with a slow, random consumer (result slot stays full)
    await window([1] * N, ready=lambda: int(rng.random() < 0.3))
    await window([0] * N, ready=lambda: 0 if len(pending) else 1)
    await drain()
    # C: short windows while the consumer is stuck low, then released
    stuck = [0] * 20
    for L in (1, 7, 3):
        await window(rnd(L), ready=lambda: stuck.pop() if stuck else 1)
    await drain()
    # D: reset in the middle of a window; next window must not inherit counts
    for b in rnd(100):
        await cyc(valid=1, bit=b)
    pending.clear()
    for _ in range(3):
        await cyc(rst_n=0)
    await window(rnd(200))
    await drain()
    n = rec.finalize("stochastic_to_binary", {"WIDTH": width})
    cocotb.log.info("recorded %d cycles", n)
