# Planches manquantes — ABYSS PROTOCOL (phase 2, 25/11/2026)

Le jeu est **déjà prêt à les recevoir** : `godot/view/sprite_unit.gd` charge automatiquement
`assets/units/sprites/<jeu>_<pose>_<vue>.png` s'il existe (sinon il garde la pose neutre + l'arme découpée).
Il suffit de livrer les planches : Claude les détoure (`tools/split_views.py` + `tools/extract_views.py`) et les range.

## Règles communes à TOUTES les planches (à recopier dans chaque demande)
- Même personnage, même équipement, mêmes couleurs que la planche de référence existante (citée ci-dessous).
- **4 vues côte à côte, dans cet ordre, de gauche à droite** : face, profil (le personnage regarde vers la DROITE de l'image), dos, trois-quarts avant (le personnage regarde vers la GAUCHE de l'image).
- Personnage **en pied**, entièrement visible, pieds sur la même ligne, même échelle dans les 4 vues, **espace vide d'au moins 5 % de la largeur entre deux vues** (elles ne doivent pas se toucher).
- Fond gris neutre uni (#808080 à #9a9a9a), **aucune ombre portée au sol**, aucun texte, aucune grille, aucun décor.
- Éclairage studio doux venant du haut à gauche, rendu semi-réaliste militaire (style des planches CHAR-HUM-001 et HUM-002).
- Format paysage 16:9, 2752 × 1536 px (ou 1376 × 768 minimum), JPEG ou PNG.
- L'arme est **tenue dans la pose** (elle fait partie de l'image).

## Soldats (priorité 1 — 4 soldats × 5 poses = 20 planches)
| Soldat | Référence | Arme tenue | Noms de fichiers attendus |
|---|---|---|---|
| Walker (fusilier) | CHAR-HUM-001 | AR-9 Neptune (WEAPONS-001 n°1) | `POSE-WALKER-<pose>.jpg` |
| Okafor (lourd) | HUM-002 | lanceur lourd à énergie (WEAPONS-001 n°6) | `POSE-OKAFOR-<pose>.jpg` |
| Lind (tireuse de précision) | CHAR-001 marine lourd, teinte bleu acier | SR-9 (WEAPONS-001 n°3) | `POSE-LIND-<pose>.jpg` |
| Moreau (médecin) | CHAR-001 marine lourd, teinte sable + croix médicale verte à l'épaule | PX-3 + médikit (WEAPONS-001 n°5) | `POSE-MOREAU-<pose>.jpg` |

| `<pose>` | Description exacte | Utilisée pour |
|---|---|---|
| `AIM` | debout, jambes écartées, arme épaulée et pointée droit devant, regard dans l'axe | posture de combat (après le premier contact) |
| `FIRE` | comme AIM avec recul visible : épaule reculée, flash de bouche discret, douille éjectée | tir |
| `KNEEL` | un genou au sol, arme épaulée vers l'avant | génuflexion (+10 % précision) |
| `WALK` | 2 images par vue : pas gauche en avant / pas droit en avant, arme tenue basse prête | marche (`walk1`, `walk2`) — livrer 2 planches : `…-WALK1`, `…-WALK2` |
| `RELOAD` | debout, arme inclinée, main sur le chargeur | rechargement |

Prompt type (ChatGPT, à adapter par soldat et par pose) :
```
ABYSS PROTOCOL — planche de pose de personnage. Même personnage, même armure, mêmes couleurs que la planche
de référence jointe « Walker – Assault Marine ». Pose : debout, jambes écartées, fusil AR-9 Neptune épaulé et
pointé droit devant, regard dans l'axe du canon. Quatre vues côte à côte de gauche à droite : face ; profil
(le personnage regarde vers la droite de l'image) ; dos ; trois-quarts avant (il regarde vers la gauche de l'image).
Personnage en pied, pieds alignés, même échelle, large espace vide entre les vues. Fond gris neutre uni,
aucune ombre au sol, aucun texte. Lumière studio douce du haut à gauche. Rendu semi-réaliste, science-fiction
militaire sous-marine. Format paysage 16:9.
```

## Aliens (priorité 2)
| Créature | Référence | Poses | Fichiers |
|---|---|---|---|
| Néréide | ALIEN-001 / CHAR-002 | `ATTACK` (bras griffus projetés), `HIT`, `WALK1`, `WALK2` | `POSE-NEREIDE-<pose>.jpg` |
| Spectre | ALIEN-002 / CHAR-003 | `ATTACK` (tentacules écartées, cœur violet brillant) | `POSE-SPECTRE-ATTACK.jpg` |
| Carapace | **planche dédiée manquante** (BIO-109 sert de remplaçant) | planche neutre 4 vues + `ATTACK` (jet d'acide) | `CHAR-004_Carapace.jpg`, `POSE-CARAPACE-ATTACK.jpg` |

Prompt Carapace (neutre) : voir le message du 25/11 16 h 09 (crustacé lourd 1,4 m, six pattes, deux pinces,
carapace brun-ambre segmentée, yeux ambre, glandes d'acide vertes, 4 vues, fond gris uni, sans ombre au sol).

## Décor (priorité 3)
| Fichier | Contenu | Usage |
|---|---|---|
| `DOOR-001_Blast_Door.jpg` | porte blindée de sas, 4 états (fermée, entrouverte, ouverte, détruite), vue 3/4, fond gris | sas d'évacuation |
| `DECAL-001_Floor_Decals.jpg` | planche à plat vue de dessus : flaques, traces de sang alien violet, brûlures, câbles au sol, grilles d'évacuation, 12 éléments isolés sur fond gris | détails au sol |
| `PROP-011_Corpse_Marine.jpg` | marine mort au sol, vue de dessus et 3/4, sans sang humain excessif | récit (traces de lutte) |

## Ce que Claude fera à la réception
Découpe des vues, détourage, mise à l'échelle (hauteur réelle), import WebP, branchement automatique par le nom.
Temps estimé : ~10 min par planche, sans action de Max.
