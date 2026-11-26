"""Découpe une planche de poses (personnages alignés sur fond uni gris) en sprites détourés.

Usage : python3 -I tools/cut_pose_sheet.py planche.jpg sortie_dossier nom [--tol 7]   (5 personnages attendus)
Sortie : <nom>_1.png ... <nom>_N.png (RGBA, recadrés, de gauche à droite) + <nom>_check.jpg (contrôle sur damier).
Méthode : modèle de fond lissé (bords gauche/droit de chaque ligne, interpolés), pixels proches de ce fond
et peu saturés, puis composantes connexes reliées au bord (ou grandes poches entre bras et corps).
Les originaux ne sont jamais modifiés.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def cut(src, out_dir, name, tol=7.0, smooth=2.2, count=5):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    lum = a.mean(axis=2)
    # fond : médiane des 12 colonnes de chaque bord, lissée verticalement, interpolée horizontalement
    left = ndimage.median_filter(np.median(lum[:, :12], axis=1), size=31)
    right = ndimage.median_filter(np.median(lum[:, -12:], axis=1), size=31)
    t = np.linspace(0, 1, w)[None, :]
    bg = left[:, None] * (1 - t) + right[:, None] * t
    # un fond en vignette est plus clair au centre : on corrige par la médiane des lignes du haut et du bas
    top = ndimage.median_filter(np.median(lum[:10, :], axis=0), size=61)
    bot = ndimage.median_filter(np.median(lum[-10:, :], axis=0), size=61)
    rowmix = np.linspace(0, 1, h)[:, None]
    bg2 = top[None, :] * (1 - rowmix) + bot[None, :] * rowmix
    bg = (bg + bg2) / 2
    sat = a.max(axis=2) - a.min(axis=2)
    # le fond est lisse : une matière sombre (tissu, caoutchouc) proche du fond garde du grain
    mu = ndimage.uniform_filter(lum, 7)
    std = np.sqrt(np.maximum(ndimage.uniform_filter(lum * lum, 7) - mu * mu, 0))
    cand = (np.abs(lum - bg) < tol) & (sat < min(9, tol + 2)) & (std < smooth)
    cand = ndimage.binary_opening(cand, iterations=1)
    lab, n = ndimage.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    sizes = ndimage.sum(cand, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    for i in border:
        keep[i] = True
    keep[1:][sizes > 2500] = True
    bgmask = keep[lab]
    fg = ~bgmask
    fg = ndimage.binary_fill_holes(ndimage.binary_opening(fg, iterations=2)) & fg | ndimage.binary_closing(fg, iterations=2) & fg
    # alpha adouci (1 px) pour éviter le liseré gris
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = im.copy()
    rgba.putalpha(alpha)
    # personnages : composantes connexes (les armes débordent d'une colonne à l'autre) ; les petits
    # morceaux détachés sont rattachés au personnage le plus proche
    solid = np.asarray(alpha) > 40
    lab2, m = ndimage.label(solid)
    sz = ndimage.sum(solid, lab2, range(1, m + 1))
    big = [i + 1 for i in np.argsort(sz)[::-1] if sz[i] > 0.02 * sz.max()]
    big = [i for i in big if sz[i - 1] > 0.15 * sz.max()]
    objs = ndimage.find_objects(lab2)
    centers = {i: (objs[i - 1][1].start + objs[i - 1][1].stop) / 2 for i in big}
    owner = np.zeros(m + 1, int)
    for i in range(1, m + 1):
        c = (objs[i - 1][1].start + objs[i - 1][1].stop) / 2
        if i in big:
            owner[i] = i
            continue
        # fragment (bout de canon séparé par un trou) : au personnage le plus proche en pixels
        sl = objs[i - 1]
        y0, y1 = max(0, sl[0].start - 40), min(h, sl[0].stop + 40)
        x0, x1 = max(0, sl[1].start - 40), min(w, sl[1].stop + 40)
        sub = lab2[y0:y1, x0:x1]
        near = sub == i
        best = (0, big[0])
        for _ in range(40):  # premier personnage touché en grossissant le fragment pixel par pixel
            near = ndimage.binary_dilation(near)
            hits = [(int(((sub == b) & near).sum()), b) for b in big]
            best = max(hits)
            if best[0] > 0:
                break
        owner[i] = best[1] if best[0] > 0 else min(big, key=lambda b: abs(centers[b] - c))
    runs = sorted(big, key=lambda b: centers[b])
    # personnages soudés (arme qui touche le voisin) : tant qu'il en manque, on coupe le morceau le plus
    # large à la colonne la plus vide de son tiers central
    pieces = [(b, objs[b - 1][1].start, objs[b - 1][1].stop) for b in runs]
    while len(pieces) < count:
        j = max(range(len(pieces)), key=lambda i: pieces[i][2] - pieces[i][1])
        b, x0, x1 = pieces[j]
        colsum = ndimage.uniform_filter1d((owner[lab2] == b).sum(axis=0).astype(float), 25)
        lo, hi = x0 + (x1 - x0) // 3, x1 - (x1 - x0) // 3
        c = lo + int(np.argmin(colsum[lo:hi]))
        pieces[j:j + 1] = [(b, x0, c), (b, c, x1)]
    os.makedirs(out_dir, exist_ok=True)
    check = Image.new("RGB", (w, h), (255, 0, 255))
    check.paste(rgba, (0, 0), rgba)
    check.resize((w // 3, h // 3)).save(os.path.join(out_dir, name + "_check.jpg"), quality=80)
    out = []
    arr = np.asarray(rgba)
    xs = np.arange(w)[None, :]
    masks = [(owner[lab2] == b) & (xs >= c0) & (xs < c1) for b, c0, c1 in pieces]
    # un fragment coupé (bout d'arme) touche la frontière : il revient au morceau voisin
    for i in range(len(masks)):
        lk, nk = ndimage.label(masks[i])
        if nk < 2:
            continue
        szk = ndimage.sum(masks[i], lk, range(1, nk + 1))
        main = 1 + int(np.argmax(szk))
        c0, c1 = pieces[i][1], pieces[i][2]
        for j in range(1, nk + 1):
            if j == main:
                continue
            frag = lk == j
            cols = np.nonzero(frag.any(axis=0))[0]
            if i > 0 and cols.min() <= c0 + 1:
                masks[i] &= ~frag; masks[i - 1] |= frag
            elif i + 1 < len(masks) and cols.max() >= c1 - 2:
                masks[i] &= ~frag; masks[i + 1] |= frag
    for i, keepm in enumerate(masks):
        # poussières isolées : on ne garde que les morceaux d'une taille raisonnable
        lk, nk = ndimage.label(keepm)
        if nk > 1:
            szk = ndimage.sum(keepm, lk, range(1, nk + 1))
            main = lk == 1 + int(np.argmax(szk))
            close = ndimage.binary_dilation(main, iterations=4)
            ok = [j + 1 for j in range(nk) if szk[j] > 0.06 * szk.max() or (szk[j] > 400 and (close & (lk == j + 1)).any())]
            keepm = np.isin(lk, ok)
        keepm = ndimage.binary_dilation(keepm, iterations=2)
        one = arr.copy()
        one[..., 3] = np.where(keepm, one[..., 3], 0)
        # quart gauche : les personnages regardent à droite ; un canon fin qui dépasse là vient du voisin.
        # Une ouverture morphologique l'efface sans toucher aux volumes épais (épaules, sac à dos).
        m = one[..., 3] > 40
        nz = np.nonzero(m.any(axis=0))[0]
        if len(nz):
            xq = nz[0] + (nz[-1] - nz[0]) // 4
            opened = ndimage.binary_opening(m, structure=np.ones((3, 3)), iterations=16)
            lo2, _ = ndimage.label(opened)
            if lo2.max():
                big2 = np.argmax(np.bincount(lo2[opened]))
                opened = ndimage.binary_dilation(lo2 == big2, iterations=17) & m
            strip = np.zeros_like(m); strip[:, :xq] = True
            drop = strip & m & ~opened
            one[..., 3] = np.where(drop, 0, one[..., 3])
            # restes détachés après l'ouverture
            m2 = one[..., 3] > 90
            l3, n3 = ndimage.label(m2, structure=np.ones((3, 3)))
            if n3 > 1:
                s3 = ndimage.sum(m2, l3, range(1, n3 + 1))
                one[..., 3] = np.where(np.isin(l3, 1 + np.nonzero(s3 > 0.03 * s3.max())[0]), one[..., 3], 0)
        part = Image.fromarray(one, "RGBA")
        part = part.crop(part.getbbox())
        p = os.path.join(out_dir, "%s_%d.png" % (name, i + 1))
        part.save(p)
        out.append((p, part.size))
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    tol = 7.0
    if "--tol" in args:
        i = args.index("--tol")
        tol = float(args[i + 1])
        del args[i:i + 2]
    for p, size in cut(args[0], args[1], args[2], tol):
        print(p, size)
