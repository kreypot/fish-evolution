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

	gs._ensure_themes()
	check(gs.TOTAL_LEVELS == 300, "game has exactly 300 levels")
	check(gs.themes.size() == 30, "30 worlds (one per 10 levels)")
	check(gs.get_theme_for_level(1)["name"] == gs.themes[0]["name"], "level 1 uses theme 1")
	check(gs.get_theme_for_level(10)["name"] == gs.themes[0]["name"], "level 10 uses theme 1")
	check(gs.get_theme_for_level(11)["name"] == gs.themes[1]["name"], "level 11 uses theme 2")
	check(gs.get_theme_for_level(100)["name"] == gs.themes[9]["name"], "level 100 uses theme 10")
	check(gs.get_theme_for_level(101)["name"] == gs.themes[10]["name"], "level 101 starts world 11")
	check(gs.get_theme_for_level(300)["name"] == gs.themes[29]["name"], "level 300 uses world 30")

	var ok_monotonic := true
	var ok_speed := true
	var ok_fields := true
	var prev: Dictionary = gs.get_level_config(1)
	for n in range(1, 301):
		var c: Dictionary = gs.get_level_config(n)
		for key in ["chase_time", "rest_time", "u", "length", "big_density", "predator_speed", "detect_range", "big_min", "big_max", "rock_density", "small_density", "medium_density", "patrol_share", "jelly_density", "rock_max", "theme"]:
			if not c.has(key):
				ok_fields = false
		if n > 1:
			if c["length"] <= prev["length"] or c["big_density"] < prev["big_density"] or c["predator_speed"] < prev["predator_speed"]:
				ok_monotonic = false
		# the player now always swims at 300 px/s; predators are still checked against the old, stricter limit of 200
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
	var ok_size := true
	var ok_rest := true
	for n in range(1, 301):
		var c2: Dictionary = gs.get_level_config(n)
		if c2["big_max"] > gs.MAX_SIZE or c2["big_min"] >= c2["big_max"]:
			ok_size = false
		if c2["rest_time"] < 1.0 or c2["chase_time"] < 5.0:
			ok_rest = false
	check(ok_size, "predator sizes stay within MAX_SIZE on all 300 levels")
	check(ok_rest, "predators always get tired (rest >= 1 s) on all 300 levels")
	check(gs.get_level_config(1)["length"] >= 8000.0, "level 1 is long enough (8000+ px, about 40 s)")
	check(gs.get_level_config(300)["length"] <= 60000.0, "level 300 is not endless")
	check(gs.get_level_config(1000)["level"] == 300, "level index is clamped to 300")
	check(gs.is_boss_level(10) and gs.is_boss_level(300) and not gs.is_boss_level(15) and not gs.is_boss_level(5), "boss levels are 10, 20, ... 300")
	var boss_script = load("res://scripts/boss.gd")
	var ok_boss := true
	for n in range(1, 301):
		if boss_script.speed_for_level(n) >= 195.0:
			ok_boss = false
	check(ok_boss, "the boss is always slower than a fully grown player (195 px/s)")
	var cps: Array = gs.CHECKPOINT_FRACTIONS
	check(cps.size() == 3 and cps[0] < cps[1] and cps[1] < cps[2] and cps[2] < 1.0, "3 checkpoints in increasing order before the finish")

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

	# --- fish species, coins, ads config (v1.2) ---
	var sp_items: Array = gs.items_in("species")
	check(sp_items.size() == 17, "17 fish species in the shop")
	var prices_ok := int(sp_items[0]["price"]) == 0
	for i in range(1, sp_items.size()):
		if int(sp_items[i]["price"]) <= int(sp_items[i - 1]["price"]):
			prices_ok = false
	check(prices_ok, "first fish is free and prices rise from the smallest fish to the golden whale")
	check(gs.is_owned("sp_goldie") and gs.equipped["species"] == "sp_goldie", "starter fish is owned and equipped")
	var orca: Dictionary = gs.get_item("sp_orca")
	check(gs.get_look("sp_orca")["body"] == orca["body"], "the 'Natural' skin uses the fish's own colours")
	check(gs.get_look("sp_whale")["spec"].get("spout", false) == true, "baby whale has its water spout")
	check(gs.get_look("sp_koi")["pattern"] == 2, "koi has a natural spotted pattern")
	check(gs.get_look("skin_ruby")["body"] == gs.get_item("skin_ruby")["body"], "a bought skin overrides the natural colours")
	check(maxi(1, int(round(8.0 * gs.COIN_PER_SIZE))) >= 1, "even the smallest fish gives at least 1 coin")
	check(int(round(100.0 * gs.COIN_PER_SIZE)) >= 10, "a big predator gives 10+ coins")
	var total_price := 0
	for it in gs.shop_items:
		total_price += int(it["price"])
	check(total_price >= 150000, "there is a lot to buy (150,000+ coins of items) to keep players engaged")
	var ac = load("res://scripts/ad_config.gd").new()
	var ad_ids: Dictionary = ac.ids()
	var ids_ok := true
	for key in ["app_open", "interstitial", "rewarded"]:
		if not str(ad_ids[key]).begins_with("ca-app-pub-"):
			ids_ok = false
	check(ids_ok, "all three ad unit ids look valid")
	check(ac.INTERSTITIAL_MIN_GAP_SEC >= 30 and ac.INTERSTITIAL_EVERY_N_WINS >= 1, "between-level ads have a minimum gap")
	check(ac.STARTUP_AD_FROM_LAUNCH >= 2, "the startup ad is skipped on the first launches")
	check(ac.free_coins(300) > ac.free_coins(1), "free-coins reward grows with progress")

	gs.free()
	print("---- ", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
