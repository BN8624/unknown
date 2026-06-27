# 효과음·배경음(BGM)을 numpy로 합성해 저장 — 균열기사 (AI 아님, CC0 자체생성, 결정적 seed 19)
# SFX → assets/gen_sfx/*.wav, BGM 루프 → assets/gen_bgm/theme.wav
import math
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(__file__)
SFX_DIR = os.path.join(ROOT, "..", "assets", "gen_sfx")
BGM_DIR = os.path.join(ROOT, "..", "assets", "gen_bgm")
RNG = np.random.default_rng(19)


def _write(path, x, peak=0.8):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x / m * peak, -1.0, 1.0)
    data = (x * 32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("saved", os.path.relpath(path, ROOT), "%.1fs" % (len(x) / SR))


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(f, dur):
    return np.sin(2 * math.pi * f * t(dur))


def env(n, a=0.005, r=0.08):
    a = max(1, int(SR * a)); r = max(1, int(SR * r))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] = np.linspace(1, 0, r)
    return e


def noise(dur):
    return RNG.uniform(-1, 1, int(SR * dur))


def lp(x, a=0.2):  # 간단한 1극 저역통과
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


# ── SFX ──────────────────────────────────────────────────────────
def sfx_slash():
    d = 0.14; tt = t(d)
    sw = np.sin(2 * math.pi * (1400 - 1000 * tt / d) * tt)
    x = lp(noise(d), 0.5) * np.exp(-tt * 38) * 0.7 + sw * np.exp(-tt * 30) * 0.4
    _write(os.path.join(SFX_DIR, "slash.wav"), x * env(len(x), 0.001, 0.05), 0.55)


def sfx_hit():
    d = 0.12; tt = t(d)
    body = np.sin(2 * math.pi * 150 * np.exp(-tt * 6) * tt) * np.exp(-tt * 26)
    x = body + 0.4 * noise(d) * np.exp(-tt * 55)
    _write(os.path.join(SFX_DIR, "hit.wav"), x * env(len(x), 0.001, 0.04), 0.7)


def sfx_crit():
    d = 0.32; tt = t(d)
    body = np.sin(2 * math.pi * 110 * np.exp(-tt * 4) * tt) * np.exp(-tt * 12)
    ring = (np.sin(2 * math.pi * 1760 * tt) + 0.5 * np.sin(2 * math.pi * 2640 * tt)) * np.exp(-tt * 16)
    x = body * 0.9 + ring * 0.4 + 0.5 * noise(d) * np.exp(-tt * 40)
    _write(os.path.join(SFX_DIR, "crit.wav"), x * env(len(x), 0.001, 0.12), 0.85)


def sfx_levelup():
    notes = [523, 659, 784, 1047]; seg = 0.11
    x = np.array([])
    for f in notes:
        s = sine(f, seg) * env(int(SR * seg), 0.004, 0.07)
        x = np.concatenate([x, s])
    # 가벼운 잔향(지연 합)
    d = np.zeros(len(x) + int(SR * 0.12))
    d[:len(x)] += x
    d[int(SR * 0.12):int(SR * 0.12) + len(x)] += x * 0.35
    _write(os.path.join(SFX_DIR, "level_up.wav"), d, 0.55)


def sfx_boss():
    d = 0.8; tt = t(d)
    swell = np.sin(2 * math.pi * (70 + 30 * tt / d) * tt)
    x = swell + 0.6 * np.sin(2 * math.pi * 110 * tt) + 0.3 * lp(noise(d), 0.05)
    x *= np.minimum(1.0, tt / 0.2) * np.exp(-tt * 1.2)
    _write(os.path.join(SFX_DIR, "boss_appear.wav"), x * env(len(x), 0.05, 0.25), 0.8)


def sfx_victory():
    chord = [523, 659, 784, 1047]; d = 0.8; tt = t(d)
    x = np.zeros(len(tt))
    for f in chord:
        x += np.sin(2 * math.pi * f * tt) * np.exp(-tt * 2.0)
    x += np.sin(2 * math.pi * 1568 * t(d)) * np.exp(-t(d) * 3) * 0.4
    _write(os.path.join(SFX_DIR, "boss_victory.wav"), x * env(len(x), 0.005, 0.3), 0.7)


def sfx_button():
    d = 0.05; tt = t(d)
    x = np.sin(2 * math.pi * 720 * tt) * np.exp(-tt * 90) + 0.3 * noise(d) * np.exp(-tt * 140)
    _write(os.path.join(SFX_DIR, "button.wav"), x, 0.4)


def sfx_prestige():
    d = 0.7; tt = t(d)
    x = np.sin(2 * math.pi * (300 + 500 * tt / d) * tt) * np.linspace(0.2, 1, len(tt))
    x += 0.5 * np.sin(2 * math.pi * (600 + 700 * tt / d) * tt) * np.linspace(0, 1, len(tt))
    _write(os.path.join(SFX_DIR, "prestige.wav"), x * env(len(x), 0.02, 0.25), 0.6)


# ── BGM (16초 무한 루프, 다크 판타지 앰비언트) ──────────────────────
def bgm():
    bpm = 72.0
    beat = 60.0 / bpm
    chord_dur = beat * 4  # 한 코드 4박
    # Am - F - C - G (A minor)
    chords = [
        [220.00, 261.63, 329.63],  # Am
        [174.61, 220.00, 261.63],  # F
        [261.63, 329.63, 392.00],  # C
        [196.00, 246.94, 392.00],  # G
    ]
    bass = [110.0, 87.31, 130.81, 98.00]
    total = chord_dur * len(chords)
    n = int(SR * total)
    out = np.zeros(n)
    for ci, ch in enumerate(chords):
        s = int(ci * chord_dur * SR)
        seg = int(chord_dur * SR)
        tt = np.linspace(0, chord_dur, seg, endpoint=False)
        # 패드: 코드 음 + 살짝 디튠, 부드러운 진입/퇴장
        pad = np.zeros(seg)
        for f in ch:
            pad += np.sin(2 * math.pi * f * tt)
            pad += 0.5 * np.sin(2 * math.pi * (f * 1.005) * tt)
            pad += 0.25 * np.sin(2 * math.pi * (f * 0.5) * tt)
        penv = np.minimum(1.0, tt / 0.4) * np.minimum(1.0, (chord_dur - tt) / 0.4)
        pad = lp(pad, 0.08) * penv * 0.5
        # 베이스
        b = np.sin(2 * math.pi * bass[ci] * tt) * penv * 0.6
        # 아르페지오(코드음을 8분음표로 가볍게 뜯기)
        arp = np.zeros(seg)
        step = beat / 2
        ni = 0
        tcur = 0.0
        while tcur < chord_dur - 0.01:
            f = ch[ni % len(ch)] * 2.0
            st = int(tcur * SR)
            ln = int(step * SR)
            at = t(min(step, chord_dur - tcur))
            pluck = np.sin(2 * math.pi * f * at) * np.exp(-at * 6.0)
            arp[st:st + len(pluck)] += pluck[:max(0, seg - st)][:len(pluck)] if st + len(pluck) <= seg else pluck[:seg - st]
            ni += 1
            tcur += step
        out[s:s + seg] += pad + b + arp * 0.22
    # 공기감 노이즈 패드(아주 낮게)
    air = lp(RNG.uniform(-1, 1, n), 0.01) * 0.05
    out += air
    _write(os.path.join(BGM_DIR, "theme.wav"), out, 0.62)


def main():
    for f in [sfx_slash, sfx_hit, sfx_crit, sfx_levelup, sfx_boss, sfx_victory, sfx_button, sfx_prestige]:
        f()
    bgm()


if __name__ == "__main__":
    main()
