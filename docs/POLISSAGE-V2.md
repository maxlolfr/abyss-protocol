# Passe de polissage visuel V2 (ordre de Max, 25/11 23 h 32)

Modèles Tripo intégrés et mécaniques validées : à conserver. Ne pas régénérer les modèles existants.

1. Contamination organique intégrée aux murs (pas de plaques rectangulaires superposées).
2. Ombres de contact sous les personnages et les accessoires.
3. Proportions, orientations et points d'ancrage des objets corrigés.
4. Surfaces bleues provisoires supprimées dès que les ressources existent.
5. Éclairages variés : blanc industriel, orange, rouge d'urgence, violet organique.
6. Décors plus denses et mieux composés, sans gêner les déplacements.
7. Postures de combat et intégration des animations des personnages préparées.
8. Plusieurs niveaux de zoom tactique.
9. Interface plus lisible sur téléphone.
10. Performances préservées ; i/s mesurées pendant les combats.

Objectif : présentation de jeu commercial, esprit XCOM, identité propre. Mécaniques inchangées.

## État au 25/11 23 h 40
- PR #13 fusionnée par Max. Compilation OK, mais la **publication GitHub Pages échoue** (erreur côté GitHub : « Fetching artifact metadata failed », 3 essais). À relancer : `gh api -X POST repos/maxlolfr/abyss-protocol/actions/workflows/build.yml/dispatches -f ref=main`.
- Sols à recevoir de Max (GLB non compressé), murs du Nid à 1 500 faces.
