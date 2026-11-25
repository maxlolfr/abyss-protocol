# Modèles 3D (Tripo) : quoi exporter, sous quel nom, comment le jeu les branche

Mis à jour le 25/11/2026 (22 h 45) d'après l'inventaire prévisionnel de Max (8 lots, GLB, PBR, textures 2K).

## Envoi
- **Un ZIP par lot** dans la conversation avec Claude. Trop lourd : coupe-le (Lot 1 A, Lot 1 B…).
- Noms : ceux du tableau ci-dessous de préférence. Les intitulés de l'inventaire marchent aussi (« Mur métallique standard.glb », « Porte blindée.glb »…), avec ou sans accents, majuscules ou espaces. Variantes : `_02`, `_03`… Décor propre à une carte : suffixe `_port` ou `_nid` (sinon : architecture humaine = station, extraterrestre = Nid).
- Claude lance `python3 -I tools/import_lot.py lot.zip` : reconnaissance des noms, comptage des triangles, version **allégée** (textures 1024 px, 512 px pour les modules répétés) rangée dans `godot/assets/models/…`. **Les originaux et les ZIP ne sont jamais publiés.**
- Pas de FBX ni d'OBJ : GLB uniquement (l'outil signale les fichiers à réexporter).

## Comparaison avec ce qui existe déjà (doublons)
| Inventaire | Déjà dans le jeu | Décision |
|---|---|---|
| Lot 8 : Néréide | `units/nereide.glb` (Tripo, sans squelette) | **Ne pas réexporter**, sauf version riggée + animée (alors elle remplace l'actuelle). |
| Lot 8 : marines | `okafor.glb`, `lind.glb` (sans squelette) | Idem. **Walker et Moreau** : à exporter. |
| Lot 8 : extraterrestres lourds | `brute.glb` | Doublon probable : n'exporter que si c'est une autre créature. |
| `armored_soldier` (déjà reçu) | même maillage qu'Okafor | Non utilisé. |
| `alien_creature.fbx` (déjà reçu) | sans texture, espèce inconnue | Réexporter en GLB texturé et dire de quelle espèce il s'agit. |
| Lot 1 : barricade tactique / Lot 3 : caisse militaire | objets peints des planches (sprites) | Le modèle 3D **remplace** le sprite automatiquement : pas un doublon. |
| Lot 4 : roches, cristaux | décor procédural du Nid (blocs, prismes) | Le modèle 3D remplace les formes provisoires. |
| Lot 7 : fusil d'assaut | armes découpées de WEAPONS-001 (2D, tenues par les sprites) | Le modèle 3D sert aux personnages 3D. |
| Port attaqué : grue, conteneurs, quai | **absents de l'inventaire** | Décor procédural gardé (`grue`, `conteneur` acceptés plus tard). |

## Priorité d'export (dans cet ordre)
### Priorité 1 — Mission Némésis (station)
| Fichier | Rôle dans le jeu | Remplace |
|---|---|---|
| `sol_dalle` | dalle de sol 1 × 1 m, répétée sur toute la carte | sol provisoire |
| `mur_coque` | module de paroi extérieure, 1 m de large, ≈ 2,4 m de haut | coque |
| `mur_angle` | angle de paroi à 90° (coin extérieur vers +X +Z) | coins de coque |
| `mur_hublot` | paroi avec vitre renforcée sur l'océan | hublots |
| `cloison` | mur intérieur destructible, 1 m de large, ≈ 1,8 m | cloisons |
| `plateforme` | bloc de passerelle 1 × 1 × 1 m (dessus praticable) | mezzanines |
| `escalier` | volée de 1 m montant vers +X | escaliers |
| `garde_corps` | garde-corps d'1 m sur le bord +Z | rambardes |
| `couvert_bas_01` à `_04` | couverts bas (≈ 1 m) : caisse, barricade, console basse… | caisses peintes |
| `couvert_haut_01` à `_02` | couverts hauts (≈ 1,6 m) | — |
| `terminal_vertical`, `console_commandement`, `panneau_electrique`, `reacteur`, `capsule_confinement`, `equipement_labo`, `tuyau_droit`, `tuyau_coude` | objets le long des parois | objets peints |
| `mur_contamine` | paroi contaminée (zone ouest) | excroissances peintes |
| `walker`, `moreau` (personnages, Lot 8) | soldats | sprites |
| `carapace`, `spectre` | créatures de Némésis | sprites / modèle articulé |
| `fusil_assaut`, `pistolet`, `arme_lourde` (Lot 7) | armes des soldats 3D | — |

### Priorité 2 — Port attaqué
`caisse_militaire`, `barricade`, `reservoir`, `conteneur` (si Tripo en a un), couverts `couvert_bas_01_port`… (les modules de sol et de quai restent procéduraux tant qu'il n'y a pas d'équivalent).

### Priorité 3 — Le Nid
`mur_biomecanique` (paroi de la caverne), `mur_alien_b` (variante), `pilier_biomecanique` (mur intérieur), `arche_alien`, `structure_organique`, `cristaux_violets` (+ `_02`…), `roche` (+ `_02`…), `oeuf_alien`, `cocon`, `nid_alien`, `masse_organique`, `artefact_alien`, `ruche`, `noyau_nid` (objectif de la mission), couverts `couvert_bas_01_nid`…

### Priorité 4 — Base Neptune
Salles (`rooms/`) : `commandement`, `sonar`, `hangar`, `laboratoire`, `atelier`, `dortoir`, `infirmerie`, `stockage`, `reacteur_base`, `confinement`.

### Priorité 5 — Géoscape
`base_neptune`, `station_recherche`, `batiment_militaire`.

### Priorité 6 — Interceptions
`barracuda`, `triton` (véhicule de transport), `sous_marin_recherche`, `drone_combat`, `robot_quadrupede`, aliens `eclaireur`, `moissonneur`, `cuirasse`.

Plus tard : `porte_blindee`, `porte_circulaire`, `pilier_metallique`, `arme_energie`, `arme_alien`, `grenade`, `kit_medical`, `leviathan`, `recrue_a`, `recrue_b`.

## Réglages d'export Tripo (téléphone d'abord)
| Catégorie | Triangles max | Remarque |
|---|---|---|
| Modules répétés (sol, murs, passerelle, garde-corps) | **≤ 1 500** (sol ≤ 500) | répétés jusqu'à 200 fois : c'est le poste le plus coûteux |
| Couverts et objets de décor | ≤ 5 000 | |
| Personnages et créatures | 10 000 à 20 000 | **auto-rig + animations** si possible (repos, marche, tir, impact, mort) |
| Armes | ≤ 3 000 | canon vers l'avant |
| Engins, salles, bâtiments | ≤ 15 000 à 20 000 | |

Repères : pieds ou base au sol, face vers l'avant. L'échelle n'a pas d'importance (le jeu remet chaque pièce à sa taille), mais un module doit être **un seul module** (un mur = 1 case de large, pas une rangée). Les néons peuvent rester d'une seule couleur : le jeu les recolore (cyan humain, violet alien) si le matériau est émissif ou nommé `neon`, `glow`, `light`, `emissive`.

## Ce que fait le jeu (déjà prêt, `godot/view/model_kit.gd`)
- **Branchement sans code** : un fichier présent remplace la pièce provisoire, un fichier absent la garde. Ordre de recherche : `kit/<thème>/` puis `kit/`, `props/<thème>/` puis `props/`.
- **Échelle, orientation, origine** automatiques (boîte englobante) : largeur d'une case pour les modules, hauteur pour les objets, longueur pour les armes ; un mur livré dans l'autre sens est tourné ; une dalle a son dessus au ras du sol. Réglage fin : table `TUNING` (échelle, rotation, décalage).
- **Performance** : les modules répétés sont dessinés en un seul objet par type (MultiMesh), maillage importé conservé (niveaux de détail de l'import gardés), pas de collisions physiques (le combat se joue sur la grille de la simulation, qui garde lignes de tir et couverts).
- **Murs qui cachent les soldats** : coque abaissée côté caméra, cloisons et couverts rendus translucides devant une unité ; marche aussi avec les modèles 3D (maillages imbriqués compris). Les gros objets hors carte se masquent côté caméra.
- **Couverts** : `couvert_bas_NN` sur les cases de couvert bas (choix et rotation variés par case), `couvert_haut_NN` prêt pour les couverts hauts.
- **Personnages** (`view/model_unit.gd`) : squelette détecté (main droite pour l'arme), animations livrées reconnues par leur nom et jouées avec celles du jeu ; sans squelette, le modèle entier est animé. Arme 3D attachée selon l'arme réellement portée.
- **Contrôle** : `tests/model_kit_test.gd` (faux GLB générés à la volée : échelle, orientation, couverts, néons, armes, coupe caméra), lancé par la CI.

Registre des personnages existants : `godot/view/model_registry.gd` (table `TUNING` : hauteur, rotation).

## Reçus le 25/11 (22 h 40 → 22 h 50), GLB envoyés un par un
Import : `python3 -I tools/import_lot.py fichier.glb …` (accepte maintenant des GLB isolés, ignore le préfixe d'envoi). Les triangles sont réduits automatiquement par `tools/reduce_glb.py` (simplification de Godot, `godot/tests/lods.gd`) ; Godot s'arrête quand la forme se dégraderait, d'où quelques modèles au-dessus du budget.

| Reçu | Rangé sous | Triangles reçus → gardés | Utilisé |
|---|---|---|---|
| mur_humain | `kit/station/mur_coque` | 11 732 → 1 540 | coque de la station |
| porte alien contaminée (en fait un mur humain envahi) | `kit/station/mur_contamine` | 19 181 → 5 509 | paroi ouest de Némésis (clé `hull_x`) |
| barricade_humaine, barricade_humain2 | `kit/station/couvert_bas_01`, `_02` | ≈ 10 000 → ≈ 2 600 | couverts bas |
| barricade_extra | `kit/nid/couvert_bas_01` | 21 546 → 5 385 | couverts du Nid |
| mur_extra, pilier_extra | `kit/nid/mur_biomecanique`, `pilier_biomecanique` | ≈ 21 000 → ≈ 3 200 | parois et murs du Nid |
| arche_extra | `props/arche_alien` | 19 788 → 4 946 | objet peint k009_5 |
| sci-fi terminal (2e envoi) | `props/terminal_vertical` | 9 014 → 4 506 | terminal |
| control console, control panel, cargo crate, pipeline, power core, canister | `props/console_commandement`, `panneau_electrique`, `caisse_militaire`, `tuyau_droit`, `reacteur`, `capsule_confinement` | 4 000-11 000 → 3 000-4 500 | objets peints remplacés |
| industrial staircase | `kit/station/escalier` | 8 266 → 2 216 | escaliers |
| pilier_humain, porte_blinde_humain, vault door | `kit/station/pilier_metallique`, `porte_blindee`, `porte_circulaire` | → ≈ 2 500-2 900 | rangés, pas encore placés |
| industrial floor grate | `kit/station/sol_grille` | 6 230 → 2 331 | rangé, **pas utilisé comme sol** : répété sur toute la carte il triplait le coût (1,4 M primitives) |

Écartés : 1er « sci-fi terminal » (même maillage que pilier_humain, autre texture), 2e vault door (fichier identique), metal hatch window (plaque plate : trappe de sol ou hublot ? question à Max), industrial catwalk (passerelle de 0,33 × 1 m avec rambardes, 24 000 triangles : ne correspond pas au bloc `plateforme` 1 × 1 m).

Coût de rendu (primitives, `campaign_battle_shot.gd`) avant → après : épave 222 k → 492 k, port 192 k ≈ 259 k, Nid 192 k → 712 k (murs du Nid à 3 200 triangles chacun). **À demander à Max** : exporter les modules répétés (murs, piliers, sols) depuis Tripo avec une limite de faces ≈ 1 500.

### Sols reçus à 23 h (à réexporter)
`sci-fi floor tile` (→ `sol_dalle` station), `sci-fi floor panel` (→ `sol_dalle_02`, variante semée une case sur cinq), `alien organic floor` (→ `sol_dalle` du Nid), `purple lava stone` (→ `sol_dalle_02` du Nid) : très bons budgets (330 à 470 triangles), mais **compressés** (gltfpack, `EXT_meshopt_compression`) : Godot ne les lit pas. Les réexporter depuis Tripo en GLB **sans compression** ; le jeu est déjà prêt (clés `floor` et `floor_b`, dalles tournées d'un quart de tour au hasard). L'outil d'import signale désormais ces fichiers au lieu de les ranger. `industrial floor grate` reçu deux fois (identique).

### Optimisation téléphone (25/11, 23 h 15)
- Murs, sols, piliers : un MultiMesh par type (déjà en place) ; maillage et matériaux d'un modèle chargés une seule fois (cache de `ModelKit`).
- **Ombres** : en qualité haute, les modèles projettent leurs vraies ombres. En **moyenne** (défaut téléphone), les pièces répétées projettent l'ombre d'une **boîte à leurs dimensions** (12 triangles) et les objets isolés n'en projettent pas. En basse et allégée, il n'y a pas d'ombres (inchangé). Les ombres simplifiées des coques s'abaissent avec la paroi côté caméra.
- Primitives mesurées (haute → moyenne → allégée) : épave 492 k → 306 k → 173 k, Nid 712 k → 384 k → 249 k, port 259 k → 246 k.
- `trappe` (metal hatch window, plaque plate) : posée à plat sur une dalle de la station sur 17, 0,85 m de large (`ModelKit.node(…, "width")`). `passerelle_etroite` (catwalk 0,33 × 1 m) : rangée à sa taille réelle (14 400 triangles), en attente d'un emplacement.
- Mesure sur appareil (i/s) : compteur dans le menu du jeu ; profils haute / moyenne / basse / allégée et baisse automatique sous 24 i/s (déjà en place).
