# Démo Phaser 4.2.1 — salle Némésis (branche `experiment/phaser4`)

Vertical slice mobile de la directive V2 (§5, §12) : la salle de confinement de Némésis en 2.5D premium,
jouable au doigt, sur la même simulation TypeScript et le même HUD que le prototype Phaser.

## Lancer
- Page : `phaser/nemesis.html` (2e entrée Vite, à côté de `index.html`). `?seed=xxx`, `?q=allegee`, `?auto` (partie lancée d'office, pour les captures).
- Ressources : `python3 -I tools/build_phaser_nemesis.py` → `phaser/public/nemesis/` (2,8 Mo, relançable, rien d'autre n'est écrit).
- Tests : Vitest (2 nouveaux tests Némésis dans `tests/engine.test.ts`), Playwright `e2e/nemesis.spec.ts` (toucher, aperçu, confirmation, tour alien, 0 erreur).

## Dalles de sol de Max (26/11, 6 h 50)
- 6 dalles isométriques reçues (2 identiques) → `tools/iso_tile.py` repère la face du dessus et la ramène au losange 2:1 → `assets2d/tiles/` (512×256, versions allégées ; masters dans `~/abyss_masters/floors`).
- Sol précalculé : métal propre (centre, 2×2 cases par dalle), métal abîmé (pourtour, 2×2), trappe sur tout le sas (3×3), métal contaminé puis roche alien en se rapprochant de la cuve (1 case, miroirs pour varier). Normal map tirée du relief de chaque dalle.

## Ce qui est en place
- **Simulation** : `NEMESIS_MAP` (même plan que `godot/sim/data.gd`), `createBattle(seed, 'nemesis')`, 3 aliens fixes renforcés (valeurs Godot). Sauvegarde séparée (`nemesis.*`).
- **Rendu** (`src/nemesis/NemesisScene.ts`, contrat `src/game/view.ts` partagé avec le prototype) :
  - sol de toute la salle précalculé en iso 2:1 + normal map (dalles, caillebotis, bandes du sas, contamination violette autour de la cuve, occlusion au pied des parois) ;
  - coque texturée (blocs hauts au fond, coupe basse devant), machinerie réelle pour les cloisons, 37 objets des planches (couvertures, terminal, décor adossé) ;
  - Light2D Phaser 4 : plafonniers (un qui grésille), appliques, alarmes (gyrophare plus fort après l'alerte), terminal, bassins, artefact pulsant, lampes frontales qui suivent les soldats ;
  - filtres caméra : vignette + bloom (`Phaser.Actions.AddEffectBloom`, coupé en qualité allégée) ; self-shadow sur les objets ;
  - particules : neige marine, bulles, vapeur, étincelles d'une console, aura de l'artefact, impacts, explosion + fumée ;
  - eau animée (caustiques en fondu), x-ray des machines qui cachent une unité, brouillard de guerre.
- **Soldats** : planches de poses de Max (26/11), découpées par `tools/cut_pose_sheet.py` : debout, marche (2 images alternées + balancement), genou, visée (tir et surveillance). Portraits des cartes tirés des mêmes images.
  Attribution supposée : octopus/brun = **Walker**, blond = **Lind**, médecin = **Moreau**, Ω = **Okafor** (à confirmer).
- **Aliens** : 4 vues fixes (face, 3/4, profil, dos) + animation procédurale (respiration, flottement du Spectre, balancement).
- **Sons** : vrais sons ElevenLabs du dépôt transcodés en AAC (lecture Safari iOS), voix radio et soldats sans chevauchement, ambiance « chambre alien », compresseur ; synthèse en secours tant qu'un son n'est pas chargé.
- **Mobile** : canvas à la définition réelle (×2 max) puis réduit en CSS, baisse automatique (×1, sans bloom) si < 40 i/s pendant 6 s, pause audio en arrière-plan, message si le contexte WebGL est perdu.

## Limites connues (honnêtes)
- Soldats : vues de dos et 3/4 dos intégrées (26/11, 7 h). Encore retournées gauche/droite (l'épaule de l'arme s'inverse) ; pas de pose de visée de dos (on garde le 3/4 dos).
- Aliens : pas encore d'images d'animation (tir, impact, mort = effets et rotation, pas de vraies poses).
- Mort : sprite couché par rotation (provisoire).
- Mezzanines **plates** côté TypeScript (hauteurs = Godot uniquement) : caillebotis au sol, pas d'escalier réel.
- Mesures i/s : uniquement en émulation logicielle (SwiftShader, 2–25 i/s, non représentatif). **Mesures réelles à faire sur iPhone 15 Pro Max / Honor Magic V5 / iPad.**

## Ressources à demander en priorité (une planche par ligne, même style que celles du 26/11)
2. Les 4 soldats : **tir (recul)**, **touché**, **à terre**.
3. Néréide, Carapace, Spectre : debout, déplacement, attaque, touché, mort (5 poses, fond uni).
4. Salle Némésis : rambardes de mezzanine et escalier isométriques détourés (pour retrouver les hauteurs).
