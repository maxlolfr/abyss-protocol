# Audio — master V03 (lots 01 à 03) intégré dans Godot

Source : `ABYSS_PROTOCOL_AUDIO_MASTER_V03.zip` de Max (25/11/2026). 80 fichiers : 9 musiques, 5 ambiances, 18 voix, 48 bruitages.
Code : `godot/view/audio.gd` (seul fichier de logique sonore). Contrôle : `godot --headless --path godot -s res://tests/audio_tests.gd`.

## Fichiers
- Musiques et ambiances : OGG d'origine copiés tels quels dans `assets/audio/music/` et `assets/audio/ambience/`.
- Bruitages et voix : WAV convertis en OGG Vorbis mono 48 kHz (96 kb/s bruitages, 80 kb/s voix), comme le lot 01 déjà en place. Les 12 bruitages du lot 01 déjà dans le jeu ne sont pas retouchés.
- Pas : niveaux égalisés dans chaque banque (le README ne le faisait pas : `step_metal_02` était 17 dB sous les autres). Correction : béton 01 +0,5, 02 −8 ; métal 02 +16,7, 03 −1, 04 −2,6 ; eau 01 +1,3, 02 −0,1, 03 −5,7 dB. Le béton reste plus doux : +9 dB à la lecture.

## Bus
Music −7, Ambience −11, SFX −2, UI −6, Voice −4, Radio −3 dB. Radio : passe-haut 300 Hz, passe-bas 3 kHz, compresseur (−18 dB, 3:1). La musique baisse de 4 dB pendant un message radio.

## Où sonne quoi
| Écran / événement | Son |
|---|---|
| Titre | mus_01 |
| Géoscape, base | mus_04 ; clic de bouton ui_confirm ; erreur ui_error ; contact/site sonar ; interception ou assaut alarm_intruder ; résultat d'interception harpoon_fire ; recherche terminal_access ; salle generator_start ; fabrication crate_open ; fin de campagne mus_07 |
| Carte Némésis | amb_01, exploration mus_02, pas métal |
| Carte Épave (`lab`) | amb_04, exploration mus_05, pas métal |
| Carte Port | amb_02, exploration mus_02, pas béton |
| Carte Nid | amb_05, exploration mus_05, pas eau ; première Carapace ou Spectre repéré : boss_arrival + mus_08 |
| Début de mission | radio_mission_start (+ radio_artifact sur Némésis et le Nid) |
| Premier contact | radio_contact ; soldat « Contact! » ; Carapace : carapace_alert |
| Tour 2 sans contact | radio_move |
| Tir raté (fusil, pistolet) | bullet_ricochet ; touche sur Carapace : carapace_hit |
| Dernière munition | empty_weapon (chargeur vide) + « Running low on ammo! » |
| Blessure / mort d'un soldat | « I'm hit! » / « Man down! Medic! » |
| Dernier soldat debout | mus_09 + radio_abort |
| Première cloison détruite | hull_breach + alarm_pressure + radio_pressure ; chaque cloison : cover_break |
| Soin / rechargement | medkit / reload_rifle ou reload_harpoon |
| Accroupi, en guet | gear_rustle (+ « Copy that. » au guet) |
| Artefact ramassé | objective_complete + radio_objective |
| Alarme de l'artefact | alarm_intruder + mus_06 + radio_extract |
| Porteur de l'artefact dans le sas | radio_extraction_ready |
| Renforts | radio_reinforcements |
| Terminal | terminal_hack + terminal_access + radio_terminal |
| Fin du tour du joueur | ui_turn_end |
| Fin de mission | radio_mission_success ou radio_abort, puis mus_07 une fois |
| Déplacement Néréide / Spectre | nereid_move / spectre_move |

Règles : messages radio en file triée par priorité (pression, abandon, extraction en tête), une fois par mission chacun, grésillement avant le message. Répliques de soldats espacées (pas de chevauchement). Pas : jamais deux fois la même variante de suite pour une unité. Une musique plus calme n'écrase pas un état plus tendu (exploration < combat < extraction < boss < dernier carré).

## Boucles
- Bouclées par Godot (raccord intégré) : mus_01 à 03, amb_01.
- Relancées en fondu enchaîné de 2 s (raccord non validé à l'écoute) : mus_04, 05, 06, 08, 09 et amb_02 à 05. Si Max valide un raccord, passer la piste dans `SEAMLESS` et mettre `loop=true` dans son `.import`.
- mus_07 : une seule fois.

## Non utilisés pour l'instant
amb_03_reactor_room, door_locked, glass_break, elevator_start, elevator_stop (pas encore d'événement de jeu qui leur corresponde).

## À vérifier par Max sur téléphone
Niveaux relatifs (voix contre musique), intelligibilité de la radio, premier démarrage du son sur iOS et Android.
