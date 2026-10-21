"""Record vectors for the encoder->decoder loopback (Microarch_Lib test_loopback_stochastic/
loopback_top.sv) at WIDTH=8. Closed-form golden: decoded value == encoded value, exactly."""
import cocotb
from hwrecord import Recorder

VALUES = [0, 1, 2, 0x5A, 0x7F, 0x80, 0xA5, 0xFE, 0xFF, 0x33]


@cocotb.test()
async def record(dut):
    width = len(dut.binary_in)
    rec = Recorder(
        dut,
        [("rst_n", 1), ("binary_in", width), ("valid_binary_in", 1), ("ready_binary_out", 1)],
        [("ready_binary_in", 1), ("valid_binary_out", 1), ("binary_out", width)],
    )
    zero = dict(binary_in=0, valid_binary_in=0, ready_binary_out=1)
    await rec.preroll(rst_n=0, **zero)
    for _ in range(4):
        await rec.step(rst_n=0, **zero)
    cyc = 0
    for k, v in enumerate(VALUES):
        accepted = False
        got = None
        while got is None:
            # consumer stalls during part of the run to exercise a held result
            ready = 0 if (k % 3 == 1 and 280 <= cyc % 300 < 330) else 1
            o = await rec.step(rst_n=1, binary_in=v, valid_binary_in=int(not accepted), ready_binary_out=ready)
            cyc += 1
            if not accepted and o["ready_binary_in"]:
                accepted = True
            if o["valid_binary_out"]:
                assert o["binary_out"] == v, f"loopback: in={v} out={o['binary_out']}"
                if ready:
                    got = o["binary_out"]
            assert cyc < 20000, "loopback never produced a result"
    await rec.step(rst_n=1, **zero)
    n = rec.finalize("sc_loopback", {"WIDTH": width})
    cocotb.log.info("recorded %d cycles", n)
