#!/usr/bin/env python3
"""Makes the three sound effects of Rudis from scratch (no recordings).

Run it from the project folder:   python3 tools/make_sounds.py

It writes short 16-bit mono WAV files into sounds/:
  swing.wav  - a "whoosh" when a weapon is swung
  hit.wav    - a dull "thud" when a blow lands
  clang.wav  - a metallic "clang" when a blow is blocked

The sounds are pure maths (noise and sine waves), made for this project,
so there is no licence to worry about: they are free to use (CC0).
Change the numbers below and run the script again to change a sound.
"""
import math
import os
import random
import struct
import wave

RATE = 22050  # samples per second; plenty for short effects
random.seed(42)  # same "random" noise every time, so the files do not change


def write(name, samples, peak=0.6):
    """Normalises to `peak` (0..1, so not too loud) and saves as WAV."""
    top = max(abs(s) for s in samples) or 1.0
    path = os.path.join(os.path.dirname(__file__), "..", "sounds", name)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(
            struct.pack("<h", int(s / top * peak * 32767)) for s in samples))
    print("wrote", os.path.normpath(path), "%.2f s" % (len(samples) / RATE))


def lowpass(samples, amount):
    """Simple smoothing filter; amount 0..1, higher = duller sound."""
    out, last = [], 0.0
    for s in samples:
        last = last * amount + s * (1.0 - amount)
        out.append(last)
    return out


def swing():
    # Noise that swells and fades, with a moving filter: "whhOOsh".
    n = int(RATE * 0.22)
    out, last = [], 0.0
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 2
        cut = 0.93 - 0.25 * math.sin(math.pi * t)  # brighter in the middle
        last = last * cut + random.uniform(-1, 1) * (1 - cut)
        out.append(last * env)
    return out


def hit():
    # A low sine "drop" plus a short burst of dull noise: "thud".
    n = int(RATE * 0.18)
    noise = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.85)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        freq = 140 * math.exp(-t * 12) + 55
        phase += 2 * math.pi * freq / RATE
        body = math.sin(phase) * math.exp(-t * 22)
        crack = noise[i] * math.exp(-t * 60) * 2.5
        out.append(body + crack)
    return out


def clang():
    # A few out-of-tune sine "ringing" partials, like metal on metal.
    n = int(RATE * 0.45)
    partials = [(820, 1.0, 9), (1335, 0.7, 11), (2110, 0.5, 14), (3070, 0.3, 18)]
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-t * d)
                for f, a, d in partials)
        s += random.uniform(-1, 1) * math.exp(-t * 90) * 0.8  # the "click" of impact
        out.append(s)
    return out


if __name__ == "__main__":
    write("swing.wav", swing(), peak=0.45)
    write("hit.wav", hit(), peak=0.7)
    write("clang.wav", clang(), peak=0.5)
