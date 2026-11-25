# ABYSS PROTOCOL — reprise de session (lire en premier)

Projet phare de Maxlol Games (Max, testeur sur téléphone, pas d'ordinateur). Langue : **français**.
Vision : `docs/MASTER_GDD.md`, `docs/ART_DIRECTION.md`, `docs/CLAUDE_START.md`. Décisions : `docs/DECISIONS.md`. Bible artistique de ChatGPT (privée) : `Game-studio-ai/docs/studio/results/m-0017/ART_BIBLE_HANDOFF_V1.md`, mission ChatGPT dans les commentaires de la PR #24 du studio.

## État au 25/11/2026, 11 h (Bangkok)
- **Phase 1** (prototype tactique) : deux prototypes jouables, publiés sur https://maxlolfr.github.io/abyss-protocol/ (GitHub Pages, source « GitHub Actions », activée par Max).
  - `godot/` : **moteur définitif du jeu (décision ferme de Max, 25/11 10 h 55)** : Godot 4.7.2 + GDScript, vraie 3D isométrique. 31 tests (`godot --headless --path godot -s res://tests/run_tests.gd`). Détails : `docs/PROTOTYPE-GODOT.md`.
  - `phaser/` : Phaser 4.2.1 + TypeScript, 2.5D, gardé comme **référence fonctionnelle** de la simulation (28 tests Vitest + test Playwright). Plus de développement de rendu Phaser.
- PR #1 (vertical slice : labo Godot, parité gameplay, effets, HUD compacts) : fusionnée par Max et publiée.
- Reste de la phase 1 : retours de Max sur iPhone 15 Pro Max, Honor Magic V5, iPad (i/s ombres on/off), intégration de ses décors et personnages (≈ 50 images : références 2D pour modèles et textures 3D). **Ne pas lancer la phase 2 sans validation.**

## Comment travailler ici
- CI : `.github/workflows/build.yml` teste les deux simulations, compile les deux versions Web et publie Pages sur `main`. Claude lit les journaux via `gh api .../actions/jobs/<id>/logs` ; il ne peut ni ouvrir `*.github.io` depuis le shell (utiliser WebFetch), ni activer Pages, ni créer de dépôt.
- Local (environnement Claude) : npm bloqué. Godot : télécharger `Godot_v4.7.2-stable_linux.x86_64.zip` + modèles d'export depuis les releases GitHub (marche). Phaser : récupérer `phaser@4.2.1` par Git (dépôt phaserjs/phaser, tag v4.2.1, dist/ + types/), bundler avec l'esbuild de `/opt/npm-tools`, tester avec la bibliothèque Playwright de `/opt/npm-tools` (args SwiftShader).
- Règles : branche `claude-b/...` + PR ; simulation séparée du rendu ; aucune dépense ; demander avant toute génération ElevenLabs ; pas de production massive de contenu avant validation du plaisir de jeu.

## Mission Némésis (en cours depuis le 25/11, 11 h)
Ordre de Max : première mission Némésis de très haute qualité, Godot 3D, DA V3.1, autonomie technique, pas de campagne avant validation, dépôt studio jamais public. Journal et décisions : `docs/NEMESIS.md`. Images rangées : PR #25 du studio (63 références, aucun personnage).

## Reprise (fenêtre suivante) — état au 25/11 18 h 45
- Fusionnées par Max à 17 h 49 : #5 (refonte V1 + son), #6 (phase 2). Studio : #27.
- En cours : branche `claude-b/phase2-finitions` (PR à valider, **ne pas fusionner sans Max**) : équilibrage Némésis (65 %), interface (cartes, fiche ennemi, débriefing), profil « allégée » + baisse automatique. Détails : `docs/NEMESIS.md`.
- Planches attendues : `docs/PLANCHES-MANQUANTES.md` (poses des soldats, Carapace, lot 2 des sons).
- Format de réponse demandé par Max : barre 🟩⬜ + % + coût estimé en tokens + temps estimé, à chaque message ; prévenir quand la fenêtre devient trop longue.
- Outils locaux : Godot 4.7.2 à retélécharger dans /home/claude/bin (marche). Tests `tests/run_tests.gd` (42), équilibre `tests/balance.gd -- 80`, coût de rendu `tests/perf.gd -- <qualité>`, captures `tests/shot.gd` (5e argument = qualité), `tests/ui_shot.gd`, `tests/screens_shot.gd`, partie auto `tests/play_smoke.gd`.

## Phase 3 (25/11 20 h 30 → 21 h 30, branche `claude-b/phase3`, PR à valider, ne pas fusionner sans Max)
- Directive de Max : géoscape complet → base Neptune → campagne 3-5 missions reliée à Némésis → modèles GLB remplaçables. Qualité avant vitesse, aucune régression tactique.
- Fait : `sim/strategy/` (moteur de campagne), `view/strategy/` (globe, 4 onglets, décisions), cartes Port et Nid, passage campagne ↔ combat (`view/session.gd`). Journal complet : `docs/PHASE3.md`. Décisions : `docs/DECISIONS.md`.
- Tests : `tests/run_tests.gd` (42), `tests/strategy_tests.gd` (50), campagne robot `tests/campaign_smoke.gd -- 2 [parfait]` (lent, hors CI), captures `tests/strategy_shot.gd -- /tmp/x/`, `tests/campaign_battle_shot.gd -- out.png port|nid|epave`.
- Max fournit les musiques dans la conversation suivante (OGG/MP3 nommés) : les brancher sur le titre, le géoscape, la base, les alertes.
- Phase 3 fusionnée par Max (#9, 25/11 21 h 41). Décors Port/Nid : branche `claude-b/decors-port-nid` (voir `docs/PHASE3.md`). Les sons sont intégrés par une autre conversation : ne pas toucher à `view/audio.gd` ni `assets/audio/` sans demander.
- Suite probable : retours de Max sur téléphone, équilibrage stratégique (pas prioritaire selon Max), musiques, branchement des catégories GLB autres que `units`.

## Modèles 3D Tripo (25/11 20 h, PR #8 incluse dans la phase 3)
- Max a un abonnement Tripo et modélise tout le jeu. Versions allégées (textures 1024 JPEG, `tools/lighten_glb.py`) dans `godot/assets/models/units/` : okafor (s2), lind (s3), nereide, brute. Registre : `view/model_registry.gd`, noms attendus : `docs/MODELES-3D.md`. Animations du modèle entier tant qu'il n'y a pas de squelette. Originaux jamais publiés.
- `armored_soldier` = même maillage qu'Okafor (ancienne texture) : non utilisé. `alien_creature.fbx` : sans texture, espèce inconnue : non utilisé, question posée à Max.
- À demander : versions avec auto-rig + animations Tripo (idle, marche, tir), armes en main ou armes séparées, Walker et Moreau, Carapace, Spectre.
- Aperçus : `tests/model_preview.gd`, `tests/lineup.gd` (inclut la Brute).

## Intégration des modèles 3D de Max (25/11 22 h 30, branche `claude-b/integration-3d`)
- Max envoie ses modèles Tripo par ZIP (8 lots, inventaire dans `docs/MODELES-3D.md` : priorités, noms, budgets, doublons).
- Import : `python3 -I tools/import_lot.py lot.zip [--dry]` (noms reconnus, triangles, version allégée rangée ; originaux jamais publiés). Puis `godot --headless --path godot --import`, captures (`tests/campaign_battle_shot.gd`, `tests/shot.gd`), réglages dans `TUNING` de `view/model_kit.gd`.
- Branchement : `view/model_kit.gd` (kit, couverts, objets, armes), `view/model_unit.gd` (squelette, animations, arme), test `tests/model_kit_test.gd` (CI).
- Décors Port/Nid fusionnés (#11). Ne rien régénérer de payant.

## Lot de modèles du 25/11 22 h 40 (branche `claude-b/modeles-lot2`, cette conversation)
- 18 modèles rangés et branchés, tableau et écartés dans `docs/MODELES-3D.md` (fin). Réduction automatique des triangles : `tools/reduce_glb.py` + `godot/tests/lods.gd`.
- Paroi contaminée ouest de Némésis : clé `hull_x` (`view/main.gd`, `view/model_kit.gd`).
- Tests : 42 + 50 réussis. Coût : Nid 712 k primitives (à surveiller sur téléphone).
- **Push refusé dans cette conversation** (permission) : la branche est seulement locale. Max a demandé une reprise à 1 h 20 (heure de Bangkok) pour continuer et livrer.

## Prochaines étapes probables
1. Suite de `docs/NEMESIS.md` : N1 à N4 faits (N4 = refonte visuelle avec les sprites des planches de Max, interface, performance). Inventaire des ressources : `Game-studio-ai/docs/studio/art/abyss-protocol/ASSET_INVENTORY.md`. Max a autorisé (25/11 15 h 36) la publication des versions allégées de ses créations dans le jeu public, jamais les originaux, zips, planches complètes ni prompts.
2. Mesures d'i/s de Max (haute / moyenne / allégée) ; Évacuer visible même si le soldat sélectionné n'est pas dans le sas (Phaser).
3. Intégrer les références visuelles de ChatGPT/Gemini quand elles seront dans le studio ; vrais modèles via `godot/view/unit_visuals.gd` (`res://assets/units/<kind>.tscn`).
