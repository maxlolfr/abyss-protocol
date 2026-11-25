# Mission Némésis — journal de production (Godot 3D, DA V3.1)

Mission de Max (25/11/2026, 11 h) : une première mission Némésis de très haute qualité, avant toute campagne.
Références : 63 images privées dans le studio (`Game-studio-ai/docs/studio/art/abyss-protocol/`), salle ENV-007.

## Décisions
| Date | Décision | Pourquoi |
|---|---|---|
| 25/11 | **Modèles 3D construits en code (GDScript), pas dans Blender** | Blender ne peut pas être téléchargé depuis l'environnement de Claude (blender.org bloqué). Les modèles sont de vrais maillages (arêtes chanfreinées, plusieurs matériaux) générés au lancement et partagés entre cases. Si Max peut fournir Blender plus tard, les pièces pourront être exportées en glTF. |
| 25/11 | **Textures PBR procédurales** (`tools/gen_textures.py` → `godot/assets/textures/`) | Aucun service payant ; reproductibles ; répétables sans couture. 7 jeux : plate, hull, floor, grate, hazard, crate, screen. Import WebP avec mipmaps (pas de compression GPU : compatible iPhone/Android en WebGL). |
| 25/11 | Projection **triplanaire** | Les pièces n'ont pas besoin de dépliage UV ; la densité de texture reste constante (1 texture = 1 m). |
| 25/11 | La carte de jeu (`AbyssData.LAB`) est **conservée** pour ce lot | Les 31 tests reposent dessus. Le plan de la salle Némésis (cuve centrale, mezzanines symétriques) viendra dans un lot dédié avec ses propres tests. |
| 25/11 | Unités : articulations rigides (pas de squelette déformé) | Un scaphandre blindé et des créatures à carapace se lisent bien en pièces rigides ; animations légères pour mobile ; un modèle glTF riggé pourra remplacer chaque unité via `assets/units/<kind>.tscn` sans toucher au jeu. |
| 25/11 | Kit dans `godot/view/kit.gd` (`AbyssKit`) | Une carte ne décrit que des cases ; le kit fabrique sols, cloisons, coque, caisses, consoles, passerelles, garde-corps, escaliers, bassin, berceau de l'artefact, excroissances. Réutilisable pour les missions suivantes. |

## Avancement
- **N1 — kit modulaire et habillage du labo** (branche `claude-b/nemesis-n1`) : toutes les primitives du décor remplacées par le kit, berceau de confinement Némésis et artefact retravaillé, rayons de lumière des hublots, ambiance plus sombre et contrastée, débris chanfreinés. 31 tests OK.
- **N2 — soldats et aliens articulés** (`godot/view/rigs.gd`, même branche) : plongeur en scaphandre blindé (casque à visière, bouteilles dorsales, fusil tenu à deux mains par IK), Néréide voûtée à nageoires et griffes, Carapace à six pattes et deux pinces, Spectre méduse à huit tentacules. Animations repos, marche, tir, impact, mort (le corps reste au sol), génuflexion des soldats. Planche de contrôle : `tests/lineup.gd`.
- **N2.1 — d'après les planches de 15 h** : couleurs des soldats (combinaison marine, plaques acier, poches cuir, accents cyan, casque à bulle avec visage), Okafor en variante lourde à épaulières et sac ambre, Néréide bleu nuit à lignes cyan, Spectre gris fumé à cœur violet. Boutons d'action avec les icônes UI-112 de Max (`assets/ui/icons/`).
- **N3 — salle Némésis, effets, caméra** :
  - Carte `AbyssData.NEMESIS` (16×14) d'après ENV-007 : cuve de l'artefact au fond, mezzanines symétriques reliées par deux escaliers, terminal sur la mezzanine est, bassins techniques, sas au sud. Le jeu s'ouvre sur Némésis ; `?map=lab` rouvre l'ancien labo. La sauvegarde retient la carte. 6 tests de plus (37).
  - Effets `godot/view/fx.gd` d'après VFX-001 à 010 : flash de bouche étoilé, projectiles visibles avec traînée (vitesse propre à chaque arme, jet d'acide en cloche), impacts différents sur métal, soldat, alien, acide (flaque qui reste), onde psychique, explosion (boule de feu, éclats, fumée qui monte, onde au sol), soin.
  - Caméra : suit en douceur une unité qui sort du cadre, secousse proportionnelle aux gros dégâts.
  - Props : caisses gris acier à témoin cyan (PROP-007), barricades inclinées à bandes de danger (PROP-009).
  - Contrôle : `tests/play_smoke.gd` joue une partie complète avec tous les effets et vérifie qu'aucune erreur ne survient ; `tests/fxshot.gd` photographie les effets au ralenti.
- **Équilibrage à faire** : en IA contre IA, l'escouade gagne Némésis ≈ 83 % du temps en 4 tours en moyenne. On règle après les essais de Max (l'IA joue différemment d'un humain).
- N4 (prévu) — performance mobile (mesures de Max), réglages qualité automatiques, états de destruction des props, Carapace d'après sa future planche.

## Vérifier
- Tests : `godot --headless --path godot -s res://tests/run_tests.gd`
- Capture hors ligne : `xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/shot.gd -- sortie.png 0 17 8,7`
