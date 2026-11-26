# ABYSS PROTOCOL — reprise (lire en premier, rien d'autre sans besoin)

Max teste sur téléphone, pas d'ordinateur. Français. Économiser les tokens : réponses courtes, ne relire que les fichiers utiles.

- **Décision du 26/11 (7 h 52)** : Phaser seulement ; Godot (`godot/`) gelé, ne pas y toucher. Claude décide de la technique ; ChatGPT/Gemini ne font que les images, d'après `Game-studio-ai/docs/studio/art/abyss-protocol/CHARTE_PRODUCTION_IMAGES.md` (§0 méthode, §8 inventaire, §9 images demandées).
- **Objectif unique** : la salle Némésis jouable (`phaser/nemesis.html`), 2 soldats (Walker, Okafor) contre 3 aliens (Carapace = grosse bête, Néréide, Spectre). Style figurines : 1-2 poses par personnage, mouvements en code. Aucune nouvelle fonction avant le retour de Max.
- **Code** : simulation `phaser/src/sim/` (ne pas réécrire), scène `phaser/src/nemesis/NemesisScene.ts`, HUD `phaser/src/game/hud.ts`.
- **Images** : `python3 -I tools/batch_images.py <dossier valide du studio>` détoure, corrige la pente (36° → 2:1), met à l'échelle et écrit `phaser/public/nemesis/{walls,units}` + `walls/anchors.json`. Ancien lot : `tools/build_phaser_nemesis.py`.
- **Local sans npm** : Phaser 4.2.1 par `git clone --depth 1 --branch v4.2.1 --filter=blob:none --sparse https://github.com/phaserjs/phaser` (`sparse-checkout set dist types`), lien vers `phaser/node_modules/phaser` ; `tsc`, `esbuild`, `playwright` dans `/opt/npm-tools`, Chromium dans `/opt/pw-browsers` (SwiftShader). Vitest tourne en CI seulement.
- **Publication** : la CI (`.github/workflows/build.yml`) publie GitHub Pages depuis `main` : https://maxlolfr.github.io/abyss-protocol/phaser/nemesis.html
- Règles : branche `claude-b/...` + PR ; aucune dépense ; demander avant ElevenLabs. Historique détaillé : `docs/` (à n'ouvrir qu'en cas de besoin).
