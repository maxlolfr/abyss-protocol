# ABYSS PROTOCOL — Étude comparative des moteurs (25/11/2026)

Auteur : Claude (lead dev). Objet : choisir le moteur **avant** de figer le prototype de la phase 1.
Statut : **recommandation en attente de validation par Max.** Rien n'est payé, rien n'est souscrit.

## 1. Méthode : des essais réels, pas seulement de la théorie

| Vérification | Résultat |
|---|---|
| Télécharger Godot 4.7.2 officiel depuis GitHub et le lancer dans l'environnement cloud de Claude | ✅ `4.7.2.stable.official.ed1daf0bf`, en mode sans écran |
| Modèles d'export Godot (1,28 Go) | ✅ téléchargés, export Web réussi |
| Spike Godot : même carte du labo, murs en relief, 4 lumières avec **ombres portées** (LightOccluder2D) | ✅ `spikes/godot/`, export Web, lancé dans Chromium |
| Spike Phaser 4.2.1 : même carte, normal maps procédurales, lumières dynamiques, brouillard, unités | ✅ lancé dans Chromium |
| Lecture des résultats et des journaux GitHub Actions du dépôt | ✅ (statut des étapes + logs lisibles) |
| Installer des paquets npm (Phaser AE, Vite, Vitest…) depuis l'environnement de Claude | ❌ npm est bloqué sur ce compte ; Phaser a été récupéré via Git. **GitHub Actions, lui, installe normalement.** |
| SDK Android dans l'environnement de Claude | ❌ absent (Java présent) ; les runners GitHub Actions l'ont |

Capture côte à côte (même navigateur, 844×390 paysage) : `docs/etude/spikes-phaser-vs-godot.png`.

### Mesures (Chromium sans GPU, rendu logiciel — **indicatif seulement**)

| | Phaser 4.2.1 | Godot 4.7.2 (Web, sans threads) |
|---|---|---|
| Poids à télécharger (gzip) | **0,38 Mo** (moteur + jeu) | **10,1 Mo** (wasm 39 Mo brut) |
| Images/s en rendu logiciel | 34 | 8 |
| Erreurs console | 0 | 0 |

Ces images/s ne représentent pas un téléphone (le Honor Magic V5, l'iPhone 15 Pro Max et l'iPad ont un vrai GPU : les deux moteurs devraient y tenir 60 i/s sur cette carte). Elles montrent en revanche que **la version Web de Godot est bien plus lourde** (moteur complet en WebAssembly).
Le test réel sur les trois appareils reste à faire par Max : un compteur d'i/s est prévu dans le menu du prototype.

## 2. Comparatif

Note sur 5 pour ABYSS PROTOCOL (5 = idéal).

| Critère | Phaser 4.2.1 | Phaser AE | Godot 4.7.2 | Babylon.js 9 | Three.js r187 |
|---|---|---|---|---|---|
| 2.5D iso avec assets 2D pré-rendus (choix du GDD) | **5** | 4 | 4 | 2 (fait pour la 3D) | 2 |
| Vraie 3D (étages, caméra libre) | 1 | 1 | **5** | **5** | 4 |
| Lumières dynamiques | 4 (lumières + normal maps + auto-ombrage) | 4 | **5** | **5** (lumières groupées, volumétrique) | 4 |
| Ombres portées par les murs | 2 (à simuler : décalques pré-rendus) | 2 | **5** (occluders 2D ou ombres 3D) | **5** | 4 |
| Décors destructibles | 4 en 2.5D (déjà fait : grenade) | 4 | **5** | 5 | 4 |
| Plusieurs niveaux de hauteur | 3 (tri de profondeur + décalage z) | 3 | **5** | 5 | 4 |
| Brouillard + lignes de vue | 5 (logique dans la simulation, indépendante du moteur) | 5 | 5 | 5 | 5 |
| Globe terrestre interactif | 2 (2D projetée) | 2 | 4 | **5** (géospatial, atmosphère physique) | 4 |
| Base modulaire (grille de salles) | 5 | 5 | 5 | 4 | 4 |
| Poids et démarrage sur téléphone (lien Web) | **5** | 4 | 2 (10 Mo, iOS Safari plus fragile) | 3 | 4 |
| Applications Android / iOS | 4 (Capacitor) | 4 | **5** (export natif) | 4 (Capacitor) | 4 |
| Compilation cloud + GitHub Pages | **5** | 3 (CLI locale + compte phaser.io) | 4 (export headless OK, Web sans threads) | 5 | 5 |
| Garde la simulation TypeScript déjà écrite et testée | **5** | 5 | 1 (réécriture en GDScript ; **C# ne s'exporte pas encore sur le Web**) | **5** | **5** |
| Production d'assets par l'équipe (ChatGPT/Gemini font des images 2D) | **5** | 4 | 3 | 2 (modèles 3D nécessaires) | 2 |
| Gratuit / open source | ✅ MIT | ⚠️ licence Polyform Shield, crédits pour les designs, pack Pro payant | ✅ MIT | ✅ Apache 2.0 | ✅ MIT |

### Phaser AE (`@phaser-ae/cli`)
Outil de phaser.io qui relie leur éditeur de conception à Claude Code : skill, fiche `CLAUDE.md`, CLI `setup` / `doctor`. Il demande une installation sur un ordinateur (Node 20), un compte phaser.io, et des **crédits** au-delà du premier design (163 packs d'extension gratuits, 195 réservés à l'offre Pro). Le moteur AE est sous licence Polyform Shield, pas une licence open source.
**Verdict** : pas nécessaire. Le moteur Phaser lui-même est MIT, et les **skills officiels Phaser 4** (livrés dans le dépôt Phaser : lumières, filtres, migration v3→v4…) sont déjà utilisés par Claude. Phaser AE impose un poste local, ce qui va contre la contrainte « pas de logiciel local ».

## 3. Réponses aux 8 questions de Max

1. **Godot dans l'environnement ?** Oui : Claude a téléchargé Godot 4.7.2 officiel et l'a exécuté. L'environnement est éphémère : Godot est re-téléchargé à chaque session (≈ 80 Mo, + 1,3 Go si besoin d'exporter), ou c'est GitHub Actions qui s'en charge.
2. **MCP ou skill Godot ?** Aucun installé. Le catalogue public contient des skills communautaires (patterns GDScript, architecture Godot 4.7, pipeline d'export), non officiels et non installés. Aucun MCP Godot trouvé dans le registre des connecteurs.
3. **Installer et exécuter Godot soi-même ?** Oui, sans écran : lancer des scènes, exécuter des scripts, exporter. Pas d'éditeur visuel : Claude écrit les scènes `.tscn` en texte.
4. **Programmer, compiler, tester et corriger un jeu Godot sans toi ?** Oui pour la version Web, démontré par le spike : code GDScript → export → test dans Chromium → capture → correction. Limites : pas de GPU, donc pas de vraie mesure de performance ; tests unitaires possibles via un addon (GUT ou gdUnit, récupérables par Git).
5. **Compilations Android et Web automatiques avec GitHub Actions ?** Oui pour le Web (même commande que le spike). Android : faisable sur les runners GitHub (SDK Android présent) ; la signature Play Store demande ta clé en secret GitHub. Claude lit les journaux des builds, mais ne peut pas télécharger les artefacts via son proxy : l'APK se récupère depuis la page GitHub (Release ou artefact), sur ton téléphone.
6. **Version jouable depuis ton téléphone ?** Oui : lien Web (GitHub Pages sur un dépôt public, ou Netlify, connecté ici). Avec Phaser, aussi en aperçu Claude privé instantané. Le wasm Godot (39 Mo) dépasse la limite de 32 Mo par fichier de ces aperçus, donc pour Godot ce sera Pages ou Netlify uniquement.
7. **Skills et MCP jeux vidéo disponibles** :
   - Skills : `html5-game-dev`, `game-balance-lab`, `sprite-animation-pipeline`, `chatgpt-game-asset-prompts`, `agence-game-designer`, `agence-audio-jeux`, `agence-narrative-designer`, `agence-reality-checker`, `agence-sortie-store` (Capacitor, TestFlight), `agence-marketing-jeux`, `crazygames-regles`, `code-minimal`, `delegation-agents-jeux`, les fiches de tes jeux ; **une quarantaine de skills Unity** (`unity:*`, `unity-perf:*`) ; Icons8 et skills design/UX.
   - MCP : **ElevenLabs** (sons, musiques, voix, images, vidéo), **Three.js 3D Viewer**, **3dCMS** (scènes 3D), **Netlify** (déploiement), **HyperFrames** (vidéo), artefacts Claude (hébergement d'aperçus), Chrome (navigateur). Playwright est présent en bibliothèque pour les tests.
   - Pas de skill ni de MCP Godot ou Babylon. Skills officiels Phaser 4 récupérés depuis le dépôt Phaser.
8. **Recommandation** : voir ci-dessous.

## 4. Recommandation

**Phaser 4.2.1 + TypeScript + Vite pour le combat tactique (phase 1 et suite), avec Babylon.js 9 en module séparé pour le globe du géoscape (phase 2). Godot reste le plan B documenté.**

Pourquoi :
1. **C'est exactement la direction artistique demandée** : 2.5D isométrique avec des assets 2D pré-rendus. Le studio produit des images 2D (ChatGPT, Gemini), pas des modèles 3D. Phaser 4 sait éclairer ces images (normal maps, lumières dynamiques, auto-ombrage) : le spike le montre déjà.
2. **Le cœur du jeu est déjà écrit et testé** : la simulation TypeScript (28 tests). Phaser et Babylon la gardent telle quelle. Godot imposerait de la réécrire en GDScript, car C# ne s'exporte pas encore sur le Web.
3. **Le test sur téléphone est immédiat** : 0,38 Mo contre 10 Mo, aperçu privé instantané, GitHub Pages, puis Capacitor pour les stores. Ça compte, puisque Max teste tout depuis son téléphone.
4. **Le globe mérite un vrai moteur 3D** : Babylon.js 9 (géospatial, atmosphère physique) en TypeScript, dans la même chaîne Vite/Vitest/Playwright. On le charge seulement sur l'écran Monde (chargement progressif).
5. **Risque principal, assumé** : les ombres portées des murs. Phaser n'a pas d'occluders 2D comme Godot ; on les simulera par des ombres pré-rendues dans les assets et par l'assombrissement du brouillard. Si Max veut de vrais étages 3D ou une destruction volumétrique, ce sera le signal de bascule vers Godot (ou Babylon pour le combat).

**Porte de décision** : à la fin de la phase 1, Max teste sur le Honor Magic V5, l'iPhone 15 Pro Max et l'iPad. Si le rendu Phaser ne paraît pas assez « premium », on bascule le combat sur Godot 4.7 (3D orthographique, vraies ombres). Les tests de la simulation servent alors de cahier des charges pour la réécriture.
