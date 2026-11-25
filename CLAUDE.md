# ABYSS PROTOCOL — reprise de session (lire en premier)

Projet phare de Maxlol Games (Max, testeur sur téléphone, pas d'ordinateur). Langue : **français**.
Jeu : Godot 4.7.2 + GDScript, 3D isométrique (`godot/`), moteur de compatibilité (WebGL : pas de SSAO, SSR ni brouillard volumétrique). `phaser/` = référence de simulation seulement.
Publié sur https://maxlolfr.github.io/abyss-protocol/ (CI `.github/workflows/build.yml` : tests + Pages sur `main`).

## PRIORITÉ ABSOLUE (ordre de Max, 25/11 18 h 17) : qualité graphique, référence XCOM 2 sous-marin
Répartition : 40 % environnements 3D · 25 % personnages (préparer de vrais modèles 3D animés ; Max les fait sur **Tripo**, ne plus demander de planches de poses) · 20 % lumière, matériaux, ombres, effets · 10 % caméra, animations, mise en scène · 5 % son.
Attendu : décors riches, métaux crédibles, murs et sols en relief, lumière cinématographique, profondeur, bassins convaincants, ambiance industrielle sombre, fin de l'aspect prototype.
**Interdit pour l'instant** : équilibrage, simulations statistiques, optimisations non bloquantes. Sons des lots 1 et 2 déjà produits (ElevenLabs) : vérifier ce qui existe avant toute génération, demander avant de générer.
Livrer des **captures avant/après** pour chaque amélioration majeure. Budget indicatif : 200 à 300 k tokens. **Ne pas fusionner la phase 3 sans Max.**

## État de la phase 3 (branche `claude-b/phase3-visual-overhaul`, 25/11 20 h)
Fait (non encore montré à Max) :
- Parois de coque en relief d'après KIT-001 (`kit.gd` `hull(variant)`) : 0 = panneau et tuyaux, 1 = ventilation et lampe-cage ambre, 2 = grande baie. Vue d'océan animée derrière les baies (`shaders/ocean.gdshader`). Ombre de contact au pied des murs (`ao_edge`).
- Bassins : fosse de 0,7 m, eau animée (`shaders/water.gdshader`), fond à caustiques, margelle à bandes de danger (`pool`, `pit_side`).
- Caniveaux techniques sous caillebotis ajouré, rangée y = 8 et colonne x = 8 de Némésis (`trench`, `main._is_trench`).
- Mezzanines sur ossature (poteaux, entretoises), chaperon sombre sur les murs.
- Environnement (`main._build_env`) : ACES, contraste, halo, ciel de réflexion pour les métaux (`shaders/reflect_sky.gdshader`), contre-jour froid, abysse bleu sous la station (`backdrop`), coupe épaisse de la station avec nervures et conduites (ce n'est plus un « ciel étoilé »), vignettage (`vignette`).
- Textures : acier gris brossé (plus de bleu marine), sol plus calme (`tools/gen_textures.py`).
- Lampe principale tournée à `(-52, -62, 0)` : **pas encore vérifiée en capture**.

À faire, dans l'ordre :
1. Vérifier la capture de la vue par défaut (lumière venant du haut à gauche de l'écran, sol bien lisible), puis faire les **avant/après** (le « avant » se capture depuis un worktree de `main`).
2. Décor : plus d'habillage des planches KIT/PROP (≈ 60 objets découpés dans `assets/props`, 49 utilisés), cloisons intérieures plus riches, plafonnage suggéré, sas.
3. Lumière et effets : lampes-cages réelles sur 2 ou 3 points clés, fumée au sol, reflets humides.
4. Personnages : chargement glTF prêt pour Tripo (`view/unit_visuals.gd` → `res://assets/units/<kind>.glb` ou `.tscn`, squelette et animations nommées idle, walk, aim, fire, hit, death) ; garder les sprites tant qu'il n'y a pas de modèle.
5. Caméra et mise en scène, puis son (lots 1 et 2).
6. Tests (`run_tests.gd`, 42), PR vers `main` avec captures, mise à jour de `docs/NEMESIS.md`.

## Outils (environnement de Claude)
- Godot : `curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`, à décompresser dans /home/claude/bin. Lancer `godot --headless --import --path godot` après chaque changement de texture.
- Capture : `xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 -s res://tests/shot.gd -- sortie.png <yaw> <zoom> <x,y> <qualité>`. Exemples : vue d'ensemble `0 17 8,7 haute`, plan rapproché `0 9 8,9`, angle opposé `2 6 12,4`. Compter environ 2 min par capture ; **jamais deux captures en même temps** (elles partagent la sauvegarde).
- Références : dépôt `maxlolfr/Game-studio-ai` (privé), `docs/studio/art/abyss-protocol/` (inventaire `ASSET_INVENTORY.md`, bible `docs/studio/results/m-0017/ART_BIBLE_HANDOFF_V1.md`). Repères visuels : ENV-007 (salle Némésis), ENV-003, KIT-001 (murs), KIT-003 (sols), KIT-004 (structures). Ne jamais publier les originaux.
- GitHub : API REST seulement (`gh api`), pas GraphQL. Branches `claude-b/...` + PR.
- Format de réponse demandé par Max : barre 🟩⬜ + % + coût estimé en tokens + temps estimé, à chaque message ; prévenir tôt quand la conversation devient longue et proposer d'en ouvrir une nouvelle.
