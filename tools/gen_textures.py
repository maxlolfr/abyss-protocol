"""Textures PBR procédurales et répétables d'ABYSS PROTOCOL (kit modulaire Némésis).

Usage : python3 tools/gen_textures.py  ->  godot/assets/textures/<nom>_{albedo,normal,rough}.png
Aucune image externe : tout est calculé (bruit périodique, panneaux, rivets, usure), donc reproductible.
Palette : bible artistique V3.1 (acier #465766, océan #10263B, ambre #FFB547, cyan #39D9EF).
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textures")
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:N, 0:N] / N  # 0..1, 1 texture = 1 m (triplanaire)


def noise(scale, octaves=4):
    """Bruit périodique (filtré en fréquence), valeurs 0..1."""
    acc = np.zeros((N, N))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = np.fft.fftfreq(N)[:, None] ** 2 + np.fft.fftfreq(N)[None, :] ** 2
        k = scale * 2 ** o / N
        spec = np.fft.fft2(rng.standard_normal((N, N))) * np.exp(-f / (2 * k * k))
        n = np.real(np.fft.ifft2(spec))
        acc += amp * (n - n.mean()) / (n.std() + 1e-9)
        tot += amp
        amp *= 0.5
    acc /= tot
    return np.clip(acc * 0.25 + 0.5, 0, 1)


def blur(a, r):
    f = np.fft.fftfreq(N)[:, None] ** 2 + np.fft.fftfreq(N)[None, :] ** 2
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-f * (np.pi * r) ** 2 * 2)))


def panels(div_x, div_y, groove=0.006, bevel=0.012):
    """Hauteur de plaques : 1 au centre, rainures entre plaques, chanfrein."""
    dx = np.abs(((xx * div_x) % 1) - 0.5) * 2  # 1 au bord
    dy = np.abs(((yy * div_y) % 1) - 0.5) * 2
    ex = (1 - dx) / div_x / 2  # distance au bord en m
    ey = (1 - dy) / div_y / 2
    e = np.minimum(ex, ey)
    return np.clip((e - groove) / bevel, 0, 1), e


def rivets(div_x, div_y, inset=0.025, r=0.007):
    h = np.zeros((N, N))
    for cx in np.linspace(0, 1, div_x + 1)[:-1]:
        for cy in np.linspace(0, 1, div_y + 1)[:-1]:
            for ox in (inset, 1 / div_x - inset):
                for oy in (inset, 1 / div_y - inset):
                    px, py = (cx + ox) % 1, (cy + oy) % 1
                    ddx = np.minimum(np.abs(xx - px), 1 - np.abs(xx - px))
                    ddy = np.minimum(np.abs(yy - py), 1 - np.abs(yy - py))
                    d = np.sqrt(ddx ** 2 + ddy ** 2)
                    h = np.maximum(h, np.clip(1 - (d / r) ** 2, 0, 1) ** 0.5)
    return h


def hexcol(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def save(name, albedo, height, rough, strength=6.0, emission=None):
    os.makedirs(OUT, exist_ok=True)
    a = np.clip(albedo, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8), "RGB").save(f"{OUT}/{name}_albedo.png", optimize=True)
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(f"{OUT}/{name}_normal.png", optimize=True)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(f"{OUT}/{name}_rough.png", optimize=True)
    if emission is not None:
        Image.fromarray((np.clip(emission, 0, 1) * 255).astype(np.uint8), "RGB").save(f"{OUT}/{name}_emission.png", optimize=True)


def grime(base, dirt_col, amount, streak=True):
    g = noise(6, 5)
    d = np.clip((g - (1 - amount)) * 3, 0, 1)
    if streak:  # coulures verticales (rouille, condensation)
        s = blur(rng.random((N, N)) * (rng.random((1, N)) > 0.93), 1.5)
        s = np.cumsum(s, axis=0) % 1  # traînées périodiques
        s = blur(np.clip(s - 0.85, 0, 1) * 4, 2)
        d = np.clip(d + s * 0.5, 0, 1)
    return base * (1 - d[..., None] * 0.55) + dirt_col * d[..., None] * 0.55, d


def metal_plate():
    """Cloisons et équipements : acier militaire peint, plaques 0,5 m, rivets, usure."""
    h, e = panels(2, 2)
    rv = rivets(2, 2)
    n = noise(24, 4)
    col = hexcol("4b5d6d") * (0.88 + 0.18 * n[..., None])
    col, d = grime(col, hexcol("2a2620"), 0.35)
    edge = np.clip(1 - e / 0.02, 0, 1) * (noise(40, 3) > 0.55)  # peinture écaillée sur les arêtes
    col = col * (1 - edge[..., None]) + hexcol("8e9aa3") * edge[..., None]
    groove = 1 - h
    col *= (1 - groove[..., None] * 0.6)
    height = h * 0.6 + rv * 0.5 + n * 0.05
    rough = 0.45 + 0.25 * d + 0.1 * n - 0.15 * edge
    save("plate", col, height, rough)


def hull():
    """Coque : grandes plaques sombres 1 m, nervures, boulons, condensation."""
    h, e = panels(1, 2, groove=0.008, bevel=0.02)
    rv = rivets(1, 2, inset=0.03, r=0.01)
    n = noise(12, 5)
    col = hexcol("26394a") * (0.85 + 0.25 * n[..., None])
    col, d = grime(col, hexcol("0d1a24"), 0.45)
    col *= (1 - (1 - h)[..., None] * 0.7)
    rough = 0.35 + 0.35 * noise(30, 3) * (1 - d) + 0.2 * d  # zones humides plus brillantes
    save("hull", col, h * 0.8 + rv * 0.6 + n * 0.08, rough)


def floor():
    """Sol : tôle larmée antidérapante en dalles de 1 m, joints sombres, traces de passage."""
    h, e = panels(1, 1, groove=0.008, bevel=0.015)
    u, v = xx * 22, yy * 22
    lu, lv = (u % 1) - 0.5, (v % 1) - 0.5
    sg = np.where((np.floor(u) + np.floor(v)) % 2 > 0, 1, -1)
    ra, rb = (lu + sg * lv) / 1.414, (lu - sg * lv) / 1.414
    tread = np.clip(1 - (ra / 0.36) ** 2 - (rb / 0.09) ** 2, 0, 1) ** 0.5  # tôle larmée : lozenges croisés
    n = noise(16, 5)
    col = hexcol("3a4a57") * (0.85 + 0.2 * n[..., None])
    worn = blur(noise(4, 3), 3) > 0.52
    col = col * (1 - tread[..., None] * 0.08) + hexcol("9aa6ae") * (tread * worn)[..., None] * 0.35
    col, d = grime(col, hexcol("1c1d1c"), 0.4, streak=False)
    col *= (1 - (1 - h)[..., None] * 0.75)
    rough = 0.55 + 0.2 * d - 0.25 * tread * worn
    save("floor", col, h * 0.5 + tread * 0.35 + n * 0.04, rough)


def grate():
    """Caillebotis des passerelles : barres porteuses + entretoises, vide sombre (fond)."""
    bars = (np.abs(((xx * 16) % 1) - 0.5) < 0.16).astype(float)
    cross = (np.abs(((yy * 4) % 1) - 0.5) < 0.06).astype(float)
    m = np.maximum(bars, cross)
    m = blur(m, 0.6)
    n = noise(20, 4)
    col = hexcol("55636e") * (0.8 + 0.3 * n[..., None]) * m[..., None] + hexcol("05090d") * (1 - m[..., None])
    col, d = grime(col, hexcol("2b241a"), 0.3, streak=False)
    save("grate", col, m, 0.4 + 0.3 * d + 0.3 * (1 - m), strength=10)


def hazard():
    """Bandes de danger ambre/noir usées (sas, bords de fosse)."""
    s = ((xx + yy) * 8) % 1 < 0.5
    col = np.where(s[..., None], hexcol("e3a03a"), hexcol("16181a"))
    n = noise(30, 4)
    wear = np.clip((noise(14, 4) - 0.55) * 5, 0, 1)
    col = col * (1 - wear[..., None]) + hexcol("4a4f52") * wear[..., None]
    col *= (0.85 + 0.2 * n[..., None])
    col, d = grime(col, hexcol("1d1a14"), 0.3, streak=False)
    save("hazard", col, n * 0.1 + (1 - wear) * 0.15, 0.6 + 0.2 * d)


def crate():
    """Caisses militaires : vert olive mat, nervures horizontales, pochoirs blancs."""
    rib = (np.abs(((yy * 6) % 1) - 0.5) < 0.08).astype(float)
    rib = blur(rib, 0.8)
    n = noise(20, 4)
    col = hexcol("4a5236") * (0.85 + 0.25 * n[..., None])
    sten = ((xx > 0.18) & (xx < 0.82) & (yy > 0.40) & (yy < 0.52)) & (((xx * 40) % 1) < 0.65) & (((yy * 30) % 1) > 0.2)
    col = col * (1 - sten[..., None] * 0.7) + hexcol("cfd2c8") * sten[..., None] * 0.7
    col, d = grime(col, hexcol("23211a"), 0.35)
    save("crate", col * (1 - rib[..., None] * 0.15), rib * 0.6 + n * 0.05, 0.7 + 0.15 * d)


def screen():
    """Écrans de console : interface cyan (courbes, grilles, colonnes de données)."""
    col = np.zeros((N, N, 3)) + hexcol("041018")
    grid = ((np.abs(((xx * 16) % 1)) < 0.03) | (np.abs(((yy * 16) % 1)) < 0.03)) * 0.25
    wave = np.abs(yy - (0.3 + 0.08 * np.sin(xx * 2 * np.pi * 3) + 0.03 * np.sin(xx * 2 * np.pi * 11))) < 0.006
    bars = (xx > 0.55) & (xx < 0.95) & (yy > 0.55) & (yy < 0.92) & (((xx * 20) % 1) < 0.6) & (yy > 0.92 - 0.37 * (0.5 + 0.5 * np.sin(np.floor(xx * 20) * 1.7)))
    text = (xx < 0.45) & (yy > 0.55) & (((yy * 40) % 1) < 0.35) & (noise(60, 1) > 0.45)
    em = grid[..., None] * hexcol("39d9ef") + (wave | bars | text)[..., None] * hexcol("39d9ef")
    alert = (xx > 0.05) & (xx < 0.3) & (yy > 0.06) & (yy < 0.12)
    em = em * (1 - alert[..., None]) + alert[..., None] * hexcol("ffb547")
    scan = 0.85 + 0.15 * (((yy * 180) % 1) < 0.5)
    em *= scan[..., None]
    save("screen", col + em * 0.3, np.zeros((N, N)), np.full((N, N), 0.15), emission=em)


def flesh():
    """Peau alienne neutre (teintée par matériau) : écailles fines, veines, aspect humide."""
    n = noise(10, 5)
    cells = noise(48, 2)
    scales = np.clip(np.abs(cells - 0.5) * 6, 0, 1)
    veins = np.clip(1 - np.abs(noise(5, 4) - 0.5) * 18, 0, 1) + np.clip(1 - np.abs(noise(9, 3) - 0.5) * 22, 0, 1) * 0.6
    col = np.ones((N, N, 3)) * (0.62 + 0.25 * n[..., None]) * (0.9 + 0.1 * scales[..., None])
    col = col * (1 - np.clip(veins, 0, 1)[..., None] * 0.45)
    save("flesh", col, scales * 0.4 + veins * 0.5 + n * 0.2, 0.25 + 0.35 * noise(20, 3), strength=5)


def fabric():
    """Combinaison de plongée : néoprène renforcé (trame croisée) + coutures."""
    u, v = xx * 64, yy * 64
    weave = 0.5 + 0.25 * np.sin(u * 2 * np.pi) * np.sin(v * 2 * np.pi)
    seam = (np.abs(((xx * 2) % 1) - 0.5) < 0.006) | (np.abs(((yy * 3) % 1) - 0.5) < 0.006)
    n = noise(14, 4)
    col = hexcol("2a3b4a") * (0.85 + 0.2 * n[..., None]) * (0.92 + 0.12 * weave[..., None])
    col = col * (1 - seam[..., None] * 0.35)
    col, d = grime(col, hexcol("1a1a18"), 0.3, streak=False)
    save("fabric", col, weave * 0.3 - seam * 0.4, 0.7 + 0.15 * d, strength=4)


if __name__ == "__main__":
    for f in (metal_plate, hull, floor, grate, hazard, crate, screen, flesh, fabric):
        f()
        print("ok", f.__name__)
