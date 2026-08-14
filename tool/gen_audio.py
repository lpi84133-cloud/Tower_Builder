#!/usr/bin/env python3
"""Procedural audio bake for Tower Builder.

Renders every one-shot cue and both looping beds into 16-bit mono WAV under
`assets/audio/`. Stdlib only (``wave`` + ``math`` + ``random``) so the bake is
reproducible on a clean machine with no wheels to install.

Synthesis is FM-based: a carrier is phase-modulated by one operator whose index
falls off over the cue's lifetime, which gives the metallic/industrial timbre the
site art asks for. Percussive material comes from a Karplus-Strong string and a
one-pole-filtered noise burst instead of raw waveform mixing.

Run: ``python tool/gen_audio.py``
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

RATE = 44_100
BIT_DEPTH = 2  # bytes per sample
HEADROOM = 0.89

OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "assets", "audio")
)


# --------------------------------------------------------------------------- #
# envelopes
# --------------------------------------------------------------------------- #
def adsr(length: int, attack=0.004, decay=0.06, sustain=0.55, release=0.18, curve=2.0):
    """Sample-rate ADSR with an exponential release shaped by ``curve``."""
    a = max(1, int(attack * RATE))
    d = max(1, int(decay * RATE))
    r = max(1, int(release * RATE))
    s = max(0, length - a - d - r)
    out = [0.0] * length
    for i in range(length):
        if i < a:
            v = i / a
        elif i < a + d:
            v = 1.0 - (1.0 - sustain) * ((i - a) / d)
        elif i < a + d + s:
            v = sustain
        else:
            k = (i - a - d - s) / r
            v = sustain * max(0.0, 1.0 - k) ** curve
        out[i] = v
    return out


def glide(start: float, end: float, length: int, bend=1.0):
    """Exponential frequency ramp; ``bend`` > 1 front-loads the movement."""
    if length <= 1:
        return [start]
    ratio = end / start
    return [start * (ratio ** ((i / (length - 1)) ** bend)) for i in range(length)]


# --------------------------------------------------------------------------- #
# voices
# --------------------------------------------------------------------------- #
def fm_voice(freq, dur, ratio=2.0, index=3.4, index_fall=3.0, gain=0.6, envelope=None):
    """Two-operator FM: carrier at ``freq``, modulator at ``freq * ratio``."""
    n = int(dur * RATE)
    amp = envelope or adsr(n)
    car_phase = 0.0
    mod_phase = 0.0
    car_step = 2 * math.pi * freq / RATE
    mod_step = 2 * math.pi * freq * ratio / RATE
    out = [0.0] * n
    for i in range(n):
        k = index * (1.0 - i / n) ** index_fall
        mod_phase += mod_step
        car_phase += car_step
        out[i] = math.sin(car_phase + k * math.sin(mod_phase)) * gain * amp[i]
    return out


def fm_sweep(f0, f1, dur, ratio=1.5, index=5.0, gain=0.6, bend=1.0, envelope=None):
    """FM voice whose carrier glides from ``f0`` to ``f1``."""
    n = int(dur * RATE)
    amp = envelope or adsr(n, attack=0.002, decay=0.04, sustain=0.6, release=dur * 0.5)
    track = glide(f0, f1, n, bend)
    car_phase = 0.0
    mod_phase = 0.0
    out = [0.0] * n
    for i in range(n):
        f = track[i]
        car_phase += 2 * math.pi * f / RATE
        mod_phase += 2 * math.pi * f * ratio / RATE
        k = index * (1.0 - i / n) ** 2.2
        out[i] = math.sin(car_phase + k * math.sin(mod_phase)) * gain * amp[i]
    return out


def plucked(freq, dur, damp=0.494, gain=0.55, seed=11):
    """Karplus-Strong: noise-filled delay line with a two-tap averaging filter."""
    n = int(dur * RATE)
    size = max(2, int(RATE / freq))
    rnd = random.Random(seed)
    line = [rnd.uniform(-1.0, 1.0) for _ in range(size)]
    out = [0.0] * n
    idx = 0
    for i in range(n):
        cur = line[idx]
        nxt = line[(idx + 1) % size]
        line[idx] = (cur + nxt) * damp
        out[i] = cur * gain
        idx = (idx + 1) % size
    tail = adsr(n, attack=0.001, decay=0.02, sustain=0.8, release=dur * 0.6, curve=1.4)
    return [s * tail[i] for i, s in enumerate(out)]


def thump(freq, dur, gain=0.7, seed=5, tone=0.22):
    """Body-heavy impact: pitched sine drop plus a dark filtered noise transient."""
    n = int(dur * RATE)
    track = glide(freq, freq * 0.42, n, bend=0.7)
    amp = adsr(n, attack=0.0015, decay=0.05, sustain=0.35, release=dur * 0.7, curve=2.6)
    rnd = random.Random(seed)
    phase = 0.0
    lp = 0.0
    out = [0.0] * n
    for i in range(n):
        phase += 2 * math.pi * track[i] / RATE
        lp += (rnd.uniform(-1.0, 1.0) - lp) * tone
        body = math.sin(phase)
        out[i] = (body * 0.78 + lp * 0.32) * gain * amp[i]
    return out


def air(dur, gain=0.4, bright=0.55, seed=3, release=None):
    """Band-limited hiss for dust / release whooshes (two cascaded one-poles)."""
    n = int(dur * RATE)
    rnd = random.Random(seed)
    amp = adsr(n, attack=0.01, decay=0.05, sustain=0.7,
               release=release if release is not None else dur * 0.6, curve=1.8)
    hp_prev = 0.0
    lp_prev = 0.0
    out = [0.0] * n
    for i in range(n):
        x = rnd.uniform(-1.0, 1.0)
        lp_prev += (x - lp_prev) * bright
        hp = lp_prev - hp_prev
        hp_prev += (lp_prev - hp_prev) * 0.06
        out[i] = hp * gain * amp[i]
    return out


# --------------------------------------------------------------------------- #
# arrangement helpers
# --------------------------------------------------------------------------- #
def blend(*voices):
    n = max(len(v) for v in voices)
    out = [0.0] * n
    for v in voices:
        for i, s in enumerate(v):
            out[i] += s
    return out


def after(delay, voice):
    return [0.0] * int(delay * RATE) + list(voice)


def chain(*voices):
    out = []
    for v in voices:
        out.extend(v)
    return out


def rest(dur):
    return [0.0] * int(dur * RATE)


def semitone(root, steps):
    return root * (2.0 ** (steps / 12.0))


def bake(name, samples, peak_target=HEADROOM):
    os.makedirs(OUT_DIR, exist_ok=True)
    peak = max((abs(s) for s in samples), default=0.0)
    scale = (peak_target / peak) if peak > 1e-9 else 1.0
    if scale > 1.0:
        scale = min(scale, 3.0)  # lift quiet cues, but never blow up silence
    payload = bytearray()
    for s in samples:
        v = s * scale
        # gentle tanh-ish soft clip keeps transients from squaring off
        if v > 1.0 or v < -1.0:
            v = math.tanh(v)
        payload += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32_767))
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(BIT_DEPTH)
        w.setframerate(RATE)
        w.writeframes(bytes(payload))
    print(f"  {name:<20} {len(samples) / RATE:5.2f}s  {len(payload) // 1024:>5} KiB")


# --------------------------------------------------------------------------- #
# one-shot cues
# --------------------------------------------------------------------------- #
def cue_ui_tap():
    return blend(
        fm_voice(742.0, 0.055, ratio=3.0, index=2.2, index_fall=4.0, gain=0.34,
                 envelope=adsr(int(0.055 * RATE), attack=0.001, decay=0.012,
                               sustain=0.35, release=0.036, curve=2.4)),
        air(0.028, gain=0.09, bright=0.34, seed=21),
    )


def cue_module_seat():
    """Steel module settling onto the stack: thump + short metallic ring."""
    return blend(
        thump(154.0, 0.2, gain=0.72, seed=31, tone=0.19),
        after(0.012, plucked(392.0, 0.16, damp=0.487, gain=0.2, seed=41)),
        after(0.006, air(0.09, gain=0.16, bright=0.4, seed=17)),
    )


def cue_storey_ok():
    """Two-step confirmation, brighter on the second step."""
    return blend(
        chain(
            fm_voice(587.33, 0.085, ratio=2.0, index=1.9, gain=0.36,
                     envelope=adsr(int(0.085 * RATE), attack=0.002, decay=0.02,
                                   sustain=0.5, release=0.05)),
            fm_voice(880.0, 0.17, ratio=2.0, index=2.4, gain=0.38,
                     envelope=adsr(int(0.17 * RATE), attack=0.002, decay=0.03,
                                   sustain=0.5, release=0.12)),
        ),
        after(0.085, plucked(1760.0, 0.14, damp=0.482, gain=0.13, seed=53)),
    )


def cue_payout():
    """Collect cue: rising fourths finished by a wide shimmering pad."""
    root = 261.63
    steps = [0, 5, 9, 12]
    body = chain(*[
        fm_voice(semitone(root, s), 0.095, ratio=1.5, index=2.6, gain=0.34,
                 envelope=adsr(int(0.095 * RATE), attack=0.002, decay=0.02,
                               sustain=0.55, release=0.055))
        for s in steps
    ])
    tail = after(len(steps) * 0.095, blend(
        fm_voice(semitone(root, 16), 0.42, ratio=1.0, index=1.4, index_fall=1.6, gain=0.34,
                 envelope=adsr(int(0.42 * RATE), attack=0.006, decay=0.08,
                               sustain=0.5, release=0.3, curve=1.7)),
        plucked(semitone(root, 24), 0.4, damp=0.4955, gain=0.14, seed=61),
    ))
    return blend(body, tail)


def cue_brix():
    """Currency tick: tight metallic double blip."""
    return chain(
        fm_voice(1046.5, 0.045, ratio=4.0, index=3.2, gain=0.3,
                 envelope=adsr(int(0.045 * RATE), attack=0.001, decay=0.01,
                               sustain=0.4, release=0.03)),
        fm_voice(1567.98, 0.13, ratio=4.0, index=2.6, gain=0.3,
                 envelope=adsr(int(0.13 * RATE), attack=0.001, decay=0.02,
                               sustain=0.42, release=0.1)),
    )


def cue_collapse():
    """Structure fails: pitch-down groan under a rubble burst."""
    return blend(
        fm_sweep(330.0, 78.0, 0.5, ratio=1.005, index=6.5, gain=0.6, bend=0.75,
                 envelope=adsr(int(0.5 * RATE), attack=0.004, decay=0.09,
                               sustain=0.62, release=0.3, curve=1.9)),
        after(0.1, thump(96.0, 0.32, gain=0.5, seed=71, tone=0.12)),
        after(0.06, air(0.36, gain=0.3, bright=0.24, seed=83)),
    )


def cue_rank_up():
    """Promotion fanfare: stacked fifths, then a held chord."""
    root = 349.23
    lead = chain(*[
        fm_voice(semitone(root, s), 0.1, ratio=2.0, index=2.2, gain=0.32,
                 envelope=adsr(int(0.1 * RATE), attack=0.002, decay=0.02,
                               sustain=0.55, release=0.06))
        for s in (0, 7, 12)
    ])
    hold = after(0.3, blend(
        fm_voice(semitone(root, 16), 0.5, ratio=1.0, index=1.2, index_fall=1.4, gain=0.3,
                 envelope=adsr(int(0.5 * RATE), attack=0.01, decay=0.1,
                               sustain=0.55, release=0.34, curve=1.6)),
        fm_voice(semitone(root, 19), 0.5, ratio=1.0, index=0.9, index_fall=1.4, gain=0.2,
                 envelope=adsr(int(0.5 * RATE), attack=0.02, decay=0.1,
                               sustain=0.5, release=0.34, curve=1.6)),
        plucked(semitone(root, 28), 0.46, damp=0.4958, gain=0.12, seed=97),
    ))
    return blend(lead, hold)


def cue_release():
    """Hook lets go: cable whip plus a short descending air rush."""
    return blend(
        air(0.3, gain=0.34, bright=0.5, seed=101, release=0.22),
        fm_sweep(660.0, 190.0, 0.26, ratio=2.5, index=4.0, gain=0.26, bend=0.9),
    )


# --------------------------------------------------------------------------- #
# looping beds
# --------------------------------------------------------------------------- #
def bed(name, root, progression, bar=2.2, lift=0.5, seed=7):
    """Four-bar loop: FM pad + walking bass + sparse plucked motif."""
    out = []
    rnd = random.Random(seed)
    bar_n = int(bar * RATE)
    for bar_index, step in enumerate(progression):
        f = semitone(root, step)
        pad_env = adsr(bar_n, attack=bar * 0.22, decay=bar * 0.16,
                       sustain=0.66, release=bar * 0.42, curve=1.5)
        pad = blend(
            fm_voice(f, bar, ratio=1.0, index=0.85, index_fall=1.1,
                     gain=0.15, envelope=pad_env),
            fm_voice(f * 1.5, bar, ratio=2.0, index=0.5, index_fall=1.2,
                     gain=0.09 * lift, envelope=pad_env),
        )
        bass = fm_voice(f * 0.5, bar * 0.62, ratio=1.0, index=1.1, index_fall=2.4,
                        gain=0.17,
                        envelope=adsr(int(bar * 0.62 * RATE), attack=0.02,
                                      decay=bar * 0.12, sustain=0.5,
                                      release=bar * 0.3, curve=1.8))
        motif = []
        cursor = bar * 0.25
        for _ in range(3):
            note = semitone(root, step + rnd.choice((12, 16, 19, 24)))
            motif = blend(motif or [0.0], after(cursor, plucked(
                note, bar * 0.3, damp=0.4952, gain=0.075 * lift,
                seed=rnd.randrange(1 << 16))))
            cursor += bar * 0.22
        chunk = blend(pad, bass, motif)
        # pad/trim every bar to an exact length so the loop point is sample-tight
        if len(chunk) < bar_n:
            chunk = chunk + [0.0] * (bar_n - len(chunk))
        out.extend(chunk[:bar_n])
        if bar_index == len(progression) - 1:
            # crossfade the loop seam back into bar one
            fade = int(min(bar_n // 4, 0.35 * RATE))
            for i in range(fade):
                w = i / fade
                out[-fade + i] *= (1.0 - w)
                out[i] = out[i] * (1.0 - w) + out[-fade + i] * w
    bake(name, out)


def main():
    print(f"baking Tower Builder audio -> {OUT_DIR}")
    bake("ui_tap.wav", cue_ui_tap())
    bake("module_seat.wav", cue_module_seat())
    bake("storey_ok.wav", cue_storey_ok())
    bake("payout.wav", cue_payout())
    bake("brix.wav", cue_brix())
    bake("collapse.wav", cue_collapse())
    bake("rank_up.wav", cue_rank_up())
    bake("release.wav", cue_release())
    # Lobby bed: slow, wide, Dorian-flavoured.
    bed("bed_shell.wav", 174.61, [0, -4, -9, -2], bar=2.4, lift=0.45, seed=13)
    # Site bed: a touch faster and brighter to sit under the crane.
    bed("bed_site.wav", 196.0, [0, 3, 7, 5], bar=1.9, lift=0.75, seed=29)
    print("audio bake complete")


if __name__ == "__main__":
    main()
