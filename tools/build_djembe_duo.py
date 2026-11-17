#!/usr/bin/env python3
"""
Génère les données du mini-jeu « Djembé Duo » et du calibrage :
  - audio/music/djembe_duo.ogg   : le morceau complet (groove + appels du maître)
  - audio/music/calibration.ogg  : 16 bips réguliers pour mesurer la latence
  - audio/sfx/player_hit.wav     : le son de frappe du joueur
  - data/charts/djembe_duo.json  : la « partition » (sections, cues, notes attendues)
  - data/charts/calibration.json

Les patterns ci-dessous sont la source de vérité : la musique et la partition
sont générées ensemble, donc elles sont toujours parfaitement alignées.

Les sons sont des placeholders synthétisés : à remplacer par la vraie musique
(il suffira alors d'écrire la partition à la main ou avec un outil).

Usage : python3 tools/build_djembe_duo.py   (depuis la racine du projet)
Dépendances : numpy, scipy, ffmpeg (avec libvorbis)
"""
import json
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(7)

# --------------------------------------------------------------------------
# Paramètres du mini-jeu
# --------------------------------------------------------------------------
BPM = 108
STEPS_PER_BEAT = 4          # doubles-croches
BEATS_PER_BAR = 4
STEPS_PER_BAR = STEPS_PER_BEAT * BEATS_PER_BAR
FIRST_BEAT_OFFSET = 0.5     # silence avant le temps 0 dans le fichier audio

# Chaque pattern = positions (en doubles-croches, 0..15) des frappes dans une mesure.
PATTERNS = [
    [0, 4, 8, 12], [0, 4, 8, 12],
    [0, 4, 8, 10, 12], [0, 6, 8, 12],
    [0, 3, 6, 8, 12], [0, 3, 6, 8, 12],
    [0, 3, 6, 10, 12], [2, 4, 7, 10, 12],
    [0, 3, 6, 9, 12, 14], [0, 3, 6, 8, 10, 12, 14],
]
ROOTS = [55.0, 55.0, 43.65, 49.0]   # basse : La, La, Fa, Sol

STEP_SEC = 60.0 / BPM / STEPS_PER_BEAT


# --------------------------------------------------------------------------
# Synthèse
# --------------------------------------------------------------------------
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def exp_env(dur, decay):
    t = t_axis(dur)
    return np.exp(-t / decay)


def sweep_sine(f0, f1, glide, dur):
    t = t_axis(dur)
    k = np.log(f1 / f0) / glide
    freq = np.where(t < glide, f0 * np.exp(k * t), f1)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def filt(x, kind, freq, order=2):
    if kind == "band":
        lo, hi = freq
        sos = butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    else:
        sos = butter(order, freq, btype=kind, fs=SR, output="sos")
    return sosfilt(sos, x)


def kick(v=1.0):
    d = 0.35
    return 0.9 * v * sweep_sine(150, 42, 0.11, d) * exp_env(d, 0.09)


def clap():
    d = 0.15
    x = filt(noise(d), "band", (1000, 2400)) * exp_env(d, 0.035)
    return 0.9 * x


def shaker(v):
    d = 0.06
    return v * 2.2 * filt(noise(d), "high", 6500) * exp_env(d, 0.012)


def bell():
    d = 0.18
    t = t_axis(d)
    x = 0.09 * np.sign(np.sin(2 * np.pi * 1320 * t)) * 0.3 + 0.1 * np.sin(2 * np.pi * 1980 * t)
    return x * exp_env(d, 0.04)


def bass(f):
    d = 0.26
    t = t_axis(d)
    saw = 2 * ((t * f) % 1.0) - 1
    x = filt(saw, "low", 380, order=4)
    env = np.minimum(1, t / 0.005) * np.exp(-t / 0.09)
    return 0.55 * x * env


def wood(accent=False):
    d = 0.08
    f = 1750 if accent else 1300
    return 0.6 * np.sin(2 * np.pi * f * t_axis(d)) * exp_env(d, 0.018)


def crash():
    d = 1.6
    return 0.35 * filt(noise(d), "high", 5000) * exp_env(d, 0.45)


def lead_drum():
    d = 0.3
    body = 0.85 * sweep_sine(245, 175, 0.08, d) * exp_env(d, 0.07)
    slap = 0.5 * filt(noise(d), "band", (1700, 2800)) * exp_env(d, 0.012)
    return body + slap


def player_drum():
    d = 0.25
    body = 0.75 * sweep_sine(330, 265, 0.05, d) * exp_env(d, 0.05)
    slap = 0.6 * filt(noise(d), "band", (2800, 4400)) * exp_env(d, 0.015)
    return body + slap


class Mixer:
    def __init__(self, dur):
        self.buf = np.zeros(int(dur * SR) + SR)

    def add(self, t, sound, gain=1.0):
        i = int(round(t * SR))
        n = min(len(sound), len(self.buf) - i)
        if n > 0 and i >= 0:
            self.buf[i:i + n] += sound[:n] * gain

    def render(self):
        x = np.tanh(self.buf * 0.9)          # léger compresseur/saturation
        return x / max(1e-9, np.max(np.abs(x))) * 0.9


# --------------------------------------------------------------------------
# Écriture fichiers
# --------------------------------------------------------------------------
def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        write_wav(wav, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                        "-c:a", "libvorbis", "-q:a", "5", path], check=True)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")


# --------------------------------------------------------------------------
# Djembé Duo
# --------------------------------------------------------------------------
def build_djembe_duo():
    # Structure : intro, décompte, puis (appel, réponse) × N, puis outro
    bars = [{"type": "intro"}, {"type": "count"}]
    for k, p in enumerate(PATTERNS):
        bars.append({"type": "call", "phrase": k, "pattern": p})
        bars.append({"type": "response", "phrase": k, "pattern": p})
    bars.append({"type": "outro"})

    length_steps = len(bars) * STEPS_PER_BAR
    mix = Mixer(FIRST_BEAT_OFFSET + length_steps * STEP_SEC + 2.5)
    sections, cues, notes = [], [], []

    for b, bar in enumerate(bars):
        bar_step = b * STEPS_PER_BAR
        sec = {"step": bar_step, "type": bar["type"]}
        if "phrase" in bar:
            sec["phrase"] = bar["phrase"]
        sections.append(sec)

        for i in range(STEPS_PER_BAR):
            step = bar_step + i
            t = FIRST_BEAT_OFFSET + step * STEP_SEC
            kind = bar["type"]

            if kind == "outro":
                if i == 0:
                    mix.add(t, kick())
                    mix.add(t, crash())
                    mix.add(t, lead_drum())
                    cues.append({"step": step, "type": "lead_hit"})
                continue

            # Groove afrobeat
            g = 0.55
            if i in (0, 8):
                mix.add(t, kick(), g)
            if i == 11:
                mix.add(t, kick(0.5), g)
            if i in (4, 12):
                mix.add(t, clap(), g * 0.6)
            mix.add(t, shaker(0.07 if i % 4 == 2 else 0.03), g)
            if i % 4 == 2:
                mix.add(t, bell(), g)
            root = ROOTS[b % 4]
            for s, mul in ((0, 1), (3, 1), (8, 1.5), (11, 2), (14, 1.5)):
                if i == s:
                    mix.add(t, bass(root * mul), g)

            if kind == "count" and i % 4 == 0:
                mix.add(t, wood(i == 0))
                cues.append({"step": step, "type": "count", "value": i // 4 + 1})

            if kind == "call" and i in bar["pattern"]:
                mix.add(t, lead_drum())
                cues.append({"step": step, "type": "lead_hit"})

            if kind == "response" and i in bar["pattern"]:
                notes.append({"step": step, "type": "tap"})

    write_ogg(os.path.join(ROOT, "audio/music/djembe_duo.ogg"), mix.render())
    write_json(os.path.join(ROOT, "data/charts/djembe_duo.json"), {
        "id": "djembe_duo",
        "title": "Djembé Duo",
        "genre": "afrobeat",
        "audio": "res://audio/music/djembe_duo.ogg",
        "bpm": BPM,
        "steps_per_beat": STEPS_PER_BEAT,
        "beats_per_bar": BEATS_PER_BAR,
        "first_beat_offset": FIRST_BEAT_OFFSET,
        "length_steps": length_steps,
        "sections": sections,
        "cues": cues,
        "notes": notes,
    })


# --------------------------------------------------------------------------
# Calibrage : 16 bips à 100 BPM (une noire = 4 steps)
# --------------------------------------------------------------------------
def build_calibration():
    bpm, n, offset = 100, 16, 1.0
    step_sec = 60.0 / bpm / 4
    mix = Mixer(offset + n * 4 * step_sec + 1.0)
    notes = []
    for k in range(n):
        step = k * 4
        mix.add(offset + step * step_sec, wood(k % 4 == 0))
        notes.append({"step": step, "type": "tap"})
    write_ogg(os.path.join(ROOT, "audio/music/calibration.ogg"), mix.render())
    write_json(os.path.join(ROOT, "data/charts/calibration.json"), {
        "id": "calibration",
        "title": "Calibrage",
        "genre": "",
        "audio": "res://audio/music/calibration.ogg",
        "bpm": bpm,
        "steps_per_beat": 4,
        "beats_per_bar": 4,
        "first_beat_offset": offset,
        "length_steps": n * 4,
        "sections": [{"step": 0, "type": "calibration"}],
        "cues": [],
        "notes": notes,
    })


if __name__ == "__main__":
    build_djembe_duo()
    build_calibration()
    write_wav(os.path.join(ROOT, "audio/sfx/player_hit.wav"), player_drum() * 0.9)
    print("OK : audio et partitions générés.")
