extends SceneTree
## Banc d'équilibrage : N parties IA contre IA sur une carte.
## godot --headless --path godot -s res://tests/balance.gd -- [parties=40] [carte=nemesis]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var map := args[1] if args.size() > 1 else "nemesis"
	var wins := 0
	var ends := 0
	var turns := 0
	var lost := 0
	var dead_aliens := 0
	for i in n:
		var g := AbyssBattle.new("bal%d" % i, map)
		var ev: Array = []
		while g.outcome == "ongoing" and g.turn < 30:
			AbyssAI.run(g, true, ev)
			if g.outcome == "ongoing":
				g.apply({"type": "end_turn"})
		ends += int(g.outcome != "ongoing")
		wins += int(g.outcome == "victory")
		turns += g.turn
		for u in g.units:
			if not u.alive:
				if u.human: lost += 1
				else: dead_aliens += 1
	print("%s : %d/%d victoires (%d %%), %d terminées, %.1f tours, %.1f soldats perdus, %.1f aliens tués" % [
		map, wins, n, roundi(100.0 * wins / n), ends, float(turns) / n, float(lost) / n, float(dead_aliens) / n])
	quit()
