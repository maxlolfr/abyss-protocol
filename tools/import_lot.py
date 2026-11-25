"""Import d'un lot ZIP de modèles 3D (Tripo, GLB) dans le jeu.

Usage : python3 -I tools/import_lot.py lot.zip [lot2.zip ... | modele.glb ...] [--dry]

Pour chaque fichier du lot :
- reconnaît le nom (nomenclature de docs/MODELES-3D.md, accents, majuscules, espaces et tirets tolérés,
  ainsi que les intitulés de l'inventaire de Max : « Mur métallique standard », « Porte blindée »…) ;
- compte les triangles et signale ceux qui dépassent le budget de leur catégorie (téléphone) ;
- range une version ALLÉGÉE (textures 1024 px, 512 px pour les modules répétés, JPEG ; triangles réduits au budget
  téléphone par la simplification de Godot, voir tools/reduce_glb.py) dans
  godot/assets/models/<catégorie>/<nom>.glb ; les originaux et le ZIP ne sont jamais copiés dans le dépôt ;
- liste ce qui reste à classer (nom inconnu) et les formats à réexporter en GLB (FBX, OBJ…).
Le ZIP est extrait dans un dossier temporaire neuf, jamais exécuté.
"""
import json
import os
import re
import struct
import sys
import tempfile
import unicodedata
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lighten_glb import lighten  # noqa: E402
from reduce_glb import reduce  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "models")

# nom de fichier -> dossier (catégorie). Les modules de décor peuvent porter un suffixe de thème : _port, _nid, _station.
KIT = ["sol_dalle", "sol_grille", "sol_bassin", "plateforme", "mur_coque", "mur_angle", "mur_hublot", "cloison", "escalier",
       "garde_corps", "berceau_artefact", "grue", "porte_blindee", "porte_circulaire", "pilier_metallique",
       "mur_contamine", "mur_biomecanique", "mur_alien_b", "pilier_biomecanique"]
KIT += ["couvert_bas_%02d" % i for i in range(1, 13)] + ["couvert_haut_%02d" % i for i in range(1, 13)]
PROPS = ["terminal_vertical", "console_commandement", "panneau_electrique", "reacteur", "capsule_confinement",
         "caisse_militaire", "barricade", "conteneur", "reservoir", "equipement_labo", "tuyau_droit", "tuyau_coude",
         "technologie_humaine", "arche_alien", "structure_organique", "cristaux_violets", "roche", "oeuf_alien", "cocon",
         "nid_alien", "masse_organique", "artefact_alien", "technologie_biomecanique", "ruche", "noyau_nid", "trappe", "passerelle_etroite"]
UNITS = ["walker", "okafor", "lind", "moreau", "recrue_a", "recrue_b", "nereide", "carapace", "spectre", "brute",
         "leviathan"]
WEAPONS = ["fusil_assaut", "fusil_precision", "arme_lourde", "pistolet", "arme_energie", "arme_alien", "grenade",
           "kit_medical", "harpon"]
CRAFTS = ["barracuda", "triton", "sous_marin_recherche", "drone_combat", "robot_quadrupede", "eclaireur",
          "moissonneur", "cuirasse"]
ROOMS = ["base_neptune", "commandement", "sonar", "hangar", "laboratoire", "atelier", "dortoir", "infirmerie",
         "stockage", "reacteur_base", "confinement", "station_recherche", "batiment_militaire"]
CATS = {**{n: "kit" for n in KIT}, **{n: "props" for n in PROPS}, **{n: "units" for n in UNITS},
        **{n: "weapons" for n in WEAPONS}, **{n: "crafts" for n in CRAFTS}, **{n: "rooms" for n in ROOMS}}
# intitulés de l'inventaire de Max -> nom du jeu
ALIASES = {
    "mur_metallique_standard": "mur_coque", "mur_metallique": "mur_coque", "angle_de_mur_a_90": "mur_angle",
    "angle_de_mur": "mur_angle", "porte_blindee": "porte_blindee", "pilier_metallique": "pilier_metallique",
    "barricade_tactique": "barricade", "porte_circulaire_etanche": "porte_circulaire", "vitre_renforcee": "mur_hublot",
    "dalle_de_sol_metallique": "sol_dalle", "dalle_de_sol": "sol_dalle", "sol_avec_grille_technique": "sol_grille",
    "escalier_industriel": "escalier", "passerelle_metallique": "plateforme", "passerelle": "plateforme",
    "tuyauteries_droites": "tuyau_droit", "tuyauterie_droite": "tuyau_droit", "tuyauteries_avec_coudes": "tuyau_coude",
    "tuyauterie_coudee": "tuyau_coude", "mur_humain_contamine": "mur_contamine",
    "mur_biomecanique_extraterrestre": "mur_biomecanique", "variante_de_mur_extraterrestre": "mur_alien_b",
    "arche_extraterrestre_ouverte": "arche_alien", "arche_extraterrestre": "arche_alien",
    "structures_organiques_extraterrestres": "structure_organique", "terminal_informatique_vertical": "terminal_vertical",
    "console_de_commandement": "console_commandement", "panneau_electrique": "panneau_electrique",
    "reacteur_energetique": "reacteur", "capsule_de_confinement": "capsule_confinement",
    "caisse_de_stockage_militaire": "caisse_militaire", "equipements_de_laboratoire": "equipement_labo",
    "technologies_humaines_diverses": "technologie_humaine", "cristaux_violets": "cristaux_violets",
    "formations_rocheuses": "roche", "oeufs_extraterrestres": "oeuf_alien", "cocon_organique": "cocon",
    "nid_extraterrestre": "nid_alien", "masse_organique_contaminante": "masse_organique",
    "artefacts_extraterrestres": "artefact_alien", "technologies_biomecaniques": "technologie_biomecanique",
    "structures_de_ruche": "ruche", "centre_de_commandement": "commandement", "station_de_recherche": "station_recherche",
    "laboratoire_scientifique": "laboratoire", "batiments_militaires": "batiment_militaire",
    "sous_marin_d_interception_barracuda": "barracuda", "sous_marin_de_recherche": "sous_marin_recherche",
    "vehicule_de_transport": "triton", "drone_de_combat": "drone_combat", "robot_de_combat_quadrupede": "robot_quadrupede",
    "fusil_d_assaut": "fusil_assaut", "fusil_de_precision": "fusil_precision", "arme_energetique": "arme_energie",
    "arme_extraterrestre": "arme_alien", "kit_medical": "kit_medical", "neride": "nereide",
    # noms des fichiers de Max (25/11 22 h 40) : humain = station, extra = extraterrestre (Nid)
    "mur_humain": "mur_coque", "pilier_humain": "pilier_metallique", "porte_blinde_humain": "porte_blindee",
    "porte_blindee_humain": "porte_blindee", "barricade_humaine": "couvert_bas_01", "barricade_humain": "couvert_bas_01",
    "barricade_humain2": "couvert_bas_02", "barricade_humaine2": "couvert_bas_02", "mur_extra": "mur_biomecanique",
    "pilier_extra": "pilier_biomecanique", "arche_extra": "arche_alien", "barricade_extra": "couvert_bas_01_nid",
    "porte_alien_contamine": "mur_contamine",  # mur humain envahi, pas une porte
    # noms anglais donnés par Tripo (« sci-fi terminal 3D model »…)
    "sci_fi_terminal_3d": "terminal_vertical", "sci_fi_cargo_crate_3d": "caisse_militaire",
    "sci_fi_control_panel_3d": "panneau_electrique", "sci_fi_control_console_3d": "console_commandement",
    "industrial_staircase_3d": "escalier", "sci_fi_vault_door_3d": "porte_circulaire",
    "industrial_pipeline_3d": "tuyau_droit", "sci_fi_power_core_3d": "reacteur",
    "industrial_floor_grate_3d": "sol_grille", "sci_fi_canister_3d": "capsule_confinement",
    "sci_fi_floor_tile_3d": "sol_dalle", "sci_fi_floor_panel_3d": "sol_dalle_02", "alien_organic_floor_3d": "sol_dalle_nid",
    "purple_lava_stone_3d": "sol_dalle_02_nid", "metal_hatch_window_3d": "trappe",
    "industrial_catwalk_3d": "passerelle_etroite",
}
# budget de triangles par catégorie (au-delà : avertissement ; le jeu reste jouable mais plus lourd sur téléphone)
BUDGET = {"kit": 3000, "props": 6000, "units": 20000, "weapons": 3000, "crafts": 15000, "rooms": 20000}
TILES = {"sol_dalle", "sol_grille", "sol_bassin", "plateforme", "mur_coque", "mur_angle", "mur_hublot", "cloison",
         "garde_corps", "mur_contamine", "mur_biomecanique", "mur_alien_b", "pilier_biomecanique"}
# triangles gardés après simplification (modules répétés sur toute la carte : le poste le plus coûteux)
REDUCE = {"tile": 1500, "kit": 3000, "props": 5000, "weapons": 3000}


def norm(stem: str) -> str:
    s = unicodedata.normalize("NFKD", stem).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    s = re.sub(r"_(v\d+|final|tripo.*|lod\d|export|model|glb)$", "", s)
    return s


def route(stem: str):
    """-> (catégorie, thème ou '', nom) ou None."""
    s = re.sub(r"^[0-9a-f]{8}_", "", norm(stem))  # préfixe ajouté par l'envoi dans la conversation
    s = ALIASES.get(s, s)  # un alias peut porter un thème (barricade_extra -> couvert_bas_01_nid)
    theme = ""
    m = re.match(r"(.+?)_(port|nid|station)$", s)
    if m:
        s, theme = m.group(1), m.group(2)
    num = ""
    m = re.match(r"(.+?)_(\d{1,2})$", s)
    if m and s not in CATS and s not in ALIASES and (m.group(1) in CATS or m.group(1) in ALIASES):
        s, num = m.group(1), "_%02d" % int(m.group(2))
    s = ALIASES.get(s, s)
    if s not in CATS:
        return None
    return CATS[s], theme, s + num


def glb_json(path: str) -> dict:
    b = open(path, "rb").read()
    return json.loads(b[20:20 + struct.unpack("<I", b[12:16])[0]])


def triangles(path: str) -> int:
    j = glb_json(path)
    acc = j.get("accessors", [])
    total = 0
    for mesh in j.get("meshes", []):
        for p in mesh.get("primitives", []):
            if "indices" in p:
                total += acc[p["indices"]]["count"] // 3
            else:
                total += acc[p["attributes"]["POSITION"]]["count"] // 3
    return total


def unzip(z: str, tmp: str) -> None:
    with zipfile.ZipFile(z) as zf:
        for info in zf.infolist():
            if not info.flag_bits & 0x800:  # nom non marqué UTF-8 (ZIP de Mac/Windows) : accents à rétablir
                try:
                    info.filename = info.filename.encode("cp437").decode("utf-8")
                except (UnicodeEncodeError, UnicodeDecodeError):
                    pass
            name = os.path.normpath(info.filename)
            if info.is_dir() or name.startswith("..") or os.path.isabs(name) or "__MACOSX" in name:
                continue
            zf.extract(info, tmp)


def main(args):
    dry = "--dry" in args
    zips = [a for a in args if not a.startswith("--")]
    done, unknown, other = [], [], []
    for z in zips:
        tmp = tempfile.mkdtemp(prefix="lot_")
        if z.lower().endswith(".glb"):  # modèle envoyé seul, hors ZIP
            os.symlink(os.path.abspath(z), os.path.join(tmp, os.path.basename(z)))
        else:
            unzip(z, tmp)
        for dirpath, _, files in os.walk(tmp):
            for f in sorted(files):
                stem, ext = os.path.splitext(f)
                ext = ext.lower()
                src = os.path.join(dirpath, f)
                if ext in (".fbx", ".obj", ".gltf", ".usdz", ".stl", ".blend"):
                    other.append(f)
                    continue
                if ext != ".glb":
                    continue
                r = route(stem)
                req = glb_json(src).get("extensionsRequired", [])
                if any(e in req for e in ("EXT_meshopt_compression", "KHR_draco_mesh_compression")):
                    other.append(f + " (compressé : " + ", ".join(req) + ")")  # Godot ne sait pas le lire
                    continue
                tris = triangles(src)
                if r is None:
                    unknown.append((f, tris))
                    continue
                cat, theme, name = r
                if cat == "kit" and not theme:  # architecture humaine -> station ; extraterrestre -> nid
                    theme = "nid" if name.startswith(("mur_bio", "mur_alien", "pilier_bio")) else "station"
                rel = os.path.join(cat, theme, name) if theme and cat in ("kit", "props") else os.path.join(cat, name)
                dst = os.path.join(ROOT, rel + ".glb")
                over = tris > BUDGET[cat]
                tile = name.split("_0")[0] in TILES
                kept = tris
                if not dry:
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    lighten(src, dst, 512 if tile else 1024)
                    _, kept = reduce(dst, dst, REDUCE["tile" if tile else cat] if (tile or cat in REDUCE) else tris)
                done.append((f, rel, tris, kept, over, os.path.getsize(dst) if not dry else os.path.getsize(src)))
    print("## Lot importé" + (" (essai, rien d'écrit)" if dry else ""))
    print("| Fichier reçu | Rangé sous | Triangles reçus → gardés | Taille |")
    print("|---|---|---|---|")
    for f, rel, tris, kept, over, size in done:
        print("| %s | `%s.glb` | %d%s → %d | %.1f Mo |" % (f, rel, tris, " ⚠️" if over else "", kept, size / 1e6))
    if unknown:
        print("\n**À classer (nom inconnu)** : " + ", ".join("%s (%d tri.)" % u for u in unknown))
    if other:
        print("\n**À réexporter en GLB sans compression** : " + ", ".join(other))


if __name__ == "__main__":
    main(sys.argv[1:])
