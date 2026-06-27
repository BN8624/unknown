# 절차적(알고리즘) 아트 텍스처를 생성해 assets/gen/*.png로 저장 — 균열기사 (AI 이미지 아님, CC0 자체생성)
# 글로우·엠버·안개·비네트·별·지면 노이즈 등 분위기 레이어용 RGBA PNG. 재실행 결정적(seed 7).
import math
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "gen")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def save(name, arr):
    Image.fromarray(arr.astype("uint8"), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("saved", name, arr.shape)


def radial_glow(size=256, power=2.2):
    y, x = np.mgrid[0:size, 0:size].astype(float)
    cx = cy = size / 2.0
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (size / 2.0)
    a = np.clip(1.0 - r, 0.0, 1.0) ** power
    out = np.zeros((size, size, 4))
    out[..., :3] = 255
    out[..., 3] = a * 255
    save("glow", out)


def ember(size=48):
    y, x = np.mgrid[0:size, 0:size].astype(float)
    r = np.sqrt((x - size / 2) ** 2 + (y - size / 2) ** 2) / (size / 2.0)
    a = np.clip(1.0 - r, 0.0, 1.0) ** 1.8
    out = np.zeros((size, size, 4))
    out[..., 0] = 255
    out[..., 1] = 230
    out[..., 2] = 170
    out[..., 3] = a * 255
    save("ember", out)


def _smooth_noise(h, w, scale, seed):
    rng = np.random.default_rng(seed)
    sh, sw = max(2, int(h / scale)), max(2, int(w / scale))
    base = rng.random((sh, sw))
    img = Image.fromarray((base * 255).astype("uint8")).resize((w, h), Image.BICUBIC)
    return np.asarray(img).astype(float) / 255.0


def fog(w=540, h=200):
    n = _smooth_noise(h, w, 40, 11) * 0.6 + _smooth_noise(h, w, 14, 12) * 0.4
    yy = np.linspace(0, 1, h)[:, None]
    band = np.exp(-((yy - 0.5) ** 2) / (2 * 0.22 ** 2))  # 가운데가 진한 가로 띠
    a = np.clip(n * band, 0, 1) * 0.5
    out = np.zeros((h, w, 4))
    out[..., :3] = 210
    out[..., 3] = a * 255
    save("fog", out)


def vignette(w=540, h=960):
    y, x = np.mgrid[0:h, 0:w].astype(float)
    dx = (x - w / 2) / (w / 2)
    dy = (y - h / 2) / (h / 2)
    r = np.sqrt(dx ** 2 + dy ** 2)
    a = np.clip((r - 0.55) / 0.75, 0, 1) ** 1.6 * 0.7
    out = np.zeros((h, w, 4))
    out[..., 3] = a * 255  # 검정, 가장자리로 갈수록 진함
    save("vignette", out)


def stars(w=540, h=520, n=150):
    out = np.zeros((h, w, 4))
    for _ in range(n):
        sx, sy = RNG.integers(0, w), RNG.integers(0, h)
        b = RNG.uniform(0.3, 1.0)
        size = RNG.choice([1, 1, 1, 2])
        yy = max(0.0, 1.0 - sy / h)  # 위쪽이 더 밝게
        out[sy:sy + size, sx:sx + size, :3] = 255
        out[sy:sy + size, sx:sx + size, 3] = b * yy * 220
    save("stars", out)


def ground(w=540, h=220):
    n = _smooth_noise(h, w, 8, 21) * 0.5 + _smooth_noise(h, w, 3, 22) * 0.5
    grain = RNG.random((h, w)) * 0.12
    v = np.clip(n * 0.5 + grain, 0, 1)
    yy = np.linspace(0, 1, h)[:, None]
    out = np.zeros((h, w, 4))
    out[..., 0] = 40 + v * 40
    out[..., 1] = 30 + v * 30
    out[..., 2] = 22 + v * 22
    out[..., 3] = (0.25 + yy * 0.35) * 255  # 아래로 갈수록 또렷
    save("ground", out)


def main():
    radial_glow()
    ember()
    fog()
    vignette()
    stars()
    ground()


if __name__ == "__main__":
    main()
