"""Composes and renders all game audio for HEADLINER.

  python3 tools/music/make_audio.py [out_dir]          (default: audio/)

Output (upload every .ogg to Roblox, see audio/README.md):
  <artist>.ogg   12 songs x 30 s for each artist (one file per artist, played in parts with PlaybackRegion)
  menu.ogg       title music + office music
  sfx.ogg        button clicks, cash, cheers, applause, pyro ...
and src/Headliner/Data/AudioMap.lua with the time regions inside the files.
Songs are instrumental: drums, bass, chords, guitars/keys/synths and a voice-like lead, styled per artist."""
import os
import sys
import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import synth as S  # noqa: E402
from synth import SR  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SONG_LEN = 30.0
SONGS = 12

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixo": [0, 2, 4, 5, 7, 9, 10],
    "phryg": [0, 1, 3, 5, 7, 8, 10],
}

# chord progressions as scale degrees (one chord per bar)
PROGS = {
    "pop": [[0, 4, 5, 3], [5, 3, 0, 4], [0, 5, 3, 4], [3, 4, 5, 5]],
    "minor": [[0, 5, 2, 6], [0, 3, 5, 4], [5, 6, 0, 0], [0, 6, 5, 6]],
    "rock": [[0, 6, 3, 0], [0, 3, 4, 3], [0, 4, 6, 3]],
    "metal": [[0, 1, 0, 6], [0, 5, 6, 0], [0, 0, 5, 1]],
    "rnb": [[1, 4, 0, 5], [3, 2, 1, 4], [0, 5, 3, 4]],
    "country": [[0, 3, 4, 0], [0, 4, 3, 0], [3, 0, 4, 4]],
    "latin": [[0, 5, 2, 6], [0, 3, 6, 4], [5, 6, 0, 0]],
}

RHYTHMS = {  # melody rhythms over 2 bars: (16th step, length in 16ths)
    "pop": [[(0, 2), (2, 2), (4, 4), (10, 2), (12, 4), (16, 2), (18, 2), (20, 2), (22, 6), (28, 4)],
            [(2, 2), (4, 2), (6, 4), (12, 2), (14, 2), (16, 4), (22, 2), (24, 8)]],
    "syncop": [[(0, 3), (3, 3), (6, 2), (8, 4), (14, 2), (16, 3), (19, 3), (22, 4), (28, 4)],
               [(0, 2), (3, 3), (6, 4), (12, 4), (16, 2), (19, 3), (22, 2), (24, 6)]],
    "long": [[(0, 6), (6, 2), (8, 8), (16, 6), (22, 2), (24, 8)], [(0, 4), (4, 4), (8, 8), (16, 8), (24, 8)]],
    "rap": [[(0, 2), (4, 2), (6, 2), (10, 2), (12, 4), (16, 2), (20, 2), (22, 2), (26, 6)]],
    "fast": [[(i * 2, 2) for i in range(16)], [(0, 3), (3, 1), (4, 2), (6, 2), (8, 4), (12, 2), (14, 2), (16, 3), (19, 1), (20, 4), (24, 8)]],
    "latin": [[(0, 3), (3, 3), (6, 2), (8, 3), (11, 3), (14, 2), (16, 4), (22, 2), (24, 8)]],
    "ballad": [[(0, 4), (4, 4), (8, 8), (16, 4), (20, 4), (24, 8)], [(2, 2), (4, 6), (10, 6), (16, 4), (20, 2), (22, 10)]],
}

DRUMS = {  # 16-step patterns: K kick, S snare, C clap, H hat, O open hat, R rim, T shaker
    "pop": {"K": "x...x...x...x...", "C": "....x.......x...", "H": "x.x.x.x.x.x.x.x.", "O": "..............x."},
    "pop2": {"K": "x.....x...x.....", "S": "....x.......x...", "H": "xxxxxxxxxxxxxxxx", "C": "............x..."},
    "rock": {"K": "x.......x.x.....", "S": "....x.......x...", "H": "x.x.x.x.x.x.x.x."},
    "metal": {"K": "xxxxxxxxxxxxxxxx", "S": "....x.......x...", "O": "x.x.x.x.x.x.x.x."},
    "edm": {"K": "x...x...x...x...", "C": "....x.......x...", "O": "..x...x...x...x.", "H": "x.x.x.x.x.x.x.x."},
    "hiphop": {"K": "x......x.x......", "C": "........x.......", "H": "x.x.x.x.x.x.xxxx", "R": "...........x...."},
    "latin": {"K": "x...x...x...x...", "S": "...x..x....x..x.", "T": "x.x.x.x.x.x.x.x.", "R": "......x.......x."},
    "country": {"K": "x.......x.......", "S": "xxxxxxxxxxxxxxxx", "H": "..x...x...x...x."},
    "rnb": {"K": "x......x..x.....", "S": "....x.......x...", "H": "x.x.x.x.x.x.x.x.", "R": "...x.......x...."},
    "indie": {"K": "x...x.....x.x...", "S": "....x.......x...", "T": "x.x.x.x.x.x.x.x."},
    "ballad": {"K": "x.......x.......", "S": "....x.......x...", "H": "x...x...x...x..."},
}

BASSLINES = {  # (16th step, length, interval in semitones above the chord root)
    "pop": [(0, 3, 0), (3, 3, 0), (6, 2, 0), (8, 3, 0), (11, 3, 0), (14, 2, 7)],
    "rock": [(i * 2, 2, 0) for i in range(8)],
    "metal": [(i, 1, 0) for i in range(16)],
    "edm": [(2, 2, 0), (6, 2, 0), (10, 2, 0), (14, 2, 12)],
    "hiphop": [(0, 6, 0), (7, 2, 0), (10, 6, 0)],
    "latin": [(0, 3, 0), (3, 3, 0), (6, 2, 7), (8, 3, 0), (11, 3, 0), (14, 2, 7)],
    "country": [(0, 4, 0), (4, 4, 7), (8, 4, 0), (12, 4, 7)],
    "rnb": [(0, 6, 0), (6, 2, 12), (8, 4, 7), (12, 3, 0), (15, 1, 12)],
    "indie": [(0, 4, 0), (4, 2, 0), (6, 2, 7), (8, 4, 0), (12, 4, 12)],
    "ballad": [(0, 16, 0)],
}

# one style per artist: tempo, scale, progressions, drum/bass patterns, instruments, mix
STYLES = {
    "lila": dict(bpm=(96, 112), scale="major", prog="pop", drums="indie", kick="soft", snare="pop", bass="picked", bline="indie", chords="strum", lead="whistle", rhythm="long", arp="bell", verb=0.38, key=(43, 47)),
    "juno": dict(bpm=(112, 124), scale="major", prog="pop", drums="pop", kick="punch", snare="pop", bass="saw", bline="pop", chords="stab", chord_inst="pluck", lead="voice", rhythm="pop", arp="pluck", verb=0.22, key=(43, 48)),
    "rusty": dict(bpm=(132, 150), scale="mixo", prog="rock", drums="rock", kick="punch", snare="pop", bass="picked", bline="rock", chords="power", lead="leadgtr", rhythm="fast", verb=0.15, key=(40, 45)),
    "voltage": dict(bpm=(126, 129), scale="minor", prog="minor", drums="edm", kick="punch", snare="pop", bass="saw", bline="edm", chords="edm", chord_inst="supersaw", lead="supersaw", rhythm="syncop", arp="pluck", verb=0.25, key=(41, 46), edm=True),
    "kai": dict(bpm=(84, 94), scale="minor", prog="minor", drums="hiphop", kick="808", snare="pop", bass="808", bline="hiphop", chords="piano", lead="bell", rhythm="rap", verb=0.2, key=(40, 45), half=True),
    "neon": dict(bpm=(118, 134), scale="major", prog="pop", drums="indie", kick="punch", snare="pop", bass="picked", bline="indie", chords="strum", lead="leadgtr", rhythm="pop", arp="bell", verb=0.28, key=(42, 47)),
    "ironclad": dict(bpm=(150, 172), scale="phryg", prog="metal", drums="metal", kick="punch", snare="metal", bass="picked", bline="metal", chords="power", lead="leadgtr", rhythm="fast", verb=0.12, key=(38, 42), heavy=True),
    "velvet": dict(bpm=(72, 86), scale="dorian", prog="rnb", drums="rnb", kick="soft", snare="pop", bass="sub", bline="rnb", chords="rhodes", lead="voice", rhythm="syncop", verb=0.32, key=(41, 46), sevenths=True, swing=0.12),
    "luna": dict(bpm=(90, 98), scale="minor", prog="latin", drums="latin", kick="punch", snare="pop", bass="saw", bline="latin", chords="marimba", lead="voice", rhythm="latin", arp="pluck", verb=0.22, key=(41, 46)),
    "dusty": dict(bpm=(100, 118), scale="major", prog="country", drums="country", kick="soft", snare="brush", bass="picked", bline="country", chords="strum", lead="fiddle", rhythm="pop", verb=0.22, key=(43, 47)),
    "starlyte": dict(bpm=(120, 128), scale="minor", prog="minor", drums="pop2", kick="punch", snare="pop", bass="saw", bline="pop", chords="edm", chord_inst="supersaw", lead="voice", rhythm="syncop", arp="pluck", verb=0.22, key=(42, 47), edm=True),
    "nova": dict(bpm=(114, 124), scale="major", prog="pop", drums="pop", kick="punch", snare="pop", bass="saw", bline="pop", chords="pad", lead="voice", rhythm="pop", arp="pluck", verb=0.3, key=(42, 47), big=True),
}
ARTISTS = ["lila", "juno", "rusty", "voltage", "kai", "neon", "ironclad", "velvet", "luna", "dusty", "starlyte", "nova"]
BALLAD_INDEX = 4  # song 4 of every setlist is the ballad
HIT_INDEX = 8  # song 8 is the big hit (always the finale)


def deg_midi(key, scale, i):
    return key + 12 * (i // 7) + scale[i % 7]


def make_melody(r, scale, key, bars, prog, rhythm_bank, step, lo_oct=24):
    """2-bar phrases A A' B A'': chord tones on strong beats, steps in between"""
    notes = []
    base = 7 * (lo_oct // 12)
    phraseA = rhythm_bank[r.integers(len(rhythm_bank))]
    phraseB = rhythm_bank[r.integers(len(rhythm_bank))]
    cache = {}
    cur = base + 4
    for p in range(0, bars, 2):
        kind = ["A", "A2", "B", "A3"][(p // 2) % 4]
        rhythm = phraseB if kind == "B" else phraseA
        if kind in cache and kind != "B":
            seq = list(cache["A"])
            if kind != "A" and len(seq) > 2:
                seq[-1] = seq[-1] + (1 if kind == "A2" else -1)
                seq[-2] = seq[-2] + (2 if kind == "A3" else 0)
        else:
            seq = []
            for (st, ln) in rhythm:
                bar = p + st // 16
                chord = prog[bar % len(prog)]
                if st % 8 == 0:
                    tones = [chord + base, chord + 2 + base, chord + 4 + base, chord + 7 + base]
                    cur = min(tones, key=lambda x: abs(x - cur) + r.random())
                else:
                    cur += int(r.choice([-2, -1, -1, 1, 1, 2]))
                cur = int(np.clip(cur, base - 1, base + 9))
                seq.append(cur)
            if kind == "A":
                cache["A"] = list(seq)
            if kind == "B":
                cache["B"] = list(seq)
        for (st, ln), d in zip(rhythm, seq):
            bar = p + st // 16
            if bar >= bars:
                continue
            notes.append((bar * 16 * step + (st % 16) * step, ln * step, deg_midi(key, scale, d)))
    return notes


def chord_notes(key, scale, deg, sevenths=False, octave=12):
    idx = [deg, deg + 2, deg + 4] + ([deg + 6] if sevenths else [])
    return [deg_midi(key + octave, scale, i) for i in idx]


def render_song(style, seed, ballad=False, hit=False, length=SONG_LEN):
    r = np.random.default_rng(seed)
    bpm = int(r.integers(64, 76)) if ballad else int(r.integers(style["bpm"][0], style["bpm"][1] + 1))
    if hit:
        bpm = min(style["bpm"][1] + 2, bpm + 3)
    beat = 60.0 / bpm
    step = beat / 4
    bar_s = beat * 4
    bars = max(6, int((length - 1.2) / bar_s))
    key = int(r.integers(style["key"][0], style["key"][1] + 1))
    scale = SCALES[style["scale"]]
    progs = PROGS[style["prog"]]
    prog = progs[int(r.integers(len(progs)))]
    edm = style.get("edm") and not ballad
    n = int((length + 2) * SR)
    tracks = {k: np.zeros(n) for k in ("drums", "bass", "chords", "lead", "arp", "pad", "fx")}
    swing = style.get("swing", 0.0)

    def stime(bar, st):
        sw = swing * step if st % 2 == 1 else 0
        return bar * bar_s + st * step + sw

    intro = 2
    build = 2 if edm else 0
    chorus_from = intro + build + (0 if edm else max(2, (bars - intro) // 3))
    kit = {
        "K": S.kick(style["kick"]), "S": S.snare(style["snare"]), "C": S.clap(), "H": S.hat(False),
        "O": S.hat(True), "R": S.rim(), "T": S.shaker(),
    }
    pattern = DRUMS["ballad" if ballad else style["drums"]]
    for b in range(bars):
        energy = 0.35 if b < intro else (0.75 if b < chorus_from else 1.0)
        if ballad:
            energy = 0.0 if b < bars // 2 else 0.6
        if edm and intro <= b < intro + build:
            # build-up: snare roll gets faster, no kick
            k = b - intro
            div = 4 if k == 0 else 2
            for st in range(0, 16, div):
                S.place(tracks["drums"], kit["S"], stime(b, st), 0.3 + 0.5 * (st / 16 + k) / 2)
            continue
        if energy <= 0:
            continue
        for inst, pat in pattern.items():
            if b < intro and inst in ("S", "C") and not edm:
                continue
            if inst == "K" and style.get("heavy") and b < chorus_from:
                pat = "x.x.x.x.x.x.x.x."
            for st, ch in enumerate(pat):
                if ch == "x":
                    g = energy * (0.9 if inst in ("K", "S", "C") else 0.55)
                    if inst == "H" and st % 4 != 0:
                        g *= 0.7
                    if style["snare"] == "brush" and inst == "S" and st not in (4, 12):
                        g *= 0.22  # brushes: soft ghost notes, accents on 2 and 4
                    g *= 0.9 + 0.2 * r.random()  # a human drummer never hits twice the same
                    S.place(tracks["drums"], kit[inst], stime(b, st), g)
        if style.get("half") and r.random() < 0.4:
            for st in (12, 13, 14, 15):  # trap hat roll
                S.place(tracks["drums"], kit["H"], stime(b, st) + step / 2, 0.35)
        if b in (intro, chorus_from) or b == 0:
            S.place(tracks["drums"], S.crash(), stime(b, 0), 0.6 * max(0.5, energy))
        if b == chorus_from - 1 and not ballad and b > 0:
            for st in (12, 13, 14, 15):  # fill into the chorus
                S.place(tracks["drums"], kit["S"], stime(b, st), 0.5)
    S.place(tracks["drums"], S.crash(), stime(bars, 0), 0.6)

    # bass
    bline = BASSLINES["ballad" if ballad else style["bline"]]
    for b in range(bars + 1):
        if b < (1 if not edm else intro + build) and not ballad:
            continue
        deg = prog[min(b, bars - 1) % len(prog)]
        root = deg_midi(key, scale, deg) - (12 if style["bass"] in ("808", "sub") else 0)
        for (st, ln, iv) in (bline if b < bars else [(0, 16, 0)]):
            f = S.midi_hz(root + iv)
            if style["bass"] == "808":
                x = S.bass(f, ln * step, "808")
            else:
                x = S.bass(f, ln * step * 0.92, style["bass"])
            S.place(tracks["bass"], x, stime(b, st), 0.8)

    # chords
    sev = style.get("sevenths", False)
    cstyle = style["chords"]
    if ballad:
        cstyle = {"rhodes": "rhodes", "strum": "strum", "power": "piano"}.get(cstyle, "piano")
    for b in range(bars + 1):
        deg = prog[min(b, bars - 1) % len(prog)]
        notes = chord_notes(key, scale, deg, sev or ballad)
        fs = [S.midi_hz(m) for m in notes]
        last = b == bars
        energy = 0.6 if b < chorus_from else 1.0
        if cstyle == "pad" or (edm and b < intro):
            for f in fs:
                S.place(tracks["pad"], S.pad(f, bar_s * (2 if last else 1)), stime(b, 0), 0.5)
            if cstyle == "pad" and b >= chorus_from:
                for st in (0, 6, 10):
                    for f in fs:
                        S.place(tracks["chords"], S.pluck_synth(f * 2, step * 2), stime(b, st), 0.25)
        elif cstyle == "piano":
            hits = [0] if last else ([0, 8] if not ballad else [0, 4, 8, 12])
            for st in hits:
                if ballad and not last:
                    m = notes[(st // 4) % len(notes)]
                    S.place(tracks["chords"], S.piano(S.midi_hz(m), beat * 1.5), stime(b, st), 0.8)
                    if st == 0:
                        S.place(tracks["chords"], S.piano(S.midi_hz(notes[0] - 12), bar_s), stime(b, 0), 0.6)
                else:
                    for f in fs:
                        S.place(tracks["chords"], S.piano(f, beat * (4 if last else 2)), stime(b, st), 0.45 * energy + 0.2)
        elif cstyle == "rhodes":
            for st in ([0] if last else [0, 10]):
                for f in fs:
                    S.place(tracks["chords"], S.rhodes(f, beat * (4 if last else 2.2)), stime(b, st), 0.6)
        elif cstyle == "strum":
            gtr = [S.midi_hz(m - 12) for m in notes] + [S.midi_hz(notes[0])]
            pat = [0] if last else ([0, 6, 8, 12, 14] if b >= chorus_from else [0, 8])
            for st in pat:
                S.place(tracks["chords"], S.clean_guitar(gtr if st % 4 == 0 else gtr[::-1], step * 4), stime(b, st), 0.7 * energy + 0.2)
        elif cstyle == "power":
            root = deg_midi(key, scale, deg) - (12 if style.get("heavy") else 0)
            pc = [S.midi_hz(root), S.midi_hz(root + 7), S.midi_hz(root + 12)]
            if last:
                S.place(tracks["chords"], S.dist_guitar(pc, bar_s * 1.5), stime(b, 0), 0.7)
                continue
            if b < intro:
                S.place(tracks["chords"], S.dist_guitar(pc, bar_s * 0.9), stime(b, 0), 0.6)
            else:
                for st in range(0, 16, 1 if style.get("heavy") else 2):
                    mute = (st % 4 != 0) or style.get("heavy") and st % 8 != 0
                    S.place(tracks["chords"], S.dist_guitar(pc[:2] if mute else pc, step * (1 if style.get("heavy") else 2), mute=mute), stime(b, st), 0.55)
        elif cstyle == "marimba":
            for st in range(0, 16, 2):
                m = notes[(st // 2) % len(notes)]
                S.place(tracks["chords"], S.marimba(S.midi_hz(m), step * 2), stime(b, st), 0.5)
            S.place(tracks["pad"], S.pad(fs[0], bar_s, cutoff=900), stime(b, 0), 0.3)
        elif cstyle in ("stab", "edm"):
            inst = S.INSTRUMENTS.get(style.get("chord_inst", "pluck"), S.pluck_synth)
            if last:
                for f in fs:
                    S.place(tracks["chords"], inst(f, bar_s), stime(b, 0), 0.5)
                continue
            if edm and b < intro + build:
                for f in fs:
                    S.place(tracks["pad"], S.pad(f, bar_s, cutoff=600 + 900 * (b - intro + 1)), stime(b, 0), 0.5)
                continue
            hits = [0, 3, 6, 10, 12] if b >= chorus_from else [0, 6, 10]
            for st in hits:
                for f in fs:
                    S.place(tracks["chords"], inst(f, step * 2.5), stime(b, st), 0.42)
            if edm:
                for f in fs:
                    S.place(tracks["pad"], S.pad(f, bar_s, cutoff=1800), stime(b, 0), 0.3)

    # arpeggio layer in the chorus
    if style.get("arp") and not ballad:
        ainst = S.INSTRUMENTS[style["arp"]]
        for b in range(chorus_from, bars):
            deg = prog[b % len(prog)]
            notes = chord_notes(key, scale, deg, False, 24)
            for st in range(0, 16, 2 if style["arp"] == "bell" else 1):
                if style["arp"] == "bell" and st % 4 == 2 and r.random() < 0.5:
                    continue
                m = notes[(st if style["arp"] != "bell" else st // 2) % len(notes)]
                S.place(tracks["arp"], ainst(S.midi_hz(m), step * 0.9), stime(b, st), 0.3)

    # lead melody (voice-like in pop styles)
    lead_name = "piano" if (ballad and style["lead"] in ("leadgtr", "supersaw")) else style["lead"]
    linst = S.INSTRUMENTS.get(lead_name, S.voice)
    bank = RHYTHMS["ballad" if ballad else style["rhythm"]]
    oct_ = 24 if lead_name not in ("bell", "whistle") else 36
    mel = make_melody(r, scale, key, bars, prog, bank, step, oct_)
    vowels = ["a", "o", "e", "a", "u"]
    for i, (st, ln, m) in enumerate(mel):
        b = int(st // bar_s)
        if b < intro and not ballad:
            continue
        g = 0.55 if b >= chorus_from else 0.42
        if lead_name == "voice":
            x = S.voice(S.midi_hz(m), ln * 0.95, 1.0, vowels[i % len(vowels)])
        else:
            x = linst(S.midi_hz(m), ln * 0.95)
        S.place(tracks["lead"], x, st + (swing * step if int(st / step) % 2 == 1 else 0), g)
        if (style.get("big") or hit) and b >= chorus_from and lead_name == "voice":
            # doubled an octave higher in big choruses
            S.place(tracks["lead"], S.voice(S.midi_hz(m + 12), ln * 0.95, 1.0, "e"), st, g * 0.35)

    # EDM: riser in the build and side-chain ducking on the kick
    if edm:
        t0 = intro * bar_s
        dur = build * bar_s
        nn = int(dur * SR)
        rise = S.noise(nn) * np.linspace(0, 1, nn) ** 2
        rise = S.bandpass(rise, 800, 9000)
        S.place(tracks["fx"], rise, t0, 0.35)
        duck = np.ones(n)
        for b in range(intro + build, bars):
            for st in (0, 4, 8, 12):
                i = int(stime(b, st) * SR)
                k = min(int(beat * 0.6 * SR), n - i)
                if k > 0:
                    duck[i:i + k] = np.minimum(duck[i:i + k], 0.35 + 0.65 * np.linspace(0, 1, k) ** 0.6)
        for kk in ("pad", "chords", "bass"):
            tracks[kk] *= duck

    gains = {"drums": 0.95, "bass": 0.85, "chords": 0.6, "lead": 0.75, "arp": 0.35, "pad": 0.45, "fx": 0.6}
    if ballad:
        gains.update(drums=0.5, chords=0.85, lead=0.7)
    mix = np.zeros(n)
    for k, x in tracks.items():
        mix += x * gains[k]
    wet = style["verb"] + (0.15 if ballad else 0)
    mix = S.reverb(mix, 2.2 if ballad else 1.5, wet)
    out = mix[: int(length * SR)]
    # fade the end so every song ends cleanly in its 30 s slot
    fl = int(1.6 * SR)
    out[-fl:] *= np.linspace(1, 0, fl) ** 1.5
    out[: int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
    return S.master(out, 0.15 if not ballad else 0.12)


# ------------------------------------------------------------------ crowd + effects
def crowd(dur, swell=1.0, high=False, seed=3):
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for _ in range(70):
        c = r.uniform(500, 2600 if high else 1600)
        v = S.bandpass(r.uniform(-1, 1, n), c * 0.8, c * 1.25)
        on = r.uniform(0, dur * 0.3)
        a = np.clip((t - on) / r.uniform(0.2, 0.6), 0, 1) * (0.6 + 0.4 * np.sin(2 * np.pi * r.uniform(0.2, 1.2) * t + r.uniform(0, 6)))
        out += v * a
    for _ in range(14):  # "woo" voices
        on = r.uniform(0, dur * 0.6)
        ln = r.uniform(0.6, 1.4)
        k = int(ln * SR)
        f = np.linspace(r.uniform(450, 650), r.uniform(800, 1100), k)
        v = S.voice(f[0], ln, 1.0, "u")[:k]
        S.place(out, v * np.sin(np.pi * np.linspace(0, 1, len(v))), on, 0.6)
    for _ in range(3):  # whistles
        on = r.uniform(0, dur * 0.7)
        S.place(out, S.whistle(r.uniform(2200, 3000), r.uniform(0.4, 0.9)), on, 0.5)
    shape = np.clip(t / 0.4, 0, 1) * np.clip((dur - t) / (dur * 0.45), 0, 1) ** 0.7 * swell
    return S.lowpass(out * shape, 6500)


def murmur(dur, seed=5):
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for _ in range(50):
        c = r.uniform(250, 1200)
        v = S.bandpass(r.uniform(-1, 1, n), c * 0.85, c * 1.2)
        out += v * (0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(0.3, 2) * t + r.uniform(0, 6)))
    # seamless loop: cross-fade the end into the start
    k = int(0.5 * SR)
    out[:k] = out[:k] * np.linspace(0, 1, k) + out[-k:] * np.linspace(1, 0, k)
    return out[: n - k]


def applause(dur, seed=9):
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    clap = S.bandpass(r.uniform(-1, 1, int(0.02 * SR)), 900, 4500) * np.exp(-np.arange(int(0.02 * SR)) / SR * 180)
    rate = 260
    for _ in range(int(rate * dur)):
        tt = r.uniform(0, dur)
        S.place(out, clap * r.uniform(0.4, 1.0), tt, 1.0)
    shape = np.clip(t / 0.3, 0, 1) * np.clip((dur - t) / (dur * 0.5), 0, 1)
    return out * shape


def tone_seq(notes, inst, gap):
    x = np.zeros(int((len(notes) * gap + 1.5) * SR))
    for i, m in enumerate(notes):
        S.place(x, inst(S.midi_hz(m), gap * 1.4), i * gap, 0.8)
    return x


def sfx_bank():
    out = {}
    out["click"] = S.lowpass(S.noise(int(0.012 * SR)), 5000) * 0.3
    out["click"] = np.concatenate([out["click"], np.sin(2 * np.pi * 1900 * np.arange(int(0.05 * SR)) / SR) * np.exp(-np.arange(int(0.05 * SR)) / SR * 90) * 0.4])
    out["hover"] = np.sin(2 * np.pi * 1300 * np.arange(int(0.05 * SR)) / SR) * np.exp(-np.arange(int(0.05 * SR)) / SR * 70) * 0.15
    out["place"] = S.tom(140) * 0.8 + S.lowpass(S.noise(int(0.4 * SR)), 900) * np.exp(-np.arange(int(0.4 * SR)) / SR * 25) * 0.4
    out["delete"] = tone_seq([67, 60], S.pluck_synth, 0.09)
    out["cash"] = tone_seq([88, 93], S.bell, 0.08) + np.pad(S.highpass(S.noise(int(0.3 * SR)), 5000) * np.exp(-np.arange(int(0.3 * SR)) / SR * 12) * 0.25, (0, int(1.62 * SR) + int(0.16 * SR) - int(0.3 * SR)))[: len(tone_seq([88, 93], S.bell, 0.08))]
    out["notify"] = tone_seq([76, 83], S.bell, 0.12)
    out["error"] = tone_seq([52, 49], S.lead_square, 0.12)
    out["soldout"] = tone_seq([60, 64, 67, 72, 76, 79, 84], lambda f, d: S.synth_saw(f, d, 1, 3500, 0.006, 4, 0.01, 0.2), 0.09)
    out["levelup"] = tone_seq([60, 64, 67, 72, 67, 72, 76, 84], S.pluck_synth, 0.11)
    out["cheer"] = crowd(6.0, 1.0, True, 3)
    out["scream"] = crowd(3.5, 1.3, True, 4)
    out["applause"] = applause(6.0) * 1.3 + crowd(6.0, 0.4, False, 6) * 0.5
    out["crowd"] = murmur(8.5)
    nb = int(1.8 * SR)
    tb = np.arange(nb) / SR
    out["boom"] = S.sine(45 + 60 * np.exp(-tb * 15)) * np.exp(-tb * 3) + S.lowpass(S.noise(nb), 1500) * np.exp(-tb * 5) * 0.8
    nw = int(1.4 * SR)
    w = S.noise(nw)
    out["whoosh"] = S.bandpass(w, 400, 5000) * np.sin(np.pi * np.linspace(0, 1, nw)) * 0.7
    fw = np.zeros(int(2.6 * SR))
    S.place(fw, out["boom"] * 0.7, 0.0)
    rr = np.random.default_rng(2)
    for _ in range(90):
        S.place(fw, S.hat(False) * rr.uniform(0.3, 1), rr.uniform(0.3, 2.3))
    out["firework"] = fw
    for k in out:
        pk = np.max(np.abs(out[k])) + 1e-9
        out[k] = (out[k] / pk * (0.6 if k in ("click", "hover") else 0.9)).astype(np.float32)
    return out


SFX_ORDER = ["click", "hover", "place", "delete", "cash", "notify", "error", "soldout", "levelup", "cheer", "scream", "applause", "crowd", "boom", "whoosh", "firework"]


def write_ogg(path, x):
    # libsndfile's Vorbis encoder crashes on long files, so: WAV -> ffmpeg
    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    sf.write(wav, np.clip(x, -1, 1), SR, subtype="PCM_16")
    codec = ["-c:a", "libvorbis", "-q:a", "4"] if path.endswith(".ogg") else ["-c:a", "libmp3lame", "-b:a", "128k"]
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav] + codec + [path], check=True)
    os.remove(wav)


def menu_music():
    """title theme (stadium pop) + office theme (lo-fi), 80 s each"""
    title = []
    style = dict(STYLES["nova"])
    style.update(bpm=(100, 100), key=(41, 41), verb=0.35)
    for i in range(3):
        title.append(render_song(style, 900 + i, length=27.0))
    office = []
    lofi = dict(STYLES["velvet"])
    lofi.update(bpm=(80, 80), drums="hiphop", kick="soft", lead="rhodes", rhythm="long", verb=0.3)
    for i in range(3):
        office.append(render_song(lofi, 950 + i, length=27.0))
    a = np.concatenate(title)
    b = np.concatenate(office)
    vinyl = S.highpass(S.noise(len(b)), 3000) * 0.01
    return a, (b + vinyl).astype(np.float32)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "audio")
    os.makedirs(out_dir, exist_ok=True)
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    lua = ["-- Generated by tools/music/make_audio.py: where each sound sits inside the uploaded files (seconds).",
           "local AudioMap = {}", "AudioMap.SONG_LEN = %d" % SONG_LEN, "AudioMap.BALLAD_INDEX = %d" % BALLAD_INDEX, "AudioMap.HIT_INDEX = %d" % HIT_INDEX]
    for aid in ARTISTS:
        if only and aid not in only:
            continue
        songs = []
        for i in range(1, SONGS + 1):
            seed = (abs(hash(aid)) % 1000) * 0 + ARTISTS.index(aid) * 100 + i
            x = render_song(STYLES[aid], seed, ballad=(i == BALLAD_INDEX), hit=(i == HIT_INDEX))
            songs.append(np.pad(x, (0, int(SONG_LEN * SR) - len(x))))
        write_ogg(os.path.join(out_dir, aid + ".ogg"), np.concatenate(songs))
        print("wrote", aid, flush=True)
    if not only or "menu" in only:
        a, b = menu_music()
        write_ogg(os.path.join(out_dir, "menu.ogg"), np.concatenate([a, np.zeros(int(0.5 * SR), np.float32), b]))
        lua.append("AudioMap.MENU = { title = { 0, %.3f }, office = { %.3f, %.3f } }" % (len(a) / SR, len(a) / SR + 0.5, len(b) / SR))
        print("wrote menu", flush=True)
    if not only or "sfx" in only:
        bank = sfx_bank()
        pos, parts, rows = 0.0, [], []
        for k in SFX_ORDER:
            x = bank[k]
            rows.append("\t%s = { %.3f, %.3f }," % (k, pos, len(x) / SR))
            parts.append(x)
            gap = np.zeros(int(0.25 * SR), np.float32)
            parts.append(gap)
            pos += (len(x) + len(gap)) / SR
        write_ogg(os.path.join(out_dir, "sfx.ogg"), np.concatenate(parts))
        lua.append("AudioMap.SFX = {")
        lua.extend(rows)
        lua.append("}")
        print("wrote sfx", flush=True)
    lua.append("return AudioMap")
    if not only:
        with open(os.path.join(ROOT, "src", "Headliner", "Data", "AudioMap.lua"), "w") as f:
            f.write("\n".join(lua) + "\n")


if __name__ == "__main__":
    main()
