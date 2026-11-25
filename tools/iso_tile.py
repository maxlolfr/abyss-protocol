"""Extrait la face supérieure d'une dalle isométrique (image sur fond clair uni) et la redresse en losange 2:1.

Usage : python3 -I tools/iso_tile.py dalle.jpg sortie.png [--size 512]
Sortie : losange RGBA de size × size/2 (sommet haut = coin nord de la case), prêt à être plaqué par
tools/build_phaser_nemesis.py. Les dalles des générateurs n'ont pas toujours un rapport 2:1 exact :
la face est repérée par ses coins (haut, gauche, droit), puis une transformation affine la ramène au 2:1.
"""
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


def corners(img):
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    bg = np.median(np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3)]), axis=0)
    diff = np.abs(a - bg).max(axis=2)
    m = ndimage.binary_opening(diff > 28, iterations=2)
    lab, n = ndimage.label(m)
    m = lab == (1 + np.argmax(ndimage.sum(m, lab, range(1, n + 1))))
    ys, xs = np.nonzero(m)
    top = (xs[ys == ys.min()].mean(), ys.min())
    # gauche / droite : point le plus haut de la colonne extrême (la tranche de la dalle descend en dessous)
    lx, rx = xs.min(), xs.max()
    left = (lx, ys[xs <= lx + 2].min())
    right = (rx, ys[xs >= rx - 2].min())
    return np.array(top, float), np.array(left, float), np.array(right, float)


def extract(src, size=512):
    img = Image.open(src).convert("RGB")
    t, l, r = corners(img)
    # léger retrait vers l'intérieur pour éviter le liseré de la tranche
    c = (l + r) / 2
    t, l, r = c + (t - c) * 0.985, c + (l - c) * 0.985, c + (r - c) * 0.985
    W, H = size, size // 2
    # destination : haut (W/2, 0), gauche (0, H/2), droite (W, H/2)
    D = np.array([[W / 2, 0, 1], [0, H / 2, 1], [W, H / 2, 1]], float)
    S = np.array([t, l, r])
    M = np.linalg.solve(D, S)  # (x', y', 1) @ M = (sx, sy)
    coeffs = (M[0, 0], M[1, 0], M[2, 0], M[0, 1], M[1, 1], M[2, 1])
    out = img.transform((W, H), Image.AFFINE, coeffs, resample=Image.BICUBIC).convert("RGBA")
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([(W / 2, 0), (W, H / 2), (W / 2, H), (0, H / 2)], fill=255)
    out.putalpha(mask)
    return out, (t, l, r)


if __name__ == "__main__":
    args = sys.argv[1:]
    size = 512
    if "--size" in args:
        i = args.index("--size"); size = int(args[i + 1]); del args[i:i + 2]
    im, c = extract(args[0], size)
    im.save(args[1])
    print(args[1], [tuple(round(v) for v in p) for p in c])
