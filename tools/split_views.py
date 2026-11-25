"""Coupe une planche à N vues en N colonnes aux creux de la silhouette, pour détourer vue par vue
(quand les vues se touchent, extract_views.py les verrait comme un seul sujet).
usage : python3 tools/split_views.py planche.jpg sortie_prefixe [N]  ->  sortie_prefixe-col1.png …
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

src, out = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 4
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(float)
ref = np.median(np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3)]), 0)
fg = np.abs(a - ref).max(2) > 28
prof = ndi.uniform_filter1d(fg.sum(0).astype(float), 15)
w = a.shape[1]
cuts = [0]
for k in range(1, n):
    c = int(w * k / n)
    lo, hi = c - w // 10, c + w // 10
    cuts.append(lo + int(np.argmin(prof[lo:hi])))
cuts.append(w)
for i in range(n):
    im.crop((cuts[i], 0, cuts[i + 1], a.shape[0])).save(f"{out}-col{i + 1}.png")
print(cuts)
