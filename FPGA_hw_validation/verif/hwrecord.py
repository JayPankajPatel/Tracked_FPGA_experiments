"""Record cycle-exact stimulus + expected outputs from a cocotb simulation so
the same vectors can be replayed on hardware (rtl/hwb_core.sv) and compared
against an ILA capture (verif/compare_trace.py).

Cycle convention (must match hwb_core.sv): vector k is applied at a falling
edge, outputs are sampled pre-clock-edge in the same cycle, then the clock
steps. Packed words are LSB-first in field order; the first input field must
be the active-low reset (so the all-zero idle word holds the DUT in reset).
"""

import json
import os
from pathlib import Path

from cocotb.triggers import ReadOnly, RisingEdge
from ma_clkrst import clock_step, drive, sample_pre_edge, start_clock  # noqa: F401


class Recorder:
    def __init__(self, dut, in_fields, out_fields, outdir=None, period_ns=10):
        self.dut = dut
        self.in_fields = in_fields  # [(name, width), ...] LSB first; [0] is rst_n
        self.out_fields = out_fields
        self.outdir = Path(outdir or os.environ.get("HWB_GEN_DIR", "gen"))
        self.vectors = []  # packed input words
        self.expected = []  # packed output words
        start_clock(dut.clk, period_ns)

    @staticmethod
    def _pack(fields, values):
        word, shift = 0, 0
        for name, width in fields:
            v = int(values[name])
            assert 0 <= v < (1 << width), f"{name}={v} does not fit {width} bits"
            word |= v << shift
            shift += width
        return word

    async def step(self, **inputs):
        """Apply one cycle of inputs; return the pre-edge output dict."""
        assert inputs.keys() == {n for n, _ in self.in_fields}, "need every input field"
        await drive(self.dut, **inputs)
        await sample_pre_edge(self.dut)
        out = {n: int(getattr(self.dut, n).value) for n, _ in self.out_fields}
        self.vectors.append(self._pack(self.in_fields, inputs))
        self.expected.append(self._pack(self.out_fields, out))
        await clock_step(self.dut)
        return out

    def finalize(self, name, params=None):
        d = self.outdir
        d.mkdir(parents=True, exist_ok=True)
        in_w = sum(w for _, w in self.in_fields)
        out_w = sum(w for _, w in self.out_fields)
        n = len(self.vectors)
        assert self.vectors[0] & 1 == 0, "vector 0 must have rst_n=0"
        hexw_in, hexw_out = (in_w + 3) // 4, (out_w + 3) // 4
        (d / "vectors.mem").write_text("".join(f"{v:0{hexw_in}x}\n" for v in self.vectors))
        (d / "expected.mem").write_text("".join(f"{v:0{hexw_out}x}\n" for v in self.expected))
        depth = 1 << max(1, (n - 1).bit_length())
        (d / "meta.json").write_text(
            json.dumps(
                {
                    "name": name,
                    "in_fields": self.in_fields,
                    "out_fields": self.out_fields,
                    "in_w": in_w,
                    "out_w": out_w,
                    "n": n,
                    "params": params or {},
                },
                indent=1,
            )
        )
        (d / "meta.tcl").write_text(
            f"set META(in_w) {in_w}\nset META(out_w) {out_w}\nset META(n) {n}\n"
            f"set META(ila_depth) {max(depth, 1024)}\n"
        )
        defs = [f"`define HWB_IN_W {in_w}", f"`define HWB_OUT_W {out_w}", f"`define HWB_DEPTH {n}"]
        for k, v in (params or {}).items():
            defs.append(f"`define P_{k} {v}")
        (d / "hwb_params.svh").write_text("\n".join(defs) + "\n")
        return n
