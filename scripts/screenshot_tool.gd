extends Node
## Takes REAL screenshots of the REAL game (it plays levels with a small bot) for the Play Store.
## Not used in the shipped app. Run (the GitHub workflow "Take screenshots" does this for you):
##   godot --path . --resolution 1920x1080 --fixed-fps 30 --audio-driver Dummy res://scenes/screenshots.tscn -- --out=build/shots/phone
## Your save file is never touched (autosave is switched off).

var out_dir := "build/shots"

# One entry per gameplay screenshot. size = player size, frac = how far into the level, skin etc. = shop look.
var gameplay_shots: Array = [
	{"name": "01_eat_to_grow", "level": 8, "size": 46.0, "frac": 0.30, "frames": 150, "skin": "skin_goldie", "pat": "pat_none", "acc": "acc_none", "trail": "trail_pink", "species": "sp_dolphin"},
	{"name": "02_escape_predators", "level": 34, "size": 38.0, "frac": 0.35, "frames": 150, "skin": "skin_goldie", "pat": "pat_none", "acc": "acc_crown", "trail": "trail_bubbles", "species": "sp_shark"},
	{"name": "04_volcano_world", "level": 62, "size": 58.0, "frac": 0.30, "frames": 150, "skin": "skin_goldie", "pat": "pat_none", "acc": "acc_none", "trail": "trail_gold", "species": "sp_orca"},
	{"name": "06_neon_abyss", "level": 82, "size": 64.0, "frac": 0.30, "frames": 150, "skin": "skin_goldie", "pat": "pat_none", "acc": "acc_none", "trail": "trail_rainbow", "species": "sp_whale"},
	{"name": "07_start_small", "level": 1, "size": 22.0, "frac": 0.12, "frames": 120, "skin": "skin_goldie", "pat": "pat_none", "acc": "acc_none", "trail": "trail_bubbles"},
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	GameState.autosave = false
	GameState.tutorial_seen = true
	DirAccess.make_dir_recursive_absolute(_abs(out_dir))
	await _run()
	print("Screenshots finished.")
	get_tree().quit()


func _abs(rel: String) -> String:
	if rel.is_absolute_path():
		return rel
	return ProjectSettings.globalize_path("res://").path_join(rel)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := _abs(out_dir).path_join(shot_name + ".png")
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _unlock_everything() -> void:
	for it in GameState.shop_items:
		if not GameState.owned_items.has(it["id"]):
			GameState.owned_items.append(it["id"])
	GameState.coins = 1250
	GameState.unlocked_level = 37
	for i in range(1, 37):
		GameState.best_scores[i] = 800 + i * 37


func _equip(skin: String, pat: String, acc: String, trail: String, species: String = "sp_goldie") -> void:
	GameState.equipped = {"species": species, "skin": skin, "pattern": pat, "trail": trail, "acc": acc}


func _run() -> void:
	_unlock_everything()

	# 1) gameplay shots
	for spec in gameplay_shots:
		await _gameplay(spec)

	# 2) shop
	_equip("skin_goldie", "pat_none", "acc_crown", "trail_gold", "sp_whale")
	var shop: Node = load("res://scenes/shop.tscn").instantiate()
	add_child(shop)
	await _frames(40)
	await _shot("03_customize_fish")
	shop.queue_free()
	await _frames(2)

	# 3) level select (shows page 4 = levels 31-40)
	var levels: Node = load("res://scenes/level_select.tscn").instantiate()
	add_child(levels)
	await _frames(40)
	await _shot("05_300_levels")
	levels.queue_free()
	await _frames(2)

	# 4) level complete screen
	_equip("skin_goldie", "pat_stripes", "acc_none", "trail_bubbles")
	await _level_complete()

	# 5) main menu
	GameState.coins = 1250
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(60)
	await _shot("09_main_menu")
	menu.queue_free()
	await _frames(2)


func _start_game(level: int) -> Node:
	GameState.current_level = level
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _frames(5)
	game.god_mode = true
	return game


func _gameplay(spec: Dictionary) -> void:
	_equip(spec["skin"], spec["pat"], spec["acc"], spec["trail"], str(spec.get("species", "sp_goldie")))
	var game: Node = await _start_game(int(spec["level"]))
	var p = game.player
	p.size_val = float(spec["size"])
	p.shown_size = float(spec["size"])
	p.position = Vector2(game.length * float(spec["frac"]), 450.0)
	game.camera.position = p.position + Vector2(160.0, 0.0)
	game.camera.reset_smoothing()
	game._update_activation()
	for i in int(spec["frames"]):
		_bot(game)
		await get_tree().process_frame
	await _shot(str(spec["name"]))
	game.queue_free()
	await _frames(2)


func _level_complete() -> void:
	var game: Node = await _start_game(12)
	var p = game.player
	p.size_val = 52.0
	p.shown_size = 52.0
	p.position = Vector2(game.length - 260.0, 450.0)
	game.camera.position = p.position + Vector2(160.0, 0.0)
	game.camera.reset_smoothing()
	game.coins_run = 37
	for i in 150:
		game.hud.joystick.direction = Vector2(1.0, 0.0)
		await get_tree().process_frame
	await _shot("08_level_complete")
	game.queue_free()
	await _frames(2)


## Tiny autopilot: chase the nearest green-ring fish or coin, run away from red-ring fish.
func _bot(game: Node) -> void:
	var p = game.player
	var has_target := false
	var target := Vector2.ZERO
	var best_d := 650.0
	var flee := Vector2.ZERO
	for f in game.fish_list:
		if not f.active:
			continue
		var d: float = p.position.distance_to(f.position)
		if f.relation == 1 and d < best_d:
			has_target = true
			target = f.position
			best_d = d
		elif f.relation == 2 and d < 320.0:
			flee += (p.position - f.position).normalized() * (320.0 - d)
	for c in game.coin_list:
		if not c.active:
			continue
		var d2: float = p.position.distance_to(c.position)
		if d2 < best_d * 0.8:
			has_target = true
			target = c.position
			best_d = d2 / 0.8
	var dir := Vector2(1.0, 0.0)
	if has_target:
		dir = (target - p.position).normalized()
	if flee != Vector2.ZERO:
		dir = (dir + flee.normalized() * 1.5).normalized()
	game.hud.joystick.direction = dir
