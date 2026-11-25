MAXLOL GAMES — ABYSS PROTOCOL

Réorientation stratégique, refonte artistique et développement Godot 3D / Phaser 4.2.1

1. NOUVELLE DIRECTION DU PROJET

Nous avons testé la dernière version d’ABYSS PROTOCOL.

Le travail fonctionnel est encourageant, mais la qualité graphique est très insuffisante par rapport à nos ambitions commerciales et à la quantité de ressources artistiques déjà produites.

Nous ne souhaitons pas abandonner Godot, mais nous décidons de développer deux versions du même jeu :

* ABYSS PROTOCOL 3D : Godot, principalement pour PC et iPad.
* ABYSS PROTOCOL 2.5D : Phaser 4.2.1, principalement pour iPhone, Android et navigateur Web.

Ces deux versions doivent partager autant que possible leurs données, leurs mécaniques, leur équilibrage, leur scénario et leurs ressources.

Nous ne voulons pas financer deux développements complètement indépendants.

Ne supprime aucun travail existant. Préserve la version actuelle, les branches, les ressources et les sauvegardes. Ne modifie pas directement main sans validation.

2. ÉVALUATION ARTISTIQUE ACTUELLE

Voici notre évaluation subjective de la version Godot à partir des dernières captures :

* Ambiance science-fiction : 7/10.
* Décors et textures : 6,5/10.
* Personnages : 4,5/10.
* Éclairage : 3/10.
* Matériaux : 4/10.
* Composition des environnements : 4/10.
* Caméra : 4/10.
* Interface de combat : 4,5/10.
* Interface stratégique : 3/10.
* Base Neptune : 2/10.
* Qualité commerciale globale : 4,5/10.

Notre objectif est d’atteindre au minimum 8/10 sur la qualité artistique globale avant de poursuivre la production massive de contenu.

Nous avons investi dans plus d’une centaine de ressources graphiques 2D, des modèles 3D Tripo, des textures, des personnages, des véhicules, des objets, des extraterrestres et une importante bibliothèque audio ElevenLabs.

Nous devons désormais exploiter correctement ces ressources au lieu de multiplier les fonctionnalités et les nouveaux assets.

3. AUDIT TECHNIQUE GODOT

Analyse les causes réelles de la qualité graphique actuelle.

Ne te contente pas d’affirmer que les modèles ont été intégrés.

Vérifie notamment :

Personnages :

* Échelle et proportions cohérentes.
* Orientation des personnages.
* Position des armes dans les mains.
* Qualité des squelettes et du rigging.
* Animations idle, marche, course, visée, tir, accroupissement, blessure et mort.
* Transitions entre animations.
* Position des pieds sur le sol.
* Ombres de contact.
* Lisibilité des silhouettes.

Éclairage :

* Éclairage directionnel.
* Sources lumineuses locales.
* Contraste entre zones éclairées et sombres.
* Éclairage d’accentuation des personnages.
* Ombres dynamiques.
* Ambient occlusion lorsque compatible.
* Éclairage précalculé si nécessaire.
* Bloom maîtrisé.
* Suppression de la dominante bleue excessive.
* Différenciation chromatique des environnements.

Matériaux :

* Roughness.
* Metallic.
* Normal maps.
* Textures PBR.
* Réflexions excessives.
* Échelle des textures.
* Compression des textures.
* Apparence plastique de certains modèles.
* Compatibilité du rendu Web, mobile et natif.

Environnements :

* Supprimer l’impression de figurines posées sur un plateau.
* Réduire le vide autour des zones jouables.
* Créer une architecture crédible.
* Intégrer tuyauteries, câbles, portes, machines, consoles et détails environnementaux.
* Éviter les répétitions excessives de textures.
* Donner une identité spécifique à chaque mission.
* Utiliser les ressources déjà disponibles avant d’en demander de nouvelles.

Caméra :

* Revoir angle, perspective et cadrage.
* Améliorer le zoom.
* Centrer intelligemment la zone jouable.
* Améliorer la lisibilité des combats.
* Éviter les mouvements cinématiques gênants.

Performances :

* Identifier les causes des performances observées entre 29 et 45 FPS sur les captures.
* Mesurer le nombre de draw calls, les triangles, la mémoire, les textures et les coûts d’éclairage.
* Distinguer les limitations de Godot Web de celles d’une compilation native.
* Proposer des profils graphiques adaptés à chaque appareil.

4. REFONTE DE L’INTERFACE STRATÉGIQUE

L’interface actuelle ressemble encore trop à un outil de développement.

Nous voulons une expérience de jeu premium, pas une succession de tableaux et de boutons.

Base Neptune :

Transformer la grille textuelle actuelle en véritable base sous-marine immersive.

Utiliser une représentation en coupe ou isométrique illustrée avec :

* Centre de commandement.
* Laboratoire.
* Atelier.
* Dortoirs.
* Réacteur.
* Hangars.
* Sonar.
* Stockage.
* Personnel.
* Animations d’activité.
* Salles en construction.

Gestion de l’escouade :

Créer un écran premium avec :

* Personnage visible en grand.
* Portrait.
* Armure.
* Arme équipée.
* Inventaire.
* Statistiques.
* Compétences.
* Grades.
* Expérience.
* Historique des missions.

Recherche et fabrication :

Remplacer progressivement les listes austères par des interfaces illustrées :

* Artefacts.
* Autopsies extraterrestres.
* Arbres technologiques.
* Illustrations des équipements.
* Plans de fabrication.
* Progression des recherches.

Carte mondiale :

Améliorer le globe actuel avec :

* Signatures sonar.
* Activité extraterrestre.
* Alertes.
* Déplacement des véhicules.
* Stations sous-marines.
* Effets animés.
* Informations tactiques et stratégiques.

Corriger également les problèmes de caractères et d’icônes non affichés sur iOS ainsi que les problèmes de taille et de lisibilité des boutons.

5. CRÉATION DE LA VERSION PHASER 4

Créer une branche expérimentale dédiée :

experiment/phaser4

Utiliser :

* Phaser 4.2.1 stable, après vérification officielle.
* TypeScript.
* Vite.
* WebGL.
* Architecture modulaire.
* Dépendances limitées et gratuites.
* GitHub Pages pour les premières démonstrations.

Consulter la documentation officielle de Phaser 4 ainsi que les fichiers skills disponibles dans son dépôt GitHub pour éviter de programmer selon les anciennes API Phaser 3.

La version Phaser doit être un véritable jeu tactique isométrique 2.5D premium.

Nous ne voulons pas d’une imitation simplifiée, d’un prototype constitué de rectangles, ni d’une carte composée de simples images mal détourées.

Exploiter :

* Décors isométriques précalculés.
* Sprites haute qualité.
* Atlas de textures.
* Tri de profondeur.
* Gestion des occlusions.
* Ombres de contact.
* Éclairages compatibles Phaser 4.
* Particules.
* Effets de tir.
* Fumée.
* Explosions.
* Effets sous-marins.
* Animations de personnages.
* Caméra fluide.
* Zoom tactile.
* Interface adaptée au téléphone.
* Gestion de la mémoire et chargement progressif.

La logique tactique doit être indépendante de l’affichage graphique.

6. RÉUTILISATION DU CODE EXISTANT

Effectue un audit complet du dépôt existant.

Identifie précisément :

* Le code directement réutilisable.
* Le code GDScript à transposer en TypeScript.
* Les algorithmes réutilisables.
* Les systèmes dépendants du moteur.
* Les systèmes indépendants du moteur.
* Les données à extraire dans un format commun.
* Les systèmes trop complexes à mutualiser immédiatement.

Étudie particulièrement :

* Combat au tour par tour.
* Unités de temps.
* Déplacements.
* Pathfinding.
* Intelligence artificielle.
* Couvertures.
* Visibilité.
* Probabilités de tir.
* Dégâts.
* Inventaire.
* Économie.
* Recherche.
* Fabrication.
* Recrutement.
* Grades.
* Progression.
* Missions.
* Campagne.
* Sauvegardes.

Propose une architecture commune reposant au minimum sur des données JSON versionnées, des règles documentées et des scénarios de tests partagés.

Évalue si une mutualisation plus poussée du moteur de simulation est réellement rentable. Ne crée pas une architecture complexe uniquement pour partager du code.

Les deux versions doivent produire des résultats cohérents pour les mêmes situations de combat.

7. INVENTAIRE DES RESSOURCES EXISTANTES

Avant de demander de nouvelles images, audite toutes les ressources présentes dans GitHub et les archives déjà reçues.

Nous disposons notamment de nombreuses images 2D originales qui ont servi à la génération des modèles Tripo.

Classe chaque ressource :

* Utilisable immédiatement.
* À détourer.
* À recadrer.
* À redimensionner.
* À convertir.
* À animer.
* À transformer en sprite sheet.
* À rendre depuis un modèle GLB.
* Inutilisable.
* Manquante.

Évite d’analyser plusieurs fois les mêmes ressources.

Utilise des scripts gratuits pour créer automatiquement les inventaires, miniatures, planches contact, dimensions, poids, hashes et détection des doublons.

Ne charge pas inutilement toutes les images en pleine résolution dans ton contexte IA.

8. RESSOURCES À DEMANDER POUR PHASER

Fournis une liste exacte, priorisée et exploitable des images nécessaires.

Pour chaque ressource manquante, indique :

* Nom du fichier.
* Catégorie.
* Utilisation.
* Dimensions.
* Format PNG ou WebP.
* Transparence nécessaire.
* Angle de caméra.
* Perspective.
* Direction de l’éclairage.
* Nombre d’orientations.
* Nombre d’animations.
* Niveau de priorité.
* Possibilité de réutiliser une image existante.
* Possibilité de générer automatiquement cette ressource depuis un GLB.

Catégories :

* Soldats Walker, Okafor, Lind et Moreau.
* Extraterrestres Néréide, Carapace, Spectre et autres créatures existantes.
* Armes.
* Véhicules Triton et Barracuda.
* Sols.
* Murs.
* Portes.
* Couvertures tactiques.
* Consoles.
* Machines.
* Décors.
* Salles de la base Neptune.
* Portraits.
* Interfaces.
* Icônes.
* Effets visuels.
* Animations.

Évalue la possibilité d’utiliser Blender en mode headless pour produire automatiquement des sprites depuis les modèles GLB existants.

Ne demande pas huit nouvelles générations IA pour huit orientations si les modèles 3D permettent de produire ces orientations proprement.

Distingue les modèles déjà riggés des modèles statiques nécessitant un travail supplémentaire.

Précise exactement quelles ressources doivent être générées individuellement et lesquelles peuvent être regroupées en planches.

Pour Gemini, limiter les générations à cinq images par lot maximum.

9. ORGANISATION DES ZIP

Je préfère envoyer des archives ZIP complètes et organisées plutôt que transmettre les images individuellement.

Propose une nomenclature claire, par exemple :

ABYSS_SHARED_ASSETS/

* characters/
* aliens/
* weapons/
* vehicles/
* environments/
* tiles/
* base_rooms/
* portraits/
* ui/
* icons/
* effects/
* audio/
* models_glb/
* manifests/

Produis un manifest contenant les chemins, dimensions, formats, catégories et états d’intégration.

Prépare les scripts nécessaires pour :

* Décompresser les archives.
* Détecter les doublons.
* Renommer les fichiers.
* Optimiser les images.
* Générer les atlas.
* Vérifier les ressources manquantes.
* Intégrer automatiquement les assets compatibles.

Ne me demande pas de renommer manuellement des centaines de fichiers si tu peux automatiser cette opération.

10. PRODUCTION D’UNE VERTICAL SLICE

Suspendre temporairement le développement de nouvelles fonctionnalités non indispensables.

La priorité absolue est de produire une démonstration artistique de la première mission Station Némésis.

Godot :

* Une salle de qualité premium.
* Deux soldats.
* Un extraterrestre.
* Des couvertures.
* Des animations.
* Un éclairage travaillé.
* Une interface propre.

Phaser :

* La même salle.
* Les mêmes soldats.
* Le même extraterrestre.
* Les mêmes mécaniques.
* Un rendu isométrique 2.5D premium.
* Des animations et effets convaincants.

Nous devons pouvoir comparer objectivement les deux moteurs.

Ne développe pas toute la campagne Phaser avant validation de cette démonstration.

11. OBJECTIFS DE PERFORMANCE

Pour Phaser :

* Objectif de 60 FPS sur téléphone performant.
* Minimum visé de 30 FPS stables sur appareil intermédiaire.
* Interface tactile lisible.
* Adaptation au paysage.
* Gestion des safe areas iOS.
* Chargement raisonnable.
* Mémoire maîtrisée.

Pour Godot :

* Objectif de 60 FPS sur PC compatible.
* Profil adapté à l’iPad.
* Distinction entre Web et natif.
* Options graphiques fonctionnelles.

Ne déclare jamais un objectif atteint sans mesures réelles.

12. ÉCONOMIE DE TOKENS — PRIORITÉ MAJEURE

Le développement actuel consomme énormément de tokens Claude pour une qualité visuelle insuffisante.

Nous voulons changer cette méthode.

Règles impératives :

* Ne pas relire l’intégralité du dépôt à chaque tâche.
* Utiliser Git diff et des recherches ciblées.
* Ne pas charger systématiquement tous les assets.
* Utiliser des scripts plutôt que des opérations manuelles répétitives.
* Ne pas réécrire les fichiers qui fonctionnent.
* Ne pas dupliquer les données entre les moteurs.
* Utiliser des tests automatisés.
* Limiter les longues descriptions dans les comptes rendus.
* Éviter les refactorisations inutiles.
* Travailler par objectifs courts et vérifiables.
* Arrêter une approche qui échoue plusieurs fois et expliquer le blocage.
* Demander une validation avant toute opération coûteuse ou refonte majeure.

Maintenir des documents de référence courts :

* CLAUDE.md
* PROJECT_STATE.md
* ART_DIRECTION.md
* SHARED_GAME_RULES.md
* ASSET_MANIFEST.json
* TASKS.md
* COST_TRACKER.md

Chaque nouvelle session doit pouvoir reprendre le travail sans relire toutes les conversations précédentes.

Utiliser un modèle moins coûteux pour les opérations simples si l’environnement le permet.

Réserver les modèles les plus puissants aux problèmes complexes d’architecture, de rendu et d’optimisation.

13. ESTIMATION FINANCIÈRE ET TECHNIQUE

Avant toute production importante, fournis un budget détaillé pour :

A. Refonte artistique Godot.

B. Audit et extraction des données communes.

C. Création de la vertical slice Phaser.

D. Conversion des assets et animations.

E. Portage des systèmes tactiques.

F. Portage de la partie stratégique.

G. Optimisation mobile.

H. Tests et publication.

Pour chaque étape, indique :

* Temps estimé.
* Tokens d’entrée.
* Tokens de sortie.
* Tokens mis en cache si disponibles.
* Coût API théorique en euros selon le modèle utilisé.
* Impact probable sur les quotas de mon abonnement Claude.
* Risques.
* Dépendances.
* Économies possibles.

Présente trois scénarios : économique, équilibré et premium.

Distingue les mesures réelles des simples estimations. Ne prétends pas connaître mes quotas ou ma consommation exacte si ces données ne sont pas accessibles.

Compare le coût total de trois stratégies :

1. Godot uniquement.
2. Phaser uniquement.
3. Godot et Phaser avec données et tests communs.

Évalue le surcoût réel lié au maintien de deux moteurs.

14. LIVRABLES ATTENDUS AVANT VALIDATION

Ta première réponse doit contenir :

1. Ton diagnostic technique des défauts graphiques.
2. Les preuves issues du code qui confirment ou infirment nos hypothèses.
3. Un inventaire des ressources déjà disponibles.
4. Une liste précise des ressources manquantes pour Phaser.
5. Le pourcentage estimé de travail réutilisable, détaillé par système.
6. L’architecture proposée.
7. Le budget en tokens et en euros.
8. Le calendrier prévisionnel.
9. Les risques liés aux deux moteurs.
10. Les actions permettant de réduire les coûts.
11. Les premières améliorations graphiques prioritaires.
12. La méthode de validation des deux démonstrations.

Tu peux commencer immédiatement les audits non destructifs et les inventaires automatisés.

En revanche, ne lance pas un développement massif avant validation de ton plan et de son budget.

Notre priorité n’est plus la quantité de code produit.

Notre priorité est la qualité visuelle, le plaisir de jeu, la fluidité et la rentabilité commerciale.

Nous voulons créer un véritable jeu indépendant premium dans l’esprit des grands jeux tactiques, avec sa propre identité artistique sous-marine.

Moins de tokens gaspillés. Moins de fonctionnalités non validées. Plus de qualité visible.

MAXLOL GAMES — ABYSS PROTOCOL.
---
## Notes de Claude (26/11, 0 h 30), à reprendre dans une nouvelle session
- Captures de Max (iPhone, Safari) : 29 à 45 i/s en qualité moyenne ; boutons de vitesse du géoscape affichés en carrés (glyphes absents de la police sur iOS) ; base Neptune = grille de boutons ; écrans Escouade/Recherche = listes.
- Musique « absente » chez Max : fichiers et code présents (view/audio.gd, main.gd l. 139/158). Vérifier l'interrupteur « Son et musique » du menu, le mode silencieux iOS, et le déblocage audio Web au premier appui.
- Livrables demandés : section 14 ci-dessus. Pas de développement massif avant validation du plan et du budget.
