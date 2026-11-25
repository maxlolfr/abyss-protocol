# ABYSS PROTOCOL — ABYSSAL RESONANCE
25/11/2026 — ChatGPT, direction sonore. Statut : proposition en attente de validation Max. Aucun audio généré. Godot 4.7 confirmé dans DECISIONS.md.
## Identité
Science-fiction militaire abyssale, industrielle et organique. Motif original ré–mib–la (registre grave, intervalles espacés), sonar filtré, métal résonant, drones, percussions sèches. Pas de paroles, d'imitation ni de référence à un artiste. Silence et dynamique avant spectacle.
## Lot 1 proposé
Une génération par fichier. Prompts anglais. Budget indicatif 900 crédits/min musique, 200/SFX, total 5300, plafond proposé 6000. Solde et prix effectifs à confirmer avant exécution.
| ID / nom final | Durée s | Prompt |
|---|---:|---|
| mus_01_abyss_protocol.ogg | 60 | Original instrumental dark underwater military sci-fi main theme, sparse D Eb A sonar motif, deep analog drones, restrained bowed metal, cinematic but intimate, stable loop-compatible opening and ending, no vocals or final cadence |
| mus_02_silent_depths.ogg | 60 | Minimal instrumental abyssal laboratory exploration, slow suspended D-centered harmony, distant three-note sonar motif, subtle cold synth textures, soft pulse, no climax, matching start and end |
| mus_03_contact_hostile.ogg | 60 | Instrumental tactical combat tension, restrained industrial percussion, steady 96 BPM, unsettling D Eb A motif, no heroic fanfare, stable intensity, loop-compatible ending |
| amb_01_lab_pressure.ogg | 30 | Seamless submarine lab room tone, low ventilation, distant pressure creaks, subtle water resonance, no voices or sudden impacts |
| sfx_sonar_signature.wav | 3 | Three distinct sonar tones D Eb A with metallic underwater resonance, isolated |
| sfx_rifle_fire.wav | 1 | Single compact futuristic military rifle discharge, dry transient, enclosed metallic room |
| sfx_harpoon_fire.wav | 2 | Heavy fictional pneumatic harpoon launch, mechanical clack and compressed thump |
| sfx_alien_plasma.wav | 1 | Single alien energy discharge, organic electric snap |
| sfx_armor_impact.wav | 1 | Short hard impact on futuristic armor, dry metal |
| sfx_grenade_blast.wav | 3 | Single fictional grenade explosion in industrial compartment, short decay |
| sfx_step_metal.wav | 0.7 | One armored boot step on steel grating |
| sfx_airlock.wav | 3 | Heavy hydraulic airlock opening, seals releasing, metal slide |
| sfx_nereid_alert.wav | 2 | Amphibious alien warning hiss, wet organic clicks, no words |
| sfx_spectre_psionic.wav | 3 | Unnatural psychic wave, shimmering dissonant reversed texture |
| sfx_artifact_pulse.wav | 4 | Ancient alien device awakens, three ominous resonant pulses |
| sfx_ui_confirm.wav | 0.5 | Short clean cyan-sonar-inspired tactical confirmation beep |
## Godot integration (proposed; Claude owns code)
Path godot/assets/audio/{music,ambience,sfx}; runtime res://assets/audio/. Ogg Vorbis stereo music and ambience, WAV PCM mono positional effects where feasible, 44.1 or 48 kHz. Master originals preserved privately. Validate loops by listening to three consecutive repetitions, trim/crossfade offline if necessary, enable import loop for Ogg. Match loudness, avoid clipping. Separate Master/Music/Ambience/SFX/UI/Voice buses. Two AudioStreamPlayer music channels for 1–2s transitions; AudioStreamPlayer3D for visible or legitimately audible events; UI nonpositional. Never reveal hidden enemy coordinates through spatial audio. React to actual simulation events, not previews; no audio mutation of simulation. Deduplicate turn events; manage voice count and step pitch variations. Web/mobile audio unlock on first interaction; test iOS, Android, mute, resume, loops. Artifact pickup triggers pulse and combat state. No new gameplay scope.
## QA and rights
Check subscription, model-specific terms and indie-game eligibility before release: https://elevenlabs.io/music-terms ; pricing https://elevenlabs.io/pricing . Do not publish standalone music library; keep originals and license records private. Record model, prompt, date, generation ID, actual credits, filename, approval and license. No signed download URLs in public GitHub. No commercial clearance claimed yet. Generate only after Max validates lot and cost; verify actual charge after first sample. No code changes in this commit.
