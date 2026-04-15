#!/usr/bin/env python3
"""Generate simple sound effects for the 2048 game as OGG-free WAV files."""
import struct
import wave
import math
import os

SAMPLE_RATE = 44100
DIR = os.path.dirname(os.path.abspath(__file__))


def write_wav(filename: str, samples: list[float], sample_rate: int = SAMPLE_RATE):
    """Write 16-bit mono WAV from float samples in [-1, 1]."""
    path = os.path.join(DIR, filename)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            f.writeframes(struct.pack("<h", int(clamped * 32767)))
    print(f"  ✓ {path} ({len(samples)} samples, {len(samples)/sample_rate:.3f}s)")


def envelope(t: float, attack: float, decay: float, duration: float) -> float:
    """Simple attack-decay envelope, t in [0, duration]."""
    if t < attack:
        return t / attack
    remaining = duration - t
    if remaining < decay:
        return max(0, remaining / decay)
    return 1.0


def gen_slide() -> list[float]:
    """Short swoosh — filtered noise sweep, 80 ms."""
    dur = 0.08
    n = int(SAMPLE_RATE * dur)
    samples = []
    import random
    random.seed(42)
    # Low-pass filtered noise with descending cutoff
    prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        cutoff = 0.15 - 0.1 * (t / dur)  # descending filter
        noise = random.uniform(-1, 1)
        prev = prev + cutoff * (noise - prev)
        env = envelope(t, 0.005, 0.03, dur)
        samples.append(prev * env * 0.5)
    return samples


def gen_merge() -> list[float]:
    """Satisfying pop — two quick sine tones, 120 ms."""
    dur = 0.12
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Two harmonics for richness
        freq1 = 520 + 200 * (1 - t / dur)  # descending
        freq2 = freq1 * 1.5
        s = (math.sin(2 * math.pi * freq1 * t) * 0.6 +
             math.sin(2 * math.pi * freq2 * t) * 0.3)
        env = envelope(t, 0.005, 0.06, dur)
        samples.append(s * env * 0.45)
    return samples


def gen_game_over() -> list[float]:
    """Descending tone — sad whomp, 400 ms."""
    dur = 0.4
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 400 - 200 * (t / dur)
        s = math.sin(2 * math.pi * freq * t)
        # Add a sub-octave
        s += 0.3 * math.sin(2 * math.pi * (freq * 0.5) * t)
        env = envelope(t, 0.01, 0.15, dur)
        samples.append(s * env * 0.35)
    return samples


def gen_win() -> list[float]:
    """Ascending fanfare — three quick notes, 500 ms."""
    notes = [523.25, 659.25, 783.99]  # C5, E5, G5
    note_dur = 0.15
    gap = 0.02
    samples = []
    for note_idx, freq in enumerate(notes):
        n = int(SAMPLE_RATE * note_dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            s = (math.sin(2 * math.pi * freq * t) * 0.5 +
                 math.sin(2 * math.pi * freq * 2 * t) * 0.2)
            env = envelope(t, 0.01, 0.06, note_dur)
            samples.append(s * env * 0.45)
        # Gap between notes
        samples.extend([0.0] * int(SAMPLE_RATE * gap))
    return samples


if __name__ == "__main__":
    print("Generating sound effects...")
    write_wav("slide.wav", gen_slide())
    write_wav("merge.wav", gen_merge())
    write_wav("game_over.wav", gen_game_over())
    write_wav("win.wav", gen_win())
    print("Done!")
