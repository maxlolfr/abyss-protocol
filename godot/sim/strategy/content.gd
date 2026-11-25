class_name StratData
## Contenu stratégique (géoscape, base Neptune, recherche, fabrication, campagne courte).
## Données séparées du moteur : l'équilibrage se règle ici. Positions en degrés (latitude, longitude).
## Unité monétaire : k (milliers de crédits).

const START_DATE := {"year": 2031, "month": 3, "day": 1}
const START_FUNDS := 2600
const BASE_POS := Vector2(38.6, -28.4) # Neptune, plateau des Açores
const TICK := 10 # minutes de simulation par pas

## Conseils régionaux de financement (zones d'influence = point de rattachement le plus proche).
const REGIONS := {
	"atl_nord": {"name": "Atlantique Nord", "pos": Vector2(45, -35), "funding": 260, "trust": 62},
	"atl_sud": {"name": "Atlantique Sud", "pos": Vector2(-22, -18), "funding": 150, "trust": 55},
	"pac_nord": {"name": "Pacifique Nord", "pos": Vector2(32, 175), "funding": 240, "trust": 55},
	"pac_sud": {"name": "Pacifique Sud", "pos": Vector2(-28, -135), "funding": 140, "trust": 55},
	"indien": {"name": "Océan Indien", "pos": Vector2(-15, 75), "funding": 170, "trust": 55},
	"arctique": {"name": "Arctique", "pos": Vector2(74, 10), "funding": 110, "trust": 60},
}

## Fosses abyssales : au-delà de la limite de pression d'une coque standard.
const TRENCHES := {
	"mariannes": {"name": "Fosse des Mariannes", "pos": Vector2(11.4, 142.4), "radius": 420},
	"porto_rico": {"name": "Fosse de Porto Rico", "pos": Vector2(19.8, -66.0), "radius": 300},
	"java": {"name": "Fosse de la Sonde", "pos": Vector2(-10.5, 110.0), "radius": 380},
	"tonga": {"name": "Fosse des Tonga", "pos": Vector2(-22.0, -175.0), "radius": 340},
	"perou_chili": {"name": "Fosse Pérou-Chili", "pos": Vector2(-23.0, -72.5), "radius": 360},
	"aleoutiennes": {"name": "Fosse des Aléoutiennes", "pos": Vector2(51.0, -176.0), "radius": 330},
	"romanche": {"name": "Fosse de la Romanche", "pos": Vector2(-0.3, -18.6), "radius": 260},
	"sandwich": {"name": "Fosse des Sandwich du Sud", "pos": Vector2(-55.8, -26.5), "radius": 280},
}

## Ports et installations côtières (cibles des opérations aliens).
const PORTS := {
	"lisbonne": {"name": "Lisbonne", "pos": Vector2(38.7, -9.3)},
	"reykjavik": {"name": "Reykjavik", "pos": Vector2(64.1, -21.9)},
	"halifax": {"name": "Halifax", "pos": Vector2(44.6, -63.6)},
	"dakar": {"name": "Dakar", "pos": Vector2(14.7, -17.5)},
	"rio": {"name": "Rio de Janeiro", "pos": Vector2(-22.9, -43.2)},
	"le_cap": {"name": "Le Cap", "pos": Vector2(-33.9, 18.4)},
	"mumbai": {"name": "Mumbai", "pos": Vector2(19.0, 72.8)},
	"perth": {"name": "Perth", "pos": Vector2(-31.9, 115.8)},
	"sydney": {"name": "Sydney", "pos": Vector2(-33.9, 151.2)},
	"valparaiso": {"name": "Valparaíso", "pos": Vector2(-33.0, -71.6)},
	"san_francisco": {"name": "San Francisco", "pos": Vector2(37.8, -122.4)},
	"tokyo": {"name": "Tokyo", "pos": Vector2(35.6, 139.8)},
	"manille": {"name": "Manille", "pos": Vector2(14.6, 121.0)},
	"honolulu": {"name": "Honolulu", "pos": Vector2(21.3, -157.9)},
	"mombasa": {"name": "Mombasa", "pos": Vector2(-4.0, 39.7)},
	"tromso": {"name": "Tromsø", "pos": Vector2(69.6, 18.9)},
}

## Engins. speed en km/h, fuel en heures, sonar en km (en patrouille).
const CRAFTS := {
	"barracuda": {"name": "Barracuda", "role": "intercepteur", "speed": 420, "fuel": 22, "hull": 60, "sonar": 650,
		"weapon": {"name": "Torpilles Mk-II", "damage": 16, "acc": 62}, "upkeep": 40},
	"triton": {"name": "Triton", "role": "transport", "speed": 220, "fuel": 240, "hull": 90, "sonar": 350, "seats": 4, "upkeep": 50},
}

## Sous-marins aliens. hull, attaque par passe (damage, acc), vitesse km/h.
const ALIEN_SUBS := {
	"eclaireur": {"name": "Éclaireur", "hull": 40, "damage": 8, "acc": 45, "speed": 380, "detect": 0.22},
	"moissonneur": {"name": "Moissonneur", "hull": 85, "damage": 13, "acc": 50, "speed": 300, "detect": 0.32},
	"cuirasse": {"name": "Cuirassé abyssal", "hull": 150, "damage": 19, "acc": 55, "speed": 260, "detect": 0.4},
}

## Opérations aliens autonomes : coût (budget alien), engin, effet si elles aboutissent sans réponse.
const ALIEN_OPS := {
	"reconnaissance": {"name": "Reconnaissance", "sub": "eclaireur", "cost": 30, "hours": [40, 70], "trust": -3, "threat": 1},
	"moisson": {"name": "Moisson côtière", "sub": "moissonneur", "cost": 55, "hours": [30, 50], "trust": -6, "threat": 2},
	"raid": {"name": "Raid portuaire", "sub": "moissonneur", "cost": 70, "hours": [26, 40], "trust": -12, "threat": 3},
}

## Missions terrain. map = carte tactique ; aliens = composition de base (la menace en ajoute).
const MISSIONS := {
	"nemesis": {"name": "Station Némésis", "map": "nemesis", "hours": 120, "brief": "Laboratoire sous-marin silencieux depuis 72 h. Récupérer l'artefact du bassin de confinement.",
		"loot": {"artefact": 1}, "win_trust": 6, "lose_trust": -8, "score": 40},
	"epave": {"name": "Épave alien", "map": "lab", "hours": 40, "brief": "Un sous-marin alien abattu repose sur le plateau. Neutraliser l'équipage, sécuriser la cargaison.",
		"loot": {"alliage": 3, "moteur_alien": 1}, "win_trust": 4, "lose_trust": -3, "score": 30},
	"port": {"name": "Port attaqué", "map": "port", "hours": 20, "brief": "Des créatures sont sorties de l'eau en plein port. Éliminer les assaillants avant qu'ils ne regagnent le large.",
		"loot": {"alliage": 1}, "win_trust": 10, "lose_trust": -15, "score": 45},
	"nid": {"name": "Le Nid", "map": "nid", "hours": 0, "brief": "Au fond de la fosse, la source du signal. Arracher le noyau du Nid et le ramener au sas.",
		"loot": {}, "win_trust": 20, "lose_trust": -10, "score": 150},
}

## Butin par créature tuée (corps récupérés si la mission est gagnée).
const CORPSES := {"nereide": "corps_nereide", "carapace": "corps_carapace", "spectre": "corps_spectre"}

const ITEMS := {
	"artefact": {"name": "Artefact Némésis", "kind": "alien", "sell": 0},
	"alliage": {"name": "Alliage abyssal", "kind": "alien", "sell": 30},
	"moteur_alien": {"name": "Propulseur alien", "kind": "alien", "sell": 120},
	"corps_nereide": {"name": "Corps de Néréide", "kind": "alien", "sell": 20},
	"corps_carapace": {"name": "Corps de Carapace", "kind": "alien", "sell": 30},
	"corps_spectre": {"name": "Corps de Spectre", "kind": "alien", "sell": 40},
	"rifle": {"name": "Fusil à fléchettes", "kind": "weapon"},
	"pistol": {"name": "Pistolet à gaz", "kind": "weapon"},
	"harpoon": {"name": "Harpon lourd", "kind": "weapon"},
	"harpoon_ap": {"name": "Harpon perforant", "kind": "weapon"},
	"cavitation": {"name": "Fusil à cavitation", "kind": "weapon"},
	"combinaison": {"name": "Combinaison de plongée", "kind": "armor", "armor": 0},
	"scaphandre": {"name": "Scaphandre composite", "kind": "armor", "armor": 6},
	"medkit": {"name": "Trousse médicale", "kind": "gear"},
	"grenade": {"name": "Grenade à choc", "kind": "gear"},
	"casque_psi": {"name": "Casque psi", "kind": "gear"},
}

const START_ITEMS := {"rifle": 2, "pistol": 2, "harpoon": 1, "combinaison": 8, "medkit": 4, "grenade": 4}

## Arbre de recherche réduit. cost = jours-scientifiques ; needs = objets consommés à l'analyse ;
## after = recherches préalables ; effect = ce qui change dans le jeu (lu par le moteur).
const RESEARCH := {
	"artefact_nemesis": {"name": "Analyse de l'artefact Némésis", "cost": 50, "needs": {"artefact": 1}, "after": [],
		"desc": "Un émetteur organique. Il répond à quelque chose, très loin et très profond."},
	"autopsie_nereide": {"name": "Autopsie : Néréide", "cost": 30, "needs": {"corps_nereide": 1}, "after": [],
		"desc": "Hors de l'eau, leurs branchies s'assèchent : visée +12 % contre les Néréides.", "effect": {"acc_vs": {"nereide": 12}}},
	"autopsie_carapace": {"name": "Autopsie : Carapace", "cost": 40, "needs": {"corps_carapace": 1}, "after": [],
		"desc": "Les plaques ont des jointures : fabrication du harpon perforant (ignore 8 d'armure).", "effect": {}},
	"autopsie_spectre": {"name": "Autopsie : Spectre", "cost": 45, "needs": {"corps_spectre": 1}, "after": [],
		"desc": "Une onde porteuse identifiable : fabrication du casque psi (immunité à l'épuisement).", "effect": {}},
	"alliages": {"name": "Alliages abyssaux", "cost": 45, "needs": {"alliage": 1}, "after": [],
		"desc": "Céramique métallique tressée : scaphandre composite et coque renforcée du Barracuda.", "effect": {}},
	"cavitation": {"name": "Armes à cavitation", "cost": 60, "needs": {}, "after": ["alliages", "autopsie_nereide"],
		"desc": "Le dard des Néréides projette une bulle d'implosion : fusil à cavitation.", "effect": {}},
	"signal_abyssal": {"name": "Signal abyssal", "cost": 40, "needs": {}, "after": ["artefact_nemesis"],
		"desc": "L'artefact relaie un signal. Le trianguler exige de comprendre leur propulsion.", "effect": {}},
	"propulsion": {"name": "Propulsion alien", "cost": 55, "needs": {"moteur_alien": 1}, "after": [],
		"desc": "Bulles de supercavitation : Barracuda +25 % de vitesse, et coque haute pression.", "effect": {"interceptor_speed": 1.25}},
	"triangulation": {"name": "Triangulation du Nid", "cost": 45, "needs": {}, "after": ["signal_abyssal", "propulsion"],
		"desc": "La source est localisée au fond de la fosse des Mariannes. Il faut y descendre.", "effect": {"reveal_nest": true}},
}

## Fabrication. hours = heures-ingénieurs ; cost en k ; mats = objets consommés ; after = recherche requise.
const MANUFACTURE := {
	"medkit": {"name": "Trousse médicale", "hours": 40, "cost": 12, "mats": {}, "after": ""},
	"grenade": {"name": "Grenade à choc", "hours": 30, "cost": 10, "mats": {}, "after": ""},
	"rifle": {"name": "Fusil à fléchettes", "hours": 60, "cost": 25, "mats": {}, "after": ""},
	"harpoon_ap": {"name": "Harpon perforant", "hours": 120, "cost": 60, "mats": {"alliage": 1}, "after": "autopsie_carapace"},
	"cavitation": {"name": "Fusil à cavitation", "hours": 160, "cost": 80, "mats": {"alliage": 1}, "after": "cavitation"},
	"scaphandre": {"name": "Scaphandre composite", "hours": 140, "cost": 70, "mats": {"alliage": 1}, "after": "alliages"},
	"casque_psi": {"name": "Casque psi", "hours": 90, "cost": 45, "mats": {}, "after": "autopsie_spectre"},
	"coque_renforcee": {"name": "Coque renforcée (Barracuda)", "hours": 160, "cost": 120, "mats": {"alliage": 2}, "after": "alliages", "craft_mod": ["barracuda", "hull", 40]},
	"coque_pression": {"name": "Coque haute pression (Triton)", "hours": 260, "cost": 220, "mats": {"alliage": 2}, "after": "propulsion", "craft_mod": ["triton", "deep", 1]},
}

## Salles de la base. cost k, days, power (+ produit / - consomme), cap = capacité, upkeep k/mois.
const ROOMS := {
	"commandement": {"name": "Centre de commandement", "cost": 0, "days": 0, "power": -2, "upkeep": 20, "cap": {}, "unique": true},
	"sonar": {"name": "Sonar", "cost": 150, "days": 10, "power": -2, "upkeep": 10, "cap": {"sonar": 2400}},
	"sonar_lp": {"name": "Sonar longue portée", "cost": 320, "days": 18, "power": -4, "upkeep": 20, "cap": {"sonar": 3600}, "after": "alliages"},
	"hangar": {"name": "Hangar", "cost": 200, "days": 14, "power": -2, "upkeep": 15, "cap": {"crafts": 1}},
	"laboratoire": {"name": "Laboratoire", "cost": 250, "days": 14, "power": -3, "upkeep": 25, "cap": {"scientists": 10}},
	"atelier": {"name": "Atelier", "cost": 220, "days": 12, "power": -3, "upkeep": 20, "cap": {"engineers": 10}},
	"dortoir": {"name": "Dortoir", "cost": 120, "days": 8, "power": -1, "upkeep": 8, "cap": {"beds": 14}},
	"infirmerie": {"name": "Infirmerie", "cost": 160, "days": 10, "power": -2, "upkeep": 12, "cap": {"heal": 1}},
	"stockage": {"name": "Stockage", "cost": 80, "days": 6, "power": 0, "upkeep": 4, "cap": {"storage": 60}},
	"reacteur": {"name": "Réacteur", "cost": 260, "days": 16, "power": 16, "upkeep": 10, "cap": {}},
	"confinement": {"name": "Confinement alien", "cost": 300, "days": 18, "power": -3, "upkeep": 20, "cap": {"cells": 4}, "after": "autopsie_nereide"},
}

## Base Neptune au départ (grille 6 × 4, [colonne, ligne] → salle). Les nouvelles salles touchent une salle existante.
const BASE_W := 6
const BASE_H := 4
const START_ROOMS := [
	[2, 1, "commandement"], [3, 1, "sonar"], [1, 1, "hangar"], [1, 2, "hangar"], [2, 2, "laboratoire"],
	[3, 2, "atelier"], [2, 0, "dortoir"], [3, 0, "stockage"], [4, 1, "reacteur"],
]

const STAFF := {
	"scientists": {"name": "Scientifiques", "hire": 40, "salary": 8, "start": 6},
	"engineers": {"name": "Ingénieurs", "hire": 40, "salary": 8, "start": 5},
}
const SOLDIER_SALARY := 6
const RECRUIT_COST := 50

## Grades : seuil d'expérience et gains à la promotion.
const RANKS := [
	{"name": "Recrue", "xp": 0}, {"name": "Plongeur", "xp": 3}, {"name": "Caporal", "xp": 8},
	{"name": "Sergent", "xp": 15}, {"name": "Lieutenant", "xp": 25}, {"name": "Capitaine", "xp": 40},
]
const PROMOTION_GAIN := {"acc": 3, "react": 3, "tu": 2, "hp": 2}

## Escouade de départ (ids s1..s4 = jeux de sprites et modèles existants).
const START_SOLDIERS := [
	{"id": "s1", "name": "Sgt. Walker", "visual": "s1", "weapon": "rifle", "acc": 68, "react": 58, "tu": 60, "hp": 36, "rank": 3, "xp": 15, "role": "Fusilier"},
	{"id": "s2", "name": "Okafor", "visual": "s2", "weapon": "harpoon", "acc": 60, "react": 40, "tu": 56, "hp": 42, "rank": 1, "xp": 4, "role": "Lourd"},
	{"id": "s3", "name": "Lind", "visual": "s3", "weapon": "rifle", "acc": 74, "react": 62, "tu": 58, "hp": 32, "rank": 1, "xp": 5, "role": "Précision"},
	{"id": "s4", "name": "Moreau", "visual": "s4", "weapon": "pistol", "acc": 64, "react": 70, "tu": 66, "hp": 32, "rank": 1, "xp": 3, "role": "Médecin", "medkit": 3},
]
const FIRST_NAMES := ["Ana", "Bastien", "Chen", "Dara", "Elif", "Farid", "Greta", "Hugo", "Ines", "Jonas", "Kaia", "Luis", "Mina", "Nils", "Oren", "Priya", "Rafael", "Saga", "Tomas", "Yara"]
const LAST_NAMES := ["Abara", "Berg", "Castillo", "Dubois", "Eze", "Fujita", "Galvão", "Halvorsen", "Ibrahim", "Jensen", "Kowalski", "Lemaire", "Mendes", "Nakamura", "Ortiz", "Petrov", "Quiroga", "Rahman", "Sato", "Varga"]

## Menace : 0 → 100. À 100 la campagne est perdue ; la réduire en frappant les opérations aliens.
const THREAT_START := 12
const THREAT_DAILY := 0.22
const ALIEN_BUDGET_DAILY := 9.0 # + menace/6 par jour
const LOSE_REGIONS := 3 # conseils retirés avant la défaite
const NEST := Vector2(11.4, 142.4)
