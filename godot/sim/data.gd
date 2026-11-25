class_name AbyssData
## Contenu et équilibrage (repris de la référence TypeScript src/sim/data.ts).

const MOVE_ORTHO := 6
const MOVE_DIAG := 8
const WATER_EXTRA := 4
const RUBBLE_EXTRA := 2
const KNEEL_TU := 4
const KNEEL_ACC := 10
const WATCH_TU := 18
const GRENADE_TU := 18
const GRENADE_RANGE := 10
const GRENADE_DAMAGE := 45
const GRENADE_FALLOFF := 12
const GRENADE_RADIUS := 2
const RELOAD_TU := 8
const MEDKIT_TU := 12
const MEDKIT_HEAL := 14
const INTERACT_TU := 10
const WALL_HP := 40
const COVER_PENALTY := [0, 20, 45]
const HEIGHT_BONUS := 10 # tir plongeant : +10 % et couverture réduite d'un cran
const RANGE_FROM := 7
const WOUND_THRESHOLD := 12
const WOUND_PENALTY := 5
const MIN_CHANCE := 5
const MAX_CHANCE := 95
const EYE := 1.5 # hauteur des yeux au-dessus du sol de la case
const BODY := 1.0
const WALL_H := 1.8 # au-dessus de l'œil (1,5) : bloque la vue au sol, mais on tire PAR-DESSUS depuis la passerelle

const WEAPONS := {
	"rifle": {"name": "Fusil à fléchettes", "mag": 10, "damage": 26, "range": 14, "snap": [12, 62], "aimed": [24, 108], "breach": false},
	"pistol": {"name": "Pistolet à gaz", "mag": 12, "damage": 20, "range": 9, "snap": [9, 70], "aimed": [18, 92], "breach": false},
	"harpoon": {"name": "Harpon lourd", "mag": 4, "damage": 44, "range": 12, "snap": [16, 50], "aimed": [30, 102], "breach": true},
	"harpoon_ap": {"name": "Harpon perforant", "mag": 4, "damage": 44, "range": 12, "snap": [16, 50], "aimed": [30, 102], "breach": true, "pierce": 8},
	"cavitation": {"name": "Fusil à cavitation", "mag": 8, "damage": 34, "range": 14, "snap": [13, 64], "aimed": [26, 106], "breach": false, "pierce": 4},
	"dart": {"name": "Lance-dard", "damage": 24, "range": 12, "snap": [14, 60], "aimed": [26, 98], "breach": false},
	"acid": {"name": "Jet corrosif", "damage": 34, "range": 6, "snap": [18, 82], "aimed": [], "breach": false},
	"psi": {"name": "Onde psychique", "damage": 15, "range": 9, "snap": [20, 85], "aimed": [], "breach": false, "ignores_cover": true, "drain": 20},
}

const UNITS := {
	"soldier": {"name": "Plongeur", "hp": 34, "tu": 60, "acc": 66, "react": 55, "armor": 4, "weapon": "rifle", "vision": 12, "role": "soldier"},
	"nereide": {"name": "Néréide", "hp": 44, "tu": 64, "acc": 68, "react": 55, "armor": 3, "weapon": "dart", "vision": 11, "role": "flanker", "amphibious": true},
	"carapace": {"name": "Carapace", "hp": 90, "tu": 52, "acc": 62, "react": 35, "armor": 10, "weapon": "acid", "vision": 10, "role": "brute"},
	"spectre": {"name": "Spectre", "hp": 34, "tu": 66, "acc": 80, "react": 45, "armor": 0, "weapon": "psi", "vision": 11, "role": "psychic", "hover": true},
}

## Prototype Godot : 3 aliens seulement (demande de Max), donc plus résistants que dans la référence TS (6 aliens).
const SQUAD := [
	{"id": "s1", "name": "Sgt. Walker", "medkit": 0, "weapon": "rifle", "acc": 68, "react": 58, "tu": 60, "hp": 36, "grenades": 1},
	{"id": "s2", "name": "Okafor", "medkit": 0, "weapon": "harpoon", "acc": 60, "react": 40, "tu": 56, "hp": 42, "grenades": 0},
	{"id": "s3", "name": "Lind", "medkit": 0, "weapon": "rifle", "acc": 74, "react": 62, "tu": 58, "hp": 32, "grenades": 0},
	{"id": "s4", "name": "Moreau", "medkit": 3, "weapon": "pistol", "acc": 64, "react": 70, "tu": 66, "hp": 32, "grenades": 0},
]

## X : coque (indestructible)  # : cloison (destructible)  c/k : caisse au sol / sur la passerelle
## = : passerelle (niveau 1)  / : escalier (niveau 0,5)  ~ : eau  S : soldat
## N, C, P : Néréide, Carapace, Spectre (P sur la passerelle)
## E : sas d'évacuation  D : artefact (objectif principal)  T : terminal sur la passerelle (objectif secondaire)
const LAB := [
	"XXXXXXXXXXXXXXXX",
	"XSES..#..===T==X",
	"XEEE..#..====P=X",
	"XSES..c..======X",
	"X..c....//=====X",
	"X.......#......X",
	"X####.###..c...X",
	"X.....#.....~~.X",
	"X..c..#..c..~~.X",
	"X.....#.....~~.X",
	"X..N..###.###..X",
	"X....D...c.....X",
	"X..c....C......X",
	"XXXXXXXXXXXXXXXX",
]

## Mission Némésis (référence ENV-007) : salle de confinement, cuve centrale (artefact D), mezzanines
## symétriques reliées par deux escaliers, terminal sur la mezzanine est, bassins techniques à l'avant,
## sas d'entrée au sud. Spectre sur la mezzanine ouest, Carapace près de la cuve, Néréide dans le bassin est.
const NEMESIS := [
	"XXXXXXXXXXXXXXXX",
	"X=k=..cD.c..=T=X",
	"X=P=....C...===X",
	"X===..#..#..===X",
	"X===.c.....c===X",
	"X./..c....c../.X",
	"X...c..##..c...X",
	"X~~..........~NX",
	"X~~..........~~X",
	"X..c...#.#..c..X",
	"X.....SES......X",
	"X.....EEE......X",
	"X.....SES......X",
	"XXXXXXXXXXXXXXXX",
]

## Port attaqué (campagne) : bassin portuaire au nord d'où les créatures sont sorties, conteneurs,
## entrepôt central ouvert au sud, débarquement de l'escouade au sud-ouest. Élimination.
const PORT := [
	"XXXXXXXXXXXXXXXX",
	"X~~~~~~~~~~~~~~X",
	"X~~~~~~~N~~~~~~X",
	"X~~~...~~~~~~~~X",
	"X.....c....c...X",
	"X.c......N...c.X",
	"X.....###.###..X",
	"X..c..#.....#..X",
	"X.....#..C..#..X",
	"X.c...##...##..X",
	"X..........c...X",
	"XSES..c........X",
	"XEEE.....c...c.X",
	"XSES...........X",
	"XXXXXXXXXXXXXXXX",
]

## Le Nid (fin de la campagne courte) : caverne organique, noyau (D) entre deux bassins,
## corniches gardées par un Spectre, Néréides dans les mares. Arracher le noyau et le ramener au sas.
const NID := [
	"XXXXXXXXXXXXXXXX",
	"X=P==..~D~..==kX",
	"X====.~~~~~.===X",
	"X./..c....c../.X",
	"X...#..C....#..X",
	"X~~.#.....c.#~~X",
	"X~N..........N~X",
	"X..c..#..#..c..X",
	"X.....#..#.....X",
	"X..c........c..X",
	"X.....SES......X",
	"X.....EEE......X",
	"X.....SES......X",
	"XXXXXXXXXXXXXXXX",
]

const MAPS := {"lab": LAB, "nemesis": NEMESIS, "port": PORT, "nid": NID}

## Éliminer tous les hostiles suffit-il ? Non sur Némésis : seule l'extraction de l'artefact compte
## (la cuve contaminée réveille des renforts à la prise).
const ELIMINATION_WINS := {"lab": true, "nemesis": false, "port": true, "nid": false}

## Renforts déclenchés par l'alarme (prise de l'artefact) : [type, cases possibles par ordre de préférence,
## retard (0 = à l'alarme, 1 = au début du tour alien qui suit)].
## Ils coupent la retraite vers le sas : bassin ouest et bassin est.
const REINFORCEMENTS := {
	"nemesis": [
		["nereide", [Vector2i(1, 7), Vector2i(2, 7), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8)], 0],
		["nereide", [Vector2i(13, 8), Vector2i(14, 8), Vector2i(12, 8), Vector2i(12, 7)], 2],
	],
	"nid": [
		["nereide", [Vector2i(1, 5), Vector2i(2, 5), Vector2i(1, 6)], 0],
		["carapace", [Vector2i(13, 5), Vector2i(14, 5), Vector2i(14, 6)], 1],
		["spectre", [Vector2i(14, 2), Vector2i(13, 1)], 2],
	],
}
