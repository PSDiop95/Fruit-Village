"""Génère les sons placeholders de Merge Marché (M2).

Usage : python tools/gen_sounds.py            (depuis la racine du projet)

Stdlib uniquement, graine fixe : la sortie est reproductible.
- Notes de fusion : pluck Karplus-Strong (type kora/balafon), gamme pentatonique,
  une note par rang (rang élevé = plus aigu).
- Effets : lâcher, impact, accord de combo, jingle de découverte, Baobab (sabar),
  battement de cœur, game over, musique en boucle.
Tous ces fichiers seront remplacés par les vrais sons via data/sounds.tres.
"""

import math
import os
import random
import struct
import wave

SR = 22050  # mono 16 bits : léger pour l'APK
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")

# Pentatonique majeure (demi-tons), étendue sur plusieurs octaves.
PENTA = [0, 2, 4, 7, 9]
BASE_HZ = 220.0  # La 3
RANK_COUNT = 11

rng = random.Random(1234)


def rank_semitone(rank: int) -> int:
    return PENTA[rank % 5] + 12 * (rank // 5)


def hz(semitone: float) -> float:
    return BASE_HZ * 2.0 ** (semitone / 12.0)


def silence(seconds: float) -> list:
    return [0.0] * int(SR * seconds)


def mix_into(dst: list, src: list, offset_s: float = 0.0, gain: float = 1.0) -> None:
    o = int(offset_s * SR)
    need = o + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, v in enumerate(src):
        dst[o + i] += v * gain


def normalize(buf: list, peak: float = 0.89) -> list:
    m = max((abs(v) for v in buf), default=0.0)
    if m <= 0.0:
        return buf
    k = peak / m
    return [v * k for v in buf]


def fade(buf: list, fade_in: float = 0.002, fade_out: float = 0.01) -> list:
    n = len(buf)
    fi = max(1, int(fade_in * SR))
    fo = max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        buf[i] *= i / fi
    for i in range(min(fo, n)):
        buf[n - 1 - i] *= i / fo
    return buf


def write(path: str, buf: list) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in buf:
            s = int(max(-1.0, min(1.0, v)) * 32767)
            frames += struct.pack("<h", s)
        w.writeframes(bytes(frames))
    print("  ", os.path.relpath(path, ROOT), "%.2fs" % (len(buf) / SR))


# ------------------------------------------------------------------ Synthèse

def pluck(freq: float, seconds: float, decay: float = 0.996, bright: float = 0.5) -> list:
    """Karplus-Strong : bruit filtré par une ligne à retard (corde pincée).
    `bright` mélange bruit blanc / bruit lissé (attaque plus ou moins boisée)."""
    n = max(2, int(round(SR / freq)))
    delay = []
    prev = 0.0
    for _ in range(n):
        x = rng.uniform(-1.0, 1.0)
        prev = bright * x + (1.0 - bright) * prev
        delay.append(prev)
    out = []
    idx = 0
    for _ in range(int(seconds * SR)):
        a = delay[idx]
        b = delay[(idx + 1) % n]
        v = decay * 0.5 * (a + b)
        delay[idx] = v
        out.append(a)
        idx = (idx + 1) % n
    return fade(out, 0.0005, 0.03)


def balafon(freq: float, seconds: float) -> list:
    """Pluck + petite frappe sinusoïdale amortie (lame de bois)."""
    body = pluck(freq, seconds, decay=0.994, bright=0.65)
    hit = [math.sin(2 * math.pi * freq * 2.0 * i / SR) * math.exp(-i / (SR * 0.02))
           for i in range(int(0.08 * SR))]
    mix_into(body, hit, 0.0, 0.35)
    return body


def tone(freq: float, seconds: float, decay_s: float, f_end: float = None) -> list:
    out = []
    phase = 0.0
    n = int(seconds * SR)
    for i in range(n):
        t = i / n
        f = freq if f_end is None else freq + (f_end - freq) * t
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-i / (SR * decay_s)))
    return out


def noise(seconds: float, decay_s: float, lp: float = 0.5) -> list:
    out = []
    prev = 0.0
    for i in range(int(seconds * SR)):
        prev = lp * rng.uniform(-1, 1) + (1 - lp) * prev
        out.append(prev * math.exp(-i / (SR * decay_s)))
    return out


def drum(freq: float, gain: float = 1.0) -> list:
    """Frappe de sabar : membrane (sinus qui chute) + claquement de bruit."""
    d = tone(freq * 1.8, 0.25, 0.06, f_end=freq)
    mix_into(d, noise(0.05, 0.012, 0.9), 0.0, 0.5)
    return [v * gain for v in d]


# ------------------------------------------------------------------ Sons

def make_merge_notes() -> None:
    for r in range(RANK_COUNT):
        f = hz(rank_semitone(r))
        # Plus la note est aiguë, plus elle est courte (comme un vrai pluck).
        buf = balafon(f, 0.9 - 0.03 * r)
        write(os.path.join(SFX_DIR, "merge_%02d.wav" % r), normalize(buf, 0.8))


def make_drop() -> None:
    n = int(0.16 * SR)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        lp = 0.08 + 0.5 * t  # balayage : sourd → brillant
        prev = lp * rng.uniform(-1, 1) + (1 - lp) * prev
        env = math.sin(math.pi * t) ** 2
        out.append(prev * env)
    write(os.path.join(SFX_DIR, "drop.wav"), normalize(fade(out), 0.6))


def make_impact() -> None:
    buf = tone(170.0, 0.09, 0.025, f_end=120.0)
    mix_into(buf, noise(0.02, 0.004, 0.3), 0.0, 0.4)
    write(os.path.join(SFX_DIR, "impact.wav"), normalize(fade(buf), 0.7))


def make_combo_chord() -> None:
    buf = silence(0.7)
    for k, semi in enumerate([12, 16, 19, 24]):  # accord majeur, arpège rapide
        mix_into(buf, pluck(hz(semi), 0.65, 0.995, 0.6), 0.025 * k, 0.6)
    write(os.path.join(SFX_DIR, "combo_chord.wav"), normalize(buf, 0.75))


def make_discover() -> None:
    buf = silence(1.0)
    for k, semi in enumerate([12, 16, 19]):
        mix_into(buf, balafon(hz(semi), 0.6), 0.12 * k, 1.0)
    mix_into(buf, pluck(hz(24), 0.7, 0.996, 0.5), 0.36, 0.8)
    write(os.path.join(SFX_DIR, "discover.wav"), normalize(buf, 0.85))


def make_baobab() -> None:
    buf = silence(2.6)
    # Roulement de sabar qui accélère puis frappes finales.
    t = 0.0
    gap = 0.11
    while t < 1.1:
        mix_into(buf, drum(rng.choice([140.0, 165.0, 190.0]), 0.6 + 0.4 * t), t)
        t += gap
        gap = max(0.045, gap * 0.9)
    for k, f in enumerate([120.0, 120.0, 95.0]):
        mix_into(buf, drum(f, 1.2), 1.15 + 0.14 * k)
    # Grand accord kora.
    for k, semi in enumerate([0, 7, 12, 16, 19, 24]):
        mix_into(buf, pluck(hz(semi), 1.3, 0.997, 0.5), 1.45 + 0.03 * k, 0.55)
    write(os.path.join(SFX_DIR, "baobab.wav"), normalize(buf, 0.9))


def make_heartbeat() -> None:
    buf = silence(0.55)
    mix_into(buf, tone(62.0, 0.18, 0.05, f_end=45.0), 0.0, 1.0)
    mix_into(buf, tone(55.0, 0.16, 0.045, f_end=40.0), 0.2, 0.75)
    write(os.path.join(SFX_DIR, "heartbeat.wav"), normalize(fade(buf), 0.85))


def make_game_over() -> None:
    buf = silence(1.6)
    for k, semi in enumerate([12, 9, 7, 4, 0]):
        mix_into(buf, pluck(hz(semi), 0.7, 0.995, 0.4), 0.17 * k, 1.0)
    mix_into(buf, tone(hz(-12), 0.9, 0.35), 0.7, 0.4)
    write(os.path.join(SFX_DIR, "game_over.wav"), normalize(buf, 0.8))


def make_music() -> None:
    """Boucle afro-pop légère : 4 mesures à 100 BPM (9,6 s), raccord sans clic."""
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 4
    length = bars * 4 * beat
    buf = silence(length + 1.5)  # la traîne est repliée au début (boucle propre)
    prog = [0, 9, 5, 7]  # I – vi – IV – V (en demi-tons depuis la tonique)
    for bar in range(bars):
        root = prog[bar]
        t0 = bar * 4 * beat
        # Basse
        for b, off in enumerate([0.0, 1.5, 2.0, 3.0]):
            mix_into(buf, tone(hz(root - 24), beat * 0.9, 0.18), t0 + off * beat, 0.55)
        # Arpège kora en croches sur la pentatonique
        for s in range(8):
            semi = root + [0, 4, 7, 12, 9, 7, 4, 7][s]
            mix_into(buf, pluck(hz(semi), 0.5, 0.993, 0.45), t0 + s * beat * 0.5, 0.22)
        # Shaker en doubles croches, accent sur les contretemps
        for s in range(16):
            g = 0.10 if s % 2 else 0.05
            mix_into(buf, noise(0.05, 0.012, 0.95), t0 + s * beat * 0.25, g)
        # Grosse caisse / djembé grave
        for off in [0.0, 2.5]:
            mix_into(buf, drum(80.0, 0.5), t0 + off * beat)
    n = int(length * SR)
    loop = buf[:n]
    for i, v in enumerate(buf[n:]):
        loop[i % n] += v
    write(os.path.join(MUSIC_DIR, "market_loop.wav"), normalize(loop, 0.7))


if __name__ == "__main__":
    print("Génération des sons placeholders :")
    make_merge_notes()
    make_drop()
    make_impact()
    make_combo_chord()
    make_discover()
    make_baobab()
    make_heartbeat()
    make_game_over()
    make_music()
