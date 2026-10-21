"""Record vectors for binary_stochastic_converter (BTS). Every burst is checked
against Microarch_Lib's golden_model (pylfsr-based, bit-for-bit) and the
valid/ready protocol rules from test_binary_stochastic.py before saving."""
import os
import sys

import cocotb

sys.path.insert(0, os.path.join(os.environ["MICROARCH_LIB"], "blocks/stochastic/verif/tb/test_binary_to_stochastic"))
from test_binary_stochastic import golden_model  # noqa: E402
from hwrecord import Recorder  # noqa: E402


@cocotb.test()
async def record(dut):
    width = len(dut.binary_in)
    seed = int(dut.INIT_SEED.value)
    n_bits = (1 << width) - 1
    rec = Recorder(
        dut,
        [("rst_n", 1), ("valid_binary_in", 1), ("ready_stochastic_out", 1), ("binary_in", width)],
        [("ready_binary_in", 1), ("valid_stochastic_out", 1), ("stochastic_out", 1), ("last_cycle", 1)],
    )
    lfsr_state = seed
    idle = dict(rst_n=1, valid_binary_in=0, ready_stochastic_out=1, binary_in=0)

    async def reset(cycles=3):
        nonlocal lfsr_state
        for k in range(cycles):
            o = await rec.step(**{**idle, "rst_n": 0})
            if k > 0 or not rec.SYNC:  # sync reset: first reset cycle still shows the old state
                assert (o["ready_binary_in"], o["valid_stochastic_out"]) == (1, 0), "reset state wrong"
        lfsr_state = seed

    async def burst(value, stalls=(), accept_ready=1, hold_valid=False, abort_after=None):
        """stalls: {bit_index: stall_cycles}. accept_ready: ready_out during the accept cycle.
        hold_valid: keep valid_binary_in high while busy (must be ignored).
        abort_after: stop streaming after this many bits (caller then resets)."""
        nonlocal lfsr_state
        expected, end_state = golden_model(width, lfsr_state, value)
        o = await rec.step(rst_n=1, valid_binary_in=1, ready_stochastic_out=accept_ready, binary_in=value)
        assert o["ready_binary_in"] == 1 and o["valid_stochastic_out"] == 0, "not idle at accept"
        idx, stall_left = 0, 0
        while idx < n_bits:
            if abort_after is not None and idx >= abort_after:
                return
            if stall_left == 0 and idx in stalls and not stalled_done.get((value, idx)):
                stall_left = stalls[idx]
                stalled_done[(value, idx)] = True
            ready = 0 if stall_left else 1
            o = await rec.step(
                rst_n=1,
                valid_binary_in=int(hold_valid),
                ready_stochastic_out=ready,
                binary_in=value ^ 0xFF if hold_valid else 0,  # junk, must be ignored while busy
            )
            assert o["valid_stochastic_out"] == 1, f"valid dropped mid-burst at bit {idx}"
            assert o["stochastic_out"] == expected[idx], f"bit {idx}: dut={o['stochastic_out']} golden={expected[idx]}"
            if ready:
                assert o["last_cycle"] == int(idx == n_bits - 1), f"last_cycle wrong at bit {idx}"
                idx += 1
            else:
                assert o["last_cycle"] == 0
                stall_left -= 1
        lfsr_state = end_state

    stalled_done = {}
    await rec.preroll(**{**idle, "rst_n": 0})
    await reset(4)
    await rec.step(**idle)
    ones = {}
    for v, kw in [
        (0, {}),
        (1, {}),
        (0x55, {"stalls": {10: 3, 100: 1}}),
        (0x7F, {"accept_ready": 0}),  # accept must not depend on downstream ready (ADR 0016)
        (0x80, {"hold_valid": True}),
        (0xAA, {"stalls": {0: 2, n_bits - 1: 4}}),  # stall on first and last bit
        (0xFE, {}),
        (0xFF, {}),
        (0x02, {}),
    ]:
        await burst(v, **kw)
        await rec.step(**idle)  # one idle cycle between bursts
    await burst(0xC3, abort_after=40)  # abandoned mid-burst ...
    await reset(3)  # ... by a reset; LFSR restarts at the seed
    await rec.step(**idle)
    await burst(0x3C)
    await rec.step(**idle)
    n = rec.finalize("binary_stochastic_converter", {"WIDTH": width, "INIT_SEED": f"{width}'h{seed:x}"})
    cocotb.log.info("recorded %d cycles", n)
