# 전투 효과음 11종을 직접 합성해 assets/sfx/*.wav로 저장하는 CC0 생성 스크립트 (TASK 019)
# 외부 에셋 없이 numpy로 짧고 가벼운 식별용 효과음을 만든다. 재실행 시 동일 결과(결정적).
import math
import os
import struct
import wave

import numpy as np

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx")
RNG = np.random.default_rng(1019)  # 결정적 노이즈


def _env(n, attack=0.005, release=0.08):
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    e[n - r:] = np.linspace(1.0, 0.0, r)
    return e


def _t(dur):
    return np.linspace(0.0, dur, int(SR * dur), endpoint=False)


def _tone(freq, dur, kind="sine"):
    t = _t(dur)
    if kind == "sine":
        return np.sin(2 * math.pi * freq * t)
    if kind == "square":
        return np.sign(np.sin(2 * math.pi * freq * t))
    if kind == "tri":
        return 2 * np.abs(2 * (t * freq - np.floor(t * freq + 0.5))) - 1
    raise ValueError(kind)


def _noise(dur):
    n = int(SR * dur)
    return RNG.uniform(-1.0, 1.0, n)


def _norm(x, peak=0.7):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def _save(name, x, peak=0.7):
    x = _norm(x, peak)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("saved", os.path.basename(path), "%.0fms" % (len(x) / SR * 1000))


def attack_basic():
    # 짧은 휙 슬래시: 노이즈 + 빠른 하강 피치
    dur = 0.12
    t = _t(dur)
    sweep = np.sin(2 * math.pi * (900 - 600 * t / dur) * t)
    x = 0.6 * _noise(dur) * np.exp(-t * 40) + 0.4 * sweep
    _save("attack_basic", x * _env(len(x), 0.002, 0.05), 0.55)


def hit():
    # 둔탁한 타격: 저음 사인 + 짧은 노이즈
    dur = 0.11
    t = _t(dur)
    body = np.sin(2 * math.pi * 160 * t) * np.exp(-t * 28)
    x = body + 0.5 * _noise(dur) * np.exp(-t * 50)
    _save("hit", x * _env(len(x), 0.001, 0.04), 0.6)


def heavy():
    # 강타: 더 낮고 길고 묵직한 충격
    dur = 0.28
    t = _t(dur)
    body = np.sin(2 * math.pi * (110 - 40 * t / dur) * t) * np.exp(-t * 12)
    x = body + 0.6 * _noise(dur) * np.exp(-t * 22)
    _save("heavy", x * _env(len(x), 0.002, 0.1), 0.75)


def flurry():
    # 연격: 빠른 두 번의 베기
    dur = 0.18
    t = _t(dur)
    x = np.zeros(len(t))
    for off in (0.0, 0.07):
        s = int(off * SR)
        seg = t[: len(t) - s]
        slash = np.sin(2 * math.pi * (1100 - 500 * seg / dur) * seg) * np.exp(-seg * 45)
        x[s:] += slash[: len(x) - s]
    x += 0.3 * _noise(dur) * np.exp(-t * 40)
    _save("flurry", x, 0.5)


def counter():
    # 반격: 금속 링 (높은 음 + 약한 배음 잔향)
    dur = 0.25
    t = _t(dur)
    x = np.sin(2 * math.pi * 880 * t) + 0.5 * np.sin(2 * math.pi * 1320 * t)
    x *= np.exp(-t * 14)
    _save("counter", x, 0.5)


def level_up():
    # 레벨업: 상승 아르페지오 (C-E-G-C)
    notes = [523, 659, 784, 1047]
    seg = 0.1
    x = np.array([])
    for i, f in enumerate(notes):
        s = _tone(f, seg) * _env(int(SR * seg), 0.004, 0.06)
        x = np.concatenate([x, s])
    _save("level_up", x, 0.5)


def elite_appear():
    # 엘리트 등장: 낮고 불길한 단음 + 비브라토
    dur = 0.45
    t = _t(dur)
    vib = 1 + 0.02 * np.sin(2 * math.pi * 6 * t)
    x = np.sin(2 * math.pi * 196 * t * vib) + 0.5 * np.sin(2 * math.pi * 233 * t)
    _save("elite_appear", x * _env(len(x), 0.02, 0.18), 0.55)


def boss_appear():
    # 보스 등장: 더 깊고 길고 위압적 (저음 두 음 하강)
    dur = 0.7
    t = _t(dur)
    x = np.sin(2 * math.pi * (130 - 20 * t / dur) * t)
    x += 0.6 * np.sin(2 * math.pi * 98 * t)
    x += 0.3 * _noise(dur) * np.exp(-t * 4)
    _save("boss_appear", x * _env(len(x), 0.03, 0.25), 0.7)


def boss_charge():
    # 보스 강공격 준비: 긴장감 상승 톤
    dur = 0.5
    t = _t(dur)
    x = np.sin(2 * math.pi * (220 + 260 * t / dur) * t)
    x *= np.linspace(0.3, 1.0, len(t))
    _save("boss_charge", x * _env(len(x), 0.02, 0.05), 0.5)


def boss_victory():
    # 보스 승리: 밝은 화음 상승 마무리
    dur = 0.7
    parts = [(523, 0.0), (659, 0.0), (784, 0.0), (1047, 0.18)]
    n = int(SR * dur)
    x = np.zeros(n)
    t = _t(dur)
    for f, off in parts:
        s = int(off * SR)
        seg = t[: n - s]
        x[s:] += np.sin(2 * math.pi * f * seg) * np.exp(-seg * 2.2)
    _save("boss_victory", x * _env(len(x), 0.005, 0.2), 0.6)


def button():
    # 버튼: 아주 짧은 클릭
    dur = 0.05
    t = _t(dur)
    x = np.sin(2 * math.pi * 660 * t) * np.exp(-t * 90)
    x += 0.3 * _noise(dur) * np.exp(-t * 120)
    _save("button", x, 0.4)


def main():
    for fn in [attack_basic, hit, heavy, flurry, counter, level_up,
               elite_appear, boss_appear, boss_charge, boss_victory, button]:
        fn()


if __name__ == "__main__":
    main()
