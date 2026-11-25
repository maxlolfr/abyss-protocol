# ABYSS PROTOCOL — reprise de session (lire en premier)

Projet phare de Maxlol Games (Max, testeur sur téléphone, pas d'ordinateur). Langue : **français**.
Vision : `docs/MASTER_GDD.md`, `docs/ART_DIRECTION.md`, `docs/CLAUDE_START.md`. Décisions : `docs/DECISIONS.md`. Bible artistique de ChatGPT (privée) : `Game-studio-ai/docs/studio/results/m-0017/ART_BIBLE_HANDOFF_V1.md`, mission ChatGPT dans les commentaires de la PR #24 du studio.

## État au 25/11/2026, 11 h (Bangkok)
- **Phase 1** (prototype tactique) : deux prototypes jouables, publiés sur https://maxlolfr.github.io/abyss-protocol/ (GitHub Pages, source « GitHub Actions », activée par Max).
  - `godot/` : Godot 4.7.2 + GDScript, vraie 3D isométrique (choix préféré de Max, non définitif). 31 tests (`godot --headless --path godot -s res://tests/run_tests.gd`). Détails : `docs/PROTOTYPE-GODOT.md`.
  - `phaser/` : Phaser 4.2.1 + TypeScript, 2.5D, **référence fonctionnelle** de la simulation (28 tests Vitest + test Playwright).
- PR #1 (`claude-b/vertical-slice` : labo Godot, parité gameplay, effets, HUD compacts) : CI verte, **fusion en attente de l'accord de Max**.
- Choix définitif du moteur : après les tests de Max sur iPhone 15 Pro Max, Honor Magic V5, iPad (i/s ombres on/off). **Ne pas lancer la phase 2 sans validation.**

## Comment travailler ici
- CI : `.github/workflows/build.yml` teste les deux simulations, compile les deux versions Web et publie Pages sur `main`. Claude lit les journaux via `gh api .../actions/jobs/<id>/logs` ; il ne peut ni ouvrir `*.github.io` depuis le shell (utiliser WebFetch), ni activer Pages, ni créer de dépôt.
- Local (environnement Claude) : npm bloqué. Godot : télécharger `Godot_v4.7.2-stable_linux.x86_64.zip` + modèles d'export depuis les releases GitHub (marche). Phaser : récupérer `phaser@4.2.1` par Git (dépôt phaserjs/phaser, tag v4.2.1, dist/ + types/), bundler avec l'esbuild de `/opt/npm-tools`, tester avec la bibliothèque Playwright de `/opt/npm-tools` (args SwiftShader).
- Règles : branche `claude-b/...` + PR ; simulation séparée du rendu ; aucune dépense ; demander avant toute génération ElevenLabs ; pas de production massive de contenu avant validation du plaisir de jeu.

## Prochaines étapes probables
1. Fusion de la PR #1, puis retours de Max sur appareils.
2. Équilibrage Godot (l'escouade gagne trop en IA contre IA), Évacuer visible même si le soldat sélectionné n'est pas dans le sas (Phaser).
3. Intégrer les références visuelles de ChatGPT/Gemini quand elles seront dans le studio ; vrais modèles via `godot/view/unit_visuals.gd` (`res://assets/units/<kind>.tscn`).
