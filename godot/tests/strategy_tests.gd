extends SceneTree
## Tests de la campagne (géoscape, base, recherche, soldats) : godot --headless --path . -s res://tests/strategy_tests.gd

var passed := 0
var failed := 0

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("ÉCHEC : ", label)

## Avance du temps en répondant aux décisions comme un joueur pressé (rompre, annuler l'assaut).
func run(c: AbyssCampaign, mins: int) -> void:
	var end := c.minutes + mins
	var guard := 0
	while c.minutes < end and c.outcome == "ongoing" and guard < 1000:
		guard += 1
		if c.pending.get("type", "") == "intercept":
			c.apply({"type": "disengage"})
		elif c.pending.get("type", "") == "assault":
			c.apply({"type": "assault_cancel"})
		c.advance(end - c.minutes)

func _init() -> void:
	var D := StratData
	# géométrie
	var lis := Vector2(38.7, -9.1)
	var ny := Vector2(40.7, -74.0)
	check(absf(AbyssGeo.dist_km(lis, ny) - 5420.0) < 60.0, "Lisbonne – New York ≈ 5 420 km")
	var mid := AbyssGeo.step_toward(lis, ny, 1000.0)
	check(absf(AbyssGeo.dist_km(lis, mid) - 1000.0) < 2.0, "avance de 1 000 km sur le grand cercle")
	check(AbyssGeo.step_toward(lis, ny, 9000.0) == ny, "s'arrête sur la destination")
	check(absf(AbyssGeo.dist_km(AbyssGeo.from_vec(AbyssGeo.to_vec(ny)), ny)) < 0.5, "conversion lat/lon ↔ vecteur")

	# départ
	var c := AbyssCampaign.new("test")
	check(c.funds == D.START_FUNDS and c.soldiers.size() == 4 and c.crafts.size() == 2, "fonds, 4 soldats, Barracuda + Triton")
	check(c.site_of_kind("nemesis").size() > 0, "Némésis est la première mission")
	check(c.region_of(D.BASE_POS) == "atl_nord", "Neptune est en Atlantique Nord")
	check(c.trench_at(D.NEST) == "mariannes", "le Nid est dans la fosse des Mariannes")
	check(c.power() >= 0, "la base de départ a assez d'énergie")
	check(c.capacity("scientists") == 10 and c.capacity("crafts") == 2, "capacités de départ")
	check(c.build_error(5, 3, "laboratoire") != "", "construction isolée refusée")
	check(c.build_error(2, 1, "laboratoire") != "", "emplacement occupé refusé")
	check(c.build_error(0, 1, "infirmerie") == "", "construction adjacente acceptée")
	var f0 := c.funds
	c.apply({"type": "build", "x": 0, "y": 1, "room": "infirmerie"})
	check(c.funds == f0 - int(D.ROOMS["infirmerie"]["cost"]) and c.room_count("infirmerie") == 0, "chantier payé, salle pas encore prête")

	# assaut sur Némésis : le Triton part, arrive, la décision bloque le temps
	var nem := c.site_of_kind("nemesis")
	var tri := c._craft_of_type("triton")
	c.apply({"type": "send", "craft": tri["id"], "site": nem["id"]})
	check(tri["state"] == "outbound", "le Triton appareille")
	var ev := c.advance(60 * 48)
	check(c.pending.get("type", "") == "assault", "arrivée sur zone : décision d'assaut")
	var t_arr := c.minutes
	c.advance(600)
	check(c.minutes == t_arr, "le temps est bloqué tant que la décision attend")
	var cfg := c.mission_config(nem["id"])
	check(cfg["map"] == "nemesis" and cfg["squad"].size() == 4, "configuration du combat : carte + escouade")

	# le combat tactique réel, joué par l'IA, puis ses conséquences
	var b := AbyssBattle.new(cfg["seed"], cfg["map"], cfg["squad"], cfg["aliens"], cfg["mods"])
	check(b.living(true).size() == 4 and b.unit("s1").name == "Sgt. Walker", "le combat reçoit l'escouade de la campagne")
	var e2: Array = []
	while b.outcome == "ongoing" and b.turn < 30:
		AbyssAI.run(b, true, e2)
		if b.outcome == "ongoing":
			b.apply({"type": "end_turn"})
	var res := b.result()
	check(res["soldiers"].size() == 4 and res.has("kills"), "résultat de combat exploitable")
	c.apply_result(nem["id"], res)
	check(c.site_of_kind("nemesis").is_empty() and c.pending.is_empty(), "mission close, Triton rappelé")
	check(c.stats["missions"] == 1, "mission comptée")

	# résultat construit à la main : mort, blessure, promotion, butin
	var c2 := AbyssCampaign.new("test2")
	var s2 := c2.site_of_kind("nemesis")
	var walker_acc := int(c2.soldier("s1")["acc"])
	c2.apply_result(s2["id"], {"outcome": "victory", "artifact": true, "kills": {"nereide": 1, "carapace": 1}, "soldiers": [
		{"id": "s1", "alive": true, "hp": 36, "max_hp": 36, "kills": 4, "wounds": 0},
		{"id": "s2", "alive": false, "hp": 0, "max_hp": 42, "kills": 0},
		{"id": "s3", "alive": true, "hp": 12, "max_hp": 32, "kills": 0, "wounds": 1},
		{"id": "s4", "alive": true, "hp": 32, "max_hp": 32, "kills": 0}]})
	check(c2.soldier("s2")["status"] == "dead", "mort définitive")
	check(c2.soldier("s3")["status"] == "wounded" and int(c2.soldier("s3")["wound_until"]) > c2.minutes, "blessure = jours d'infirmerie")
	check(int(c2.soldier("s1")["rank"]) == 4 and int(c2.soldier("s1")["acc"]) == walker_acc + 3, "promotion au grade suivant avec gains")
	check(int(c2.items.get("artefact", 0)) == 1 and int(c2.items.get("corps_nereide", 0)) == 1, "artefact et corps récupérés")
	check(c2.squad().size() == 2, "seuls les soldats prêts embarquent")

	# recherche → fabrication
	check(c2.can_research("artefact_nemesis") == "", "l'artefact peut être analysé")
	check(c2.can_research("signal_abyssal") != "", "le signal attend l'analyse")
	c2.apply({"type": "research", "id": "artefact_nemesis"})
	check(int(c2.items["artefact"]) == 0 and c2.busy_scientists() == 6, "artefact consommé, scientifiques affectés")
	run(c2, 1440 * 9)
	check(c2.has_research("artefact_nemesis"), "recherche terminée en ~9 jours avec 6 scientifiques")
	c2.items["alliage"] = 3
	c2.apply({"type": "research", "id": "alliages"})
	run(c2, 1440 * 9)
	check(c2.soldier("s3")["status"] == "ready", "le blessé est rétabli après ~15 jours sans infirmerie")
	check(c2.has_research("alliages") and c2.can_manufacture("scaphandre") == "", "alliages → scaphandre fabricable")
	c2.apply({"type": "manufacture", "id": "scaphandre"})
	run(c2, 1440 * 3)
	check(int(c2.items.get("scaphandre", 0)) == 1, "scaphandre fabriqué par 5 ingénieurs")
	c2.apply({"type": "equip", "id": "s1", "slot": "armor", "item": "scaphandre"})
	check(c2.soldier("s1")["armor"] == "scaphandre" and int(c2.items["combinaison"]) >= 1, "équipement échangé avec le stock")
	var ep := c2._add_site("epave", Vector2(40, -30), 600, ["nereide"])
	var cf: Dictionary = c2.mission_config(ep["id"])
	check(cf["squad"].filter(func(q): return q["id"] == "s1")[0]["armor"] == 6, "l'armure passe au combat")
	check(cf["mods"]["acc_vs"].is_empty(), "pas de bonus sans autopsie")

	# nid : triangulation → site abyssal, inaccessible sans coque haute pression
	c2.research_done.append_array(["signal_abyssal", "propulsion"])
	c2.apply({"type": "research", "id": "triangulation"})
	run(c2, 1440 * 9)
	var nid := c2.site_of_kind("nid")
	check(not nid.is_empty() and nid["deep"], "le Nid est révélé en zone abyssale")
	var ev2 := c2.apply({"type": "send", "craft": c2._craft_of_type("triton")["id"], "site": nid["id"]})
	check(ev2.size() == 1 and ev2[0]["t"] == "error", "coque haute pression requise")

	# rapport mensuel et sauvegarde
	var c3 := AbyssCampaign.new("mois")
	var reports := 0
	var contacts := 0
	var guard := 0
	while c3.minutes < 1440 * 32 and guard < 400:
		guard += 1
		var evs := c3.advance(1440)
		for e in evs:
			if e["t"] == "report":
				reports += 1
			if e["t"] == "contact":
				contacts += 1
		if c3.pending.size() > 0:
			c3.pending = {}
	check(reports == 1, "un rapport du conseil en fin de mois")
	check(contacts >= 1, "le sonar détecte des activités aliens dans le mois")
	var copy := AbyssCampaign.from_dict(JSON.parse_string(JSON.stringify(c3.to_dict())))
	check(copy != null and copy.minutes == c3.minutes and copy.funds == c3.funds, "sauvegarde relue")
	c3.advance(1440 * 3)
	copy.advance(1440 * 3)
	check(copy.minutes == c3.minutes and copy.contacts.size() == c3.contacts.size() and absf(copy.threat - c3.threat) < 0.01, "même partie après rechargement")

	# interception
	var c4 := AbyssCampaign.new("chasse")
	var k := c4._new_op("reconnaissance")
	k["detected"] = true
	k["pos"] = AbyssGeo.offset(D.BASE_POS, 90, 800)
	k["dest"] = AbyssGeo.offset(k["pos"], 90, 3000)
	var bar := c4._craft_of_type("barracuda")
	var odds := c4.intercept_odds(bar["id"], k["id"])
	check(odds > 40 and odds <= 100, "chances d'interception lisibles (%d %%)" % odds)
	c4.apply({"type": "send", "craft": bar["id"], "contact": k["id"]})
	c4.advance(60 * 24)
	check(c4.pending.get("type", "") == "intercept", "l'intercepteur rattrape le contact")
	var r := c4.apply({"type": "engage"})
	check(r.size() >= 1 and c4.pending.is_empty(), "interception résolue")

	# défaite
	var c5 := AbyssCampaign.new("fin")
	c5.threat = 99.9
	c5.advance(1440)
	check(c5.outcome == "defeat", "menace à 100 : campagne perdue")

	print("Tests campagne : %d réussis, %d échoués" % [passed, failed])
	quit(1 if failed else 0)
