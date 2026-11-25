# ABYSS PROTOCOL — Maxlol Games

Jeu de stratégie mondiale, de gestion de bases et de tactique au tour par tour, dans un univers sous-marin original.
Phase 1 : **deux prototypes jouables** pour choisir le moteur.

▶ **Jouer (téléphone en paysage)** : https://maxlolfr.github.io/abyss-protocol/

| Dossier | Contenu |
|---|---|
| `godot/` | Prototype **Godot 4.7.2 + GDScript, vraie 3D** isométrique : caméra rotative, 2 niveaux, ombres dynamiques, cloisons destructibles, tour par tour, interface tactile. Simulation dans `godot/sim/` (sans rendu), tests dans `godot/tests/`. |
| `phaser/` | Prototype **Phaser 4.2.1 + TypeScript**, 2.5D : **référence fonctionnelle** de la simulation (`phaser/src/sim/`, 28 tests Vitest), mission complète, sauvegarde. |
| `docs/` | Vision (`MASTER_GDD.md`, `ART_DIRECTION.md`, `CLAUDE_START.md`), étude des moteurs, décisions, comparaison des prototypes. |
| `concepts/` | Maquettes originales à venir. |

Aucun logiciel local requis : à chaque modification, GitHub Actions teste les deux simulations, compile les deux versions Web et les publie sur GitHub Pages (`.github/workflows/build.yml`).

Collaboration : Claude (code, tests, déploiement), ChatGPT (direction artistique, game design, relecture), Max (validation). Les décisions sont tenues dans `docs/DECISIONS.md`.
