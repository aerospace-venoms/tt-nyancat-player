# SPDX-FileCopyrightText: © 2026 Ames
# SPDX-License-Identifier: Apache-2.0
"""
cocotb tests for the Nyan Cat player.

The expected notes and pitches come from model/nyan.py, the same file that
generates the ROM, so the hardware is always checked against the reference.

The clock is generated in tb.v (much faster than a cocotb Clock); tests jump
ahead with Timer and read tb.cycle to measure periods in clock cycles.
"""
import sys
from pathlib import Path

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "model"))
import nyan  # noqa: E402

CLK_NS = 806
UI_PAUSE = 1 << 0
UI_OCT_SHIFT = 1        # ui[2:1]
UI_FFWD = 1 << 3

SLOT = nyan.SLOT_CLKS                       # clocks per 16th-note slot
SLOT_FFWD = SLOT >> nyan.FFWD_BITS          # fast-forward runs 8x faster
GAP_FFWD = (1 << nyan.GAP_BITS) >> nyan.FFWD_BITS


def expected_slots():
    """(note code, fresh) for each of the 256 slots, as the hardware should see them."""
    cur, out = nyan.REST, []
    for s in range(256):
        c = nyan.rom_code(s)
        fresh = c != nyan.HOLD
        if fresh:
            cur = c
        out.append((cur, fresh))
    return out


def half_period_of(code):
    return nyan.half_period(nyan.PITCHES[code - 2])


async def reset(dut, ui=0):
    dut.ena.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(5 * CLK_NS, "ns")
    assert int(dut.uo_out.value) & 0b111 == 0, "piezo and LED outputs must be low in reset"
    assert int(dut.note.value) == nyan.REST
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return int(dut.cycle.value)      # cycle of the first active edge (slot 0 starts here)


async def wait_until(dut, cycle):
    now = int(dut.cycle.value)
    assert cycle >= now, f"asked to wait for past cycle {cycle} (now {now})"
    if cycle > now:
        await Timer((cycle - now) * CLK_NS, "ns")
    await FallingEdge(dut.clk)


async def measure(dut):
    """Return (high, low) duration of out_a in clocks."""
    await RisingEdge(dut.out_a)
    c0 = int(dut.cycle.value)
    await FallingEdge(dut.out_a)
    c1 = int(dut.cycle.value)
    await RisingEdge(dut.out_a)
    c2 = int(dut.cycle.value)
    return c1 - c0, c2 - c1


@cocotb.test()
async def test_first_note(dut):
    """Real-time start: silent gap, then F# at the exact divider, push-pull outputs."""
    t0 = await reset(dut)
    code, _ = expected_slots()[0]

    # Silent during the articulation gap at the start of the note
    await wait_until(dut, t0 + 1000)
    assert int(dut.note.value) == code
    assert int(dut.out_a.value) == 0 and int(dut.out_b.value) == 0 and int(dut.led.value) == 0

    # Then a square wave with half period N
    await wait_until(dut, t0 + (1 << nyan.GAP_BITS) + 100)
    assert int(dut.led.value) == 1
    n = half_period_of(code)
    high, low = await measure(dut)
    assert (high, low) == (n, n), f"half periods {high},{low}, expected {n}"

    # Push-pull: out_b is the complement of out_a while sounding
    for _ in range(8):
        await Timer(97 * CLK_NS, "ns")
        await FallingEdge(dut.clk)
        assert int(dut.out_b.value) == 1 - int(dut.out_a.value)


@cocotb.test()
async def test_whole_song(dut):
    """Fast-forward through all 256 slots: note, gap and exact pitch for every slot."""
    t0 = await reset(dut, ui=UI_FFWD)
    for s, (code, fresh) in enumerate(expected_slots()):
        start = t0 + s * SLOT_FFWD
        # Inside the gap: note register already updated; silent if fresh or rest
        await wait_until(dut, start + GAP_FFWD // 2)
        assert int(dut.note.value) == code, f"slot {s}: note {int(dut.note.value)}, expected {code}"
        assert int(dut.uo_out.value) >> 7 == s & 1, f"slot {s}: beat output wrong"
        expect_sound = code != nyan.REST and not fresh
        assert int(dut.led.value) == expect_sound, f"slot {s}: led {int(dut.led.value)} in gap"

        # After the gap: exact pitch, or silence for a rest
        await wait_until(dut, start + GAP_FFWD + 64)
        if code == nyan.REST:
            assert int(dut.led.value) == 0 and int(dut.out_a.value) == 0, f"slot {s}: rest not silent"
        else:
            n = half_period_of(code)
            high, low = await measure(dut)
            assert (high, low) == (n, n), f"slot {s}: half periods {high},{low}, expected {n}"
    assert int(dut.both_high_seen.value) == 0, "out_a and out_b were high at the same time"


@cocotb.test()
async def test_octaves(dut):
    """ui[2:1] = k plays the first note k octaves lower (half period x 2^k)."""
    n = half_period_of(expected_slots()[0][0])
    for k in range(4):
        t0 = await reset(dut, ui=k << UI_OCT_SHIFT)
        await wait_until(dut, t0 + (1 << nyan.GAP_BITS) + 100)
        high, low = await measure(dut)
        assert (high, low) == (n << k, n << k), f"octave {k}: {high},{low}, expected {n << k}"


@cocotb.test()
async def test_pause(dut):
    """ui[0] mutes and freezes the song; releasing it resumes the same note."""
    t0 = await reset(dut)
    await wait_until(dut, t0 + SLOT // 2)
    note_before = int(dut.note.value)
    beat_before = int(dut.uo_out.value) >> 7
    dut.ui_in.value = UI_PAUSE
    await Timer(3 * CLK_NS, "ns")
    await FallingEdge(dut.clk)
    assert int(dut.uo_out.value) & 0b111 == 0, "pause must silence the outputs"
    await Timer(SLOT * CLK_NS, "ns")          # longer than a slot: song must not advance
    assert int(dut.note.value) == note_before
    assert int(dut.uo_out.value) >> 7 == beat_before
    dut.ui_in.value = 0
    await Timer(3 * CLK_NS, "ns")
    high, low = await measure(dut)
    n = half_period_of(note_before)
    assert (high, low) == (n, n)
