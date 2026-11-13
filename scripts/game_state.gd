extends Node
## GameState (autoload)
## Holds save data, settings and the difficulty table for all 300 levels.
## Everything that must survive between scenes lives here.
## To rebalance the game, change the constants and get_level_config() below.

const SAVE_PATH := "user://fish_evolution_save.cfg"
const TOTAL_LEVELS := 300
const LEVELS_PER_THEME := 10

# --- Level length (in pixels; the fish swims about 200-300 px per second) ----------------------------
# Level 1 = 9000 + 110 = ~9100 px (about 45 s).  Level 300 = ~42000 px (about 3 minutes).
# TO MAKE ALL LEVELS LONGER OR SHORTER, change LEVEL_LENGTH_SCALE (1.0 = normal, 0.5 = half as long, 2.0 = twice as long).
const LEVEL_LENGTH_BASE := 9000.0
const LEVEL_LENGTH_PER_LEVEL := 110.0
const LEVEL_LENGTH_SCALE := 1.0

# --- Checkpoints: flags at 25 %, 50 % and 75 % of every level ---------------------------------------
const CHECKPOINT_FRACTIONS := [0.25, 0.5, 0.75]
const CONTINUES_PER_ATTEMPT := 3   # how many times you may "Continue from checkpoint" before you must retry the level

# --- Size / growth rules ---------------------------------------------------
const PLAYER_START_SIZE := 20.0
const MIN_SIZE := 14.0      # jellyfish stings can never shrink you below this
const MAX_SIZE := 120.0
const EAT_RATIO := 0.85     # you can eat fish smaller than (your size * 0.85)
const DANGER_RATIO := 1.15  # fish bigger than (your size * 1.15) can eat you
const GROW_FACTOR := 0.25   # you gain this fraction of an eaten fish's size (big, visible growth)

# --- Coins -------------------------------------------------------------------
const COIN_PER_SIZE := 0.15   # coins you get for eating a fish = its size x this (small fish ~2 coins, big predators ~12)
const COIN_GROUPS_PER_KM := 1.0   # groups of 5 coins per 1000 px of level (levels are long now, so fewer per km)

var unlocked_level: int = 1
var current_level: int = 1
var music_on: bool = true
var sfx_on: bool = true
var tutorial_seen: bool = false
var best_scores: Dictionary = {}   # level (int) -> best score (int)
var launch_count: int = 0         # how many times the game was started (the startup ad is skipped on the first launches)
var autosave: bool = true          # tests switch this off so they never touch your save file

# --- Daily reward + comfort settings (Update A1) ------------------------------------------------------
# Coins for day 1..7 of the login streak. After day 7 the streak starts again at day 1.
# MISS A DAY and the streak starts again at day 1. To change the rewards, edit this list.
const DAILY_REWARDS := [50, 75, 100, 150, 200, 300, 500]
const JOYSTICK_SCALES := [0.8, 1.0, 1.3]
const JOYSTICK_NAMES := ["Small", "Normal", "Large"]

var last_daily_day: int = 0      # day number (see today_number) of the last claimed daily reward, 0 = never
var daily_streak: int = 0        # which day of the streak was claimed last (1..7)
var left_handed: bool = false    # mirrors the top bar of the level screen
var joystick_size: int = 1       # 0 small, 1 normal, 2 large
var low_quality: bool = false    # fewer effects and 30 frames per second (saves battery, helps old phones)

# --- Stats, daily missions and achievements (Update A2) -------------------------------------------------
var stats: Dictionary = {"eaten": 0, "wins": 0, "deaths": 0, "coins": 0, "seconds": 0, "best_combo": 0, "biggest": 0, "best_streak": 0}
var mission_day: int = 0                         # the day (see today_number) the current missions belong to
var mission_progress: Array = [0, 0, 0]
var mission_claimed: Array = [false, false, false]
var unlocked_achs: Array = []                    # ids of unlocked achievements
var _missions: Array = []

## 3 missions per day are picked from these 5 kinds (same missions all day, new ones every day).
## "targets" and "rewards" have 3 steps (easy / medium / harder). Change the numbers to rebalance.
const MISSION_ORDER := ["eat", "win", "coins", "combo", "grow"]
const MISSION_TYPES := {
	"eat": {"text": "Eat %d fish", "targets": [20, 35, 50], "rewards": [40, 60, 90]},
	"win": {"text": "Finish %d levels", "targets": [1, 2, 3], "rewards": [40, 70, 110]},
	"coins": {"text": "Collect %d coins in levels", "targets": [60, 120, 200], "rewards": [40, 70, 110]},
	"combo": {"text": "Reach a COMBO of x%d", "targets": [3, 4, 5], "rewards": [50, 70, 100]},
	"grow": {"text": "Grow to size %d in one level", "targets": [35, 50, 70], "rewards": [50, 80, 120]},
}

## Achievements. "stat" says what is measured: eaten, wins, deaths, coins, seconds, best_combo, biggest, best_streak,
## level (highest unlocked level) or fish (fish species owned). The coins are paid once, when it unlocks.
const ACHIEVEMENTS := [
	{"id": "eat_100", "name": "Snack Time", "text": "Eat 100 fish", "stat": "eaten", "target": 100, "reward": 50},
	{"id": "eat_1000", "name": "Hungry Fish", "text": "Eat 1000 fish", "stat": "eaten", "target": 1000, "reward": 150},
	{"id": "eat_5000", "name": "Ocean Muncher", "text": "Eat 5000 fish", "stat": "eaten", "target": 5000, "reward": 500},
	{"id": "win_1", "name": "First Swim", "text": "Finish a level", "stat": "wins", "target": 1, "reward": 30},
	{"id": "win_10", "name": "Getting Started", "text": "Finish 10 levels", "stat": "wins", "target": 10, "reward": 100},
	{"id": "win_50", "name": "Reef Runner", "text": "Finish 50 levels", "stat": "wins", "target": 50, "reward": 300},
	{"id": "win_150", "name": "Deep Explorer", "text": "Finish 150 levels", "stat": "wins", "target": 150, "reward": 800},
	{"id": "lvl_50", "name": "Halfway There", "text": "Reach level 50", "stat": "level", "target": 50, "reward": 200},
	{"id": "lvl_100", "name": "Century Swimmer", "text": "Reach level 100", "stat": "level", "target": 100, "reward": 500},
	{"id": "lvl_200", "name": "Deep Sea Master", "text": "Reach level 200", "stat": "level", "target": 200, "reward": 1000},
	{"id": "lvl_300", "name": "Ocean Legend", "text": "Reach level 300", "stat": "level", "target": 300, "reward": 2000},
	{"id": "combo_5", "name": "Combo Starter", "text": "Reach a combo of x5", "stat": "best_combo", "target": 5, "reward": 60},
	{"id": "combo_10", "name": "Combo King", "text": "Reach a combo of x10", "stat": "best_combo", "target": 10, "reward": 200},
	{"id": "size_100", "name": "Big Fish", "text": "Grow to size 100", "stat": "biggest", "target": 100, "reward": 200},
	{"id": "coins_5000", "name": "Coin Collector", "text": "Collect 5000 coins in levels", "stat": "coins", "target": 5000, "reward": 300},
	{"id": "fish_5", "name": "Fish Friend", "text": "Own 5 fish", "stat": "fish", "target": 5, "reward": 100},
	{"id": "fish_10", "name": "Fish Collector", "text": "Own 10 fish", "stat": "fish", "target": 10, "reward": 300},
	{"id": "fish_all", "name": "Whole Ocean", "text": "Own every fish", "stat": "fish", "target": 17, "reward": 1000},
	{"id": "streak_7", "name": "Loyal Swimmer", "text": "Claim 7 daily rewards in a row", "stat": "best_streak", "target": 7, "reward": 200},
	{"id": "time_1h", "name": "Deep Diver", "text": "Play for 1 hour", "stat": "seconds", "target": 3600, "reward": 100},
]

# --- Shop / cosmetics ---------------------------------------------------------
var coins: int = 0
var owned_items: Array = ["sp_goldie", "skin_goldie", "pat_none", "trail_bubbles", "acc_none"]
var equipped: Dictionary = {"species": "sp_goldie", "skin": "skin_goldie", "pattern": "pat_none", "trail": "trail_bubbles", "acc": "acc_none"}

const CATEGORY_NAMES := {"species": "Fish", "skin": "Skins", "pattern": "Patterns", "trail": "Trails", "acc": "Extras"}
const CATEGORY_ORDER := ["species", "skin", "pattern", "trail", "acc"]

## Every shop item. Add your own here - the shop screen builds itself from this list.
## species: a different fish body (shape + natural colours). "spec" describes the shape, see fish_art.gd (draw_fish) for the keys.
## skin: body/belly/fin colours (rainbow = cycles colour)   pattern: 0 none 1 stripes 2 spots 3 scales 4 gold scales
## trail: bubble colour (filled = sparkle dots instead of bubble rings)   acc: 0 none 1 sunglasses 2 crown
var shop_items: Array = [
	{"id": "sp_goldie", "cat": "species", "name": "Goldie", "price": 0, "body": Color("#ffa534"), "belly": Color("#ffe08a"), "fin": Color("#e0661d"), "spec": {}},
	{"id": "sp_guppy", "cat": "species", "name": "Guppy", "price": 400, "body": Color("#4fd0d0"), "belly": Color("#c9fff6"), "fin": Color("#ff7ac8"), "spec": {"base": 1, "by": 0.42, "tail": "fan"}},
	{"id": "sp_clown", "cat": "species", "name": "Clownfish", "price": 700, "body": Color("#ff7a1a"), "belly": Color("#ffb066"), "fin": Color("#d94d00"), "spec": {"bands": true}},
	{"id": "sp_puffer", "cat": "species", "name": "Pufferfish", "price": 1000, "body": Color("#e8d14a"), "belly": Color("#fff6b8"), "fin": Color("#b89a1a"), "spec": {"base": 2}},
	{"id": "sp_angel", "cat": "species", "name": "Angelfish", "price": 1500, "body": Color("#cfe8ff"), "belly": Color("#ffffff"), "fin": Color("#5b8fd6"), "spec": {"bx": 0.8, "by": 0.92, "dorsal": "tall", "anal": true, "tail": "fan"}},
	{"id": "sp_koi", "cat": "species", "name": "Koi", "price": 2200, "body": Color("#ff5a3c"), "belly": Color("#fff2e8"), "fin": Color("#ffffff"), "spec": {"base": 1, "bx": 1.15, "by": 0.5, "tail": "fan", "pattern": 2}},
	{"id": "sp_ray", "cat": "species", "name": "Stingray", "price": 3000, "body": Color("#6f86a3"), "belly": Color("#dfe8f2"), "fin": Color("#4f6278"), "spec": {"base": 4, "bx": 1.0, "by": 0.85, "tail": "whip", "dorsal": "none"}},
	{"id": "sp_sword", "cat": "species", "name": "Swordfish", "price": 4000, "body": Color("#4a78c8"), "belly": Color("#dce8ff"), "fin": Color("#2a4a90"), "spec": {"base": 1, "bx": 1.2, "by": 0.36, "nose": "bill", "dorsal": "sail", "tail": "crescent"}},
	{"id": "sp_piranha", "cat": "species", "name": "Piranha", "price": 5000, "body": Color("#7d8c99"), "belly": Color("#e0483c"), "fin": Color("#c43a2a"), "spec": {"by": 0.72, "teeth": true, "angry": true}},
	{"id": "sp_angler", "cat": "species", "name": "Anglerfish", "price": 6500, "body": Color("#3a2f5a"), "belly": Color("#6a5a9a"), "fin": Color("#231a3d"), "spec": {"by": 0.78, "nose": "lure", "teeth": true, "eye": 1.25}},
	{"id": "sp_dolphin", "cat": "species", "name": "Dolphin", "price": 9000, "body": Color("#6fa0d8"), "belly": Color("#eef6ff"), "fin": Color("#3a62a0"), "spec": {"base": 1, "bx": 1.3, "by": 0.46, "nose": "beak", "dorsal": "hook", "tail": "fluke"}},
	{"id": "sp_shark", "cat": "species", "name": "Shark", "price": 12000, "body": Color("#7f95a8"), "belly": Color("#eef2f5"), "fin": Color("#566a7c"), "spec": {"base": 3}},
	{"id": "sp_hammer", "cat": "species", "name": "Hammerhead", "price": 16000, "body": Color("#8a8f7a"), "belly": Color("#eef0e6"), "fin": Color("#5d6150"), "spec": {"base": 3, "nose": "hammer"}},
	{"id": "sp_orca", "cat": "species", "name": "Orca", "price": 22000, "body": Color("#1e2330"), "belly": Color("#ffffff"), "fin": Color("#12151f"), "spec": {"base": 1, "bx": 1.35, "by": 0.56, "dorsal": "tall", "tail": "fluke", "patch": true, "fin_scale": 1.4}},
	{"id": "sp_narwhal", "cat": "species", "name": "Narwhal", "price": 30000, "body": Color("#8fb0c8"), "belly": Color("#f2f6fa"), "fin": Color("#46657f"), "spec": {"base": 1, "bx": 1.25, "by": 0.5, "nose": "tusk", "tail": "fluke", "dorsal": "none", "pattern": 2}},
	{"id": "sp_whale", "cat": "species", "name": "Baby Whale", "price": 40000, "body": Color("#4f8fe0"), "belly": Color("#e8f3ff"), "fin": Color("#2f62b0"), "spec": {"bx": 1.4, "by": 0.74, "tail": "fluke", "dorsal": "none", "spout": true, "eye": 1.3}},
	{"id": "sp_goldwhale", "cat": "species", "name": "Golden Whale", "price": 75000, "body": Color("#ffcf3a"), "belly": Color("#fff3b8"), "fin": Color("#d9961a"), "spec": {"bx": 1.4, "by": 0.74, "tail": "fluke", "dorsal": "none", "spout": true, "eye": 1.3, "pattern": 4}},
	{"id": "skin_goldie", "cat": "skin", "name": "Natural", "price": 0, "body": Color("#ffa534"), "belly": Color("#ffe08a"), "fin": Color("#e0661d")},
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


var _themes_extended := false


func _ready() -> void:
	_ensure_themes()
	load_game()
	apply_quality()
	launch_count += 1   # counts every start of the game
	save_game()


## Returns the visual theme dictionary for a level (10 levels per theme).
func get_theme_for_level(level: int) -> Dictionary:
	_ensure_themes()
	var idx: int = clampi(floori((level - 1) / float(LEVELS_PER_THEME)), 0, themes.size() - 1)
	return themes[idx]


## Worlds 11-30 are colour variations of the first 10 with new names, so there are 30 different worlds for 300 levels.
func _ensure_themes() -> void:
	if _themes_extended:
		return
	_themes_extended = true
	var names: Array = [
		"Tropical Lagoon", "Pearl Bay", "Mangrove Maze", "Whale Highway", "Pirate Cove",
		"Aurora Deep", "Lava Tubes", "Frozen Reef", "Crystal Caverns", "Abyssal Void",
		"Golden Sands", "Rainbow Reef", "Mushroom Forest", "Storm Surge", "Atlantis Ruins",
		"Moonlit Depths", "Magma Core", "Glacier Gate", "Glowing Bay", "The Final Trench",
	]
	for k in 20:
		var base: Dictionary = themes[k % 10]
		var shift: float = 0.17 if k < 10 else 0.43
		var v_mul: float = 1.0 if k < 10 else 0.92
		var t: Dictionary = {"name": names[k], "pred_hue": fposmod(float(base["pred_hue"]) + shift, 1.0)}
		for key in ["top", "bottom", "sand", "plant", "coral", "rock"]:
			var c: Color = base[key]
			t[key] = Color.from_hsv(fposmod(c.h + shift, 1.0), clampf(c.s * 1.05, 0.0, 1.0), clampf(c.v * v_mul, 0.0, 1.0))
		themes.append(t)


## Difficulty table for all 300 levels.
##  * Levels 1-100 use the original curve (t goes 0 -> 1).
##  * Levels 101-300 start from the level-100 difficulty and keep getting harder (u goes 0 -> 1) WITHOUT breaking
##    the fairness rules: predators stay slower than the player and still get tired.
func get_level_config(level: int) -> Dictionary:
	var n: int = clampi(level, 1, TOTAL_LEVELS)
	var t: float = clampf(float(n - 1) / 99.0, 0.0, 1.0)
	var u: float = clampf(float(n - 100) / 200.0, 0.0, 1.0)
	return {
		"level": n,
		"t": t,
		"u": u,
		"theme": get_theme_for_level(n),
		"length": (LEVEL_LENGTH_BASE + float(n) * LEVEL_LENGTH_PER_LEVEL) * LEVEL_LENGTH_SCALE,
		"small_density": 8.0,                          # edible fish per 1000 px
		"medium_density": 2.5 + 3.5 * t + 2.0 * u,     # mixed-size fish per 1000 px
		"big_density": 0.8 + 2.7 * t + 2.0 * u,        # predators per 1000 px
		"predator_speed": 125.0 + 75.0 * t,            # never above 200: the player is always faster
		"detect_range": 330.0 + 200.0 * t + 150.0 * u,
		"patrol_share": 0.3 + 0.4 * t + 0.2 * u,
		"big_min": 40.0 + 10.0 * t + 4.0 * u,
		"big_max": 70.0 + 40.0 * t + 8.0 * u,          # never above MAX_SIZE (120)
		"jelly_density": 0.0 if n < 5 else 0.6 + 2.4 * t + 3.0 * u,
		"rock_density": 1.5 + 1.5 * t + 1.0 * u,
		"rock_max": 55.0 + 95.0 * t + 25.0 * u,
		"chase_time": 5.0 + 3.0 * u,                   # seconds a predator keeps chasing...
		"rest_time": 2.5 - 1.3 * u,                    # ...and how long it rests afterwards
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
	var sp := get_item(str(ids["species"]))
	var skin := get_item(str(ids["skin"]))
	var pat := get_item(str(ids["pattern"]))
	var trail := get_item(str(ids["trail"]))
	var acc := get_item(str(ids["acc"]))
	var spec: Dictionary = sp.get("spec", {})
	# The skin called "Natural" (id skin_goldie) means: use the fish's own colours.
	var natural: bool = str(ids["skin"]) == "skin_goldie"
	var colors: Dictionary = sp if natural else skin
	var pattern: int = int(pat.get("pattern", 0))
	if pattern == 0:
		pattern = int(spec.get("pattern", 0))   # some fish (Koi, Narwhal, Golden Whale) have a natural pattern
	return {
		"species": str(ids["species"]),
		"spec": spec,
		"body": colors.get("body", Color("#ffa534")),
		"belly": colors.get("belly", Color("#ffe08a")),
		"fin": colors.get("fin", Color("#e0661d")),
		"rainbow": (not natural) and bool(skin.get("rainbow", false)),
		"pattern": pattern,
		"acc": acc.get("acc", 0),
		"trail_color": trail.get("color", Color.WHITE),
		"trail_filled": trail.get("filled", false),
		"trail_rainbow": trail.get("rainbow", false),
	}


## Number of the current day on the phone's calendar (local date). Used by the daily reward.
func today_number() -> int:
	var d: Dictionary = Time.get_date_dict_from_system()
	var unix: int = Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"], "hour": 0, "minute": 0, "second": 0})
	return floori(float(unix) / 86400.0)


## True if today's reward has not been claimed yet. (If the phone clock is set back, nothing can be claimed.)
func daily_can_claim() -> bool:
	return today_number() > last_daily_day


## The streak day (1..7) that claiming right now would give.
func daily_next_streak() -> int:
	var s: int = 1
	if last_daily_day > 0 and today_number() == last_daily_day + 1:
		s = daily_streak + 1
	if s > DAILY_REWARDS.size():
		s = 1
	return s


func daily_reward_for(streak_day: int) -> int:
	return int(DAILY_REWARDS[clampi(streak_day - 1, 0, DAILY_REWARDS.size() - 1)])


## Gives today's reward. Returns the number of coins (0 if it was already claimed today).
func claim_daily() -> int:
	if not daily_can_claim():
		return 0
	var s: int = daily_next_streak()
	var gain: int = daily_reward_for(s)
	daily_streak = s
	stats["best_streak"] = maxi(int(stats["best_streak"]), s)
	last_daily_day = today_number()
	add_coins(gain)
	save_game()
	return gain


# --- Missions, stats and achievements (Update A2) ----------------------------------------------------

## Picks the 3 missions of a day. The same day always gives the same missions.
func make_missions(day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 17
	var pool: Array = MISSION_ORDER.duplicate()
	var out: Array = []
	for i in 3:
		var idx: int = rng.randi_range(0, pool.size() - 1)
		var kind: String = str(pool[idx])
		pool.remove_at(idx)
		var tier: int = rng.randi_range(0, 2)
		var info: Dictionary = MISSION_TYPES[kind]
		var target: int = int(info["targets"][tier])
		out.append({"kind": kind, "target": target, "reward": int(info["rewards"][tier]), "text": str(info["text"]) % target})
	return out


## Starts a new set of missions when a new day has begun. (A phone clock set back changes nothing.)
func refresh_missions() -> void:
	var t: int = today_number()
	if t > mission_day:
		mission_day = t
		mission_progress = [0, 0, 0]
		mission_claimed = [false, false, false]
		_missions = []
	if _missions.is_empty():
		_missions = make_missions(mission_day)


func today_missions() -> Array:
	refresh_missions()
	return _missions


func mission_progress_of(i: int) -> int:
	return int(mission_progress[i])


func mission_is_claimed(i: int) -> bool:
	return bool(mission_claimed[i])


## Gives the coins of a finished mission. Returns 0 if it is not finished or was already claimed.
func claim_mission(i: int) -> int:
	refresh_missions()
	if i < 0 or i >= _missions.size() or bool(mission_claimed[i]):
		return 0
	if int(mission_progress[i]) < int(_missions[i]["target"]):
		return 0
	mission_claimed[i] = true
	var gain: int = int(_missions[i]["reward"])
	add_coins(gain)
	save_game()
	return gain


## game.gd calls this when something that counts happens: "eat", "win", "coins" (amount), "death".
func note_add(kind: String, amount: int = 1) -> void:
	refresh_missions()
	if kind == "eat":
		stats["eaten"] = int(stats["eaten"]) + amount
	elif kind == "win":
		stats["wins"] = int(stats["wins"]) + amount
	elif kind == "coins":
		stats["coins"] = int(stats["coins"]) + amount
	elif kind == "death":
		stats["deaths"] = int(stats["deaths"]) + amount
	for i in _missions.size():
		if str(_missions[i]["kind"]) == kind:
			mission_progress[i] = int(mission_progress[i]) + amount


## "combo" and "grow": only the best value counts.
func note_max(kind: String, value: int) -> void:
	refresh_missions()
	if kind == "combo":
		stats["best_combo"] = maxi(int(stats["best_combo"]), value)
	elif kind == "grow":
		stats["biggest"] = maxi(int(stats["biggest"]), value)
	for i in _missions.size():
		if str(_missions[i]["kind"]) == kind:
			mission_progress[i] = maxi(int(mission_progress[i]), value)


func species_total() -> int:
	var n: int = 0
	for it in shop_items:
		if it["cat"] == "species":
			n += 1
	return n


func ach_value(stat: String) -> int:
	if stat == "level":
		return unlocked_level
	if stat == "fish":
		var n: int = 0
		for it in shop_items:
			if it["cat"] == "species" and owned_items.has(it["id"]):
				n += 1
		return n
	return int(stats.get(stat, 0))


## Unlocks every achievement that is reached now, pays its coins once, and returns the newly unlocked ones.
func check_achievements() -> Array:
	var got: Array = []
	for a in ACHIEVEMENTS:
		if unlocked_achs.has(a["id"]):
			continue
		if ach_value(str(a["stat"])) >= int(a["target"]):
			unlocked_achs.append(str(a["id"]))
			add_coins(int(a["reward"]))
			got.append(a)
	if not got.is_empty():
		save_game()
	return got


func achievement_line(i: int) -> String:
	var a: Dictionary = ACHIEVEMENTS[i]
	var t: int = int(a["target"])
	if unlocked_achs.has(a["id"]):
		return "[X] %s - %s   +%d" % [str(a["name"]), str(a["text"]), int(a["reward"])]
	var v: int = mini(ach_value(str(a["stat"])), t)
	return "[  ] %s - %s   (%d/%d)  +%d" % [str(a["name"]), str(a["text"]), v, t, int(a["reward"])]


func achievements_unlocked_count() -> int:
	return unlocked_achs.size()


func stats_text() -> String:
	var secs: int = int(stats["seconds"])
	var hours: int = floori(float(secs) / 3600.0)
	var minutes: int = floori(float(secs % 3600) / 60.0)
	var text := ""
	text += "Fish eaten: %d\n" % int(stats["eaten"])
	text += "Levels finished: %d   (reached level %d of %d)\n" % [int(stats["wins"]), unlocked_level, TOTAL_LEVELS]
	text += "Times eaten: %d\n" % int(stats["deaths"])
	text += "Coins collected in levels: %d\n" % int(stats["coins"])
	text += "Biggest size: %d\n" % int(stats["biggest"])
	text += "Best combo: x%d\n" % int(stats["best_combo"])
	text += "Best daily streak: %d\n" % int(stats["best_streak"])
	text += "Fish owned: %d of %d\n" % [ach_value("fish"), species_total()]
	text += "Time played: %d h %d min" % [hours, minutes]
	return text


## Low quality mode: 30 frames per second instead of the phone's maximum.
func apply_quality() -> void:
	Engine.max_fps = 30 if low_quality else 0


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
	cf.set_value("stats", "launch_count", launch_count)
	for k in stats:
		cf.set_value("stats", "s_" + str(k), stats[k])
	cf.set_value("missions", "day", mission_day)
	cf.set_value("missions", "progress", mission_progress)
	cf.set_value("missions", "claimed", mission_claimed)
	cf.set_value("achievements", "unlocked", unlocked_achs)
	cf.set_value("daily", "last_day", last_daily_day)
	cf.set_value("daily", "streak", daily_streak)
	cf.set_value("settings", "left_handed", left_handed)
	cf.set_value("settings", "joystick_size", joystick_size)
	cf.set_value("settings", "low_quality", low_quality)
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
	launch_count = maxi(0, int(cf.get_value("stats", "launch_count", 0)))
	for k in stats.keys():
		stats[k] = maxi(0, int(cf.get_value("stats", "s_" + str(k), 0)))
	mission_day = maxi(0, int(cf.get_value("missions", "day", 0)))
	var mp: Array = cf.get_value("missions", "progress", [0, 0, 0])
	var mc: Array = cf.get_value("missions", "claimed", [false, false, false])
	mission_progress = [0, 0, 0]
	mission_claimed = [false, false, false]
	for i in 3:
		if i < mp.size():
			mission_progress[i] = maxi(0, int(mp[i]))
		if i < mc.size():
			mission_claimed[i] = bool(mc[i])
	var ua: Array = cf.get_value("achievements", "unlocked", [])
	unlocked_achs.clear()
	for x in ua:
		unlocked_achs.append(str(x))
	last_daily_day = maxi(0, int(cf.get_value("daily", "last_day", 0)))
	daily_streak = clampi(int(cf.get_value("daily", "streak", 0)), 0, DAILY_REWARDS.size())
	left_handed = bool(cf.get_value("settings", "left_handed", false))
	joystick_size = clampi(int(cf.get_value("settings", "joystick_size", 1)), 0, 2)
	low_quality = bool(cf.get_value("settings", "low_quality", false))
	coins = maxi(0, int(cf.get_value("shop", "coins", 0)))
	var saved_owned: Array = cf.get_value("shop", "owned", owned_items)
	for sid in saved_owned:
		if not owned_items.has(str(sid)) and not get_item(str(sid)).is_empty():
			owned_items.append(str(sid))
	for cat in CATEGORY_ORDER:
		var eid: String = str(cf.get_value("equipped", cat, equipped[cat]))
		if is_owned(eid) and not get_item(eid).is_empty() and get_item(eid)["cat"] == cat:
			equipped[cat] = eid
