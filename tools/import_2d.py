"""Import par lots des images 2D originales de Max (ZIP par catégorie, ou fichiers isolés).

Usage : python3 -I tools/import_2d.py <zip|image|dossier> [...] [--masters DIR] [--cat 08_FLOORS_WALLS]
        [--labels etiquettes.json]   ({"nom_fichier": ["catégorie", "objet vu"]}, pour les noms IMG_xxxx)

- Catégorie : préfixe 01_..16_ du nom du ZIP ou d'un dossier interne, sinon --cat, sinon « 00_A_CLASSER ».
- Chaque ZIP est extrait dans un dossier temporaire neuf (chemins vérifiés), jamais exécuté.
- Les masters sont copiés SANS modification ni renommage dans DIR/<catégorie>/ (hors dépôt par défaut :
  ~/abyss_masters), jamais publiés. Le nom normalisé n'existe que dans le manifest.
- Manifest cumulatif : assets2d/ASSET_MANIFEST_2D.json (hash, dimensions, format, poids, transparence,
  fond détecté, empreinte perceptuelle, doublons exacts et variantes proches, état de validation).
- Planches contact : DIR/_contact/<catégorie>.jpg (vignettes 256 px, à regarder plutôt que les originaux).
"""
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import unicodedata
import zipfile

from PIL import Image, ImageDraw

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(REPO, "assets2d", "ASSET_MANIFEST_2D.json")
CATS = ["01_CHARACTERS", "02_ALIENS", "03_BOSSES", "04_WEAPONS", "05_VEHICLES", "06_ROBOTICS",
        "07_ENVIRONMENTS", "08_FLOORS_WALLS", "09_PROPS", "10_BASE_NEPTUNE", "11_UI_HUD",
        "12_PORTRAITS", "13_VFX", "14_TEXTURES", "15_AUDIO", "16_MODELS_GLB"]
IMG = {".png", ".jpg", ".jpeg", ".webp"}
OTHER = {".glb", ".gltf", ".fbx", ".obj", ".ogg", ".mp3", ".wav"}


def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_") or "sans_nom"


def category_of(path, default):
    for part in reversed(re.split(r"[\\/]", path)):
        m = re.match(r"(\d{2})[_ -]", part)
        if m:
            for c in CATS:
                if c.startswith(m.group(1) + "_"):
                    return c
    return default


def dhash(im):
    g = im.convert("L").resize((17, 16), Image.LANCZOS)
    p = list(g.getdata())
    bits = 0
    for y in range(16):
        for x in range(16):
            bits = (bits << 1) | (p[y * 17 + x] > p[y * 17 + x + 1])
    return "%064x" % bits


def background(im):
    """Fond d'après la bordure : transparent, blanc, gris, sombre, ou varie (capture, scène)."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    if w * 2 < h and h > 2000:
        return "capture_telephone"
    px = rgba.load()
    pts = [(x, y) for x in range(0, w, max(1, w // 40)) for y in (0, h - 1)]
    pts += [(x, y) for y in range(0, h, max(1, h // 40)) for x in (0, w - 1)]
    vals = [px[p] for p in pts]
    if sum(v[3] < 16 for v in vals) > 0.9 * len(vals):
        return "transparent"
    lum = [(v[0] + v[1] + v[2]) / 3 for v in vals]
    mean = sum(lum) / len(lum)
    if max(lum) - min(lum) > 60:
        return "varie"
    return "blanc" if mean > 225 else "gris" if mean > 70 else "sombre"


def scan(src, cat, masters, entries, origin):
    ext = os.path.splitext(src)[1].lower()
    raw = open(src, "rb").read()
    sha = hashlib.sha256(raw).hexdigest()
    name = os.path.basename(src)
    e = {"nom_original": name, "origine": origin, "categorie": cat, "sha256": sha,
         "poids_ko": round(len(raw) / 1024), "format": ext.lstrip(".")}
    if ext in IMG:
        with Image.open(src) as im:
            e.update(largeur=im.width, hauteur=im.height, fond=background(im), dhash=dhash(im))
        e["transparence"] = e["fond"] == "transparent"
    known = {x["sha256"]: x for x in entries}
    if sha in known:
        e["doublon_exact_de"] = known[sha]["nom_normalise"]
    e["nom_normalise"] = "%s_%s_%s%s" % (cat[:2], slug(os.path.splitext(name)[0])[:40], sha[:6], ext)
    dest = os.path.join(masters, cat, name)
    if os.path.exists(dest) and hashlib.sha256(open(dest, "rb").read()).hexdigest() != sha:
        dest = os.path.join(masters, cat, sha[:6] + "_" + name)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if not os.path.exists(dest):
        shutil.copy2(src, dest)
    e["chemin_master"] = os.path.relpath(dest, masters)
    e["etat"] = "doublon" if "doublon_exact_de" in e else (
        "a_detourer" if e.get("fond") in ("blanc", "gris", "sombre") else
        "a_recadrer" if e.get("fond") == "capture_telephone" else
        "a_examiner" if ext in IMG else "non_image")
    e["godot"] = "texture/reference" if ext in IMG else ("modele" if ext in (".glb", ".gltf") else "?")
    e["phaser"] = "sprite apres detourage" if e["etat"] == "a_detourer" else (
        "sprite" if e.get("transparence") else "?")
    entries.append(e)
    return e


def near_duplicates(entries, limit=10):
    imgs = [e for e in entries if "dhash" in e and "doublon_exact_de" not in e]
    for i, a in enumerate(imgs):
        close = [b["nom_normalise"] for b in imgs[:i] + imgs[i + 1:]
                 if bin(int(a["dhash"], 16) ^ int(b["dhash"], 16)).count("1") <= limit]
        if close:
            a["variantes_proches"] = close
        else:
            a.pop("variantes_proches", None)


def contact_sheet(entries, masters, cat):
    items = [e for e in entries if e["categorie"] == cat and "dhash" in e]
    if not items:
        return None
    cols, t = 6, 256
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * t, rows * (t + 20)), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    for i, e in enumerate(items):
        with Image.open(os.path.join(masters, e["chemin_master"])) as im:
            im = im.convert("RGB")
            im.thumbnail((t - 8, t - 8))
            x, y = (i % cols) * t, (i // cols) * (t + 20)
            sheet.paste(im, (x + (t - im.width) // 2, y + (t - im.height) // 2))
        d.text((x + 4, y + t + 2), "%d %s" % (i + 1, e["nom_original"][:34]), fill=(230, 230, 230))
    out = os.path.join(masters, "_contact", cat + ".jpg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out, quality=85)
    return out


def safe_extract(zpath, dest):
    with zipfile.ZipFile(zpath) as z:
        for m in z.infolist():
            target = os.path.realpath(os.path.join(dest, m.filename))
            if not target.startswith(os.path.realpath(dest) + os.sep) or m.is_dir():
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(m) as fi, open(target, "wb") as fo:
                shutil.copyfileobj(fi, fo)


def main(argv):
    masters = os.path.expanduser("~/abyss_masters")
    default = "00_A_CLASSER"
    labels = {}
    args, i = [], 0
    while i < len(argv):
        if argv[i] == "--masters":
            masters, i = argv[i + 1], i + 2
        elif argv[i] == "--labels":
            labels, i = json.load(open(argv[i + 1])), i + 2
        elif argv[i] == "--cat":
            default, i = argv[i + 1], i + 2
        else:
            args.append(argv[i]); i += 1
    entries = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else []
    seen_before = len(entries)
    skipped = []
    for a in args:
        files = []
        tmp = None
        if a.lower().endswith(".zip"):
            tmp = tempfile.mkdtemp(prefix="abyss_zip_")
            safe_extract(a, tmp)
            base = category_of(os.path.basename(a), default)
            for r, _, fs in os.walk(tmp):
                files += [(os.path.join(r, f), category_of(os.path.relpath(os.path.join(r, f), tmp), base))
                          for f in fs if not f.startswith(("._", ".DS_Store"))]
        elif os.path.isdir(a):
            for r, _, fs in os.walk(a):
                files += [(os.path.join(r, f), category_of(os.path.join(r, f), default)) for f in fs]
        else:
            files.append((a, category_of(a, default)))
        for f, cat in sorted(files):
            if os.path.splitext(f)[1].lower() in IMG | OTHER:
                lab = labels.get(os.path.basename(f))
                e = scan(f, lab[0] if lab else cat, masters, entries, os.path.basename(a))
                if lab:
                    e["objet"] = lab[1]
            else:
                skipped.append(f)
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
    near_duplicates(entries)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    json.dump(entries, open(MANIFEST, "w"), ensure_ascii=False, indent=1)
    new = entries[seen_before:]
    for cat in sorted({e["categorie"] for e in new}):
        print("planche :", contact_sheet(entries, masters, cat))
    stats = {}
    for e in new:
        stats[e["etat"]] = stats.get(e["etat"], 0) + 1
    print("%d fichiers ajoutés, %s ; ignorés : %d" % (len(new), stats, len(skipped)))


if __name__ == "__main__":
    main(sys.argv[1:])
