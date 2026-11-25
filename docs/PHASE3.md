# Phase 3 : géoscape, base Neptune, campagne (journal)

Directive de Max (25/11/2026, 20 h 30) : géoscape complet, puis base Neptune, puis campagne de 3 à 5 missions reliée à Némésis, architecture prête pour les GLB Tripo, sans régression tactique. Branche `claude-b/phase3` (contient `claude-b/modeles-tripo`).

## Ce qui existe (implémenté et testé)

| Système | Fichiers | État |
|---|---|---|
| Moteur de campagne (temps, sauvegarde versionnée, déterminisme) | `godot/sim/strategy/campaign.gd` | testé |
| Contenu et équilibrage | `godot/sim/strategy/content.gd` | réglable sans code |
| Géométrie du globe | `godot/sim/strategy/geo.gd` | testé |
| Globe 3D, jour/nuit, grille sonar, fosses, tracés | `godot/view/strategy/globe.gd`, `tools/gen_globe.py` | captures |
| Écran stratégique, 4 onglets, décisions, bandeaux | `godot/view/strategy/strategy.gd`, `panels.gd`, `marker.gd`, `ui.gd` | captures |
| Passage campagne ↔ combat | `godot/view/session.gd`, `main.gd`, `hud.gd` | testé + captures |
| Cartes de campagne Port attaqué, Le Nid | `godot/sim/data.gd` | IA contre IA |
| Registre des modèles GLB | `godot/view/model_registry.gd`, `docs/MODELES-3D.md` | Okafor, Lind, Néréide, Brute branchés |

### Géoscape
- Temps en pause par défaut, 4 vitesses (5 min/s, 1 h/s, 6 h/s, 1 j/s). Pause automatique seulement pour une décision : contact, interception, Triton sur zone, mission, recherche terminée, rapport mensuel.
- Six conseils régionaux (Atlantique Nord/Sud, Pacifique Nord/Sud, océan Indien, Arctique) : financement × confiance. Un mois sans activité alien rassure (+5) ; une confiance ≤ 10 au rapport = retrait du conseil ; trois retraits = défaite.
- Opérations aliens autonomes, financées par un budget qui croît avec la menace : reconnaissance (Éclaireur), moisson côtière (Moissonneur), raid portuaire (crée une mission « Port attaqué »). Elles partent des fosses abyssales.
- Détection : sonar de Neptune (2 400 km, 3 600 avec le sonar longue portée, −40 % en déficit d'énergie) + sonar des engins en mer. Contact incertain : cercle d'erreur qui se resserre tant qu'il est suivi, contact perdu sinon.
- Barracuda (intercepteur) : chances estimées affichées avant d'engager (200 duels simulés), règles lisibles (une torpille puis une riposte par passe, 8 passes). Victoire = épave → mission « Épave alien » ; épave au-dessus d'une fosse = coque haute pression requise.
- Triton (transport, 4 places, 240 h d'autonomie) : refuse une destination hors d'autonomie.
- Menace 0 → 100 (défaite à 100) : + chaque jour, + opérations abouties, missions perdues ou abandonnées ; − victoires, interceptions, destruction du Nid.

### Base Neptune
- Grille 6 × 4, construction adjacente : coût, durée, énergie, entretien, capacité, prérequis de recherche (sonar longue portée, confinement).
- Personnel : scientifiques (labos), ingénieurs (ateliers), affectation par projet (+/−).
- Infirmerie : divise par deux la convalescence. Hangar : capacité d'engins. Stocks : objets aliens revendables (choix argent / recherche).
- Budget mensuel prévisionnel (financement, personnel, salles, engins).

### Recherche et fabrication (arbre réduit mais fonctionnel)
Artefact Némésis → Signal abyssal ; Épave → Propulseur → Propulsion (Barracuda +25 %, coque haute pression) ; Signal + Propulsion → Triangulation → **Le Nid** (fosse des Mariannes). Autopsies : Néréide (+12 % de visée contre elles), Carapace (harpon perforant), Spectre (casque psi). Alliages → scaphandre (+6 d'armure), coque renforcée ; Alliages + Néréide → fusil à cavitation. Chaque découverte change une décision : quoi chasser, quoi vendre, où aller.

### Soldats persistants
Grades (Recrue → Capitaine) avec gains à chaque promotion, XP (survie, éliminations, victoire), blessures en jours d'infirmerie, mort définitive (mémorial), recrues renouvelées chaque mois, équipement depuis le stock (arme, armure, grenades, trousses, casque psi), choix de qui embarque.

## Mesures
- Tests : 42 tactiques (inchangés : Némésis IA 10/12, labo 12/16, même résultat qu'avant la phase 3) + 50 de campagne.
- IA contre IA sur les cartes de campagne (8 parties) : Port 5/8, Épave 5/8, Nid 6/8 avec une escouade équipée.
- Campagne complète jouée par un robot (`tests/campaign_smoke.gd`) :
  - combats parfaits (plafond stratégique) : victoire mi-avril, 5 à 9 missions, 4 à 8 interceptions ;
  - combats joués par l'IA d'escouade (qui perd beaucoup de soldats) : défaite par la menace vers octobre. Un joueur humain doit se situer entre les deux : **à confirmer par les essais de Max**.

## Limites connues (reportées)
- Une seule base (pas d'extension mondiale), pas de défense de base, pas de prisonniers (salle de confinement sans usage), pas de drones.
- Les recrues réutilisent les apparences de Lind et Moreau ; l'arme dessinée suit l'apparence, pas l'arme réellement portée.
- Pas de musique propre au géoscape (Max fournit les morceaux).
- Équilibrage stratégique à valider en jeu réel.

## Décors Port attaqué et Le Nid (25/11, 22 h 30, branche `claude-b/decors-port-nid`)
- Thèmes de carte (`AbyssKit.begin_theme`) : le kit garde ses formes et change de matériaux pendant la construction du décor (les unités et les effets ne sont pas touchés) ; quelques pièces changent de forme.
- **Port** (nuit, surface) : sol d'asphalte, quai bétonné bas avec garde-corps, bollards et lampadaires au sodium, cloisons d'entrepôt en tôle ondulée rouillée, eau du bassin profonde, mer au nord, conteneurs empilés et grue portuaire hors carte, pluie oblique, couverts de quai (caisses, sacs de sable, fûts, citerne, chariot), matériel de quai le long des bords.
- **Le Nid** (caverne) : sol et parois de roche mate, piliers de chitine tressée à nervures lumineuses, corniches de roche, mares phosphorescentes, cristaux violets, stalagmites hors carte, spores qui montent ; couverts organiques (cocons, cristaux, masses tentaculaires).
- Les objets hauts hors carte se masquent côté caméra comme la coque. Ambiance (couleur, brume, soleil) propre à chaque carte, conservée en qualité allégée.
- Coût de rendu (vue entière, 2 rotations) : Port 346 appels (haute) / 216 (allégée), Nid 308 / 204, Némésis 345 / 231 : équivalent.
- Captures : `tests/campaign_battle_shot.gd -- out.png port|nid [qualité] [rotations]` (affiche aussi le coût de rendu).
- Remplaçables plus tard par les environnements Tripo de Max.
