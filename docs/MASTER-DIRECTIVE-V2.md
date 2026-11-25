MAXLOL GAMES — ABYSS PROTOCOL

MASTER PRODUCTION DIRECTIVE — GODOT 3D & PHASER 4

Date : 26 novembre 2026
Projet : ABYSS PROTOCOL
Dépôt : abyss-protocol
Branche de référence : claude-b/reorientation
Document précédent : docs/REORIENTATION-2026-11-26.md

Tu reprends la responsabilité technique du développement d’ABYSS PROTOCOL.

Tu dois désormais agir comme un développeur senior de jeux vidéo, un architecte logiciel, un technical artist et un responsable de l’optimisation des coûts de production.

Lis le document de réorientation existant (docs/REORIENTATION-2026-11-26.md), mais considère les instructions suivantes comme prioritaires en cas de contradiction.

1. AMBITION COMMERCIALE

ABYSS PROTOCOL est un jeu tactique premium de science-fiction et d’horreur sous-marine, inspiré des grandes références du genre tactique, notamment XCOM et Terror from the Deep, tout en possédant son propre univers, ses personnages et sa direction artistique.

Nous ne voulons pas créer un petit prototype Web amateur.

Nous voulons un véritable jeu indépendant commercialisable, doté d’une identité forte, d’une excellente présentation graphique et d’une profondeur stratégique importante.

Les dernières versions Godot sont fonctionnelles, mais visuellement très en dessous de nos attentes.

Nous ne validons pas leur qualité artistique actuelle.

2. NOUVELLE STRATÉGIE MULTIPLATEFORME

Nous validons deux versions complémentaires :

ABYSS PROTOCOL 3D

* Godot.
* PC en priorité.
* Steam à terme.
* iPad, sous réserve de validation des performances et des possibilités de compilation native.
* Véritable rendu 3D.
* Animations squelettiques.
* Caméra dynamique.
* Éclairage avancé.
* Options graphiques adaptées au matériel.

ABYSS PROTOCOL MOBILE

* Phaser 4.2.1 minimum, ou version stable officielle supérieure si disponible.
* TypeScript.
* Vite.
* WebGL.
* iPhone.
* Android.
* Navigateurs.
* Rendu isométrique 2.5D premium.
* Priorité à la beauté graphique, la lisibilité et la fluidité.

Ne pas utiliser Phaser 3 par habitude.

Consulte impérativement :

https://github.com/phaserjs/phaser

https://docs.phaser.io

https://phaser.io/download/archive

Examine les fichiers skills officiels du dépôt Phaser 4 destinés aux agents IA.

Utilise les API réellement disponibles dans Phaser 4 et non des API obsolètes issues de Phaser 3.

Évalue les fonctionnalités pertinentes du nouveau renderer, notamment les éclairages, les filtres, les shaders, le batching, les atlas, les masques et les effets GPU.

N’utilise pas systématiquement toutes les nouveautés. Sélectionne celles qui améliorent réellement notre jeu.

3. INFORMATION MAJEURE SUR NOS ASSETS

Le développeur n’a jusqu’ici reçu qu’une partie de notre bibliothèque artistique, principalement les modèles 3D et certaines ressources associées.

Le propriétaire du projet possède également les images originales 2D haute définition ayant servi à créer de nombreux modèles Tripo.

Cette bibliothèque 2D n’a pas encore été intégralement transmise.

Nous disposons déjà de nombreuses ressources produites par ChatGPT et Gemini :

* Soldats.
* Extraterrestres.
* Boss.
* Véhicules.
* Armes.
* Accessoires.
* Robots.
* Machines.
* Portes.
* Murs.
* Sols.
* Textures.
* Décors.
* Interfaces.
* Portraits.
* Concepts artistiques.
* Environnements.
* Équipements scientifiques et militaires.

Nous pouvons également continuer à générer des images et des modèles supplémentaires selon les besoins.

Ne considère donc pas les ressources actuellement présentes dans GitHub comme la totalité de notre bibliothèque.

Ne lance pas une production massive de sprites à partir des GLB avant d’avoir examiné les images 2D originales.

Nous voulons sélectionner, pour chaque objet, la meilleure méthode :

A. Utilisation directe de l’image 2D originale.

B. Détourage ou transformation de cette image.

C. Génération d’une nouvelle illustration spécialisée.

D. Rendu précalculé depuis un GLB.

E. Animation squelettique 2D.

F. Sprite sheet générée à partir d’un modèle 3D animé.

G. Combinaison de plusieurs techniques.

Choisis la solution offrant le meilleur rapport entre qualité artistique, temps de production, consommation de tokens et performances.

4. AUDIT ARTISTIQUE GODOT

Les dernières captures montrent les problèmes suivants.

Évaluation subjective :

* Ambiance générale : 7/10.
* Décors et textures : 6,5/10.
* Personnages : 4,5/10.
* Éclairage : 3/10.
* Matériaux : 4/10.
* Composition : 4/10.
* Caméra : 4/10.
* Interface de combat : 4,5/10.
* Interface stratégique : 3/10.
* Base Neptune : 2/10.
* Qualité commerciale globale : 4,5/10.

Objectif minimum : 8/10 après validation artistique humaine.

Ces notes ne constituent pas un audit technique. Tu dois rechercher les véritables causes dans le code et les scènes.

Personnages

Les personnages ressemblent actuellement à des figurines rigides posées sur un plateau.

Vérifie :

* Échelles relatives.
* Proportions.
* Origines et pivots.
* Orientations.
* Positionnement au sol.
* Ombres de contact.
* Qualité du rigging.
* Squelettes.
* Animations.
* Transitions.
* Position des armes.
* Postures tactiques.
* Accroupissement.
* Visée.
* Recul.
* Déplacement.
* Blessures.
* Mort.

Détermine quels modèles sont correctement riggés et lesquels sont statiques.

N’invente pas des animations inexistantes.

Si une animation manque, explique la méthode permettant de la produire.

Éclairage et matériaux

Le rendu actuel est trop sombre, trop bleu, trop métallique et insuffisamment contrasté.

Nous voulons :

* Des sources lumineuses crédibles.
* Une hiérarchie claire des éclairages.
* Des zones chaudes et froides.
* Des personnages immédiatement lisibles.
* Des ombres cohérentes.
* Des ombres de contact.
* Des matériaux différenciés.
* Des textures moins répétitives.
* Des reflets maîtrisés.
* Un bloom subtil.
* Des effets atmosphériques.

Vérifie les textures PBR, les normal maps, les paramètres metallic et roughness, le tone mapping et les réglages du renderer.

Distingue les fonctionnalités disponibles avec Godot Compatibility, Mobile et Forward+.

Ne promets pas sur Web des fonctionnalités réservées aux renderers natifs.

Environnements

Le problème actuel est que les objets semblent avoir été déposés sur une grille sans véritable composition architecturale.

Les cartes doivent ressembler à de véritables lieux.

Chaque scène doit posséder :

* Une logique architecturale.
* Une circulation crédible.
* Des zones fonctionnelles.
* Des éléments de couverture.
* Des points d’intérêt.
* Des détails environnementaux.
* Une identité visuelle.
* Une histoire racontée par le décor.

Intègre les câbles, tuyauteries, consoles, portes, machines et éléments déjà disponibles.

Évite l’effet plateau flottant au milieu du vide.

Caméra

Revois :

* Perspective.
* Angle.
* Distance.
* Zoom.
* Cadrage.
* Suivi des personnages.
* Visibilité derrière les murs.
* Occlusion.
* Gestion des étages.
* Lisibilité tactique.

Le joueur doit immédiatement comprendre la scène et ses possibilités d’action.

5. DIRECTION ARTISTIQUE PHASER

Phaser n’est pas une version secondaire au rabais.

Il est possible que sa direction artistique soit finalement plus convaincante que celle de Godot.

Nous voulons une 2.5D de qualité premium.

Références de présentation : jeux tactiques isométriques haut de gamme, environnements précalculés, illustrations réalistes et interfaces militaires modernes.

Aucune copie directe de ressources appartenant à d’autres jeux.

Environnements

Étudie deux méthodes :

MÉTHODE A :
Décors précalculés complets, avec couches séparées pour les éléments interactifs.

MÉTHODE B :
Environnements modulaires construits à partir de tilesets et d’objets isométriques.

Évalue une méthode hybride combinant :

* Sols précalculés.
* Architecture détaillée.
* Objets interactifs indépendants.
* Couches de premier plan.
* Éléments de couverture.
* Éclairages.
* Particules.
* Effets atmosphériques.
* Décors animés.

Le décor visuel et la grille de déplacement doivent être séparés.

Ne sacrifie pas la qualité graphique pour faciliter le placement des cases.

Personnages et animations

Étudie les possibilités :

* Sprites précalculés depuis Tripo.
* Images originales 2D.
* Animations squelettiques 2D.
* Sprite sheets.
* Rendus 3D automatisés dans Blender.
* Animations générées à partir des modèles riggés.

Nous voulons au minimum :

* Idle.
* Marche.
* Visée.
* Tir.
* Accroupissement.
* Réaction aux impacts.
* Mort.

Commence avec quatre orientations si cela suffit à la caméra retenue. Passe à huit uniquement lorsque le résultat le justifie.

Évite les personnages qui glissent, les images simplement retournées lorsque l’équipement devient incohérent et les animations artificielles de mauvaise qualité.

Effets graphiques

Exploite intelligemment Phaser 4 pour obtenir :

* Ombres de contact.
* Lumières dynamiques.
* Reflets simulés.
* Particules.
* Fumée.
* Explosions.
* Étincelles.
* Impacts.
* Tirs.
* Éclairages d’urgence.
* Effets sous-marins.
* Effets extraterrestres.
* Animation des consoles et machines.

Les effets doivent renforcer la lisibilité et l’immersion, sans transformer le jeu en accumulation de néons.

6. REFONTE COMPLÈTE DES INTERFACES

Nous refusons que la version commerciale ressemble à un outil de développement.

Base Neptune

Construire une représentation immersive de la base sous-marine.

Étudier une vue en coupe illustrée avec :

* Hangars.
* Dortoirs.
* Laboratoire.
* Atelier.
* Réacteur.
* Sonar.
* Stockage.
* Centre de commandement.
* Personnel visible.
* Machines animées.
* Salles en construction.

Chaque salle doit être reconnaissable visuellement.

La représentation peut utiliser des illustrations 2D de haute qualité, y compris dans la version Godot si cela permet d’obtenir un meilleur résultat.

Escouade

Créer une véritable interface de gestion des soldats :

* Personnage visible en grand.
* Portrait.
* Arme.
* Armure.
* Inventaire.
* Accessoires.
* Statistiques.
* Compétences.
* Grades.
* Expérience.
* Historique.
* État de santé.

Les personnages Walker, Okafor, Lind et Moreau doivent posséder une identité forte.

Laboratoire et atelier

Prévoir :

* Illustrations des recherches.
* Autopsies extraterrestres.
* Artefacts.
* Équipements.
* Technologies.
* Arbres de recherche.
* Fabrication.
* Progression.

Globe stratégique

Améliorer :

* Signaux sonar.
* Activité ennemie.
* Déplacements du Triton et du Barracuda.
* Stations.
* Alertes.
* Animations.
* Informations.
* Profondeur océanique.

Interface de combat

* Boutons lisibles sur téléphone.
* Portraits adaptés.
* Informations tactiques hiérarchisées.
* Probabilités de réussite.
* Unités de temps.
* Points de vie.
* Couvertures.
* Prévisualisation des déplacements.
* Indicateurs de sélection.
* Safe areas iOS.
* Correction des caractères manquants.
* Suppression des éléments visuels inutiles.

7. RÉUTILISATION DU CODE GODOT

Nous refusons de financer deux jeux entièrement indépendants.

Audite chaque système existant :

* Combat.
* Pathfinding.
* Intelligence artificielle.
* Visibilité.
* Couvertures.
* Calcul des dégâts.
* Probabilités.
* Unités de temps.
* Inventaire.
* Économie.
* Campagne.
* Missions.
* Événements.
* Recherche.
* Fabrication.
* Recrutement.
* Grades.
* Progression.
* Sauvegardes.
* Audio.

Pour chaque système, indique :

1. État actuel.
2. Fichiers concernés.
3. Dépendance à Godot.
4. Possibilité de récupération.
5. Pourcentage estimé de travail réutilisable.
6. Réécriture nécessaire en TypeScript.
7. Coût estimé.
8. Risque.
9. Tests existants.

Vérifie également si une ancienne implémentation Web, JavaScript ou Phaser existe dans l’historique ou dans les branches du dépôt.

Ne transpose pas automatiquement du GDScript si une implémentation JavaScript exploitable existe déjà.

8. ARCHITECTURE COMMUNE

Propose une organisation simple permettant de maintenir deux moteurs sans doubler inutilement les coûts.

Organisation indicative à adapter après audit :

shared/
data/
missions/
characters/
enemies/
weapons/
research/
balance/
localization/
schemas/
tests/

godot/

phaser/

assets/
source/
godot/
phaser/
shared/

tools/

docs/

Les données doivent être versionnées et centralisées.

Les règles tactiques doivent être documentées.

Les deux moteurs doivent partager des scénarios de tests déterministes.

Utilise des seeds reproductibles si nécessaire.

Ne construis pas une infrastructure excessivement complexe pour mutualiser du code.

Compare les solutions :

* Données JSON communes et deux implémentations légères.
* Génération automatique de données et de code.
* Moteur de simulation partagé si techniquement et économiquement pertinent.

Explique ton choix.

9. ORGANISATION DES RESSOURCES 2D À RECEVOIR

Le propriétaire du projet peut transmettre de nombreuses archives ZIP contenant les images originales.

Ne lui demande pas d’envoyer les images une par une sauf nécessité particulière.

Prépare une procédure d’importation par lots.

Propose les catégories suivantes :

01_CHARACTERS
02_ALIENS
03_BOSSES
04_WEAPONS
05_VEHICLES
06_ROBOTICS
07_ENVIRONMENTS
08_FLOORS_WALLS
09_PROPS
10_BASE_NEPTUNE
11_UI_HUD
12_PORTRAITS
13_VFX
14_TEXTURES
15_AUDIO
16_MODELS_GLB

Cette nomenclature est indicative.

Accepte également des ZIP non organisés et automatise leur classement autant que possible.

Pour chaque fichier, produire un manifest comprenant :

* Nom original.
* Nom normalisé.
* Chemin.
* Hash.
* Dimensions.
* Format.
* Taille.
* Transparence.
* Catégorie.
* Personnage ou objet associé.
* Utilisation prévue.
* Compatibilité Godot.
* Compatibilité Phaser.
* État de validation.

Génère automatiquement des planches contact pour identifier visuellement les ressources.

Ne déduis pas le contenu d’une image uniquement à partir de son nom.

Utilise les hashes pour les doublons exacts et des méthodes perceptuelles pour détecter les variantes similaires, sans supprimer automatiquement les originaux.

Conserve les masters haute définition.

Génère ensuite des versions optimisées adaptées à chaque moteur.

10. DEMANDES DE NOUVELLES IMAGES

Une fois les archives reçues et analysées, produis un tableau des ressources manquantes.

Pour chaque élément, donne :

* Identifiant.
* Nom du fichier.
* Description.
* Catégorie.
* Angle exact.
* Perspective.
* Orientation.
* Style.
* Éclairage.
* Dimensions.
* Transparence.
* Ombre intégrée ou séparée.
* Usage dans le jeu.
* Animation nécessaire.
* Priorité.
* Méthode de génération recommandée.

Prépare également les prompts de génération correspondants.

Le propriétaire peut produire les ressources avec :

* ChatGPT.
* Gemini.
* Tripo.
* Autres outils si validés.

Gemini : cinq images maximum par lot de génération.

Tripo : images individuelles adaptées à la reconstruction 3D.

Phaser : images individuelles ou planches cohérentes selon l’usage.

Ne demande pas des ressources inutiles simplement pour remplir une liste.

11. PIPELINE GRAPHIQUE

Prépare des outils gratuits et automatisés pour :

* Importer les ZIP.
* Générer les planches contact.
* Détecter les doublons.
* Détourer lorsque possible.
* Recadrer.
* Redimensionner.
* Générer les atlas.
* Optimiser les PNG et WebP.
* Exporter les variantes mobiles.
* Générer les manifests.
* Vérifier les fichiers manquants.
* Produire des rendus depuis Blender headless.
* Générer des sprites multi-orientations.
* Valider les pivots et dimensions.

Teste ces outils sur un petit échantillon avant de les appliquer à toute la bibliothèque.

Ne modifie jamais les fichiers sources originaux de manière destructive.

Évite d’envoyer inutilement des centaines d’images en pleine résolution dans le contexte du modèle IA.

12. PREMIÈRE VERTICAL SLICE

La mission Station Némésis doit servir de démonstration commune.

Construire progressivement :

GODOT :
Une salle immersive en véritable 3D.

PHASER :
La même salle dans un rendu 2.5D premium.

Contenu identique :

* Deux soldats minimum.
* Un extraterrestre minimum.
* Déplacement.
* Couvertures.
* Tir.
* Animations.
* Effets lumineux.
* Bruitages.
* Interface tactique.
* Objectif de mission.

Avant le développement complet de chaque démonstration, produire une composition visuelle de référence.

La composition doit utiliser nos véritables ressources et servir de cible au moteur graphique.

Une maquette statique n’est pas considérée comme une démonstration jouable.

Ne passe pas à la campagne complète tant que les deux démonstrations ne sont pas évaluées.

13. CRITÈRES DE VALIDATION

Utilise une grille de notation sur 100 :

* Qualité des personnages : 15 points.
* Qualité des environnements : 15 points.
* Éclairage et ambiance : 15 points.
* Animations : 15 points.
* Interface : 15 points.
* Lisibilité tactique : 10 points.
* Fluidité : 10 points.
* Cohérence artistique : 5 points.

Objectif : au moins 80/100 après évaluation humaine.

Fournis des preuves :

* Captures avant/après.
* Captures en situation réelle.
* Courtes vidéos si possible.
* Mesures FPS.
* Temps de chargement.
* Mémoire.
* Rapports de tests.
* URL jouable.

Ne valide pas toi-même la qualité artistique finale.

Ne confonds pas quantité de code, quantité d’assets intégrés et qualité du résultat.

14. PERFORMANCES

Appareils de référence :

* iPhone 15 Pro Max.
* Honor Magic V5.
* iPad.
* PC.

Phaser :

* Objectif 60 FPS sur téléphone performant.
* Minimum visé 30 FPS stables sur appareil intermédiaire.
* Chargement progressif.
* Mémoire maîtrisée.
* Interface paysage adaptée.
* Zoom tactile.
* Gestion des interruptions.
* Gestion de la perte de contexte WebGL.

Godot :

* Objectif 60 FPS sur PC compatible.
* Profil graphique iPad.
* Profil Web de démonstration.
* Optimisation des draw calls.
* Réduction des coûts d’éclairage.
* Gestion des textures et modèles.

Les résultats doivent être mesurés sur les appareils réels ou clairement identifiés comme mesures d’émulation.

15. AUDIO

Nous possédons déjà une importante bibliothèque audio ElevenLabs.

Vérifie :

* Musiques réellement présentes.
* Bruitages.
* Voix radio.
* Voix des soldats.
* Ambiances.
* Boucles.
* Formats.
* Chargement.
* Lecture sur Safari iOS.
* Déverrouillage audio après interaction utilisateur.
* Mixage.
* Réglages de volume.

Vérifie l’état de la PR audio existante et son intégration effective.

Ne régénère aucun son existant sans justification.

Mutualise les fichiers audio entre les deux moteurs lorsque les formats le permettent.

16. ÉCONOMIE DE TOKENS

Cette priorité est aussi importante que la programmation.

Nous avons déjà dépensé beaucoup de tokens pour obtenir des résultats graphiques insuffisants.

Tu dois modifier ta méthode.

OBLIGATIONS :

* Lire uniquement les fichiers pertinents.
* Utiliser Git diff.
* Utiliser des recherches ciblées.
* Automatiser les opérations répétitives.
* Éviter la relecture complète du dépôt.
* Éviter les réécritures inutiles.
* Ne pas dupliquer les données.
* Ne pas produire des rapports excessivement longs.
* Utiliser des modèles moins coûteux pour les tâches simples si disponibles.
* Réserver les modèles puissants aux difficultés réelles.
* Exploiter le prompt caching lorsqu’il est disponible.
* Maintenir un contexte compact et réutilisable.
* Arrêter une approche qui échoue plusieurs fois.
* Ne pas multiplier les fonctionnalités non validées.

Maintiens les fichiers :

CLAUDE.md
PROJECT_STATE.md
ART_DIRECTION.md
SHARED_GAME_RULES.md
ASSET_MANIFEST.json
TASKS.md
COST_TRACKER.md

Ces fichiers doivent rester synthétiques et à jour.

Chaque session doit commencer par une lecture ciblée de ces documents, et non une relecture de toutes les conversations précédentes.

Lorsqu’une session approche de sa limite de contexte, prépare un checkpoint exploitable pour la suivante.

17. BUDGET ET RENTABILITÉ

Produis un budget comparatif pour :

A. Godot uniquement.

B. Phaser uniquement.

C. Godot + Phaser avec mutualisation maximale raisonnable.

D. Godot + Phaser avec mutualisation minimale.

Pour chaque stratégie :

* Temps de développement.
* Tokens d’entrée.
* Tokens de sortie.
* Cache éventuel.
* Coût API théorique.
* Consommation potentielle des quotas Claude.
* Temps consacré aux assets.
* Temps de tests.
* Coût de maintenance.
* Risques techniques.
* Avantages commerciaux.

Décompose ensuite le budget par jalon.

Jalon 1 : audit.

Jalon 2 : réception et classement des images 2D.

Jalon 3 : architecture commune.

Jalon 4 : démonstration artistique Phaser.

Jalon 5 : démonstration artistique Godot.

Jalon 6 : validation comparative.

Jalon 7 : développement tactique complet.

Jalon 8 : développement stratégique complet.

Jalon 9 : optimisation.

Jalon 10 : publication.

Présente trois scénarios :

ÉCONOMIQUE
ÉQUILIBRÉ
PREMIUM

Distingue les données mesurées des estimations.

Ne prétends pas connaître les quotas exacts de mon abonnement si tu n’y as pas accès.

Ne présente pas une estimation API comme une facture réelle d’abonnement.

18. GITHUB ET SÉCURITÉ DU PROJET

Ne détruis aucune version existante.

Ne modifie pas directement main.

Utilise des branches dédiées pour les expérimentations :

experiment/phaser4
experiment/godot-visual-overhaul

Adapte les noms si ces branches existent déjà.

Préserve les sauvegardes, les ressources et les déploiements existants.

Prépare des commits cohérents et des PR clairement documentées.

Vérifie les conflits avec le travail en cours.

Ne fusionne pas une refonte majeure sans validation.

19. PREMIÈRES ACTIONS ATTENDUES

Commence immédiatement par :

1. Lire les documents de reprise.
2. Inspecter l’état réel du dépôt.
3. Rechercher les implémentations JavaScript existantes.
4. Auditer les systèmes Godot réutilisables.
5. Consulter les skills officiels Phaser 4.
6. Préparer la procédure d’import des ZIP 2D.
7. Fournir les spécifications des ressources attendues.
8. Établir un budget et un calendrier.
9. Identifier les premières corrections artistiques Godot.
10. Préparer les branches de travail isolées.

N’attends pas la réception de toutes les images pour effectuer les audits et préparer les outils.

En revanche, ne reconstruis pas massivement les ressources graphiques avant d’avoir examiné la bibliothèque 2D que je vais transmettre.

Ne lance pas deux productions complètes en parallèle sans architecture et budget validés.

Ta première réponse doit être structurée, concrète, documentée et relativement concise.

Je veux également savoir immédiatement quels ZIP je peux t’envoyer.

Notre objectif final n’est pas d’avoir énormément de code.

Notre objectif est d’avoir un excellent jeu, magnifique, fluide, rentable et techniquement maintenable.

MAXLOL GAMES — ABYSS PROTOCOL
MASTER DIRECTIVE V2.