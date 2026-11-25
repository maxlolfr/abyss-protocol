"""Détoure les vues d'une planche de modélisation (fond gris en dégradé) en sprites PNG transparents.

usage : python3 tools/extract_views.py planche.jpg sortie_prefixe [nb_vues] [hauteur_px] [seuil]
- Modélise le fond par une surface quadratique (le dégradé gris des planches), garde les grandes formes
  qui se détachent (les personnages), bouche les trous, adoucit les bords, recadre et aligne les pieds en bas.
- Les vues sont rendues de gauche à droite : sortie_prefixe-1.png … -N.png (+ un .json avec les boîtes).
Les originaux restent dans le studio privé ; seuls ces sprites allégés vont dans le jeu.
"""
import sys, json
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

src, out = sys.argv[1], sys.argv[2]
want = int(sys.argv[3]) if len(sys.argv) > 3 else 4
H_OUT = int(sys.argv[4]) if len(sys.argv) > 4 else 512
T = float(sys.argv[5]) if len(sys.argv) > 5 else 16.0
PUNCH = len(sys.argv) > 6 and sys.argv[6] == "1"
MINH = float(sys.argv[7]) if len(sys.argv) > 7 else 0.35  # hauteur mini d'un sujet (part de l'image)  # sujets opaques : retire le fond resté enfermé (entre les jambes)

im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
h, w, _ = a.shape
yy, xx = np.mgrid[0:h, 0:w]
sat = a.max(2) - a.min(2)
lum = a.mean(2)
grad = np.hypot(ndi.sobel(lum, 0), ndi.sobel(lum, 1))

# 1) fond : pixels gris, lisses, proches de la teinte des bords
edge = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
ref = np.median(edge, 0)
cand = (sat < 14) & (grad < 25) & (np.abs(lum - ref.mean()) < 45)
ys, xs = np.where(cand)
sel = np.random.default_rng(1).choice(len(ys), min(40000, len(ys)), replace=False)
ys, xs = ys[sel] / h, xs[sel] / w
A = np.stack([np.ones_like(xs), xs, ys, xs * xs, ys * ys, xs * ys], 1)
bg = np.zeros_like(a)
Y, X = yy / h, xx / w
B = np.stack([np.ones_like(X), X, Y, X * X, Y * Y, X * Y], -1)
for c in range(3):
    coef, *_ = np.linalg.lstsq(A, a[(ys * h).astype(int), (xs * w).astype(int), c], rcond=None)
    bg[..., c] = B @ coef
diff = np.abs(a - bg).max(2)

# 2) masque : formes qui se détachent, nettoyées, trous bouchés
fg = diff > T
fg = ndi.binary_closing(fg, np.ones((5, 5)), iterations=2)
fg = ndi.binary_opening(fg, np.ones((3, 3)))
lab, n = ndi.label(fg)
objs = ndi.find_objects(lab)
cands = []
for i, sl in enumerate(objs):
    hh = sl[0].stop - sl[0].start
    if hh > MINH * h:
        cands.append((hh * (sl[1].stop - sl[1].start), i + 1, sl))
cands = sorted(cands, reverse=True)[:want]
cands.sort(key=lambda c: c[2][1].start)
boxes = []
for k, (_, lid, sl) in enumerate(cands, 1):
    # ombre portée grise et lisse sous les pieds : retirée avant de boucher les trous (le jeu a ses ombres)
    y_lo = sl[0].start + int((sl[0].stop - sl[0].start) * 0.84)
    bl = bg.mean(2)
    shadow = (sat < 14) & (lum < bl * 0.98) & (lum > bl * 0.45) & (yy >= y_lo) & (grad < 14) & (diff < 50)
    shadow = ndi.binary_opening(shadow, np.ones((3, 3)))
    m = (lab == lid) & ~shadow
    m = ndi.binary_fill_holes(m)
    if PUNCH:
        inner_bg = m & (diff < T * 0.9) & (grad < 18) & (sat < 14)
        inner_bg = ndi.binary_opening(inner_bg, np.ones((5, 5)))
        m = m & ~inner_bg
    m = ndi.binary_opening(m, np.ones((3, 3)))
    lab2, n2 = ndi.label(m)
    if n2 > 1:
        sizes = ndi.sum(m, lab2, range(1, n2 + 1))
        m = ndi.binary_fill_holes(lab2 == (1 + int(np.argmax(sizes))))
    # alpha doux : bords progressifs selon l'écart au fond, intérieur plein
    soft = np.clip((diff - T * 0.5) / (T * 0.9), 0, 1)
    core = ndi.binary_erosion(m, iterations=2)
    alpha = np.where(core, 1.0, np.where(ndi.binary_dilation(m, iterations=2), soft, 0.0))
    alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
    y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
    pad = 6
    y0, x0, y1, x1 = max(0, y0 - pad), max(0, x0 - pad), min(h, y1 + pad), min(w, x1 + pad)
    # léger « despill » : bords ramenés vers la couleur du sujet plutôt que le gris du fond
    rgb = a[y0:y1, x0:x1]
    al = alpha[y0:y1, x0:x1, None]
    bgc = bg[y0:y1, x0:x1]
    fgc = np.clip((rgb - bgc * (1 - al)) / np.maximum(al, 0.25), 0, 255)
    rgba = np.dstack([np.where(al > 0.98, rgb, fgc), al[..., 0] * 255]).astype(np.uint8)
    spr = Image.fromarray(rgba, "RGBA")
    s = H_OUT / spr.height
    spr = spr.resize((max(1, round(spr.width * s)), H_OUT), Image.LANCZOS)
    spr.save(f"{out}-{k}.png", optimize=True)
    boxes.append({"view": k, "box": [int(x0), int(y0), int(x1), int(y1)], "size": spr.size})
json.dump({"source": src.split("/")[-1], "views": boxes}, open(f"{out}.json", "w"), indent=1)
print(f"{len(boxes)} vues -> {out}-*.png", [b["size"] for b in boxes])
