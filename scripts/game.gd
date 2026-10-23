extends Node2D
## Level manager. Builds a level from GameState.get_level_config(), spawns fish,
## jellyfish and rocks, runs the game loop (input, eating rules, collisions,
## win/lose) and talks to the HUD.
##
## World layout: the player starts at x=140 and swims RIGHT to the finish wall at
## x = level length. The ocean is 1000 px tall; the camera follows the player.

const Player = preload("res://scripts/player.gd")
const Fish = preload("res://scripts/fish.gd")
const Jelly = preload("res://scripts/jellyfish.gd")
const Hud = preload("res://scripts/hud.gd")
const Background = preload("res://scripts/background.gd")
const DecorChunk = preload("res://scripts/decor_chunk.gd")
const Gate = preload("res://scripts/finish_gate.gd")
const Fx = preload("res://scripts/fx.gd")
const Coin = preload("res://scripts/coin.gd")

enum S { TUTORIAL, PLAYING, PAUSED, WON, LOST }

const WORLD_HEIGHT := 1000.0
const CHUNK_W := 800.0

var level := 1
var cfg: Dictionary = {}
var length := 4000.0
var world_rect := Rect2()
var state: int = S.PLAYING

var player: Player
var camera: Camera2D
var hud: Hud
var background: Background
var fx: Fx
var fish_list: Array = []
var jelly_list: Array = []
var chunks: Array = []
var coin_list: Array = []
var rocks: Array = []       # Vector3(x, y, radius)

var score := 0
var eaten := 0
var stings := 0
var coins_run := 0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()

var _survive_acc := 0.0
var _activate_timer := 0.0
var _swim_timer := 0.0
var _bubble_timer := 0.0
var _trail_timer := 0.0
var _end_delay := 0.0
var _stats: Dictionary = {}


func _ready() -> void:
	level = GameState.current_level
	cfg = GameState.get_level_config(level)
	length = cfg["length"]
	world_rect = Rect2(0.0, 40.0, length + 300.0, 900.0)
	rng.seed = 7919 * level + 13    # same level = same layout every retry
	get_tree().paused = false
	_build_world()
	_build_player_and_camera()
	_spawn_creatures()
	_build_hud()
	_update_activation()
	if level == 1 and not GameState.tutorial_seen:
		state = S.TUTORIAL
		get_tree().paused = true
		hud.show_tutorial()
	else:
		state = S.PLAYING
		_begin_play()


func _exit_tree() -> void:
	get_tree().paused = false


# --- Setup -------------------------------------------------------------------

func _build_world() -> void:
	var theme: Dictionary = cfg["theme"]
	background = Background.new()
	background.theme_data = theme
	add_child(background)

	var rock_data := _generate_rocks()
	var chunk_total := int(ceil((length + 1400.0) / CHUNK_W))
	for i in chunk_total:
		var cx := -600.0 + float(i) * CHUNK_W
		var chunk_rocks: Array = []
		for r in rock_data:
			var rv: Vector3 = r
			if rv.x >= cx and rv.x < cx + CHUNK_W:
				chunk_rocks.append(rv)
		var chunk := DecorChunk.new()
		chunk.z_index = -5
		chunk.setup(cx, CHUNK_W, theme, level * 1000 + i, chunk_rocks)
		add_child(chunk)
		chunks.append(chunk)

	var gate := Gate.new()
	gate.position = Vector2(length, 0.0)
	gate.z_index = -4
	add_child(gate)


func _generate_rocks() -> Array:
	var count := int(length / 1000.0 * float(cfg["rock_density"]))
	var out: Array = []
	for i in count:
		var x := rng.randf_range(800.0, length - 250.0)
		var r := rng.randf_range(32.0, float(cfg["rock_max"]))
		out.append(Vector3(x, DecorChunk.floor_y(x) - r * 0.55, r))
	rocks = out
	return out


func _build_player_and_camera() -> void:
	player = Player.new()
	player.position = Vector2(140.0, 480.0)
	player.size_val = GameState.PLAYER_START_SIZE
	player.shown_size = GameState.PLAYER_START_SIZE
	player.start_size = GameState.PLAYER_START_SIZE
	player.world_rect = world_rect
	player.look = GameState.get_look()
	player.z_index = 3
	add_child(player)

	camera = Camera2D.new()
	camera.limit_left = -100
	camera.limit_right = int(length + 400.0)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_HEIGHT)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.position = player.position + Vector2(160.0, 0.0)
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	fx = Fx.new()
	fx.z_index = 5
	add_child(fx)


func _spawn_creatures() -> void:
	var kms := length / 1000.0
	for i in int(kms * float(cfg["small_density"])):
		_spawn_fish(0)
	for i in int(kms * float(cfg["medium_density"])):
		_spawn_fish(1)
	for i in int(kms * float(cfg["big_density"])):
		_spawn_fish(2)
	for i in int(kms * float(cfg["jelly_density"])):
		var j := Jelly.new()
		j.base_pos = Vector2(rng.randf_range(1100.0, length - 300.0), rng.randf_range(180.0, 760.0))
		j.bob = rng.randf_range(70.0, 150.0)
		j.speed = rng.randf_range(0.6, 1.1)
		j.phase = rng.randf_range(0.0, TAU)
		j.z_index = 1
		add_child(j)
		jelly_list.append(j)
	_spawn_coins(kms)


## Coins come in groups of 5 (line, wave or arc). Some sit near predators: risk vs reward.
func _spawn_coins(kms: float) -> void:
	for g in int(kms * GameState.COIN_GROUPS_PER_KM):
		var gx := rng.randf_range(500.0, length - 250.0)
		var gy := rng.randf_range(140.0, 780.0)
		var shape := rng.randi_range(0, 2)
		for k in 5:
			var cp := Vector2(gx + float(k) * 60.0, gy)
			if shape == 1:
				cp.y += sin(float(k) * 1.2) * 45.0
			elif shape == 2:
				cp.y -= sin(float(k) / 4.0 * PI) * 70.0
			var coin := Coin.new()
			coin.position = cp
			coin.z_index = 1
			add_child(coin)
			coin_list.append(coin)


## tier 0 = small prey, 1 = medium (mixed), 2 = big predator
func _spawn_fish(tier: int) -> void:
	var t: float = cfg["t"]
	var theme: Dictionary = cfg["theme"]
	var f := Fish.new()
	var min_x := 300.0 if tier == 0 else (650.0 if tier == 1 else 900.0)   # safe zone at the start
	f.position = Vector2(rng.randf_range(min_x, length - 150.0), rng.randf_range(world_rect.position.y + 40.0, world_rect.end.y - 140.0))
	f.world_rect = world_rect
	f.player = player
	var pred_speed: float = cfg["predator_speed"]
	var detect: float = cfg["detect_range"]
	match tier:
		0:
			f.size_val = rng.randf_range(8.0, 16.0)
			f.kind = rng.randi_range(0, 1)
			f.body_color = Color.from_hsv(rng.randf(), 0.55, 1.0)
			f.wander_speed = rng.randf_range(60.0, 100.0)
			f.flee_speed = rng.randf_range(170.0, 200.0)
		1:
			f.size_val = rng.randf_range(19.0, 40.0)
			f.kind = rng.randi_range(0, 2)
			f.body_color = Color.from_hsv(rng.randf(), 0.7, 0.9)
			f.wander_speed = rng.randf_range(70.0, 110.0)
			f.flee_speed = 160.0
			f.chase_speed = pred_speed * 0.85
			f.detect_range = detect * 0.8
		_:
			f.size_val = rng.randf_range(float(cfg["big_min"]), float(cfg["big_max"]))
			f.kind = 3 if rng.randf() < 0.7 else 2
			var hue: float = theme["pred_hue"]
			f.body_color = Color.from_hsv(fposmod(hue + rng.randf_range(-0.04, 0.04), 1.0), 0.75, 0.55)
			f.wander_speed = rng.randf_range(70.0, 100.0)
			f.chase_speed = pred_speed
			f.detect_range = detect
	f.flee_range = 260.0 + f.size_val * 3.0
	if tier > 0 and rng.randf() < float(cfg["patrol_share"]):
		f.patroller = true
		var reach := rng.randf_range(150.0, 350.0)
		f.patrol_a = Vector2(maxf(f.position.x - reach, 300.0), f.position.y)
		f.patrol_b = Vector2(f.position.x + reach, f.position.y)
	add_child(f)
	f.active = false
	fish_list.append(f)


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.set_level_info(level, cfg["theme"]["name"])
	hud.pause_requested.connect(_pause)
	hud.resume_requested.connect(_resume)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(_go_menu)
	hud.next_requested.connect(_next_level)
	hud.tutorial_closed.connect(_on_tutorial_closed)
	hud.back_requested.connect(_on_back)
	hud.shop_requested.connect(_go_shop)
	hud.app_paused.connect(_pause)


func _begin_play() -> void:
	AudioManager.start_music()
	hud.show_banner("Level %d - %s" % [level, cfg["theme"]["name"]])


# --- Main loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	_update_camera(delta)
	background.cam = camera.get_screen_center_position()
	_activate_timer -= delta
	if _activate_timer <= 0.0:
		_activate_timer = 0.25
		_update_activation()
	_ambient_bubbles(delta)

	if state == S.LOST or state == S.WON:
		if _end_delay > 0.0:
			_end_delay -= delta
			if _end_delay <= 0.0:
				_show_end_screen()
		return
	if state != S.PLAYING:
		return

	elapsed += delta
	_survive_acc += delta
	if _survive_acc >= 1.0:
		_survive_acc -= 1.0
		score += 1   # 1 point per second survived

	_read_input()
	_check_rocks()
	_check_jellyfish()
	_check_coins()
	_check_fish()
	if state == S.PLAYING and player.position.x >= length:
		_win()
	hud.update_stats(player.size_val, score, clampf(player.position.x / length, 0.0, 1.0), GameState.coins)


func _read_input() -> void:
	var dir: Vector2 = hud.joystick.direction
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if kb.length() > 0.1:
		dir = kb
	player.input_dir = dir.limit_length(1.0)
	_swim_timer -= get_process_delta_time()
	if player.input_dir.length() > 0.2 and _swim_timer <= 0.0:
		_swim_timer = 0.55
		AudioManager.play_sfx("swim", -12.0)


func _update_camera(delta: float) -> void:
	camera.position = player.position + Vector2(160.0, 0.0)
	var z: float = lerpf(1.0, 0.8, clampf((player.size_val - 20.0) / 80.0, 0.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2(z, z), clampf(delta * 2.0, 0.0, 1.0))


func _ambient_bubbles(delta: float) -> void:
	var center: Vector2 = camera.get_screen_center_position()
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = 0.25
		fx.bubble(center + Vector2(randf_range(-700.0, 700.0), 420.0), randf_range(2.0, 6.0))
	_trail_timer -= delta
	if _trail_timer <= 0.0 and player.velocity.length() > 120.0 and not player.dead:
		_trail_timer = 0.18
		var look: Dictionary = player.look
		var tcol: Color = look.get("trail_color", Color.WHITE)
		if look.get("trail_rainbow", false):
			tcol = Color.from_hsv(fposmod(elapsed * 0.6 + randf() * 0.2, 1.0), 0.6, 1.0)
		var filled: bool = look.get("trail_filled", false)
		fx.bubble(player.position + Vector2(-player.facing * player.shown_size, 0.0), 2.5 if filled else 3.0, tcol, filled)


## Only fish/jellyfish/decor near the camera run AI and drawing - keeps phones fast.
func _update_activation() -> void:
	var cx: float = camera.get_screen_center_position().x
	var range_x: float = 1000.0 / maxf(camera.zoom.x, 0.4)
	for f in fish_list:
		var ff: Fish = f
		ff.active = absf(ff.position.x - cx) < range_x
	for j in jelly_list:
		var jj: Jelly = j
		jj.active = absf(jj.base_pos.x - cx) < range_x
	for k in coin_list:
		var cc: Coin = k
		cc.active = absf(cc.position.x - cx) < range_x
	for c in chunks:
		var ch: DecorChunk = c
		ch.active = absf(ch.x0 + CHUNK_W * 0.5 - cx) < range_x + CHUNK_W


# --- Rules -------------------------------------------------------------------

func _check_fish() -> void:
	var pr: float = player.body_radius()
	var ppos: Vector2 = player.position
	for i in range(fish_list.size() - 1, -1, -1):
		var f: Fish = fish_list[i]
		if not f.active:
			continue
		var reach: float = (pr + f.size_val * 0.8) * 0.72
		var d: float = ppos.distance_to(f.position)
		if d > reach:
			continue
		if f.relation == 1:
			_eat(f, i)
		elif f.relation == 2:
			_lose(f)
			return
		else:   # similar size: they just bump into each other
			var push: Vector2 = (ppos - f.position).normalized()
			player.position += push * (reach - d) * 0.5
			f.position -= push * (reach - d) * 0.5


func _eat(f: Fish, idx: int) -> void:
	var pts := int(round(f.size_val * 2.0))
	score += pts
	eaten += 1
	var tier_before := int(player.size_val / 10.0)
	var stage_before: int = player.get_stage()
	player.eat_fish(f.size_val)
	fx.burst(f.position, f.body_color, 12)
	fx.popup(f.position + Vector2(0.0, -f.size_val), "+%d" % pts, Color(1.0, 0.95, 0.4))
	AudioManager.play_sfx("eat")
	if player.get_stage() != stage_before:
		AudioManager.play_sfx("grow")
		fx.popup(player.position + Vector2(0.0, -70.0), "EVOLVED!", Color(0.5, 1.0, 0.6))
	elif int(player.size_val / 10.0) != tier_before:
		AudioManager.play_sfx("grow", -4.0)
	fish_list.remove_at(idx)
	f.queue_free()


func _check_coins() -> void:
	var pr: float = player.body_radius()
	for i in range(coin_list.size() - 1, -1, -1):
		var c: Coin = coin_list[i]
		if not c.active:
			continue
		if player.position.distance_to(c.position) < pr + Coin.RADIUS:
			coins_run += c.value
			GameState.add_coins(c.value)
			score += 5 * c.value
			fx.burst(c.position, Color(1.0, 0.85, 0.2), 5, 120.0)
			AudioManager.play_sfx("coin", -4.0)
			coin_list.remove_at(i)
			c.queue_free()


func _check_rocks() -> void:
	var pr: float = player.body_radius()
	for r in rocks:
		var rv: Vector3 = r
		var center := Vector2(rv.x, rv.y)
		var offset: Vector2 = player.position - center
		var min_d: float = rv.z + pr * 0.8
		if offset.length() < min_d:
			var normal := offset.normalized() if offset.length() > 0.01 else Vector2.UP
			player.position = center + normal * min_d
			var into: float = player.velocity.dot(normal)
			if into < 0.0:
				player.velocity -= normal * into


func _check_jellyfish() -> void:
	if player.invuln > 0.0:
		return
	var pr: float = player.body_radius()
	for j in jelly_list:
		var jj: Jelly = j
		if not jj.active:
			continue
		if player.position.distance_to(jj.position) < Jelly.RADIUS * 0.9 + pr * 0.55:
			player.sting()
			player.velocity = (player.position - jj.position).normalized() * 450.0
			stings += 1
			AudioManager.play_sfx("hurt")
			fx.burst(player.position, Color(0.9, 0.5, 1.0), 10)
			fx.popup(player.position + Vector2(0.0, -60.0), "Ouch!", Color(1.0, 0.6, 1.0))
			return


func _lose(killer: Fish) -> void:
	if state != S.PLAYING:
		return
	state = S.LOST
	player.dead = true
	killer.mouth = 1.0
	hud.joystick.reset()
	fx.burst(player.position, Color(1.0, 0.6, 0.2), 18, 220.0)
	AudioManager.play_sfx("lose")
	GameState.save_game()   # keep the coins you collected
	_end_delay = 1.0


func _win() -> void:
	state = S.WON
	player.finished = true
	hud.joystick.reset()
	var old_best := int(GameState.best_scores.get(level, 0))
	score += 500 + level * 20                       # finish bonus
	score += maxi(0, int(300.0 - elapsed)) * 2      # speed bonus
	var bonus_coins := 10 + floori(level / 2.0)
	GameState.add_coins(bonus_coins)
	GameState.complete_level(level, score)   # also saves coins
	_stats = {
		"coins_run": coins_run,
		"bonus_coins": bonus_coins,
		"coins_total": GameState.coins,
		"score": score,
		"best": maxi(old_best, score),
		"new_best": score > old_best,
		"start_size": int(player.start_size),
		"size": int(player.size_val),
		"eaten": eaten,
		"time": int(elapsed),
		"is_last": level >= GameState.TOTAL_LEVELS,
	}
	hud.update_stats(player.size_val, score, 1.0, GameState.coins)
	fx.burst(player.position + Vector2(100.0, 0.0), Color(1.0, 0.9, 0.3), 30, 300.0)
	AudioManager.play_sfx("win")
	_end_delay = 1.4


func _show_end_screen() -> void:
	if state == S.WON:
		hud.show_win(_stats)
	elif state == S.LOST:
		hud.show_lose({"score": score})


# --- Pause / navigation ------------------------------------------------------

func _pause() -> void:
	if state != S.PLAYING:
		return
	state = S.PAUSED
	get_tree().paused = true
	hud.joystick.reset()
	GameState.save_game()
	hud.show_pause()


func _resume() -> void:
	if state != S.PAUSED:
		return
	state = S.PLAYING
	get_tree().paused = false
	hud.clear_overlay()


func _on_tutorial_closed() -> void:
	GameState.tutorial_seen = true
	GameState.save_game()
	hud.clear_overlay()
	get_tree().paused = false
	state = S.PLAYING
	_begin_play()


## Android back button / Esc
func _on_back() -> void:
	match state:
		S.TUTORIAL:
			_on_tutorial_closed()
		S.PLAYING:
			_pause()
		S.PAUSED:
			_resume()
		_:
			_go_menu()


func _restart() -> void:
	GameState.save_game()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _next_level() -> void:
	GameState.current_level = mini(level + 1, GameState.TOTAL_LEVELS)
	_restart()


func _go_shop() -> void:
	GameState.save_game()
	GameState.go_to("res://scenes/shop.tscn")


func _go_menu() -> void:
	GameState.save_game()
	GameState.go_to("res://scenes/main_menu.tscn")
