# Prototype Godot 4.7.2 (vraie 3D) — notes techniques

Demande de Max (25/11/2026) : privilégier Godot + GDScript en vraie 3D isométrique, sous réserve de validation technique ; garder le prototype TypeScript comme référence ; décider après comparaison des deux prototypes jouables.

## Ce qui est implémenté
| Demande | Implémentation | Vérifié |
|---|---|---|
| Carte tactique en vraie 3D | 16×14 cases, blocs 3D (sol, cloisons, coque, caisses, eau, passerelle, escalier) en primitives | ✅ navigateur |
| 4 soldats, 3 aliens | Walker, Okafor, Lind, Moreau ; Néréide, Carapace, Spectre (modèles temporaires distincts) | ✅ |
| 2 niveaux de hauteur | passerelle à 1 m + escalier (0,5 m) ; on ne saute pas 1 m ; **tir plongeant** : +10 % et couvert réduit d'un cran ; depuis la passerelle on tire **par-dessus** les cloisons | ✅ tests |
| Caméra isométrique rotative | caméra orthographique à 35,26°, rotation par quarts de tour (boutons), glisser = déplacer, pincer / molette = zoom | ✅ (rotation non capturée) |
| Éclairages et ombres dynamiques | lumière directionnelle avec ombres, lampes frontales des plongeurs (ombres), alarmes rouges pulsées, Spectre lumineux, éclairs de tir et d'explosion ; bouton « Ombres : oui/non » pour les appareils plus faibles | ✅ |
| Murs destructibles | cloisons à 40 PV : le harpon lourd (action « Brèche ») ou la grenade les abattent ; les débris restent, la ligne de vue et les trajets changent | ✅ tests + navigateur |
| Tour par tour | UT identiques à la référence (6/case, 8 en diagonale, rapide 12, précis 24, genou 4, surveillance 18), tirs de réaction, IA à score avec embuscades (surveillance) | ✅ tests |
| Interface tactile minimaliste | toucher = aperçu (coût, UT restantes, niveau, couvert, tirs de réaction possibles), re-toucher ou « Confirmer » = action ; aucune modale sauf le récapitulatif | ✅ navigateur |
| Version Web | export Compatibilité (WebGL 2), sans threads (aucun en-tête serveur requis, compatible GitHub Pages) | ✅ |

## Architecture
- `sim/` : `AbyssData` (contenu), `AbyssGrid` (carte, hauteurs, pathfinding, ligne de vue 3D, couvert, destruction), `AbyssBattle` (commandes → événements, tours, combat, réactions), `AbyssAI`, `AbyssUnit`. **Aucun nœud de scène** : testable sans écran.
- `view/` : `main.gd` (scène 3D, caméra, entrées, rejeu des événements), `hud.gd` (interface).
- `tests/run_tests.gd` : 22 vérifications + parties IA contre IA (`godot --headless --path . -s res://tests/run_tests.gd`).

## Différences avec la référence TypeScript (volontaires, pour ce prototype)
- 3 aliens au lieu de 6 (demande), donc plus résistants, alertés dès le départ et capables de se mettre en surveillance.
- Pas encore : brouillard des cases (seuls les ennemis non vus sont masqués), munitions, soin, objectifs artefact/journal, sauvegarde.

## Mesures
- Simulation : 16 parties complètes IA contre IA en ≈ 2,3 s (CPU du serveur).
- Rendu logiciel sans GPU : ≈ 2 i/s (sans valeur pour un téléphone). **La mesure de référence est celle de Max** : compteur i/s en haut à droite, sur Honor Magic V5, iPhone 15 Pro Max et iPad, ombres activées puis désactivées.
- Équilibrage : en IA contre IA, l'escouade gagne encore ≈ 80 % des parties. À régler après les essais de Max.
