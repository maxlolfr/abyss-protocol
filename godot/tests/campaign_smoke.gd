extends SceneTree
## Campagne complète jouée par un joueur automatique simple (combats joués par l'IA d'escouade) :
## godot --headless --path . -s res://tests/campaign_smoke.gd -- [nombre de campagnes]
## Vérifie que la boucle géoscape → combat → recherche → fabrication → Nid se termine.

const ORDER := ["artefact_nemesis", "autopsie_nereide", "alliages", "propulsion", "signal_abyssal", "triangulation", "autopsie_carapace", "cavitation", "autopsie_spectre"]
var perfect := false
const BUILD := ["coque_pression", "scaphandre", "coque_renforcee", "cavitation", "medkit"]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 6
	perfect = a.size() > 1 and a[1] == "parfait" # combats gagnés sans perte : plafond stratégique
	var won := 0
	for i in n:
		var r := play("smoke%d" % i)
		print("  raison : ", r.reason, " | tri=", r._craft_of_type("triton"), " | sites=", r.sites.map(func(x): return x["kind"]), " | alliage=", r.items.get("alliage"), " moteur=", r.items.get("moteur_alien"), " | prod=", r.production, " | prêts=", r.squad().size(), " | expirées=", r.journal.filter(func(e): return e["text"].begins_with("Mission abandonnée")).size())
		print("campagne %d : %s · %s · %d missions (%d gagnées) · %d interceptions · %d morts · menace %d · fonds %d" % [i, r.outcome, r.date_text(), r.stats["missions"], r.stats["won"], r.stats["intercepts"], r.stats["dead"], int(r.threat), r.funds])
		if r.outcome == "victory":
			won += 1
	print("Campagnes gagnées : %d / %d" % [won, n])
	quit()

func play(seed: String) -> AbyssCampaign:
	var c := AbyssCampaign.new(seed)
	var guard := 0
	while c.outcome == "ongoing" and c.minutes < 1440 * 240 and guard < 20000:
		guard += 1
		_decide(c)
		if c.pending.get("type", "") == "intercept":
			c.apply({"type": "engage" if int(c.pending["odds"]) >= 45 else "disengage"})
		elif c.pending.get("type", "") == "assault":
			var site_id: String = c.pending["site"]
			var cf := c.mission_config(site_id)
			if cf.is_empty():
				c.pending = {}
				continue
			var b := AbyssBattle.new(cf["seed"], cf["map"], cf["squad"], cf["aliens"], cf["mods"])
			var ev: Array = []
			while b.outcome == "ongoing" and b.turn < 30:
				AbyssAI.run(b, true, ev)
				if b.outcome == "ongoing":
					b.apply({"type": "end_turn"})
			var res := b.result()
			if perfect:
				res["outcome"] = "victory"
				res["kills"] = {}
				for k in cf["aliens"]:
					res["kills"][k] = int(res["kills"].get(k, 0)) + 1
				for sr in res["soldiers"]:
					sr["alive"] = true
					sr["hp"] = sr["max_hp"]
			c.apply_result(site_id, res)
		else:
			c.advance(360)
	return c

func _decide(c: AbyssCampaign) -> void:
	# recherche : une à la fois, dans l'ordre utile
	if c.research.is_empty():
		for id in ORDER:
			if c.can_research(id) == "":
				c.apply({"type": "research", "id": id})
				break
	if c.production.is_empty():
		for id in BUILD:
			if c.can_manufacture(id) == "" and c.funds > 400 and int(c.items.get(id, 0)) < (8 if id == "medkit" else 99):
				c.apply({"type": "manufacture", "id": id})
				break
	# équipement : meilleures armures et armes disponibles
	for s in c.soldiers:
		if s["status"] == "dead":
			continue
		if s["armor"] != "scaphandre" and int(c.items.get("scaphandre", 0)) > 0:
			c.apply({"type": "equip", "id": s["id"], "slot": "armor", "item": "scaphandre"})
		if s["weapon"] == "rifle" and int(c.items.get("cavitation", 0)) > 0:
			c.apply({"type": "equip", "id": s["id"], "slot": "weapon", "item": "cavitation"})
	# effectifs
	while c.soldiers.filter(func(s): return s["status"] != "dead").size() < 6 and c.funds > 300 and not c.recruits.is_empty():
		var before := c.soldiers.size()
		c.apply({"type": "recruit", "index": 0})
		if c.soldiers.size() == before:
			break
	# engins : le Triton va aux missions, le Barracuda chasse
	var tri := c._craft_of_type("triton")
	if tri["state"] == "base" and not c.squad().is_empty():
		for s in c.sites:
			if not s.get("deep", false) or tri.get("deep", false):
				c.apply({"type": "send", "craft": tri["id"], "site": s["id"]})
				break
	var bar := c._craft_of_type("barracuda")
	if not bar.is_empty() and bar["state"] == "base":
		for k in c.contacts:
			if k["detected"] and AbyssGeo.dist_km(k["pos"], StratData.BASE_POS) < 4000 and c.intercept_odds(bar["id"], k["id"]) >= 45:
				c.apply({"type": "send", "craft": bar["id"], "contact": k["id"]})
				break
