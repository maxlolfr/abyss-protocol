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

## Prochaines étapes probables
1. Suite de `docs/NEMESIS.md` : N1 à N3 faits (PR #3) ; attendre les retours de Max sur téléphone, puis N4 (performance, équilibrage, destruction des props, Carapace).
2. Équilibrage Godot (l'escouade gagne trop en IA contre IA), Évacuer visible même si le soldat sélectionné n'est pas dans le sas (Phaser).
3. Intégrer les références visuelles de ChatGPT/Gemini quand elles seront dans le studio ; vrais modèles via `godot/view/unit_visuals.gd` (`res://assets/units/<kind>.tscn`).
