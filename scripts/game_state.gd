extends Node
## GameState (autoload)
## Holds save data, settings and the difficulty table for all 100 levels.
## Everything that must survive between scenes lives here.
## To rebalance the game, change the constants and get_level_config() below.

const SAVE_PATH := "user://fish_evolution_save.cfg"
const TOTAL_LEVELS := 100
const LEVELS_PER_THEME := 10

# --- Size / growth rules ---------------------------------------------------
const PLAYER_START_SIZE := 20.0
const MIN_SIZE := 14.0      # jellyfish stings can never shrink you below this
const MAX_SIZE := 120.0
const EAT_RATIO := 0.85     # you can eat fish smaller than (your size * 0.85)
const DANGER_RATIO := 1.15  # fish bigger than (your size * 1.15) can eat you
const GROW_FACTOR := 0.25   # you gain this fraction of an eaten fish's size (big, visible growth)

# --- Coins -------------------------------------------------------------------
const COIN_GROUPS_PER_KM := 2.2   # groups of 5 coins per 1000 px of level

var unlocked_level: int = 1
var current_level: int = 1
var music_on: bool = true
var sfx_on: bool = true
var tutorial_seen: bool = false
var best_scores: Dictionary = {}   # level (int) -> best score (int)
var autosave: bool = true          # tests switch this off so they never touch your save file

# --- Shop / cosmetics ---------------------------------------------------------
var coins: int = 0
var owned_items: Array = ["skin_goldie", "pat_none", "trail_bubbles", "acc_none"]
var equipped: Dictionary = {"skin": "skin_goldie", "pattern": "pat_none", "trail": "trail_bubbles", "acc": "acc_none"}

const CATEGORY_NAMES := {"skin": "Skins", "pattern": "Patterns", "trail": "Trails", "acc": "Extras"}
const CATEGORY_ORDER := ["skin", "pattern", "trail", "acc"]

## Every shop item. Add your own here - the shop screen builds itself from this list.
## skin: body/belly/fin colours (rainbow = cycles colour)   pattern: 0 none 1 stripes 2 spots 3 scales 4 gold scales
## trail: bubble colour (filled = sparkle dots instead of bubble rings)   acc: 0 none 1 sunglasses 2 crown
var shop_items: Array = [
	{"id": "skin_goldie", "cat": "skin", "name": "Goldie", "price": 0, "body": Color("#ffa534"), "belly": Color("#ffe08a"), "fin": Color("#e0661d")},
	{"id": "skin_bubblegum", "cat": "skin", "name": "Bubblegum", "price": 150, "body": Color("#ff8ac8"), "belly": Color("#ffd6ec"), "fin": Color("#d6489a")},
	{"id": "skin_ocean", "cat": "skin", "name": "Ocean Blue", "price": 150, "body": Color("#3da5ff"), "belly": Color("#bfe3ff"), "fin": Color("#1c6fc4")},
	{"id": "skin_lime", "cat": "skin", "name": "Lime Zest", "price": 200, "body": Color("#8be04a"), "belly": Color("#e2ffb8"), "fin": Color("#4c9f1f")},
	{"id": "skin_ruby", "cat": "skin", "name": "Ruby", "price": 300, "body": Color("#ee3b4f"), "belly": Color("#ffb3bb"), "fin": Color("#a01228")},
	{"id": "skin_violet", "cat": "skin", "name": "Violet", "price": 300, "body": Color("#9b5cf0"), "belly": Color("#dcc6ff"), "fin": Color("#5d2bb0")},
	{"id": "skin_midnight", "cat": "skin", "name": "Midnight", "price": 500, "body": Color("#2c3e78"), "belly": Color("#7f93d6"), "fin": Color("#141f4a")},
	{"id": "skin_rainbow", "cat": "skin", "name": "Rainbow", "price": 1500, "rainbow": true, "body": Color("#ff8ac8"), "belly": Color("#ffffff"), "fin": Color("#9b5cf0")},
	{"id": "pat_none", "cat": "pattern", "name": "Plain", "price": 0, "pattern": 0},
	{"id": "pat_stripes", "cat": "pattern", "name": "Stripes", "price": 200, "pattern": 1},
	{"id": "pat_spots", "cat": "pattern", "name": "Spots", "price": 250, "pattern": 2},
	{"id": "pat_scales", "cat": "pattern", "name": "Scales", "price": 350, "pattern": 3},
	{"id": "pat_gold", "cat": "pattern", "name": "Gold Scales", "price": 800, "pattern": 4},
	{"id": "trail_bubbles", "cat": "trail", "name": "Bubbles", "price": 0, "color": Color("#ffffff"), "filled": false, "rainbow": false},
	{"id": "trail_pink", "cat": "trail", "name": "Pink Bubbles", "price": 200, "color": Color("#ff9ad5"), "filled": false, "rainbow": false},
	{"id": "trail_gold", "cat": "trail", "name": "Gold Dust", "price": 500, "color": Color("#ffd23a"), "filled": true, "rainbow": false},
	{"id": "trail_rainbow", "cat": "trail", "name": "Rainbow Sparkles", "price": 1000, "color": Color("#ffffff"), "filled": true, "rainbow": true},
	{"id": "acc_none", "cat": "acc", "name": "Nothing", "price": 0, "acc": 0},
	{"id": "acc_shades", "cat": "acc", "name": "Sunglasses", "price": 400, "acc": 1},
	{"id": "acc_crown", "cat": "acc", "name": "Crown", "price": 900, "acc": 2},
]

## One visual theme per 10 levels. pred_hue colours the big predators.
var themes: Array = [
	{"name": "Sunny Shallows", "top": Color("#4fd1f5"), "bottom": Color("#1c8fc4"), "sand": Color("#f3d99b"), "plant": Color("#3fbf6a"), "coral": Color("#ff7a8a"), "rock": Color("#8a8f98"), "pred_hue": 0.0},
	{"name": "Coral Reef", "top": Color("#3ec6e0"), "bottom": Color("#1a6fb5"), "sand": Color("#f6e0b0"), "plant": Color("#2fb36a"), "coral": Color("#ff5fa2"), "rock": Color("#7e8ea0"), "pred_hue": 0.96},
	{"name": "Kelp Forest", "top": Color("#2aa88f"), "bottom": Color("#0f5f5a"), "sand": Color("#c9b27a"), "plant": Color("#6fcf5a"), "coral": Color("#c9d65a"), "rock": Color("#6a7a70"), "pred_hue": 0.08},
	{"name": "Deep Blue", "top": Color("#1f6fc4"), "bottom": Color("#0b2a6b"), "sand": Color("#8f9ab0"), "plant": Color("#2b9fa0"), "coral": Color("#8a6cff"), "rock": Color("#56607a"), "pred_hue": 0.02},
	{"name": "Sunken Ship", "top": Color("#2b8f9e"), "bottom": Color("#123b4a"), "sand": Color("#b89f72"), "plant": Color("#7aa35a"), "coral": Color("#d98a4a"), "rock": Color("#6b5b4a"), "pred_hue": 0.05},
	{"name": "Twilight Zone", "top": Color("#5b4fc4"), "bottom": Color("#1a1450"), "sand": Color("#7a6aa8"), "plant": Color("#b36ae0"), "coral": Color("#ff7ad9"), "rock": Color("#4a4570"), "pred_hue": 0.12},
	{"name": "Volcano Vents", "top": Color("#c4492b"), "bottom": Color("#3a0f0f"), "sand": Color("#5a3a30"), "plant": Color("#ff9a2a"), "coral": Color("#ffd23a"), "rock": Color("#2e2220"), "pred_hue": 0.55},
	{"name": "Ice Waters", "top": Color("#bfe9ff"), "bottom": Color("#4a9fd8"), "sand": Color("#eaf4fb"), "plant": Color("#e8f7ff"), "coral": Color("#9fd6ff"), "rock": Color("#a9c0d4"), "pred_hue": 0.72},
	{"name": "Neon Abyss", "top": Color("#0a1f4a"), "bottom": Color("#040818"), "sand": Color("#1c2a4a"), "plant": Color("#19ffd1"), "coral": Color("#ff2bd6"), "rock": Color("#243a6a"), "pred_hue": 0.85},
	{"name": "Dark Trench", "top": Color("#101a2e"), "bottom": Color("#02030a"), "sand": Color("#1a2030"), "plant": Color("#3a4f6a"), "coral": Color("#7a2a4a"), "rock": Color("#2a3040"), "pred_hue": 0.0},
]


func _ready() -> void:
	load_game()


## Returns the visual theme dictionary for a level (10 levels per theme).
func get_theme_for_level(level: int) -> Dictionary:
	var idx: int = clampi(floori((level - 1) / float(LEVELS_PER_THEME)), 0, themes.size() - 1)
	return themes[idx]


## Difficulty table. Level 1 is gentle, level 100 is brutal but still fair:
## predators are always slower than the player and get tired after a while.
func get_level_config(level: int) -> Dictionary:
	var n: int = clampi(level, 1, TOTAL_LEVELS)
	var t: float = float(n - 1) / float(TOTAL_LEVELS - 1)   # 0.0 .. 1.0
	return {
		"level": n,
		"t": t,
		"theme": get_theme_for_level(n),
		"length": 3600.0 + n * 75.0,             # level length in pixels
		"small_density": 8.0,                    # edible fish per 1000 px
		"medium_density": 2.5 + 3.5 * t,         # mixed-size fish per 1000 px
		"big_density": 0.8 + 2.7 * t,            # predators per 1000 px
		"predator_speed": 125.0 + 75.0 * t,      # player is 200-300, so always faster
		"detect_range": 330.0 + 200.0 * t,
		"patrol_share": 0.3 + 0.4 * t,
		"big_min": 40.0 + 10.0 * t,
		"big_max": 70.0 + 40.0 * t,
		"jelly_density": 0.0 if n < 5 else 0.6 + 2.4 * t,
		"rock_density": 1.5 + 1.5 * t,
		"rock_max": 55.0 + 95.0 * t,
	}


func complete_level(level: int, score: int) -> void:
	if level >= unlocked_level and level < TOTAL_LEVELS:
		unlocked_level = level + 1
	if score > int(best_scores.get(level, 0)):
		best_scores[level] = score
	save_game()


# --- Shop helpers ----------------------------------------------------------

func items_in(cat: String) -> Array:
	var out: Array = []
	for it in shop_items:
		if it["cat"] == cat:
			out.append(it)
	return out


func get_item(id: String) -> Dictionary:
	for it in shop_items:
		if it["id"] == id:
			return it
	return {}


func is_owned(id: String) -> bool:
	return owned_items.has(id)


func is_equipped(id: String) -> bool:
	var it := get_item(id)
	return not it.is_empty() and equipped.get(it["cat"], "") == id


func add_coins(amount: int) -> void:
	coins += amount


## Returns true if the item is now owned (bought just now, or already owned).
func buy(id: String) -> bool:
	var it := get_item(id)
	if it.is_empty():
		return false
	if is_owned(id):
		return true
	if coins < int(it["price"]):
		return false
	coins -= int(it["price"])
	owned_items.append(id)
	save_game()
	return true


func equip(id: String) -> void:
	var it := get_item(id)
	if it.is_empty() or not is_owned(id):
		return
	equipped[it["cat"]] = id
	save_game()


## The look of the player's fish: equipped items, optionally with one item swapped in (shop preview).
func get_look(override_id: String = "") -> Dictionary:
	var ids: Dictionary = equipped.duplicate()
	if override_id != "":
		var o := get_item(override_id)
		if not o.is_empty():
			ids[o["cat"]] = override_id
	var skin := get_item(str(ids["skin"]))
	var pat := get_item(str(ids["pattern"]))
	var trail := get_item(str(ids["trail"]))
	var acc := get_item(str(ids["acc"]))
	return {
		"body": skin.get("body", Color("#ffa534")),
		"belly": skin.get("belly", Color("#ffe08a")),
		"fin": skin.get("fin", Color("#e0661d")),
		"rainbow": skin.get("rainbow", false),
		"pattern": pat.get("pattern", 0),
		"acc": acc.get("acc", 0),
		"trail_color": trail.get("color", Color.WHITE),
		"trail_filled": trail.get("filled", false),
		"trail_rainbow": trail.get("rainbow", false),
	}


func go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


## Resets levels, scores and tutorial. Coins and shop purchases are kept.
func reset_progress() -> void:
	unlocked_level = 1
	best_scores.clear()
	tutorial_seen = false
	save_game()


func save_game() -> void:
	if not autosave:
		return
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked_level", unlocked_level)
	cf.set_value("settings", "music_on", music_on)
	cf.set_value("settings", "sfx_on", sfx_on)
	cf.set_value("settings", "tutorial_seen", tutorial_seen)
	for k in best_scores:
		cf.set_value("scores", str(k), best_scores[k])
	cf.set_value("shop", "coins", coins)
	cf.set_value("shop", "owned", owned_items)
	for cat in equipped:
		cf.set_value("equipped", cat, equipped[cat])
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked_level = clampi(int(cf.get_value("progress", "unlocked_level", 1)), 1, TOTAL_LEVELS)
	music_on = bool(cf.get_value("settings", "music_on", true))
	sfx_on = bool(cf.get_value("settings", "sfx_on", true))
	tutorial_seen = bool(cf.get_value("settings", "tutorial_seen", false))
	best_scores.clear()
	if cf.has_section("scores"):
		for key in cf.get_section_keys("scores"):
			best_scores[int(key)] = int(cf.get_value("scores", key, 0))
	coins = maxi(0, int(cf.get_value("shop", "coins", 0)))
	var saved_owned: Array = cf.get_value("shop", "owned", owned_items)
	for sid in saved_owned:
		if not owned_items.has(str(sid)) and not get_item(str(sid)).is_empty():
			owned_items.append(str(sid))
	for cat in CATEGORY_ORDER:
		var eid: String = str(cf.get_value("equipped", cat, equipped[cat]))
		if is_owned(eid) and not get_item(eid).is_empty() and get_item(eid)["cat"] == cat:
			equipped[cat] = eid
