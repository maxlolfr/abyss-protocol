extends SceneTree
## Tests de la simulation (sans écran) : godot --headless --path . -s res://tests/run_tests.gd

var passed := 0
var failed := 0

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("ÉCHEC : ", label)

func _init() -> void:
	var b := AbyssBattle.new("t")
	var g := b.grid
	check(b.living(true).size() == 4 and b.living(false).size() == 3, "4 soldats et 3 aliens")
	check(g.z(Vector2i(10, 2)) == 1.0 and g.z(Vector2i(8, 4)) == 0.5, "deux niveaux + escalier")
	var s1 := b.unit("s1")
	check(g.step_cost(Vector2i(3, 3), Vector2i(4, 3), s1, {}) == 6.0, "pas orthogonal 6 UT")
	check(g.step_cost(Vector2i(1, 3), Vector2i(2, 4), s1, {}) == 8.0, "pas diagonal 8 UT")
	check(g.step_cost(Vector2i(7, 4), Vector2i(8, 4), s1, {}) == 6.0, "monter sur l'escalier")
	check(g.step_cost(Vector2i(10, 5), Vector2i(10, 4), s1, {}) == INF, "pas de saut de 1 m depuis le sol")
	check(g.step_cost(Vector2i(13, 7), Vector2i(13, 8), s1, {}) == 10.0, "eau +4 UT")
	# ligne de vue et couverture
	check(not g.line_clear(Vector2i(5, 1), 1.5, Vector2i(7, 1), 1.0), "la cloison bloque la vue")
	check(g.line_clear(Vector2i(5, 3), 1.5, Vector2i(7, 3), 1.0), "la caisse ne bloque pas la vue")
	check(g.cover_against(Vector2i(4, 4), Vector2i(4, 9)) == 0, "pas de couvert en terrain ouvert")
	check(g.cover_against(Vector2i(7, 3), Vector2i(1, 3)) == 1, "caisse = couvert partiel")
	check(g.cover_against(Vector2i(7, 3), Vector2i(1, 3), true) == 2, "à genoux derrière une caisse = couvert total")
	check(g.cover_against(Vector2i(7, 1), Vector2i(1, 1)) == 2, "cloison = couvert total")
	# zone atteignable = coût débité
	var r := b.reach(s1)
	var to := Vector2i(4, 3)
	var cost: float = r["cost"].get(g.idx(to), -1.0)
	var before := s1.tu
	b.apply({"type": "move", "unit": "s1", "to": to})
	check(cost > 0 and s1.tu == before - int(r["cost"][g.idx(s1.cell)]), "déplacement : UT débitées = coût de la zone atteignable")
	# murs destructibles
	var b2 := AbyssBattle.new("mur")
	var ok := b2.grid.damage_wall(Vector2i(6, 1), 44)
	check(ok and b2.grid.tile(Vector2i(6, 1)) == AbyssGrid.T.RUBBLE and b2.grid.standable(Vector2i(6, 1)), "le harpon (44) abat une cloison (40 PV)")
	check(not b2.grid.damage_wall(Vector2i(0, 1), 999), "la coque est indestructible")
	var ok2 := b2.unit("s2")
	ok2.cell = Vector2i(4, 1)
	var ev := b2.apply({"type": "breach", "unit": "s2", "at": Vector2i(6, 2)})
	check(ev.any(func(e): return e["t"] == "destroy"), "commande de brèche au harpon")
	var b3 := AbyssBattle.new("gren")
	b3.unit("s1").cell = Vector2i(3, 5)
	var ev3 := b3.apply({"type": "throw", "unit": "s1", "to": Vector2i(3, 6)})
	check(ev3.filter(func(e): return e["t"] == "destroy").size() >= 3, "la grenade abat plusieurs cloisons")
	# tir plongeant
	var b4 := AbyssBattle.new("haut")
	var sp: AbyssUnit = b4.living(false).filter(func(u): return u.kind == "spectre")[0]
	var sol := b4.unit("s1")
	sol.cell = Vector2i(10, 6)
	var high := b4.shot_info(sp, sol, "snap")
	check(high["error"] == "" and high["chance"] > 0, "le Spectre tire depuis la passerelle")
	# réaction en surveillance
	var b5 := AbyssBattle.new("watch")
	var w := b5.unit("s3")
	w.cell = Vector2i(5, 9)
	b5.apply({"type": "watch", "unit": "s3"})
	b5.alert = true
	b5.last_known["s3"] = w.cell
	var ev5 := b5.apply({"type": "end_turn"})
	check(ev5.any(func(e): return e["t"] == "shot"), "le tour alien produit des tirs")
	# déterminisme
	var x := AbyssBattle.new("det")
	var y := AbyssBattle.new("det")
	for bb in [x, y]:
		bb.apply({"type": "move", "unit": "s3", "to": Vector2i(2, 5)})
		bb.apply({"type": "end_turn"})
		bb.apply({"type": "end_turn"})
	check(x.snapshot() == y.snapshot(), "même seed + mêmes commandes = même partie")
	# objectifs, soin, munitions, brouillard, sauvegarde
	var o := AbyssBattle.new("obj")
	var c1 := o.unit("s1")
	check(o.explored.count(1) > 0 and o.explored[o.grid.idx(Vector2i(13, 12))] == 0, "brouillard : sas vu, fond du labo inconnu")
	c1.cell = o.artifact + Vector2i(-1, 0)
	var evp := o.apply({"type": "interact", "unit": "s1"})
	check(c1.carrying and evp.any(func(e): return e["t"] == "alarm"), "prendre l'artefact déclenche l'alarme")
	c1.cell = o.evac[0]
	o.apply({"type": "evacuate"})
	check(o.outcome == "victory", "évacuer l'artefact = victoire")
	var rt := AbyssBattle.new("retraite")
	rt.apply({"type": "evacuate"})
	check(rt.outcome == "defeat", "évacuer sans l'artefact = retraite")
	var tm := AbyssBattle.new("terminal")
	var lnd := tm.unit("s3")
	lnd.cell = tm.terminal + Vector2i(-1, 0)
	tm.apply({"type": "interact", "unit": "s3"})
	check(tm.logs_done, "journal téléchargé depuis la passerelle")
	var md := AbyssBattle.new("soin")
	var mo := md.unit("s4")
	var wk := md.unit("s1")
	wk.hp = 10; wk.wounds = 2
	mo.cell = wk.cell + Vector2i(1, 1)
	md.apply({"type": "heal", "unit": "s4", "target": "s1"})
	check(wk.hp == 24 and wk.wounds == 0 and mo.medkit == 2, "kit médical : +14 PV, blessures soignées")
	var am := AbyssBattle.new("ammo")
	var ok3 := am.unit("s2")
	ok3.ammo = 0
	var tgt: AbyssUnit = am.living(false)[0]
	check(am.shot_info(ok3, tgt, "snap")["error"].begins_with("Chargeur"), "chargeur vide : tir impossible")
	am.apply({"type": "reload", "unit": "s2"})
	check(ok3.ammo == 4 and ok3.tu == 56 - AbyssData.RELOAD_TU, "rechargement : 8 UT")
	var sv := AbyssBattle.new("save")
	sv.apply({"type": "move", "unit": "s3", "to": Vector2i(2, 5)})
	sv.apply({"type": "end_turn"})
	var copy := AbyssBattle.from_dict(JSON.parse_string(JSON.stringify(sv.to_dict())))
	for bb in [sv, copy]:
		bb.apply({"type": "end_turn"})
		bb.apply({"type": "end_turn"})
	check(copy.snapshot() == sv.snapshot(), "sauvegarde puis reprise = même suite de partie")
	# carte Némésis : structure, accès aux objectifs, sauvegarde
	var nm := AbyssBattle.new("nem", "nemesis")
	check(nm.map_id == "nemesis" and nm.living(true).size() == 4 and nm.living(false).size() == 3, "Némésis : 4 soldats, 3 aliens")
	var walker := nm.unit("s1")
	var rr := nm.grid.reach(walker, 9999, {})
	check(rr["cost"].has(nm.grid.idx(nm.artifact + Vector2i(1, 0))), "Némésis : la cuve de l'artefact est accessible")
	check(rr["cost"].has(nm.grid.idx(nm.terminal + Vector2i(1, 0))), "Némésis : le terminal de la mezzanine est accessible par l'escalier")
	check(rr["cost"].has(nm.grid.idx(Vector2i(2, 2))), "Némésis : la mezzanine ouest est accessible")
	check(AbyssBattle.from_dict(JSON.parse_string(JSON.stringify(nm.to_dict()))).map_id == "nemesis", "Némésis : la sauvegarde garde la carte")
	# Némésis : l'alarme fait surgir une Néréide de renfort
	var rf := AbyssBattle.new("renfort", "nemesis")
	var car := rf.unit("s1")
	car.cell = rf.artifact + Vector2i(1, 0)
	var evr := rf.apply({"type": "interact", "unit": "s1"})
	check(evr.any(func(x): return x["t"] == "spawn") and rf.living(false).size() == 4, "Némésis : premier renfort à l'alarme")
	rf.apply({"type": "end_turn"})
	check(not rf.units.any(func(x): return x.id == "r2"), "Némésis : le second renfort n'arrive pas tout de suite")
	rf.apply({"type": "end_turn"})
	check(rf.units.any(func(x): return x.id == "r2"), "Némésis : second renfort deux tours après l'alarme")
	var el := AbyssBattle.new("elim", "nemesis")
	for u in el.living(false):
		u.alive = false
	el._check_outcome([])
	check(el.outcome == "ongoing", "Némésis : éliminer les hostiles ne suffit pas")
	check(AbyssBattle.from_dict(JSON.parse_string(JSON.stringify(rf.to_dict()))).units.size() == rf.units.size(), "Némésis : les renforts sont sauvegardés")
	var nwins := 0
	var nends := 0
	for i in 12:
		var g3 := AbyssBattle.new("nsim%d" % i, "nemesis")
		var e3: Array = []
		while g3.outcome == "ongoing" and g3.turn < 30:
			AbyssAI.run(g3, true, e3)
			if g3.outcome == "ongoing":
				g3.apply({"type": "end_turn"})
		nends += int(g3.outcome != "ongoing")
		nwins += int(g3.outcome == "victory")
	print("Némésis IA contre IA : %d/12 victoires, %d/12 terminées" % [nwins, nends])
	check(nends >= 10, "Némésis : les parties IA contre IA se terminent")
	# IA contre IA : les parties se terminent
	var t0 := Time.get_ticks_msec()
	var wins := 0
	var n := 16
	var ends := 0
	for i in n:
		var g2 := AbyssBattle.new("sim%d" % i)
		var e2: Array = []
		while g2.outcome == "ongoing" and g2.turn < 30:
			AbyssAI.run(g2, true, e2)
			if g2.outcome == "ongoing":
				g2.apply({"type": "end_turn"})
		if g2.outcome != "ongoing":
			ends += 1
		if g2.outcome == "victory":
			wins += 1
	print("durée IA : %d ms" % (Time.get_ticks_msec() - t0))
	print("IA contre IA : %d/%d victoires de l'escouade, %d/%d parties terminées" % [wins, n, ends, n])
	check(ends >= n - 2, "les parties IA contre IA se terminent")
	print("Tests : %d réussis, %d échoués" % [passed, failed])
	quit(1 if failed else 0)
