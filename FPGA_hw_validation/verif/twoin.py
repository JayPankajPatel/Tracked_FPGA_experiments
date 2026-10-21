"""Shared stimulus for two-input stochastic ops (multiplier, adder): random
valids/readies/bits, with structured phases (all-ready, one-sided stalls,
consumer stall) and mid-run resets. `check(o, i)` is the block's golden check,
called every cycle with the pre-edge outputs `o` and the inputs `i` applied."""
import random

IN_FIELDS = [("rst_n", 1), ("stochastic_in_a", 1), ("valid_stochastic_in_a", 1),
             ("stochastic_in_b", 1), ("valid_stochastic_in_b", 1), ("ready_stochastic_out", 1)]
OUT_FIELDS = [("ready_stochastic_in_a", 1), ("ready_stochastic_in_b", 1),
              ("valid_stochastic_out", 1), ("stochastic_out", 1)]


async def run_phases(rec, check, on_reset, seed=2024):
    rng = random.Random(seed)

    async def cyc(a, va, b, vb, ro, rst_n=1):
        i = dict(rst_n=rst_n, stochastic_in_a=a, valid_stochastic_in_a=va,
                 stochastic_in_b=b, valid_stochastic_in_b=vb, ready_stochastic_out=ro)
        o = await rec.step(**i)
        check(o, i)

    async def reset(n=3):
        for _ in range(n):
            await cyc(0, 0, 0, 0, 0, rst_n=0)
        on_reset()

    def rnd(pa, pb, pr, n):
        return [(rng.randint(0, 1), int(rng.random() < pa), rng.randint(0, 1),
                 int(rng.random() < pb), int(rng.random() < pr)) for _ in range(n)]

    await rec.preroll(rst_n=0, stochastic_in_a=0, valid_stochastic_in_a=0, stochastic_in_b=0,
                      valid_stochastic_in_b=0, ready_stochastic_out=0)
    await reset(4)
    for ph in (
        rnd(1, 1, 1, 200),          # everything valid & ready: every cycle fires
        rnd(0.5, 1, 1, 150),        # A intermittently invalid
        rnd(1, 0.5, 1, 150),        # B intermittently invalid
        rnd(1, 1, 0.3, 150),        # slow consumer
        rnd(0.7, 0.7, 0.7, 500),    # everything random
    ):
        for t in ph:
            await cyc(*t)
    await reset(3)                  # mid-run reset
    for t in rnd(0.8, 0.8, 0.8, 400):
        await cyc(*t)
    await cyc(0, 0, 0, 0, 0)
