# Modèles 3D (Tripo) : où les déposer et sous quel nom

Le registre (`godot/view/model_registry.gd`) cherche `godot/assets/models/<catégorie>/<nom>.glb` et garde le provisoire tant que le fichier n'existe pas. **Branché aujourd'hui : les personnages et créatures (`units`).** Les autres catégories ont leurs noms réservés ; leur branchement suit l'arrivée des premiers fichiers. Pour les personnages, aucun code à modifier : Claude allège le fichier (`tools/lighten_glb.py`, textures 1024 px) et le range au bon nom. Les originaux ne sont jamais publiés.

## Format demandé à Tripo
- **GLB**, textures intégrées, environ 10 000 à 25 000 triangles par personnage.
- Personnage debout, pieds au sol, face vers l'avant. Tripo normalise la hauteur : le jeu remet à l'échelle.
- Idéal : version **auto-rig + animations** (repos, marche, tir, impact, mort). Sans squelette, le jeu anime le modèle entier.
- Armes : soit tenues dans le modèle, soit en fichiers séparés (catégorie `weapons`).

## Noms attendus
| Catégorie | Noms | Déjà là |
|---|---|---|
| `units` | `walker`, `okafor`, `lind`, `moreau` (et une ou deux recrues génériques : `recrue_a`, `recrue_b`) | okafor, lind |
| `units` | `nereide`, `carapace`, `spectre`, `brute` | nereide, brute |
| `weapons` | `rifle` (fusil à fléchettes), `pistol`, `harpoon`, `harpoon_ap`, `cavitation` | — |
| `crafts` | `barracuda`, `triton`, `eclaireur`, `moissonneur`, `cuirasse` | — |
| `props` | `console`, `capsule`, `armoire`, `reservoir`, `caisse`, `conteneur`, `noyau_nid` | — |
| `rooms` | `commandement`, `sonar`, `hangar`, `laboratoire`, `atelier`, `dortoir`, `infirmerie`, `stockage`, `reacteur`, `confinement` | — |

Réglage fin (hauteur, rotation) : `godot/view/model_registry.gd`, table `TUNING`. Aperçus : `tests/model_preview.gd`, `tests/lineup.gd`.
