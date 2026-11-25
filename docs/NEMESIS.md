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
| 25/11 | Kit dans `godot/view/kit.gd` (`AbyssKit`) | Une carte ne décrit que des cases ; le kit fabrique sols, cloisons, coque, caisses, consoles, passerelles, garde-corps, escaliers, bassin, berceau de l'artefact, excroissances. Réutilisable pour les missions suivantes. |

## Avancement
- **N1 — kit modulaire et habillage du labo** (branche `claude-b/nemesis-n1`) : toutes les primitives du décor remplacées par le kit, berceau de confinement Némésis et artefact retravaillé, rayons de lumière des hublots, ambiance plus sombre et contrastée, débris chanfreinés. 31 tests OK.
- N2 (prévu) — soldats et aliens : vrais modèles articulés + animations (repos, marche, tir, impact, mort).
- N3 (prévu) — plan de salle ENV-007, caméra (cadrages d'action), impacts et déplacements.
- N4 (prévu) — performance mobile (mesures de Max), réglages qualité automatiques.

## Vérifier
- Tests : `godot --headless --path godot -s res://tests/run_tests.gd`
- Capture hors ligne : `xvfb-run godot --path godot --rendering-driver opengl3 -s res://tests/shot.gd -- sortie.png 0 17 8,7`
