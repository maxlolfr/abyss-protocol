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
  tests/           Vitest (local : shim node:test)
  spikes/godot/    spike Godot 4.7.2 de l'étude moteurs
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
| 25/11 | Étude moteurs : recommandation Phaser 4.2.1 (combat) + Babylon.js 9 (globe), Godot 4.7.2 en plan B | **En attente de Max** |

## Équilibrage (mesuré par simulation IA contre IA, 40 parties)
Escouade pilotée par une IA simple (sans genou, surveillance, grenade ni soin) : 47,5 % de victoires, 2,8 soldats perdus en moyenne, 11 tours. Un joueur humain devrait faire mieux. À réévaluer après les tests de Max.

## Tests exécutés (25/11/2026)
- 28 tests de simulation (RNG, carte, A*, UT, LOS, brouillard, couverture, chance de toucher, réaction, objectifs, victoire/défaite, décor destructible, déterminisme, sauvegarde/reprise, IA contre IA, séparation de l'architecture) : **28/28** passent (Node 22, shim Vitest local ; le vrai Vitest tourne en CI).
- Vérification des types TypeScript strict : OK.
- Spikes Phaser et Godot ouverts dans Chromium : 0 erreur console.
- **Pas encore testé** : interface tactile complète, appareils réels, build Vite en CI.
