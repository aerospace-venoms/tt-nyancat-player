#!/usr/bin/env python3
"""Convert wav_tb.v sample file ('+', '-', '0' per sample) into a 16-bit WAV."""
import sys
import wave

RATE = round(1_240_000 / 28)
LEVEL = {"+": 8000, "-": -8000, "0": 0}


def main(src, dst):
    data = open(src).read().strip()
    with wave.open(dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(LEVEL[c].to_bytes(2, "little", signed=True) for c in data))
    print(f"wrote {dst} ({len(data) / RATE:.1f} s at {RATE} Hz)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
