# Reprise 26/11, 7 h (démo Phaser 4 Némésis)

Branche de travail : `experiment/phaser4` (PR #15, brouillon, ne pas fusionner sans Max). Contient aussi la directive V2 et l'outil d'import 2D.

## État
- Démo jouable `phaser/nemesis.html` : 4 soldats (poses de Max : debout, marche, genou, visée), 3 aliens (4 vues fixes), sol fait des dalles iso de Max, lumières, sons ElevenLabs. Journal : `docs/PHASER4-NEMESIS.md`.
- CI verte (30 tests Vitest + build). Test Playwright `e2e/nemesis.spec.ts` rallongé (machine sans GPU), dernier passage non vérifié.
- Publication d'une page jouable (artefact) refusée par une règle de sécurité : lien jouable = fusion de #15 (GitHub Pages) ou autorisation de Max.

## Fichiers sources (hors dépôt, perdus entre sessions)
- Les versions allégées utilisées par le jeu sont dans le dépôt (`phaser/public/nemesis/`, `assets2d/tiles/`). Relancer `tools/build_phaser_nemesis.py` sans les masters garde les sprites existants.
- Pour retoucher les poses : renvoyer les planches → `tools/cut_pose_sheet.py planche.jpg ~/abyss_masters/poses nom` (Moreau : `--tol 6.5` ; Walker pose 3 : effacer le bout de canon en haut à gauche).
- Pour une nouvelle dalle : `tools/iso_tile.py dalle.jpg assets2d/tiles/nom.png`, puis l'ajouter au `plan` de `bake_floor`.

## Attendu de Max (prochaine session)
1. Murs iso dans le style des dalles : mur droit face gauche + face droite (~2,5 dalles de haut), coin, hublot, console encastrée, porte du sas, mur contaminé, version mi-hauteur.
2. Soldats de dos et 3/4 dos ; tir, touché, à terre ; aliens en 5 poses.
3. À confirmer : brun à pieuvre = Walker, blond = Lind, médecin = Moreau, Ω = Okafor.

## Pour intégrer les murs
Remplacer les blocs `wall_*` générés dans `NemesisScene.buildWalls` (clés `tall`, `tall_lamp`, `tall_red`, `low`) par les images de Max détourées (fond blanc → `tools/cut_pose_sheet.py` ou détourage simple), ancrées sur le coin bas de la case.
