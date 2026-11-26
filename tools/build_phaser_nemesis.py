"""Ressources de la démo Phaser 4 « salle Némésis » (méthode hybride de la directive V2, §5).

Usage : python3 -I tools/build_phaser_nemesis.py            (relançable, n'écrit que dans phaser/public/nemesis/)

Entrées (déjà dans le dépôt, versions allégées autorisées par Max) :
  godot/assets/textures/*  godot/assets/props/*  godot/assets/units/sprites/*  godot/assets/ui/*  godot/assets/audio/*
Sorties :
  floor.webp + floor_n.webp   sol précalculé de toute la salle en projection iso 2:1 (+ normal map pour Light2D)
  wall_*.webp (+ _n)          blocs de coque / cloisons texturés (triés en profondeur dans le jeu)
  props/*.webp  units/*.webp  portraits/*.webp  fx/*.png
  sfx/*.m4a                   sons ElevenLabs existants transcodés en AAC (lecture Safari iOS garantie)
  meta.json                   géométrie (TW, TH, origine du sol) partagée avec le code TypeScript
La carte est lue dans phaser/src/sim/map.ts (NEMESIS_MAP) : une seule source de vérité.
"""
import json
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "godot", "assets")
OUT = os.path.join(ROOT, "phaser", "public", "nemesis")
TW, TH = 128, 64            # losange d'une case (px)
WALL_TALL, WALL_MID, WALL_LOW = 176, 96, 22


def nemesis_map():
    txt = open(os.path.join(ROOT, "phaser", "src", "sim", "map.ts"), encoding="utf-8").read()
    block = txt.split("export const NEMESIS_MAP = [", 1)[1].split("];", 1)[0]
    return re.findall(r"'([^']+)'", block)


def ndimage_blur(a, s):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s)), np.float32) / 255


def tex(name, size=None):
    im = Image.open(os.path.join(SRC, "textures", name + ".png")).convert("RGB")
    a = np.asarray(im, dtype=np.float32) / 255.0
    return a


def save(img, rel, q=88):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if rel.endswith(".png"):
        img.save(path, optimize=True)
    else:
        img.save(path, quality=q, method=6)
    return path


# ---------------------------------------------------------------- sol précalculé

def bake_floor(rows):
    h, w = len(rows), len(rows[0])
    W = (w + h) * TW // 2
    H = (w + h) * TH // 2 + TH
    ox, oy = h * TW // 2, TH // 2          # écran = (sx + ox, sy + oy) ; sx, sy = centre de case (iso.ts)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    sx, sy = xs - ox, ys - oy
    gx = (sx / (TW / 2) + sy / (TH / 2)) / 2
    gy = (sy / (TH / 2) - sx / (TW / 2)) / 2
    tx, ty = np.rint(gx).astype(int), np.rint(gy).astype(int)
    inside = (tx >= 0) & (ty >= 0) & (tx < w) & (ty < h)
    txc, tyc = np.clip(tx, 0, w - 1), np.clip(ty, 0, h - 1)
    grid = np.array([list(r) for r in rows])
    ch = grid[tyc, txc]

    # matériau par case : 0 dalles, 1 plaques, 2 caillebotis (mezzanines), 3 bandes de danger, 4 coque
    mat = np.zeros(ch.shape, np.int8)
    center = (np.abs(gx - (w - 1) / 2) < 4.6) & (gy > 1.5) & (gy < 9.5)
    mat[center] = 1
    mat[np.isin(ch, list("=k/PT"))] = 2
    mat[np.isin(ch, list("ES"))] = 3
    mat[ch == "X"] = 4  # sous les machines (#) on garde un vrai sol (visible quand elles deviennent transparentes)
    names = ["floor", "plate", "grate", "hazard", "hull"]
    alb = [tex(n + "_albedo") for n in names]
    nrm = [tex(n + "_normal") for n in names]
    # UV continues dans le monde : une texture couvre 2×2 cases (les joints tombent juste)
    u = ((gx + 0.5) * 0.5) % 1.0
    v = ((gy + 0.5) * 0.5) % 1.0
    pi = np.clip((v * 511).astype(int), 0, 511)
    pj = np.clip((u * 511).astype(int), 0, 511)
    col = np.zeros((H, W, 3), np.float32)
    nor = np.zeros((H, W, 3), np.float32)
    for k in range(5):
        m = mat == k
        col[m] = alb[k][pi[m], pj[m]]
        nor[m] = nrm[k][pi[m], pj[m]]
    # bandes de danger plus sobres, plaques un peu plus froides
    col[mat == 3] = col[mat == 3] * 0.72 + 0.03
    g1 = col[mat == 1].mean(axis=-1, keepdims=True)
    col[mat == 1] = (col[mat == 1] * 0.45 + g1 * 0.55) * np.array([0.78, 0.86, 0.95])
    col[mat == 2] *= 0.8

    # Dalles isométriques de Max (assets2d/tiles, extraites par tools/iso_tile.py) : chacune couvre S×S cases,
    # alignée sur la grille ; les dalles contaminées varient par miroir pour éviter la répétition.
    D = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "D"][0]
    dist = np.hypot(gx - D[0], (gy - D[1]) * 1.15)
    tdist = np.hypot(txc - D[0], (tyc - D[1]) * 1.15)
    tiles_dir = os.path.join(ROOT, "assets2d", "tiles")
    evac = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in "ES"]
    ex0, ey0 = min(p[0] for p in evac), min(p[1] for p in evac)
    plan = [  # (masque de cases, dalle, S, ancre fixe ou None)
        ((mat == 0) & (tdist >= 3.3), "metal_abime", 2, None),
        ((mat == 1) & (tdist >= 3.3), "metal_propre", 2, None),
        ((mat == 3), "trappe_sas", 3, (ex0, ey0)),
        (np.isin(mat, [0, 1]) & (tdist < 3.3) & (tdist >= 1.6), "metal_contamine", 1, None),
        (np.isin(mat, [0, 1]) & (tdist < 1.6), "rock_alien", 1, None),
    ]
    for m, name, span, anchor in plan:
        path = os.path.join(tiles_dir, name + ".png")
        if not os.path.exists(path):
            continue
        t = np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255
        th, tw = t.shape[:2]
        lum = t[..., :3].mean(axis=2)
        gyl, gxl = np.gradient(ndimage_blur(lum, 1.2))
        tn = np.dstack([-gxl * 6, -gyl * 6, np.ones_like(lum)])
        tn /= np.linalg.norm(tn, axis=2, keepdims=True)
        if anchor:
            bx, by = anchor[0], anchor[1]
        else:
            bx, by = (txc // span) * span, (tyc // span) * span
        u = (gx + 0.5 - bx) / span
        v = (gy + 0.5 - by) / span
        if span == 1:  # miroirs selon la case
            hv = (txc * 7 + tyc * 13) % 4
            sw = (hv & 1) == 1
            u, v = np.where(sw, v, u), np.where(sw, u, v)
            fl = (hv & 2) == 2
            u, v = np.where(fl, 1 - v, u), np.where(fl, 1 - u, v)
        u, v = np.clip(u, 0, 1), np.clip(v, 0, 1)
        px = np.clip(((u - v) * 0.5 + 0.5) * (tw - 1), 0, tw - 1).astype(int)
        py = np.clip((u + v) * 0.5 * (th - 1), 0, th - 1).astype(int)
        col[m] = t[py[m], px[m], :3]
        nor[m] = tn[py[m], px[m]] * 0.5 + 0.5
        mat[m] = 10  # déjà en coordonnées écran : pas de rotation de normale
    tile_done = mat == 10

    # eau : fond sombre bleu-vert (la surface animée est faite dans le jeu)
    water = inside & (ch == "~")
    col[water] = col[water] * 0.25 + np.array([0.02, 0.10, 0.13])

    # occlusion ambiante près des cloisons (champ flou calculé à la résolution des cases ×8)
    S = 8
    solid = np.isin(grid, list("X#")).astype(np.float32)
    big = np.kron(solid, np.ones((S, S), np.float32))
    blur = np.asarray(Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(S * 0.55)), np.float32) / 255
    bi = np.clip(((gy + 0.5) * S).astype(int), 0, h * S - 1)
    bj = np.clip(((gx + 0.5) * S).astype(int), 0, w * S - 1)
    ao = 1.0 - 0.62 * blur[bi, bj]
    col *= ao[..., None]

    # joints de grille très discrets (lisibilité tactique sans quadrillage criard)
    fx, fy = np.abs(gx - np.rint(gx)), np.abs(gy - np.rint(gy))
    seam = ((fx > 0.485) | (fy > 0.485)) & (mat != 4) & ~water
    col[seam] *= 0.82

    alpha = (inside & (mat != 4)).astype(np.float32)
    # bord adouci sous les cloisons (aucun liseré)
    rgba = np.dstack([np.clip(col, 0, 1), alpha])
    floor = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")

    # normal map écran : la base (u, v) de la texture suit les axes x et y de la grille à l'écran
    n = nor * 2 - 1
    du = np.array([TW / 2, TH / 2]); du /= np.linalg.norm(du)
    dv = np.array([-TW / 2, TH / 2]); dv /= np.linalg.norm(dv)
    nx = n[..., 0] * du[0] + n[..., 1] * dv[0]
    ny = n[..., 0] * du[1] + n[..., 1] * dv[1]
    nz = n[..., 2] * 1.6               # sol vu de 3/4 : relief adouci
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2) + 1e-6
    nmap = np.dstack([nx / l, -ny / l, nz / l]) * 0.5 + 0.5
    nmap[tile_done] = nor[tile_done] * np.array([1, 1, 1])  # dalles : normales déjà en espace écran
    nmap[tile_done, 1] = 1 - nmap[tile_done, 1]
    nmap[~(alpha > 0)] = [0.5, 0.5, 1.0]
    nimg = Image.fromarray((nmap * 255).astype(np.uint8), "RGB")
    save(floor, "floor.webp", 90)
    save(nimg, "floor_n.webp", 95)
    return {"ox": ox, "oy": oy, "w": W, "h": H}


# ---------------------------------------------------------------- blocs de coque

def face(texture, quad, size, shade, tint=(1, 1, 1)):
    """Plaque la texture (512²) sur le parallélogramme quad = [haut-gauche, haut-droit, bas-gauche] (px)."""
    (x0, y0), (x1, y1), (x2, y2) = quad
    # transformation affine écran -> texture : on inverse la matrice texture -> écran
    A = np.array([[(x1 - x0) / 512, (x2 - x0) / 512, x0], [(y1 - y0) / 512, (y2 - y0) / 512, y0], [0, 0, 1]])
    inv = np.linalg.inv(A)
    t = Image.fromarray((np.clip(texture * np.array(tint) * shade, 0, 1) * 255).astype(np.uint8))
    out = t.transform(size, Image.AFFINE, tuple(inv[:2].reshape(-1)), resample=Image.BICUBIC)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([(x0, y0), (x1, y1), (x1 + x2 - x0, y1 + y2 - y0), (x2, y2)], fill=255)
    return out, mask


def wall_block(key, height, top_tex, side_tex, lamp=None):
    W, H = TW, TH + height
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    nimg = Image.new("RGBA", (W, H), (128, 128, 255, 0))
    top, side = tex(top_tex), tex(side_tex)
    side_rep = np.tile(side, (max(1, height // 64), 1, 1))[:512] if height > 64 else side
    # face gauche (regarde le sud de la grille), face droite (regarde l'est)
    L = [(0, TH / 2), (W / 2, TH), (0, TH / 2 + height)]
    R = [(W / 2, TH), (W, TH / 2), (W / 2, TH + height)]
    T = [(W / 2, 0), (W, TH / 2), (0, TH / 2)]
    for quad, t, shade, nc in ((L, side_rep, 1.05, (60, 150, 215)), (R, side_rep, 1.35, (196, 150, 215)), (T, top, 0.55, (128, 112, 250))):
        f, m = face(t, quad, (W, H), shade, (0.85, 0.95, 1.05))
        img.paste(f, (0, 0), m)
        nimg.paste(Image.new("RGBA", (W, H), nc + (255,)), (0, 0), m)
    d = ImageDraw.Draw(img)
    # arêtes et lisse basse : volumes lisibles sur petit écran
    d.line([(W / 2, TH), (W / 2, TH + height)], fill=(150, 205, 230, 90), width=1)
    d.line([T[2], T[0], T[1]], fill=(160, 215, 240, 120), width=2)
    d.line([(0, TH / 2 + height - 6), (W / 2, TH + height - 6), (W, TH / 2 + height - 6)], fill=(10, 16, 22, 200), width=6)
    if lamp:
        # bandeau lumineux sur la face gauche (la lumière réelle est ajoutée dans le jeu)
        y = TH / 2 + height * 0.42
        d.line([(10, y + 5), (W / 2 - 10, y + TH / 2 - 5 + 5)], fill=lamp + (255,), width=4)
    save(img, "walls/%s.webp" % key, 90)
    save(nimg.convert("RGB"), "walls/%s_n.webp" % key, 95)


# ---------------------------------------------------------------- sprites

def fit(path, max_h, max_w=None):
    im = Image.open(path).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    s = min(1.0, max_h / im.height, (max_w or 10 ** 6) / im.width)
    if s < 1:
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    return im


def radial(size, inner=(255, 255, 255, 255), power=2.0):
    a = np.linspace(-1, 1, size)
    r = np.sqrt(a[None, :] ** 2 + a[:, None] ** 2)
    v = np.clip(1 - r, 0, 1) ** power
    out = np.zeros((size, size, 4), np.float32)
    out[..., :3] = np.array(inner[:3]) / 255
    out[..., 3] = v * inner[3] / 255
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def fx_textures():
    save(radial(256, power=1.6), "fx/glow.png")
    save(radial(32, power=1.2), "fx/spark.png")
    save(radial(12, (220, 240, 255, 200), 1.0), "fx/mote.png")
    b = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    ImageDraw.Draw(b).ellipse((2, 2, 11, 11), outline=(210, 245, 255, 220), width=1)
    save(b, "fx/bubble.png")
    sh = radial(128, (0, 0, 0, 200), 1.4).resize((128, 52), Image.LANCZOS)
    save(sh, "fx/shadow.png")
    smoke = radial(128, (170, 180, 190, 150), 1.3).filter(ImageFilter.GaussianBlur(6))
    save(smoke, "fx/smoke.png")
    # éclair de bouche : étoile allongée
    m = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    d.polygon([(0, 32), (70, 24), (128, 32), (70, 40)], fill=(255, 240, 200, 255))
    d.polygon([(50, 6), (64, 32), (50, 58), (78, 32)], fill=(255, 220, 160, 230))
    save(m.filter(ImageFilter.GaussianBlur(2)), "fx/muzzle.png")
    splat = Image.open(os.path.join(SRC, "textures", "fx_splat.png")).convert("L").resize((96, 48), Image.LANCZOS)
    s = Image.new("RGBA", splat.size, (255, 255, 255, 0))
    s.putalpha(splat)
    save(s, "fx/splat.png")
    ring = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse((4, 4, 123, 59), outline=(255, 255, 255, 255), width=3)
    save(ring, "fx/ring.png")
    # surface d'eau : caustiques douces en mosaïque (TileSprite masqué dans le jeu)
    rng = np.random.default_rng(7)
    n = np.zeros((128, 128), np.float32)
    for _ in range(26):
        cx, cy, r = rng.uniform(0, 128), rng.uniform(0, 128), rng.uniform(10, 26)
        yy, xx = np.mgrid[0:128, 0:128]
        for ddx in (-128, 0, 128):
            for ddy in (-128, 0, 128):
                d2 = np.hypot(xx - cx - ddx, yy - cy - ddy)
                n += np.exp(-((d2 - r) ** 2) / 6.0)
    n = np.clip(n / n.max() * 1.4, 0, 1)
    caus = np.dstack([n * 0.55, n * 0.95, n, n * 0.55])
    save(Image.fromarray((caus * 255).astype(np.uint8), "RGBA"), "fx/caustics.png")
    # surface d'eau d'une case (deux phases de caustiques pour un fondu enchaîné dans le jeu)
    yy, xx = np.mgrid[0:TH, 0:TW].astype(np.float32)
    inside = (np.abs(xx - TW / 2 + 0.5) / (TW / 2) + np.abs(yy - TH / 2 + 0.5) / (TH / 2)) <= 1.0
    for name, off in (("water_a", 0), ("water_b", 64)):
        c = n[(yy.astype(int) * 2 + off) % 128, (xx.astype(int) + off) % 128]
        rgba = np.zeros((TH, TW, 4), np.float32)
        rgba[..., 0], rgba[..., 1], rgba[..., 2] = 0.25 + c * 0.5, 0.75 + c * 0.25, 0.85 + c * 0.15
        rgba[..., 3] = (0.10 + c * 0.55) * inside
        save(Image.fromarray((rgba * 255).astype(np.uint8), "RGBA"), "fx/%s.png" % name)


SOUNDS = {
    # clé du jeu : (fichier source, mono)
    "rifle": "sfx/sfx_rifle_fire", "harpoon": "sfx/sfx_harpoon_fire", "pistol": "sfx/sfx_rifle_fire",
    "alien": "sfx/sfx_alien_plasma", "acid": "sfx/sfx_alien_plasma", "psi": "sfx/sfx_spectre_psionic",
    "hit": "sfx/sfx_armor_impact", "hit_alien": "sfx/sfx_carapace_hit", "miss": "sfx/sfx_bullet_ricochet",
    "step1": "sfx/sfx_step_metal", "step2": "sfx/sfx_step_metal_02", "step3": "sfx/sfx_step_metal_03",
    "water": "sfx/sfx_step_water_01", "sonar": "sfx/sfx_sonar_signature", "explosion": "sfx/sfx_grenade_blast",
    "heal": "sfx/sfx_medkit", "reload": "sfx/sfx_reload_rifle", "click": "sfx/sfx_gear_rustle",
    "confirm": "sfx/sfx_ui_confirm", "deny": "sfx/sfx_ui_error", "turn": "sfx/sfx_ui_turn_end",
    "alarm": "sfx/sfx_alarm_intruder", "pulse": "sfx/sfx_artifact_pulse", "terminal": "sfx/sfx_terminal_hack",
    "objective": "sfx/sfx_objective_complete", "nereide": "sfx/sfx_nereid_alert", "carapace": "sfx/sfx_carapace_alert",
    "spectre": "sfx/sfx_spectre_move", "airlock": "sfx/sfx_airlock", "cover": "sfx/sfx_cover_break",
    "v_start": "voice/radio/radio_mission_start", "v_artifact": "voice/radio/radio_artifact",
    "v_contact": "voice/soldiers/soldier_contact", "v_ack": "voice/soldiers/soldier_ack",
    "v_moving": "voice/soldiers/soldier_moving", "v_down": "voice/soldiers/soldier_down",
    "v_wounded": "voice/soldiers/soldier_wounded", "v_extract": "voice/radio/radio_extraction_ready",
    "v_success": "voice/radio/radio_mission_success",
    "amb": "ambience/amb_05_alien_chamber",
}


def sounds():
    for key, rel in SOUNDS.items():
        src = os.path.join(SRC, "audio", rel + ".ogg")
        dst = os.path.join(OUT, "sfx", key + ".m4a")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst) and os.path.getmtime(dst) > os.path.getmtime(src):
            continue
        args = ["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vn", "-ac", "1" if key != "amb" else "2",
                "-c:a", "aac", "-b:a", "96k" if key != "amb" else "112k"]
        if key == "amb":
            args += ["-t", "90"]
        subprocess.run(args + [dst], check=True)


# ---------------------------------------------------------------- assemblage

UNITS = {"nereide": "nereide", "carapace": "carapace", "spectre": "spectre"}
# Planches de poses de Max (26/11) découpées par tools/cut_pose_sheet.py, masters hors dépôt :
# 1 debout, 2 marche, 3 à genou, 4 visée, 5 debout (variante), tournés vers la droite ;
# planches de dos (26/11, 7 h) : 6 dos, 7 dos en marche, 8 trois-quarts dos, 9 trois-quarts dos en marche (vers la droite).
POSES_DIR = os.path.expanduser(os.environ.get("ABYSS_POSES", "~/abyss_masters/poses"))
SOLDIERS = ["walker", "okafor", "lind", "moreau"]
POSE_H = 270  # hauteur de la pose debout dans le jeu (px, avant zoom caméra)


def poses(meta):
    if not os.path.isdir(POSES_DIR):
        print("poses : %s absent, sprites existants conservés" % POSES_DIR)
        return
    out = {}
    for k in SOLDIERS:
        ims = [Image.open(os.path.join(POSES_DIR, "%s_%d.png" % (k, i))).convert("RGBA") for i in range(1, 10)
               if os.path.exists(os.path.join(POSES_DIR, "%s_%d.png" % (k, i)))]
        s = POSE_H / ims[0].height  # même échelle (planches de dos : ramenées à la même hauteur debout) pour toutes les poses : la pose à genou est naturellement plus basse
        sizes = []
        for i, im in enumerate(ims, 1):
            if i >= 6:  # planche de dos : autre cadrage, on cale la hauteur debout sur la pose 1
                r = POSE_H / im.height
                im = im.resize((max(1, round(im.width * r)), POSE_H), Image.LANCZOS)
                save(im, "units/%s_%d.webp" % (k, i), 90)
                sizes.append(im.size)
                continue
            im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            save(im, "units/%s_%d.webp" % (k, i), 90)
            sizes.append(im.size)
        out[k] = sizes
        # portrait de carte : tête et épaules de la pose debout (même visage que le personnage en jeu)
        im = ims[0]
        bb = im.getbbox()
        w = bb[2] - bb[0]
        side = int(im.height * 0.25)
        a = np.asarray(im)[..., 3] > 60
        rows = np.nonzero(a.any(axis=1))[0]
        top = rows[0]
        head_cols = np.nonzero(a[top:top + side // 3].any(axis=0))[0]
        cx = int(head_cols.mean()) if len(head_cols) else bb[0] + w // 2
        crop = im.crop((cx - side // 2, max(0, top - side // 12), cx + side // 2, max(0, top - side // 12) + side))
        bg = Image.new("RGBA", crop.size, (14, 28, 40, 255))
        bg.alpha_composite(crop)
        save(bg.convert("RGB").resize((160, 160), Image.LANCZOS), "portraits/%s.webp" % {"walker": "s1", "okafor": "s2", "lind": "s3", "moreau": "s4"}[k], 88)
    meta["poses"] = out
PROPS = ["k007_2", "p004_s4", "p005_s1", "k005_1", "k005_2", "k005_4", "k005_5", "k005_6", "k006_1", "k006_2", "k006_3", "k006_4", "k007_1", "k007_3",
         "k007_5", "k008_1", "k008_2", "k008_3", "k008_4", "k009_1", "k009_2", "k009_3", "k009_4", "k009_6", "k010_1",
         "k010_2", "k010_3", "k010_4", "k010_5", "p001_s4", "p002_s4", "p003_s4", "p006_s1", "p006_s2", "p007_s1",
         "p007_s4", "p008_s2", "p009_s1", "p009_s2", "p009_s4"]


def main():
    rows = nemesis_map()
    meta = {"TW": TW, "TH": TH, "walls": {"tall": WALL_TALL, "mid": WALL_MID, "low": WALL_LOW}}
    meta["floor"] = bake_floor(rows)
    wall_block("tall", WALL_TALL, "hull_albedo", "hull_albedo")
    wall_block("tall_lamp", WALL_TALL, "hull_albedo", "hull_albedo", lamp=(90, 230, 255))
    wall_block("tall_red", WALL_TALL, "hull_albedo", "hull_albedo", lamp=(255, 70, 50))
    wall_block("mid", WALL_MID, "plate_albedo", "hull_albedo")
    wall_block("low", WALL_LOW, "hull_albedo", "hull_albedo")
    poses(meta)
    for k, src in UNITS.items():
        for view in ("front", "q34", "side", "rear"):
            save(fit(os.path.join(SRC, "units", "sprites", "%s_%s.png" % (src, view)), 240), "units/%s_%s.webp" % (k, view), 90)
    sizes = {}
    for p in PROPS:
        im = fit(os.path.join(SRC, "props", p + ".png"), 220, 220)
        save(im, "props/%s.webp" % p, 88)
        sizes[p] = im.size
    meta["props"] = sizes
    for p in ("nereide", "spectre"):
        im = Image.open(os.path.join(SRC, "ui", "portraits", p + ".jpg")).convert("RGB").resize((160, 160), Image.LANCZOS)
        save(im, "portraits/%s.webp" % p, 86)
    fx_textures()
    sounds()
    json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
    total = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(OUT) for f in fs)
    print("ressources : %s (%.1f Mo)" % (OUT, total / 1e6))


if __name__ == "__main__":
    sys.exit(main())
