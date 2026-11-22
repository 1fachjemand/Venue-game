"""Tension music for the show intros (one cue per intro type), made with the game's own synthesizer.

  python3 tools/music/make_intro.py [out_dir]          (default: audio/)

Writes intro.ogg (6 cues of 14 s each, in the order of INTRO_ORDER) and prints the AudioMap lines.
Every cue builds up for about 11 s (low drone, a rising noise sweep, pulses getting faster) and ends in a hit,
the moment the artist appears."""
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import synth as S  # noqa: E402
from synth import SR  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CUE = 14.0
HIT = 11.2  # the hit (the intro of the show is 10 - 12 s long)
INTRO_ORDER = ["countdown", "reveal", "glitch", "stars", "heartbeat", "storm"]


def drone(root, dur, bright=600, detune=0.006):
    t = S.tt(dur)
    f = S.midi_hz(root)
    x = np.zeros(len(t))
    for d in (-detune, 0, detune):
        x += S.saw(S.const(f * (1 + d), len(t))) + 0.5 * S.saw(S.const(f * 2 * (1 - d), len(t)))
    cut = np.linspace(bright * 0.5, bright * 2.5, len(t))
    # a slowly opening filter: done in blocks with a rising cutoff
    out = np.zeros(len(t))
    blk = int(0.25 * SR)
    for i in range(0, len(t), blk):
        out[i:i + blk] = S.lowpass(x[max(0, i - blk):i + blk], cut[i])[-len(x[i:i + blk]):]
    fade = np.clip(t / 2.0, 0, 1) * np.clip((HIT - t) / 0.3, 0, 1)
    return out * fade * 0.12


def riser(dur, start=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = S.noise(n)
    out = np.zeros(n)
    blk = int(0.1 * SR)
    for i in range(0, n, blk):
        k = min(1, max(0, (t[i] - start) / (HIT - start)))
        lo = 300 + 5000 * k ** 2
        out[i:i + blk] = S.bandpass(nz[max(0, i - blk):i + blk], lo, lo * 1.8)[-len(nz[i:i + blk]):] * (k ** 1.5)
    out *= np.clip((HIT - t) / 0.05, 0, 1)
    return out * 0.5


def pulses(times, inst, gain=0.8):
    x = np.zeros(int(CUE * SR))
    for tt in times:
        if tt < HIT:
            S.place(x, inst, tt, gain)
    return x


def hit(big=True):
    x = np.zeros(int(CUE * SR))
    S.place(x, S.kick("808"), HIT, 1.0)
    S.place(x, S.crash(), HIT, 0.9 if big else 0.6)
    S.place(x, S.tom(70), HIT, 0.7)
    return x


def accel(t0, t1, start_gap, end_gap):
    times, t, g = [], t0, start_gap
    while t < t1:
        times.append(t)
        k = (t - t0) / (t1 - t0)
        g = start_gap + (end_gap - start_gap) * k
        t += g
    return times


def cue(kind):
    n = int(CUE * SR)
    x = np.zeros(n)
    if kind == "countdown":
        # a clock ticks faster and faster over a deep drone, then BOOM
        x[:] += np.pad(drone(33, HIT + 0.3), (0, n))[:n]
        tick = S.bandpass(S.noise(int(0.03 * SR)), 2500, 6000) * np.exp(-np.arange(int(0.03 * SR)) / SR * 120)
        x += pulses(accel(1.0, HIT, 1.0, 0.12), tick, 0.6)
        x += riser(CUE, 5.0)
        x += hit()
    elif kind == "reveal":
        # a choir-like swell of pads that opens up, the name appears with a big chord
        for i, m in enumerate((45, 52, 57, 60, 64)):
            p = S.pad(S.midi_hz(m), HIT - 1.0 + 0.3, 0.5)
            S.place(x, p * np.linspace(0, 1, len(p)) ** 1.5, 1.0 + i * 0.4, 0.55)
        x += riser(CUE, 3.0) * 0.7
        for m in (45, 57, 64, 69):
            ch = S.pad(S.midi_hz(m), 2.6, 1.0, 3000)
            S.place(x, ch * np.exp(-np.linspace(0, 3, len(ch))), HIT, 0.25)
        x += hit(False)
    elif kind == "glitch":
        # broken signal: noise bursts and stutters that get denser
        x[:] += np.pad(drone(31, HIT + 0.3, 900, 0.02), (0, n))[:n]
        r = np.random.default_rng(4)
        for tt in accel(0.6, HIT, 0.7, 0.06):
            ln = r.uniform(0.03, 0.12)
            b = S.highpass(S.noise(int(ln * SR)), r.uniform(800, 4000)) * 0.5
            S.place(x, b, tt, 0.5)
        x += riser(CUE, 4.0)
        x += hit()
    elif kind == "stars":
        # shimmering bells over a soft pad, rising into a bright hit
        for i, m in enumerate((48, 55, 60, 64)):
            p = S.pad(S.midi_hz(m), HIT + 0.2, 0.5, 1800)
            S.place(x, p * np.linspace(0.2, 1, len(p)), 0.3, 0.45)
        r = np.random.default_rng(7)
        scale = [72, 74, 76, 79, 81, 84, 86, 88]
        for tt in accel(0.5, HIT, 0.5, 0.11):
            S.place(x, S.bell(S.midi_hz(scale[r.integers(0, len(scale))]), 1.2, 0.5), tt, 0.5)
        x += riser(CUE, 6.0) * 0.6
        x += hit(False)
    elif kind == "heartbeat":
        # a heartbeat that gets faster and louder
        beat = S.kick("soft")
        times = []
        t, g = 0.8, 1.05
        while t < HIT - 0.2:
            times += [t, t + 0.22]
            g = max(0.42, g * 0.93)
            t += g
        hb = pulses(times, beat, 1.0)
        x += hb * np.linspace(0.5, 1.2, n)
        x[:] += np.pad(drone(28, HIT + 0.3, 300), (0, n))[:n]
        x += hit()
    elif kind == "storm":
        # wind, rolling thunder, a riser into the hit
        t = np.arange(n) / SR
        wind = S.bandpass(S.noise(n), 200, 900) * (0.4 + 0.3 * np.sin(2 * np.pi * 0.2 * t)) * np.clip((HIT - t) / 0.2, 0, 1)
        x += wind * 0.35
        r = np.random.default_rng(11)
        for tt in (1.5, 4.2, 6.8, 8.7, 10.1):
            th = S.lowpass(S.noise(int(2.2 * SR)), 180) * np.exp(-np.arange(int(2.2 * SR)) / SR * 1.6)
            S.place(x, th, tt, 1.2 + r.uniform(0, 0.4))
        x[:] += np.pad(drone(29, HIT + 0.3, 500), (0, n))[:n]
        x += riser(CUE, 4.0)
        x += hit()
    tail = np.arange(n) / SR
    x *= np.clip((CUE - tail) / 1.5, 0, 1)
    return S.reverb(x, 1.8, 0.25)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "audio")
    sys.path.insert(0, os.path.dirname(__file__))
    from make_audio import write_ogg
    parts, rows, pos = [], [], 0.0
    for k in INTRO_ORDER:
        c = cue(k).astype(np.float32)
        c = c / max(1e-6, np.max(np.abs(c))) * 0.85
        rows.append("\t%s = { %.3f, %.3f }," % (k, pos, CUE))
        parts.append(c[: int(CUE * SR)])
        pos += CUE
    write_ogg(os.path.join(out_dir, "intro.ogg"), np.concatenate(parts))
    print("AudioMap.INTRO = {")
    print("\n".join(rows))
    print("}")


if __name__ == "__main__":
    main()
