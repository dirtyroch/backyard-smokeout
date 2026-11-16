#!/usr/bin/env python3
"""Compose Porch Light, an original instrumental loop for Backyard Smokeout.

No samples, no MIDI import, no reference recording. Every sample is written here.
96 BPM, G major, 16 bars (40 seconds). The loop point is a decay to silence so
playback does not click when it repeats.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SR = 44100
BPM = 96
BEAT = 60.0 / BPM
EIGHTH = BEAT / 2.0
BARS = 16
TOTAL = BARS * 4 * BEAT
N = int(round(TOTAL * SR))

# Equal temperament from A4 = 440. Note names used below are original to this chart.
NOTE = {
    "C2": 65.41,
    "D2": 73.42,
    "E2": 82.41,
    "G2": 98.00,
    "B2": 123.47,
    "D3": 146.83,
    "E3": 164.81,
    "G3": 196.00,
    "A3": 220.00,
    "C4": 261.63,
    "D4": 293.66,
    "E4": 329.63,
    "F#4": 369.99,
    "G4": 392.00,
    "A4": 440.00,
    "B4": 493.88,
    "C5": 523.25,
    "D5": 587.33,
    "E5": 659.25,
}


def env(i: int, start: int, length: int, attack: int, release: int) -> float:
    if i < start or i >= start + length:
        return 0.0
    k = i - start
    if k < attack:
        return k / attack
    if k > length - release:
        return max(0.0, (start + length - i) / release)
    return 1.0


def add_tone(buf: list[float], freq: float, start_s: float, dur_s: float, amp: float, kind: str) -> None:
    start = int(start_s * SR)
    length = int(dur_s * SR)
    attack = int(0.02 * SR)
    release = int(min(0.18, dur_s * 0.45) * SR)
    for i in range(start, min(N, start + length)):
        t = (i - start) / SR
        e = env(i, start, length, attack, release)
        if kind == "bass":
            sample = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(2 * math.pi * freq * 2 * t)
        elif kind == "whistle":
            sample = math.sin(2 * math.pi * freq * t) + 0.22 * math.sin(2 * math.pi * freq * 2 * t)
        else:
            sample = math.sin(2 * math.pi * freq * t)
        buf[i] += amp * e * sample


def add_shaker(buf: list[float], start_s: float, dur_s: float, amp: float, seed: int) -> None:
    start = int(start_s * SR)
    length = int(dur_s * SR)
    # A tiny deterministic noise burst. Not a recorded sample.
    x = seed % 2147483647 or 1
    attack = int(0.005 * SR)
    release = max(1, length // 3)
    for n in range(length):
        i = start + n
        if i >= N:
            break
        x = (1103515245 * x + 12345) % 2147483647
        noise = (x / 2147483647) * 2 - 1
        e = env(i, start, length, attack, release)
        # high-passed-ish by subtracting a slow average
        buf[i] += amp * e * noise * (0.35 + 0.65 * math.sin(2 * math.pi * 1800 * (i / SR)))


def main() -> None:
    buf = [0.0] * N
    # Chords, two bars each, twice through: G Em C D.
    roots = ["G2", "E2", "C2", "D2"] * 2
    fifths = ["D3", "B2", "G2", "A3"] * 2
    for i, (root, fifth) in enumerate(zip(roots, fifths)):
        bar = i * 2
        add_tone(buf, NOTE[root], bar * 4 * BEAT, 1.6 * BEAT, 0.16, "bass")
        add_tone(buf, NOTE[root], (bar * 4 + 2) * BEAT, 1.5 * BEAT, 0.12, "bass")
        add_tone(buf, NOTE[fifth], (bar * 4 + 2) * BEAT, 1.2 * BEAT, 0.05, "pad")

    # Whistle. Eighth-note grid, original to this file. Rests are written as None.
    phrase = [
        ["G4", "G4", "B4", "D5", "D5", "B4", "G4", None],
        ["E4", "G4", "A4", "B4", "A4", "G4", "E4", None],
        ["C4", "E4", "G4", "A4", "G4", "E4", "D4", None],
        ["D4", "F#4", "A4", "C5", "B4", "A4", "G4", None],
    ]
    answer = [
        ["D5", "B4", "G4", "B4", "D5", "E5", "D5", None],
        ["C5", "A4", "G4", "E4", "G4", "A4", "G4", None],
        ["E4", "G4", "B4", "D5", "C5", "A4", "G4", None],
        ["A4", "G4", "E4", "D4", "G4", None, None, None],
    ]
    chart = phrase + phrase + answer + phrase
    for bar, notes in enumerate(chart):
        for step, name in enumerate(notes):
            if name is None:
                continue
            add_tone(buf, NOTE[name], (bar * 8 + step) * EIGHTH, EIGHTH * 0.92, 0.11, "whistle")

    # Soft shaker on the eighths, lighter on the offs.
    for step in range(BARS * 8):
        accent = 0.025 if step % 2 == 0 else 0.012
        add_shaker(buf, step * EIGHTH, EIGHTH * 0.35, accent, 1000 + step * 17)

    # Fade the last 80ms to exact silence so the loop join does not click.
    fade = int(0.08 * SR)
    for i in range(fade):
        buf[N - fade + i] *= 1 - (i / fade)

    peak = max(abs(s) for s in buf) or 1
    scale = 0.72 / peak
    pcm = [max(-1.0, min(1.0, s * scale)) for s in buf]
    out = Path(__file__).with_name("porch-light.wav")
    with wave.open(str(out), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in pcm))
    boundary = max(abs(pcm[0]), abs(pcm[-1]))
    print(f"wrote {out} seconds={N / SR:.3f} peak_in={peak:.3f} boundary={boundary:.5f}")


if __name__ == "__main__":
    main()
