#!/usr/bin/env python3
"""Intégration par lots des images validées (charte Abyss Protocol) vers la démo Phaser.

Fait tout d'un coup : détourage du fond uni, correction de pente (murs et pilier ramenés
à la grille 2:1 du jeu), mise à l'échelle @2x, liseré, normal map, WebP, ancrages en JSON.

    python3 -I tools/batch_images.py DOSSIER_VALIDE

DOSSIER_VALIDE = Game-studio-ai/docs/studio/art/abyss-protocol/valide-2026-11-26
Sortie : phaser/public/nemesis/{walls,units}/ + walls/anchors.json
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "phaser", "public", "nemesis")
EDGE = 64 * 2          # longueur à l'écran d'un bord de case (TW/2), en @2x
SLOPE = 0.5            # pente des bords de case en 2:1
WALL_STRETCH = 1.0     # étirement vertical fait dans la scène (VSTRETCH)

BG = {"white": (255, 255, 255), "magenta": (255, 0, 255), "green": (0, 255, 0)}


def cut(path, bg):
    """RGBA détouré : alpha progressif sur le bord, plein à l'intérieur, liseré de fond retiré."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    d = np.abs(a - np.array(BG[bg], np.float32)).max(2)
    core = ndimage.binary_fill_holes(d > 40)
    alpha = np.clip((d - 12) / 40, 0, 1)
    alpha = np.maximum(alpha, ndimage.binary_erosion(core, iterations=2))
    alpha[~ndimage.binary_dilation(core, iterations=2)] = 0
    lab, n = ndimage.label(alpha > 0.5)          # garde les vraies pièces, jette les poussières
    sizes = ndimage.sum(alpha > 0.5, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 3000])
    alpha *= ndimage.binary_dilation(keep, iterations=3)
    band = (alpha > 0) & ~ndimage.binary_erosion(alpha > 0.99, iterations=3)
    if bg == "green":  # le vert déborde sur les bords : G ramené au plus grand de R et B
        a[..., 1] = np.where(band, np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2])), a[..., 1])
    elif bg == "magenta":
        m = np.minimum(a[..., 0], a[..., 2])
        a[..., 0] = np.where(band, a[..., 0] - np.clip(m - a[..., 1] - 30, 0, None) * 0.7, a[..., 0])
        a[..., 2] = np.where(band, a[..., 2] - np.clip(m - a[..., 1] - 30, 0, None) * 0.7, a[..., 2])
    elif bg == "white":  # éclaircissement du bord par le blanc
        a = np.where(band[..., None], a * np.clip(alpha, 0.6, 1)[..., None], a)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    return rgba


def crop(rgba):
    ys, xs = np.nonzero(rgba[..., 3] > 8)
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def foot_and_slopes(rgba):
    """Point le plus bas de la base et pente de chaque côté (|dy/dx|)."""
    al = rgba[..., 3] > 128
    cols = np.nonzero(al.any(0))[0]
    bot = np.array([np.nonzero(al[:, x])[0].max() for x in cols])
    i = int(np.median(np.nonzero(bot >= bot.max() - 2)[0]))
    xf, yf = cols[i], bot[i]
    slopes = []
    for lo, hi in ((0, i), (i, len(cols))):
        n = hi - lo
        if n < 20:
            slopes.append(SLOPE)
            continue
        s = slice(lo + n // 5, hi - n // 5)
        slopes.append(abs(np.polyfit(cols[s], bot[s], 1)[0]))
    return xf, yf, slopes


def reslope(rgba):
    """Décale chaque colonne vers le bas pour ramener la base à la pente 2:1 (verticales intactes)."""
    xf, yf, (sl, sr) = foot_and_slopes(rgba)
    h, w = rgba.shape[:2]
    x = np.arange(w)
    shift = np.where(x < xf, (sl - SLOPE) * (xf - x), (sr - SLOPE) * (x - xf)).clip(0, None)
    pad = int(np.ceil(shift.max())) + 2
    out = np.zeros((h + pad, w, 4), np.float32)
    yy = np.arange(h + pad)[:, None] - shift[None, :]
    for c in range(4):
        out[..., c] = ndimage.map_coordinates(rgba[..., c].astype(np.float32), [yy, np.broadcast_to(x, yy.shape)], order=1, cval=0)
    out = crop(out.clip(0, 255).astype(np.uint8))
    return out, (sl, sr)


def resize(rgba, w, h):
    return np.asarray(Image.fromarray(rgba, "RGBA").resize((max(1, int(round(w))), max(1, int(round(h)))), Image.LANCZOS))


def normal_map(rgba):
    g = rgba[..., :3].astype(np.float32).mean(2) / 255
    g = ndimage.gaussian_filter(g, 1.2)
    nx, ny = -ndimage.sobel(g, 1) * 2, -ndimage.sobel(g, 0) * 2
    n = np.dstack([nx, ny, np.ones_like(g)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def save(rgba, rel, normal=False):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(p, "WEBP", quality=85, method=6)
    if normal:
        normal_map(rgba).save(p.replace(".webp", "_n.webp"), "WEBP", quality=90)


def walls(src, anchors):
    """Murs : face vers le bas-droite (bord x de la case). Version miroir pour l'autre bord."""
    ref_h = None
    for name in ("mur-droit-reference", "mur-hublot", "mur-console", "mur-porte-sas"):
        f = os.path.join(src, name + ".png")
        if not os.path.exists(f):
            continue
        im, sl = reslope(crop(cut(f, "white")))
        xf, yf, _ = foot_and_slopes(im)
        k = EDGE / (im.shape[1] - xf)  # la base va du pied jusqu'au bout droit
        im = resize(im, im.shape[1] * k, im.shape[0] * k * WALL_STRETCH)
        xf, yf, _ = foot_and_slopes(im)
        key = name.replace("mur-", "").replace("-reference", "")
        for side, img, fx in (("x", im, xf), ("y", im[:, ::-1].copy(), im.shape[1] - 1 - xf)):
            save(img, "walls/p_%s_%s.webp" % (key, side), normal=False)
            anchors["p_%s_%s" % (key, side)] = [round(fx / img.shape[1], 4), round(yf / img.shape[0], 4)]
        ref_h = ref_h or im.shape[0]
        print("mur", key, im.shape[1::-1], "pentes d'origine %.2f / %.2f" % sl)
    f = os.path.join(src, "pilier.png")
    if os.path.exists(f) and ref_h:
        im, sl = reslope(crop(cut(f, "white")))
        k = ref_h * 1.04 / im.shape[0]
        im = resize(im, im.shape[1] * k, im.shape[0] * k)
        xf, yf, _ = foot_and_slopes(im)
        save(im, "walls/p_pilier.webp", normal=False)
        anchors["p_pilier"] = [round(xf / im.shape[1], 4), round(yf / im.shape[0], 4)]
        print("pilier", im.shape[1::-1])


def poses(src, file, bg, picks, ref_index, prefix, ref_px):
    """Planche de poses : les pièces lues de gauche à droite et de haut en bas ;
    toutes à la même échelle, la pose ref_index mesurant ref_px de haut."""
    rgba = cut(os.path.join(src, file), bg)
    lab, n = ndimage.label(ndimage.binary_closing(rgba[..., 3] > 128, iterations=4))
    boxes = [(b, i + 1) for i, b in enumerate(ndimage.find_objects(lab)) if (b[0].stop - b[0].start) * (b[1].stop - b[1].start) > 20000]
    rows = sorted(boxes, key=lambda t: t[0][0].stop)
    # regroupe par ligne (bas des pièces proches), puis de gauche à droite
    lines, cur = [], []
    for t in rows:
        if cur and t[0][0].stop - cur[-1][0][0].stop > rgba.shape[0] * 0.15:
            lines.append(cur); cur = []
        cur.append(t)
    lines.append(cur)
    order = [t for line in lines for t in sorted(line, key=lambda t: t[0][1].start)]
    ref = order[ref_index][0]
    k = ref_px / (ref[0].stop - ref[0].start)
    for i, name in picks.items():
        b, lid = order[i]
        piece = rgba[b].copy()
        piece[..., 3] = piece[..., 3] * ndimage.binary_dilation(lab[b] == lid, iterations=2)
        piece = crop(piece)
        save(resize(piece, piece.shape[1] * k, piece.shape[0] * k), "units/%s_%s.webp" % (prefix, name))
        print("pose", prefix, name, piece.shape[1::-1], "→ ×%.2f" % k)


def main():
    src = sys.argv[1]
    anchors = {}
    walls(src, anchors)
    with open(os.path.join(OUT, "walls", "anchors.json"), "w") as fh:
        json.dump(anchors, fh, indent=1)
    S = 270  # hauteur des poses debout déjà en jeu (units/*_1.webp)
    poses(src, "walker-b.png", "magenta", {5: "hit", 9: "down"}, 0, "walker", S)
    poses(src, "okafor-touche-sol.png", "magenta", {0: "hit", 1: "down"}, 0, "okafor", S * 0.97)
    # grosse bête = Carapace : 4 poses clés (attente, approche, attaque, mort), attente à 240 px comme les autres aliens
    poses(src, "alien-bete.png", "green", {0: "idle", 1: "move", 2: "attack", 3: "dead"}, 0, "carapace", 240)


if __name__ == "__main__":
    main()
