# ABYSS PROTOCOL — Journal des décisions et architecture

Pour Claude, ChatGPT et Max. Distinguer : **vision** (GDD), **implémenté**, **testé**, **reporté**.

## Architecture (implémentée)

```
games/abyss-protocol/
  docs/            GDD, direction artistique, étude moteurs, ce journal
  src/sim/         SIMULATION PURE (TypeScript, aucun Phaser/DOM/Math.random) — portable vers Godot ou Babylon
    types.ts       état JSON sérialisable, commandes, événements
    data.ts        contenu et équilibrage chiffré (armes, unités, règles UT)
    map.ts         carte du labo (texte, Tiled en phase 4)
    rng.ts         RNG seedée (mulberry32), état dans la sauvegarde
    pathfinding.ts A* + zone atteignable (coûts en UT)
    los.ts         LineOfSight + FogOfWar
    cover.ts       CoverSystem (directionnel, à genoux)
    combat.ts      CombatResolver (toucher, dégâts, blessures, grenade, tirs de réaction)
    actions.ts     ActionPointSystem + exécution des actions
    ai.ts          EnemyAI à règles et à score (flanc / pression / harcèlement)
    turn.ts        TurnManager
    engine.ts      TacticalEngine : commandes → événements, aperçus (coût, chance, couvert, UT restantes)
    save.ts        SaveManager versionné + migrations
  src/game/        RENDU Phaser 4.2.1 (lit l'état, rejoue les événements) + AudioManager
  tests/           Vitest
(dépôt abyss-protocol : ce projet est dans phaser/ ; le prototype 3D est dans godot/, voir docs/PROTOTYPE-GODOT.md)
```

Principe : le rendu n'écrit jamais dans l'état ; il envoie des `Command` et rejoue les `GameEvent`. Même seed + mêmes commandes = même partie (testé). Les modules campagne (CampaignEngine, Geoscape, BaseManagement, ResearchSystem, Manufacturing, Inventory persistant) sont **reportés** à la phase 2 et suivront le même principe : un dossier `src/sim/<système>` pur et testé, plus un rendu séparé.

## Décisions

| Date | Décision | Statut |
|---|---|---|
| 25/11 | Code dans `Game-studio-ai/games/abyss-protocol` sur une branche ; dépôt public dédié à créer par Max pour GitHub Pages | Implémenté |
| 25/11 | Audit TACTIKA (lecture seule) : 534 lignes, PA/PM façon Dofus, canvas maison. Rien de repris tel quel ; idées reprises : règles pures qui émettent des événements, RNG mulberry32, déblocage audio iOS | Fait |
| 25/11 | Coûts UT du GDD : 6 par case (8 en diagonale, +4 dans l'eau), tir rapide 12, précis 24, recharge 8, surveillance 18, genou 4 (variantes par arme) | Implémenté, testé |
| 25/11 | Tirs de réaction façon X-COM (réactions × UT restantes / UT max) + **surveillance** : réaction garantie, premier tir gratuit | Implémenté, testé |
| 25/11 | Le déplacement s'arrête quand un nouvel ennemi apparaît (le joueur garde ses UT) | Implémenté |
| 25/11 | Objectif principal = **extraction** de l'artefact par le sas (prendre l'artefact alerte tous les aliens) ; neutraliser tous les aliens = victoire aussi ; évacuer sans l'artefact = retraite. Secondaire = journal du terminal | Implémenté, testé |
| 25/11 | Aliens du GDD : Néréide (amphibie, flanc), Carapace (blindage, pression), Spectre (onde psychique : ignore le couvert, retire 20 UT au prochain tour) | Implémenté |
| 25/11 | Alerte locale : un alien ne converge que vers un bruit proche (≤ 11 cases), sauf après la pulsation de l'artefact. Évite la ruée générale dès le premier tir | Implémenté |
| 25/11 | Décor destructible minimal : la grenade pulvérise les obstacles bas au contact (couvert perdu) | Implémenté, testé |
| 25/11 | Moteur de rendu : Phaser 3.90 abandonné au profit de **Phaser 4.2.1** (lumières `setLighting`, normal maps, filtres caméra) | Spike fait |
| 25/11 | Étude moteurs : recommandation de Claude Phaser 4.2.1 (combat) + Babylon.js 9 (globe), Godot 4.7.2 en plan B | Remplacée ci-dessous |
| 25/11 | **Max privilégie Godot + GDScript en vraie 3D** (qualité et ambition à long terme), sous réserve de validation technique ; le prototype TypeScript est conservé comme référence | Décision de Max |
| 25/11 | Dépôt public dédié `maxlolfr/abyss-protocol` (Game-studio-ai reste privé) ; les deux prototypes y sont publiés côte à côte sur GitHub Pages | Implémenté |
| 25/11 | Prototype Godot 4.7.2 : simulation GDScript sans nœuds (`godot/sim`), 2 niveaux, tir plongeant, cloisons destructibles (harpon « Brèche », grenade), caméra orthographique rotative, ombres dynamiques désactivables | Implémenté, 22 tests |
| 25/11 | Choix définitif du moteur après essai des deux prototypes | Remplacée ci-dessous |
| 25/11 | **MOTEUR DÉFINITIF : Godot 4.7 + GDScript, vraie 3D isométrique** (décision ferme de Max, 10 h 55). Le prototype Phaser reste dans `phaser/` comme référence fonctionnelle de la simulation (règles et tests), sans nouveau développement de rendu | **Validé par Max** |

## Équilibrage (mesuré par simulation IA contre IA, 40 parties)
Escouade pilotée par une IA simple (sans genou, surveillance, grenade ni soin) : 47,5 % de victoires, 2,8 soldats perdus en moyenne, 11 tours. Un joueur humain devrait faire mieux. À réévaluer après les tests de Max.

## Tests exécutés (25/11/2026)
- 28 tests de simulation (RNG, carte, A*, UT, LOS, brouillard, couverture, chance de toucher, réaction, objectifs, victoire/défaite, décor destructible, déterminisme, sauvegarde/reprise, IA contre IA, séparation de l'architecture) : **28/28** passent (Node 22, shim Vitest local ; le vrai Vitest tourne en CI).
- Vérification des types TypeScript strict : OK.
- Spikes Phaser et Godot ouverts dans Chromium : 0 erreur console.
- **Pas encore testé** : interface tactile complète, appareils réels, build Vite en CI.

## Phase 3 — campagne (25/11/2026, directive de Max 20 h 30)
- **Géoscape dans Godot** (pas de Babylon.js) : un seul moteur, un seul export Web. Globe stylisé généré (`tools/gen_globe.py`, contours tracés à la main) en attendant mieux.
- **Moteur de campagne pur** (`sim/strategy/`), même principe que le combat : commandes → événements, graine, sauvegarde versionnée (`user://abyss_campaign.json`).
- **Une base** (Neptune, Açores) pour ce prototype ; extension mondiale reportée. Le Triton a une autonomie océanique (240 h).
- **Interceptions à règles lisibles** (torpille puis riposte, 8 passes), chances affichées avant d'engager.
- **Campagne récupérable** : sans l'artefact de Némésis, une cargaison alien en fournit un autre ; le Nid reste en place après un assaut repoussé ; un mois calme rend de la confiance.
- **Écran d'entrée** = géoscape (`view/strategy/strategy.tscn`) ; « Mission Némésis seule » reste accessible, et les adresses `?map=` / `?autoplay` ouvrent toujours le combat direct.
- **Modèles 3D** : registre `assets/models/<catégorie>/<nom>.glb` (voir `docs/MODELES-3D.md`).
