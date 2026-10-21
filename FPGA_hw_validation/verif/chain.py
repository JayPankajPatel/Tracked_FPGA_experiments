"""Shared recorder for the multiply/add integration chains (encoder x2 ->
op -> decoder). Golden: each decoded value must equal the popcount of the
bits the decoder actually accepted in that window (observed on the decoder's
own inputs), delivered in order. Also records the ideal value per window so
compare_trace can report statistical accuracy."""
from collections import deque

IN_NAMES = ["rst_n", "binary_in_a", "valid_binary_in_a", "binary_in_b", "valid_binary_in_b", "ready_binary_out"]


def fields(width):
    ins = [("rst_n", 1), ("binary_in_a", width), ("valid_binary_in_a", 1), ("binary_in_b", width),
           ("valid_binary_in_b", 1), ("ready_binary_out", 1)]
    outs = [("ready_binary_in_a", 1), ("ready_binary_in_b", 1), ("valid_binary_out", 1), ("binary_out", width)]
    return ins, outs


PROBES = {
    "d_valid": lambda d: d.u_decoder.valid_stochastic_in,
    "d_ready": lambda d: d.u_decoder.ready_stochastic_in,
    "d_bit": lambda d: d.u_decoder.stochastic_in,
    "d_bound": lambda d: d.u_decoder.boundary_in,
}


async def record_chain(rec, pairs, ideal_fn, ready_pattern=lambda c: 1, seed_note=""):
    """pairs: [(a, b), ...] one per window. ideal_fn(a,b,N)->expected count."""
    width = rec.in_fields[1][1]
    n_full = (1 << width) - 1
    ia = ib = 0
    win_ones = 0
    done = deque()  # popcounts of closed windows awaiting delivery
    delivered = []
    cyc = 0

    async def step(a, va, b, vb, ready, rst_n=1):
        return await rec.step(rst_n=rst_n, binary_in_a=a, valid_binary_in_a=va, binary_in_b=b,
                              valid_binary_in_b=vb, ready_binary_out=ready)

    def account(o, ready):
        nonlocal win_ones
        if o["valid_binary_out"]:
            assert done, "valid_binary_out with no closed window"
            assert o["binary_out"] == done[0], f"binary_out={o['binary_out']} != window popcount {done[0]}"
            if ready:
                delivered.append(done.popleft())
        if o["d_valid"] and o["d_ready"]:
            win_ones += o["d_bit"]
            if o["d_bound"]:
                done.append(win_ones)
                win_ones = 0

    await rec.preroll(rst_n=0, binary_in_a=0, valid_binary_in_a=0, binary_in_b=0, valid_binary_in_b=0,
                      ready_binary_out=0)
    for _ in range(4):
        account(await step(0, 0, 0, 0, 0, rst_n=0), 0)
    while len(delivered) < len(pairs):
        assert cyc < 12 * (n_full + 20) * len(pairs), "chain stalled / windows not delivered"
        a, b = pairs[min(ia, len(pairs) - 1)][0], pairs[min(ib, len(pairs) - 1)][1]
        va, vb = int(ia < len(pairs)), int(ib < len(pairs))
        ready = ready_pattern(cyc)
        o = await step(a, va, b, vb, ready)
        account(o, ready)
        if va and o["ready_binary_in_a"]:
            ia += 1
        if vb and o["ready_binary_in_b"]:
            ib += 1
        cyc += 1
    await step(0, 0, 0, 0, 1)
    windows = [{"a": a, "b": b, "decoded": d, "ideal": ideal_fn(a, b, n_full)}
               for (a, b), d in zip(pairs, delivered)]
    return windows
