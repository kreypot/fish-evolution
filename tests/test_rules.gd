extends SceneTree
## Headless rules check. Run from the project folder:
##   godot --headless --path . -s tests/test_rules.gd
## Exits with code 1 if any check fails.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok:   ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	var gs = load("res://scripts/game_state.gd").new()

	check(gs.TOTAL_LEVELS == 100, "game has exactly 100 levels")
	check(gs.themes.size() == 10, "10 themes (one per 10 levels)")
	check(gs.get_theme_for_level(1)["name"] == gs.themes[0]["name"], "level 1 uses theme 1")
	check(gs.get_theme_for_level(10)["name"] == gs.themes[0]["name"], "level 10 uses theme 1")
	check(gs.get_theme_for_level(11)["name"] == gs.themes[1]["name"], "level 11 uses theme 2")
	check(gs.get_theme_for_level(100)["name"] == gs.themes[9]["name"], "level 100 uses theme 10")

	var ok_monotonic := true
	var ok_speed := true
	var ok_fields := true
	var prev: Dictionary = gs.get_level_config(1)
	for n in range(1, 101):
		var c: Dictionary = gs.get_level_config(n)
		for key in ["length", "big_density", "predator_speed", "detect_range", "big_min", "big_max", "rock_density", "small_density", "medium_density", "patrol_share", "jelly_density", "rock_max", "theme"]:
			if not c.has(key):
				ok_fields = false
		if n > 1:
			if c["length"] <= prev["length"] or c["big_density"] < prev["big_density"] or c["predator_speed"] < prev["predator_speed"]:
				ok_monotonic = false
		# the slowest the player can ever be is 300 * (1 - 0.35) = 195 px/s
		if c["predator_speed"] > 200.0:
			ok_speed = false
		prev = c
	check(ok_fields, "every level config has all fields")
	check(ok_monotonic, "length, predator count and predator speed never decrease with level")
	check(ok_speed, "predators are never faster than a fully grown player")

	var c1: Dictionary = gs.get_level_config(1)
	check(16.0 < gs.PLAYER_START_SIZE * gs.EAT_RATIO, "level-1 small fish (max size 16) are edible at start size")
	check(c1["big_min"] > gs.PLAYER_START_SIZE * gs.DANGER_RATIO, "level-1 predators are dangerous at start size")
	check(c1["jelly_density"] == 0.0, "no jellyfish on level 1")
	check(gs.get_level_config(100)["big_max"] <= gs.MAX_SIZE, "biggest predator fits within MAX_SIZE")
	check(gs.get_level_config(1000)["level"] == 100, "level index is clamped to 100")

	# --- growth ---
	check(gs.GROW_FACTOR >= 0.2, "growth per fish is big enough to be clearly visible")
	var grown: float = gs.PLAYER_START_SIZE + 8.0 * 12.0 * gs.GROW_FACTOR
	check(grown >= 40.0, "eating 8 average small fish grows you from 20 to 40+")

	# --- shop & coins (autosave off so no save file is touched) ---
	gs.autosave = false
	var ids := {}
	var dup := false
	for it in gs.shop_items:
		if ids.has(it["id"]):
			dup = true
		ids[it["id"]] = true
	check(not dup, "shop item ids are unique")
	for cat in gs.CATEGORY_ORDER:
		var free_count := 0
		for it in gs.items_in(cat):
			if int(it["price"]) == 0:
				free_count += 1
		check(free_count >= 1, "category '%s' has a free default item" % cat)
		check(gs.is_owned(gs.equipped[cat]), "default '%s' item is owned and equipped" % cat)
	gs.coins = 100
	check(not gs.buy("skin_bubblegum"), "cannot buy a 150-coin item with 100 coins")
	check(gs.coins == 100 and not gs.is_owned("skin_bubblegum"), "failed purchase changes nothing")
	gs.coins = 150
	check(gs.buy("skin_bubblegum"), "can buy a 150-coin item with 150 coins")
	check(gs.coins == 0 and gs.is_owned("skin_bubblegum"), "purchase spends coins and grants the item")
	gs.equip("skin_bubblegum")
	check(gs.is_equipped("skin_bubblegum"), "bought item can be equipped")
	gs.equip("skin_rainbow")
	check(not gs.is_equipped("skin_rainbow"), "unowned item cannot be equipped")
	var look: Dictionary = gs.get_look("pat_scales")
	check(look["pattern"] == 3, "preview override applies the previewed pattern")
	check(gs.get_look()["pattern"] == 0, "preview does not change the equipped look")

	gs.free()
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
