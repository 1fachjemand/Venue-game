"""Small music synthesizer for HEADLINER (numpy + scipy). Instruments, drums, effects.
All functions return mono float32 numpy arrays at SR."""
import numpy as np
from scipy import signal

SR = 44100


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def tt(dur):
    return np.arange(max(1, int(dur * SR))) / SR


def lowpass(x, f, order=2):
    f = min(f, SR * 0.45)
    sos = signal.butter(order, f, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, f, order=2):
    sos = signal.butter(order, f, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    sos = signal.butter(order, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def peak(x, f, q, gain=1.0):
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x) * gain


def env(n, a=0.005, r=0.05, hold=None):
    """attack / hold / release envelope over n samples"""
    e = np.ones(n)
    na = max(1, int(a * SR))
    nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)[: n]
    if nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def expdec(n, k):
    return np.exp(-np.arange(n) / SR * k)


def saw(freq_arr):
    ph = np.cumsum(freq_arr) / SR
    return 2 * (ph % 1.0) - 1


def square(freq_arr, duty=0.5):
    ph = np.cumsum(freq_arr) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def sine(freq_arr):
    return np.sin(2 * np.pi * np.cumsum(freq_arr) / SR)


def const(f, n):
    return np.full(n, float(f))


def vib(f, n, rate=5.5, depth=0.006, delay=0.15):
    t = np.arange(n) / SR
    d = np.clip((t - delay) / 0.2, 0, 1) * depth
    return f * (1 + d * np.sin(2 * np.pi * rate * t))


rng = np.random.default_rng(1)


def noise(n):
    return rng.uniform(-1, 1, n)


# ------------------------------------------------------------------ drums
def kick(kind="punch"):
    if kind == "808":
        n = int(0.9 * SR)
        t = np.arange(n) / SR
        f = 48 + 90 * np.exp(-t * 40)
        x = sine(f) * np.exp(-t * 2.6)
        return np.tanh(x * 2.2) * 0.9
    if kind == "soft":
        n = int(0.35 * SR)
        t = np.arange(n) / SR
        f = 55 + 70 * np.exp(-t * 35)
        return sine(f) * np.exp(-t * 11) * 0.85
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 32)
    x = sine(f) * np.exp(-t * 8)
    x[: int(0.004 * SR)] += noise(int(0.004 * SR)) * 0.5
    return np.tanh(x * 1.6)


def snare(kind="pop"):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 22)
    nz = bandpass(noise(n), 1200, 9000) * np.exp(-t * (16 if kind != "brush" else 9))
    if kind == "brush":
        return (lowpass(nz, 5000) * 0.6 + tone * 0.15) * 0.8
    if kind == "metal":
        return np.tanh((tone * 0.7 + nz * 1.2) * 1.5) * 0.8
    return tone * 0.55 + nz * 0.9


def clap():
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    e = np.zeros(n)
    for d in (0.0, 0.011, 0.022):
        i = int(d * SR)
        e[i:] += np.exp(-(t[: n - i]) * 90)
    e += np.exp(-t * 12) * 0.35
    return bandpass(noise(n), 900, 4200) * e * 1.1


def hat(open_=False):
    dur = 0.32 if open_ else 0.06
    n = int(dur * SR)
    t = np.arange(n) / SR
    return highpass(noise(n), 7000) * np.exp(-t * (9 if open_ else 70)) * 0.5


def crash():
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    return highpass(noise(n), 3500) * np.exp(-t * 2.4) * 0.45


def tom(f=110):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    return sine(f * (1 + 0.5 * np.exp(-t * 20))) * np.exp(-t * 9) * 0.8


def shaker():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    e = np.sin(np.pi * np.clip(t / 0.09, 0, 1))
    return highpass(noise(n), 5000) * e * 0.3


def rim():
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1700 * t) * 0.6 + bandpass(noise(n), 1500, 5000) * 0.4) * np.exp(-t * 60)


# ------------------------------------------------------------------ pitched instruments (freq in Hz, dur in s)
def pluck_ks(f, dur, bright=0.5, decay=0.996):
    """Karplus-Strong string, vectorised per period"""
    N = max(2, int(SR / f))
    n = int(dur * SR) + N
    out = np.zeros(n)
    buf = lowpass(noise(N), 1500 + 6000 * bright, 1) if N > 20 else noise(N)
    out[:N] = buf
    k = N
    while k < n:
        prev = out[k - N : k]
        nxt = 0.5 * (prev + np.roll(prev, 1)) * decay
        m = min(N, n - k)
        out[k : k + m] = nxt[:m]
        k += N
    return out[N:] * env(n - N, 0.001, 0.05)


def piano(f, dur, vel=1.0):
    n = int((dur + 0.8) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR * 0.45:
            break
        x += np.sin(2 * np.pi * fk * t) / k ** 1.3 * np.exp(-t * (1.6 + 0.9 * k))
    x[: int(0.003 * SR)] += noise(int(0.003 * SR)) * 0.2
    rel = np.clip(1 - (t - dur) / 0.25, 0, 1)
    return x * rel * vel * 0.6


def rhodes(f, dur, vel=1.0):
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6)
    x += 0.15 * np.sin(2 * np.pi * 14 * f * t) * np.exp(-t * 40)
    x *= np.exp(-t * 1.1) * (1 + 0.15 * np.sin(2 * np.pi * 4.5 * t))
    rel = np.clip(1 - (t - dur) / 0.3, 0, 1)
    return x * rel * vel * 0.5


def bell(f, dur, vel=1.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.2) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 4) + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 7)
    return x * vel * 0.35


def marimba(f, dur, vel=1.0):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 7) + 0.3 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t * 25)
    return x * vel * 0.6


def synth_saw(f, dur, vel=1.0, cutoff=2500, detune=0.004, voices=3, a=0.005, r=0.1, sustain=1.0):
    n = int((dur + r) * SR)
    x = np.zeros(n)
    for v in range(voices):
        d = 1 + detune * (v - (voices - 1) / 2)
        x += saw(const(f * d, n))
    x /= voices
    x = lowpass(x, cutoff)
    return x * env(n, a, r) * vel * 0.5


def supersaw(f, dur, vel=1.0, cutoff=4500):
    return synth_saw(f, dur, vel, cutoff, detune=0.006, voices=7, a=0.01, r=0.15)


def pad(f, dur, vel=1.0, cutoff=1400):
    n = int((dur + 0.6) * SR)
    x = np.zeros(n)
    for d in (0.996, 1.0, 1.004, 2.002):
        x += saw(vib(f * d, n, 0.3, 0.002, 0))
    x = lowpass(x / 4, cutoff)
    return x * env(n, min(0.4, dur / 2), 0.6) * vel * 0.4


def pluck_synth(f, dur, vel=1.0, bright=4000):
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    x = square(const(f, n), 0.35) * 0.6 + saw(const(f * 1.003, n)) * 0.4
    # filter envelope: bright attack, dark tail (two bands mixed)
    x = lowpass(x, bright) * np.exp(-t * 9) + lowpass(x, 900) * np.exp(-t * 3) * 0.4
    return x * env(n, 0.002, 0.1) * vel * 0.55


def bass(f, dur, kind="saw", vel=1.0):
    n = int((dur + 0.05) * SR)
    t = np.arange(n) / SR
    if kind == "sub":
        x = sine(const(f, n))
    elif kind == "808":
        x = np.tanh(sine(f * (1 + 0.15 * np.exp(-t * 30))) * 1.8)
        x *= np.exp(-t * 1.2)
    elif kind == "pluck":
        x = pluck_ks(f, dur + 0.05, 0.3, 0.995)[:n] * 1.6
    elif kind == "picked":
        x = lowpass(saw(const(f, n)), 900) * (0.6 + 0.4 * np.exp(-t * 6))
    else:  # saw
        x = lowpass(saw(const(f, n)) * 0.7 + sine(const(f, n)) * 0.5, 700)
    return x * env(n, 0.004, 0.04) * vel * 0.8


def dist_guitar(freqs, dur, vel=1.0, mute=False, drive=6.0):
    n = int((dur + 0.08) * SR)
    x = np.zeros(n)
    for f in freqs:
        x += saw(const(f * 0.999, n)) + saw(const(f * 1.002, n))
    t = np.arange(n) / SR
    if mute:
        x *= np.exp(-t * 18)
    x = np.tanh(x * drive) * 0.6
    x = lowpass(highpass(x, 90), 3800 if not mute else 2200)
    return x * env(n, 0.003, 0.06) * vel * 0.5


def clean_guitar(freqs, dur, vel=1.0, strum=0.012):
    n = int((dur + 0.4) * SR)
    x = np.zeros(n)
    for i, f in enumerate(freqs):
        s = pluck_ks(f, dur + 0.4, 0.6, 0.997)
        off = int(i * strum * SR)
        m = min(len(s), n - off)
        x[off : off + m] += s[:m]
    return x * vel * 0.35


FORMANTS = {"a": (800, 1150, 2900), "o": (450, 800, 2830), "e": (400, 2000, 2550), "u": (325, 700, 2530)}


def voice(f, dur, vel=1.0, vowel="a", breath=0.03):
    """vowel-like lead: saw with vibrato through three formant filters"""
    n = int((dur + 0.12) * SR)
    src = saw(vib(f, n, 5.2, 0.008, 0.18)) + noise(n) * breath
    fm = FORMANTS.get(vowel, FORMANTS["a"])
    x = peak(src, fm[0], 6, 1.0) + peak(src, fm[1], 8, 0.6) + peak(src, fm[2], 10, 0.25)
    return lowpass(x, 5000) * env(n, 0.04, 0.12) * vel * 0.9


def whistle(f, dur, vel=1.0):
    n = int((dur + 0.1) * SR)
    x = sine(vib(f, n, 5, 0.005, 0.1)) + 0.1 * sine(vib(2 * f, n, 5, 0.005, 0.1)) + bandpass(noise(n), f * 0.8, f * 1.6) * 0.08
    return x * env(n, 0.05, 0.1) * vel * 0.4


def fiddle(f, dur, vel=1.0):
    n = int((dur + 0.1) * SR)
    x = lowpass(saw(vib(f, n, 6, 0.01, 0.08)), 3500)
    x = peak(x, 1000, 2, 1.0) + x * 0.3
    return x * env(n, 0.06, 0.1) * vel * 0.35


def lead_square(f, dur, vel=1.0):
    n = int((dur + 0.08) * SR)
    x = lowpass(square(vib(f, n, 5.5, 0.004, 0.2), 0.5), 3200)
    return x * env(n, 0.01, 0.08) * vel * 0.3


def lead_guitar(f, dur, vel=1.0):
    n = int((dur + 0.1) * SR)
    x = np.tanh(saw(vib(f, n, 5.5, 0.01, 0.25)) * 5)
    x = lowpass(highpass(x, 200), 4200)
    return x * env(n, 0.005, 0.1) * vel * 0.35


INSTRUMENTS = {
    "piano": piano, "rhodes": rhodes, "bell": bell, "marimba": marimba, "saw": synth_saw, "supersaw": supersaw,
    "pad": pad, "pluck": pluck_synth, "voice": voice, "whistle": whistle, "fiddle": fiddle, "square": lead_square,
    "leadgtr": lead_guitar,
}


# ------------------------------------------------------------------ effects
_ir_cache = {}


def reverb(x, size=1.6, wet=0.25, bright=6000):
    key = (size, bright)
    if key not in _ir_cache:
        n = int(size * SR)
        t = np.arange(n) / SR
        r = np.random.default_rng(7)
        ir = r.uniform(-1, 1, n) * np.exp(-t * 6.9 / size)
        ir = lowpass(ir, bright)
        ir[: int(0.012 * SR)] = 0
        _ir_cache[key] = ir / np.sqrt(np.sum(ir ** 2))
    w = signal.fftconvolve(x, _ir_cache[key])[: len(x)]
    return x * (1 - wet * 0.5) + w * wet * 0.5


def place(buf, x, start_s, gain=1.0):
    i = int(start_s * SR)
    if i >= len(buf):
        return
    m = min(len(x), len(buf) - i)
    buf[i : i + m] += x[:m] * gain


def master(x, target_rms=0.16):
    x = highpass(x, 28)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (target_rms / rms)
    x = np.tanh(x * 1.25) / np.tanh(1.25)
    pk = np.max(np.abs(x)) + 1e-9
    if pk > 0.97:
        x = x * 0.97 / pk
    return x.astype(np.float32)
