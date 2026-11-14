extends Node2D
## Wi-Fi / hotspot arena battle: up to 8 fish fight in one pool. Bots can fill empty places.
## The HOST phone runs the whole fight and sends the picture to the other phones 20 times a second.
## The other phones only send their joystick direction and their bite presses to the host.
## Everybody has the same strength. Your fish only changes how you LOOK (species, skin, pattern, extras).
##
## Controls: touch and drag on one half of the screen to swim, tap the other half to BITE
## (the halves swap with the left-handed setting).
## Rules: 5 lives. A bite takes 1 life (2 with the FANG power). Hearts give 1 life back.
## BOLT = faster for 5 s, FANG = double bites for 7 s. The last fish alive wins.

const FishArt = preload("res://scripts/fish_art.gd")
const Background = preload("res://scripts/background.gd")
const Fx = preload("res://scripts/fx.gd")
const UITheme = preload("res://scripts/ui_theme.gd")
const ScrollBox = preload("res://scripts/scroll_box.gd")

const ARENA := Rect2(0.0, 0.0, 1400.0, 800.0)
const WALL := 40.0
const MAX_HP := 5
const FISH_SIZE := 36.0
const FISH_R := 28.0
const MAX_SPEED := 300.0
const BITE_TIME := 0.22       # seconds of the bite dash
const BITE_COOLDOWN := 0.9
const BITE_SPEED := 760.0
const INVULN := 1.1           # seconds nobody can bite you again after a hit
const STICK_R := 100.0
const SLOT_COLORS := [Color("#ff5a5a"), Color("#4aa8ff"), Color("#5ee06a"), Color("#ffd23a"), Color("#c075ff"), Color("#ff9a3c"), Color("#3fe0d0"), Color("#ff7ac8")]

const PH_WAIT := 0
const PH_COUNT := 1
const PH_FIGHT := 2
const PH_OVER := 3
const PK_HEART := 0
const PK_BOLT := 1
const PK_FANG := 2
const EV_BITE := 0
const EV_HIT := 1
const EV_PICKUP := 2
const EV_OUT := 3
const EV_WIN := 4

var fishes: Dictionary = {}    # id -> Dictionary with everything about one fish
var order: Array = []          # ids in roster order
var pickups: Dictionary = {}   # pickup id -> {"kind", "pos"}
var phase: int = PH_WAIT
var timer := 0.0               # countdown (seconds left) or fight time (seconds passed)
var winner_id := 0

var camera: Camera2D
var fx: Fx
var hud: ArenaHud
var _overlay_layer: CanvasLayer
var _online := false
var _server := true
var _my_id := 1
var _ready_ids: Dictionary = {}
var _wait_t := 0.0
var _snap_t := 0.0
var _input_t := 0.0
var _ready_t := 0.0
var _got_state := false
var _next_pickup_t := 4.0
var _pid := 1
var _time := 0.0
var _bite_seq := 0
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _stick_cur := Vector2.ZERO
var _dir := Vector2.ZERO
var _shake := 0.0
var _hurt_flash := 0.0
var _bite_flash := 0.0
var _last_count := -1
var _banner_t := 0.0
var _over_wait := 0.0
var _over_shown := false
var _left := false


func _ready() -> void:
	_online = multiplayer.multiplayer_peer is ENetMultiplayerPeer
	_server = (not _online) or multiplayer.is_server()
	_my_id = multiplayer.get_unique_id() if _online else 1
	var roster: Array = GameState.mp_roster
	if roster.is_empty():   # opened without the lobby (the build test does this): you against 3 bots
		roster = GameState.practice_roster()
		_online = false
		_server = true
		_my_id = 1
	var bg := Background.new()
	bg.theme_data = GameState.get_theme_for_level(1 + (GameState.mp_seed % 30) * 10)
	bg.cam = ARENA.get_center()
	add_child(bg)
	fx = Fx.new()
	fx.z_index = 5
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.position = ARENA.get_center()
	camera.make_current()
	_build_fish(roster)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = ArenaHud.new()
	hud.arena = self
	layer.add_child(hud)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 20
	add_child(_overlay_layer)
	if _online:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_gone)
		multiplayer.server_disconnected.connect(_on_host_gone)
	if _server:
		_ready_ids[1] = true
	get_viewport().size_changed.connect(_update_camera)
	_update_camera()


func _build_fish(roster: Array) -> void:
	var n: int = roster.size()
	var center: Vector2 = ARENA.get_center()
	for i in n:
		var r: Dictionary = roster[i]
		var ang: float = TAU * float(i) / float(maxi(n, 1)) - PI * 0.5
		var pos: Vector2 = center + Vector2(cos(ang) * 380.0, sin(ang) * 240.0)
		var id: int = int(r["id"])
		var face: float = 1.0 if pos.x < center.x else -1.0
		order.append(id)
		fishes[id] = {
			"id": id, "name": str(r["name"]), "look": r["look"], "bot": bool(r["bot"]), "slot": i % SLOT_COLORS.size(),
			"pos": pos, "tpos": pos, "vel": Vector2.ZERO, "facing": face, "turn": face, "hp": MAX_HP,
			"input": Vector2.ZERO, "bite_seq": 0, "last_seq": 0, "bite_cd": 0.0, "bite_t": 0.0, "bite_dir": Vector2.RIGHT,
			"hits": [], "invuln": 0.0, "speed_t": 0.0, "fang_t": 0.0, "out_t": 0.0, "anim": randf() * TAU, "think": 0.0, "seen": false,
		}


func _update_camera() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var z: float = minf(vp.x / (ARENA.size.x + 80.0), vp.y / (ARENA.size.y + 80.0))
	camera.zoom = Vector2(z, z)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_leave()


# --- Frame loop -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_bite_flash = maxf(_bite_flash - delta, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	_shake = maxf(_shake - 40.0 * delta, 0.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	if _server:
		_server_step(delta)
	else:
		_client_step(delta)
	_animate(delta)
	_phase_effects()
	_local_input(delta)
	if phase == PH_OVER and not _over_shown:
		_over_wait += delta
		if _over_wait > 1.2:
			_show_over()
	queue_redraw()
	hud.queue_redraw()


func _server_step(delta: float) -> void:
	if phase == PH_WAIT:
		_wait_t += delta
		if _all_ready() or _wait_t > 10.0:
			for id in order.duplicate():   # a phone that never answered is out of the fight
				var f: Dictionary = fishes[id]
				if not bool(f["bot"]) and not _ready_ids.has(id):
					f["hp"] = 0
			phase = PH_COUNT
			timer = 3.0
	elif phase == PH_COUNT:
		timer -= delta
		if timer <= 0.0:
			phase = PH_FIGHT
			timer = 0.0
	elif phase == PH_FIGHT:
		timer += delta
		_sim(delta)
	if _online and phase != PH_WAIT:
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = 0.05
			_rpc_state.rpc(phase, timer, winner_id, _pack_fish(), _pack_pickups())


func _all_ready() -> bool:
	for id in order:
		if not bool(fishes[id]["bot"]) and not _ready_ids.has(id):
			return false
	return true


func _client_step(delta: float) -> void:
	if not _got_state:   # keep telling the host that this phone is ready, until the first picture arrives
		_ready_t -= delta
		if _ready_t <= 0.0:
			_ready_t = 0.5
			_rpc_ready.rpc_id(1)


func _animate(delta: float) -> void:
	for id in order:
		var f: Dictionary = fishes[id]
		var vel: Vector2 = f["vel"]
		f["anim"] = float(f["anim"]) + delta * (6.0 + vel.length() * 0.02)
		if absf(vel.x) > 20.0:
			f["facing"] = signf(vel.x)
		f["turn"] = move_toward(float(f["turn"]), float(f["facing"]), delta * 6.0)
		if int(f["hp"]) <= 0:
			f["out_t"] = float(f["out_t"]) + delta
		if not _server:
			var pos: Vector2 = f["pos"]
			var tp: Vector2 = f["tpos"]
			f["pos"] = pos.lerp(tp, clampf(delta * 15.0, 0.0, 1.0))


func _phase_effects() -> void:
	if phase == PH_COUNT:
		var c: int = int(ceil(timer))
		if c != _last_count:
			_last_count = c
			AudioManager.play_sfx("click", -2.0, 1.0 + 0.15 * float(3 - c))
	elif phase == PH_FIGHT and _last_count != 0:
		_last_count = 0
		_banner_t = 1.0
		AudioManager.play_sfx("grow", 0.0, 1.2)


# --- Host: the fight ------------------------------------------------------------------------------------

func _sim(delta: float) -> void:
	for id in order:
		var f: Dictionary = fishes[id]
		if bool(f["bot"]) and int(f["hp"]) > 0:
			_bot_think(f, delta)
	for id in order:
		_step_fish(fishes[id], delta)
	_separate()
	_check_bites()
	_pickups_step(delta)
	_check_winner()


func _step_fish(f: Dictionary, delta: float) -> void:
	if int(f["hp"]) <= 0:
		return
	f["invuln"] = maxf(float(f["invuln"]) - delta, 0.0)
	f["bite_cd"] = maxf(float(f["bite_cd"]) - delta, 0.0)
	f["speed_t"] = maxf(float(f["speed_t"]) - delta, 0.0)
	f["fang_t"] = maxf(float(f["fang_t"]) - delta, 0.0)
	var inp: Vector2 = f["input"]
	if int(f["bite_seq"]) != int(f["last_seq"]):
		f["last_seq"] = f["bite_seq"]
		if float(f["bite_cd"]) <= 0.0 and float(f["bite_t"]) <= 0.0:
			f["bite_t"] = BITE_TIME
			f["bite_cd"] = BITE_COOLDOWN
			f["hits"] = []
			f["bite_dir"] = inp.normalized() if inp.length() > 0.3 else Vector2(float(f["facing"]), 0.0)
			_emit_event(EV_BITE, int(f["id"]), 0, f["pos"])
	var spd: float = MAX_SPEED * (1.5 if float(f["speed_t"]) > 0.0 else 1.0)
	if bool(f["bot"]):
		spd *= 0.85   # bots are a little slower than people
	var vel: Vector2 = f["vel"]
	if float(f["bite_t"]) > 0.0:
		f["bite_t"] = float(f["bite_t"]) - delta
		vel = (f["bite_dir"] as Vector2) * BITE_SPEED
	else:
		vel = vel.lerp(inp.limit_length(1.0) * spd, clampf(delta * 6.0, 0.0, 1.0))
	var pos: Vector2 = f["pos"]
	pos += vel * delta
	pos.x = clampf(pos.x, ARENA.position.x + WALL, ARENA.end.x - WALL)
	pos.y = clampf(pos.y, ARENA.position.y + WALL, ARENA.end.y - WALL)
	f["pos"] = pos
	f["vel"] = vel


## Fish cannot swim through each other: overlapping fish are pushed apart a little.
func _separate() -> void:
	for i in order.size():
		var a: Dictionary = fishes[order[i]]
		if int(a["hp"]) <= 0:
			continue
		for j in range(i + 1, order.size()):
			var b: Dictionary = fishes[order[j]]
			if int(b["hp"]) <= 0:
				continue
			var pa: Vector2 = a["pos"]
			var pb: Vector2 = b["pos"]
			var d: Vector2 = pb - pa
			var dist: float = d.length()
			var min_d: float = FISH_R * 1.5
			if dist < min_d and dist > 0.01:
				var push: Vector2 = d / dist * (min_d - dist) * 0.5
				a["pos"] = pa - push
				b["pos"] = pb + push


func _check_bites() -> void:
	for aid in order:
		var a: Dictionary = fishes[aid]
		if int(a["hp"]) <= 0 or float(a["bite_t"]) <= 0.0:
			continue
		var dirv: Vector2 = a["bite_dir"]
		var mouth: Vector2 = (a["pos"] as Vector2) + dirv * (FISH_R * 0.9)
		for vid in order:
			if vid == aid:
				continue
			var v: Dictionary = fishes[vid]
			if int(v["hp"]) <= 0 or float(v["invuln"]) > 0.0:
				continue
			if (a["hits"] as Array).has(vid):
				continue
			if mouth.distance_to(v["pos"]) < FISH_R + 22.0:
				_hit(a, v, dirv)


func _hit(a: Dictionary, v: Dictionary, dirv: Vector2) -> void:
	var dmg: int = 2 if float(a["fang_t"]) > 0.0 else 1
	v["hp"] = maxi(int(v["hp"]) - dmg, 0)
	v["invuln"] = INVULN
	v["vel"] = dirv * 520.0
	(a["hits"] as Array).append(int(v["id"]))
	_emit_event(EV_HIT, int(a["id"]), int(v["id"]), v["pos"])
	if int(v["hp"]) <= 0:
		_emit_event(EV_OUT, int(v["id"]), int(a["id"]), v["pos"])


func _pickups_step(delta: float) -> void:
	_next_pickup_t -= delta
	if _next_pickup_t <= 0.0 and pickups.size() < 3:
		_next_pickup_t = randf_range(5.0, 8.0)
		var r: float = randf()
		var kind: int = PK_HEART if r < 0.5 else (PK_BOLT if r < 0.75 else PK_FANG)
		pickups[_pid] = {"kind": kind, "pos": Vector2(randf_range(120.0, ARENA.end.x - 120.0), randf_range(120.0, ARENA.end.y - 120.0))}
		_pid += 1
	for pid in pickups.keys():
		var pk: Dictionary = pickups[pid]
		var pp: Vector2 = pk["pos"]
		for id in order:
			var f: Dictionary = fishes[id]
			if int(f["hp"]) <= 0:
				continue
			if (f["pos"] as Vector2).distance_to(pp) < FISH_R + 24.0:
				var kind2: int = int(pk["kind"])
				if kind2 == PK_HEART:
					if int(f["hp"]) >= MAX_HP:
						continue   # full health: leave the heart for somebody else
					f["hp"] = int(f["hp"]) + 1
				elif kind2 == PK_BOLT:
					f["speed_t"] = 5.0
				else:
					f["fang_t"] = 7.0
				pickups.erase(pid)
				_emit_event(EV_PICKUP, id, kind2, pp)
				break


func _check_winner() -> void:
	if phase != PH_FIGHT:
		return
	var alive: Array = []
	var humans_alive := 0
	for id in order:
		var f: Dictionary = fishes[id]
		if int(f["hp"]) > 0:
			alive.append(id)
			if not bool(f["bot"]):
				humans_alive += 1
	if alive.size() > 1 and humans_alive > 0:
		return
	phase = PH_OVER
	winner_id = 0
	var best_hp := 0
	for id in alive:   # one fish left, or only bots left: the one with the most lives wins
		var hp: int = int(fishes[id]["hp"])
		if hp > best_hp:
			best_hp = hp
			winner_id = int(id)
	_emit_event(EV_WIN, winner_id, 0, Vector2.ZERO)


## Bots: swim to the nearest enemy, bite when close, go for a heart when low on lives.
func _bot_think(f: Dictionary, delta: float) -> void:
	f["think"] = float(f["think"]) - delta
	if float(f["think"]) > 0.0:
		return   # keep the last decision for a moment, like a person would
	f["think"] = randf_range(0.12, 0.25)
	var pos: Vector2 = f["pos"]
	var target: Dictionary = {}
	var best := 1000000.0
	for id in order:
		if id == int(f["id"]):
			continue
		var o: Dictionary = fishes[id]
		if int(o["hp"]) <= 0:
			continue
		var d: float = pos.distance_to(o["pos"])
		if d < best:
			best = d
			target = o
	if target.is_empty():
		f["input"] = Vector2.ZERO
		return
	var tpos: Vector2 = target["pos"]
	var goal: Vector2 = tpos
	var chasing := true
	if int(f["hp"]) <= 2:
		for pid in pickups:
			var pk: Dictionary = pickups[pid]
			var pp: Vector2 = pk["pos"]
			if int(pk["kind"]) == PK_HEART and pos.distance_to(pp) < 600.0:
				goal = pp
				chasing = false
	var dir: Vector2 = (goal - pos).normalized()
	var side := Vector2(-dir.y, dir.x)
	var wobble: Vector2 = side * sin(_time * 1.5 + float(f["id"])) * 0.5
	if chasing and best < 125.0 and float(f["bite_cd"]) <= 0.0 and randf() < 0.6:
		f["input"] = dir   # aim the bite at the target
		f["bite_seq"] = int(f["bite_seq"]) + 1
	else:
		f["input"] = (dir + wobble).limit_length(1.0) * 0.9


func _pack_fish() -> Array:
	var out: Array = []
	for id in order:
		var f: Dictionary = fishes[id]
		var p: Vector2 = f["pos"]
		var v: Vector2 = f["vel"]
		out.append([id, p.x, p.y, v.x, v.y, f["hp"], f["bite_t"], f["invuln"], f["speed_t"], f["fang_t"], f["bite_cd"]])
	return out


func _pack_pickups() -> Array:
	var out: Array = []
	for pid in pickups:
		var pk: Dictionary = pickups[pid]
		var p: Vector2 = pk["pos"]
		out.append([pid, pk["kind"], p.x, p.y])
	return out


# --- Network messages -------------------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _rpc_ready() -> void:
	if not _server:
		return
	_ready_ids[multiplayer.get_remote_sender_id()] = true


@rpc("any_peer", "unreliable_ordered")
func _rpc_input(dir: Vector2, seq: int) -> void:
	if not _server:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if fishes.has(id):
		var f: Dictionary = fishes[id]
		f["input"] = dir.limit_length(1.0)
		f["bite_seq"] = seq


@rpc("authority", "unreliable_ordered")
func _rpc_state(ph: int, tm: float, win: int, fish: Array, picks: Array) -> void:
	_got_state = true
	phase = ph
	timer = tm
	winner_id = win
	for e in fish:
		var id: int = int(e[0])
		if not fishes.has(id):
			continue
		var f: Dictionary = fishes[id]
		var tp := Vector2(float(e[1]), float(e[2]))
		f["tpos"] = tp
		if not bool(f["seen"]):
			f["seen"] = true
			f["pos"] = tp
		f["vel"] = Vector2(float(e[3]), float(e[4]))
		f["hp"] = int(e[5])
		f["bite_t"] = float(e[6])
		f["invuln"] = float(e[7])
		f["speed_t"] = float(e[8])
		f["fang_t"] = float(e[9])
		f["bite_cd"] = float(e[10])
	pickups.clear()
	for e in picks:
		pickups[int(e[0])] = {"kind": int(e[1]), "pos": Vector2(float(e[2]), float(e[3]))}


@rpc("authority", "reliable")
func _rpc_event(kind: int, a: int, b: int, pos: Vector2) -> void:
	_play_event(kind, a, b, pos)


@rpc("authority", "reliable")
func _rpc_rematch(roster: Array, map_seed: int) -> void:
	GameState.mp_roster = roster
	GameState.mp_seed = map_seed
	get_tree().call_deferred("reload_current_scene")


func _emit_event(kind: int, a: int, b: int, pos: Vector2) -> void:
	_play_event(kind, a, b, pos)
	if _online:
		_rpc_event.rpc(kind, a, b, pos)


func _play_event(kind: int, a: int, b: int, pos: Vector2) -> void:
	if kind == EV_BITE:
		AudioManager.play_sfx("swim", -4.0, 1.5)
	elif kind == EV_HIT:
		fx.burst(pos, Color(1.0, 0.55, 0.25), 12, 260.0)
		fx.ring(pos, 8.0, 90.0, Color(1.0, 0.8, 0.4), 0.35)
		fx.popup(pos + Vector2(0.0, -40.0), "BITE!", Color(1.0, 0.85, 0.4), 30)
		AudioManager.play_sfx("chomp")
		if b == _my_id:
			_hurt_flash = 0.4
			_shake = 12.0
	elif kind == EV_PICKUP:
		var col: Color = Color("#ff6a8a") if b == PK_HEART else (Color("#ffd23a") if b == PK_BOLT else Color("#ff5a3a"))
		var label: String = "+1 LIFE" if b == PK_HEART else ("SPEED!" if b == PK_BOLT else "DOUBLE BITE!")
		fx.sparkles(pos, col, 10, 260.0)
		fx.ring(pos, 10.0, 110.0, col, 0.45)
		fx.popup(pos + Vector2(0.0, -40.0), label, col.lightened(0.3), 30)
		AudioManager.play_sfx("grow", -2.0, 1.2)
	elif kind == EV_OUT:
		fx.burst(pos, Color(1.0, 0.3, 0.3), 30, 320.0)
		fx.popup(pos + Vector2(0.0, -50.0), "OUT!", Color(1.0, 0.35, 0.35), 44)
		AudioManager.play_sfx("lose" if a == _my_id else "hurt")
		if a == _my_id:
			_shake = 16.0
	elif kind == EV_WIN:
		AudioManager.play_sfx("win")


# --- Input ------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var on_stick_side: bool = event.position.x < vp.x * 0.5
		if GameState.left_handed:
			on_stick_side = not on_stick_side
		if event.pressed:
			if on_stick_side and _stick_idx == -1:
				_stick_idx = event.index
				_stick_origin = event.position
				_stick_cur = event.position
				_dir = Vector2.ZERO
			elif not on_stick_side:
				_bite_seq += 1
				_bite_flash = 0.2
		elif event.index == _stick_idx:
			_stick_idx = -1
			_dir = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _stick_idx:
		_stick_cur = event.position
		var d: Vector2 = _stick_cur - _stick_origin
		if d.length() > STICK_R:
			_stick_origin = _stick_cur - d.normalized() * STICK_R   # the base follows the thumb
			d = _stick_cur - _stick_origin
		_dir = d / STICK_R
		if _dir.length() < 0.12:
			_dir = Vector2.ZERO


func _local_input(delta: float) -> void:
	var dir: Vector2 = _dir
	var kb: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")   # keyboard, for testing on a computer
	if kb.length() > 0.1:
		dir = kb
	if Input.is_action_just_pressed("ui_accept"):
		_bite_seq += 1
	var me = fishes.get(_my_id)
	if me == null:
		return
	if phase != PH_FIGHT or int(me["hp"]) <= 0:
		dir = Vector2.ZERO
	if _server:
		me["input"] = dir.limit_length(1.0)
		me["bite_seq"] = _bite_seq
	elif _online:
		_input_t -= delta
		if _input_t <= 0.0:
			_input_t = 1.0 / 30.0
			_rpc_input.rpc_id(1, dir, _bite_seq)


# --- Disconnects --------------------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if _server:   # nobody can join a fight that has already started
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_peer_gone(id: int) -> void:
	if not _server:
		return
	_ready_ids.erase(id)
	if fishes.has(id):
		var f: Dictionary = fishes[id]
		if int(f["hp"]) > 0:
			f["hp"] = 0
			_emit_event(EV_OUT, id, 0, f["pos"])
			_check_winner()


func _on_host_gone() -> void:
	_build_overlay("Host left", Color("#ff7a7a"), ["The host closed the game."], [["Leave", _leave]])


# --- End of the fight ---------------------------------------------------------------------------------------

func _human_count() -> int:
	var n := 0
	for id in order:
		if not bool(fishes[id]["bot"]):
			n += 1
	return n


func _show_over() -> void:
	_over_shown = true
	var title := "Draw!"
	var col := Color("#ffd23a")
	if winner_id == _my_id:
		title = "YOU WIN!"
		col = Color("#7dff9a")
	elif winner_id != 0 and fishes.has(winner_id):
		title = "%s wins!" % str(fishes[winner_id]["name"])
	elif winner_id == 0:
		title = "Draw!"
	var lines: Array = []
	if _online and _human_count() >= 2:   # real battle with other people: a small coin reward
		var gain: int = 10
		if winner_id == _my_id:
			gain += 40
			GameState.note_add("mpwin", 1)
		GameState.add_coins(gain)
		GameState.save_game()
		lines.append("Coins: +%d" % gain)
		var got: Array = GameState.check_achievements()
		if not got.is_empty():
			lines.append("Achievement: %s" % str(got[0]["name"]))
	else:
		lines.append("Practice battle (no coins).")
	var buttons: Array = []
	if _server:
		buttons.append(["Rematch", _rematch])
	else:
		lines.append("Waiting for the host to start a rematch...")
	buttons.append(["Leave", _leave])
	_build_overlay(title, col, lines, buttons)


func _build_overlay(title: String, col: Color, lines: Array, buttons: Array) -> void:
	for c in _overlay_layer.get_children():
		c.queue_free()
	var root := Control.new()
	root.theme = UITheme.make()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.05, 0.12, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	var box := ScrollBox.new()
	box.setup(vb, true, 110.0)
	panel.add_child(box)
	vb.add_child(UITheme.label(title, 56, col))
	for line in lines:
		vb.add_child(UITheme.label(str(line), 28))
	for b in buttons:
		var btn: Button = UITheme.button(str(b[0]), b[1], 420.0, 74.0)
		vb.add_child(btn)


func _rematch() -> void:
	var keep: Array = []
	for r in GameState.mp_roster:
		var id: int = int(r["id"])
		if bool(r["bot"]) or id == 1 or (_online and multiplayer.get_peers().has(id)):
			keep.append(r)
	GameState.mp_roster = keep
	GameState.mp_seed = randi()
	if _online:
		_rpc_rematch.rpc(keep, GameState.mp_seed)
	get_tree().reload_current_scene()


func _leave() -> void:
	if _online:
		multiplayer.multiplayer_peer = null
	GameState.mp_roster = []
	GameState.go_to("res://scenes/main_menu.tscn")


# --- Drawing ------------------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(ARENA, Color(1, 1, 1, 0.05))
	draw_rect(ARENA, Color(1, 1, 1, 0.55), false, 6.0)
	for pid in pickups:
		_draw_pickup(pickups[pid])
	for id in order:
		_draw_fish(fishes[id])
	for id in order:
		_draw_tag(fishes[id])


func _draw_heart(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p + Vector2(-r * 0.5, -r * 0.25), r * 0.55, col)
	c.draw_circle(p + Vector2(r * 0.5, -r * 0.25), r * 0.55, col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.02, -r * 0.05), p + Vector2(r * 1.02, -r * 0.05), p + Vector2(0.0, r * 1.05)]), col)


func _draw_pickup(pk: Dictionary) -> void:
	var p: Vector2 = pk["pos"] + Vector2(0.0, sin(_time * 2.5) * 5.0)
	var kind: int = int(pk["kind"])
	var col: Color = Color("#ff6a8a") if kind == PK_HEART else (Color("#ffd23a") if kind == PK_BOLT else Color("#ff5a3a"))
	draw_circle(p, 44.0 + 4.0 * sin(_time * 4.0), Color(col.r, col.g, col.b, 0.18))
	draw_circle(p, 30.0, col.darkened(0.35))
	draw_circle(p, 26.0, col)
	if kind == PK_HEART:
		_draw_heart(self, p + Vector2(0.0, 1.0), 12.0, Color.WHITE)
	elif kind == PK_BOLT:
		draw_colored_polygon(PackedVector2Array([p + Vector2(4, -15), p + Vector2(-9, 3), p + Vector2(-1, 3), p + Vector2(-5, 15), p + Vector2(10, -5), p + Vector2(2, -5)]), Color.WHITE)
	else:   # fang: two white teeth
		draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -10), p + Vector2(-2, -10), p + Vector2(-8, 13)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([p + Vector2(2, -10), p + Vector2(13, -10), p + Vector2(8, 13)]), Color.WHITE)


func _draw_fish(f: Dictionary) -> void:
	var hp: int = int(f["hp"])
	var pos: Vector2 = f["pos"]
	var look: Dictionary = f["look"]
	var cols: Array = FishArt.resolve_colors(look, _time)
	var t: float = float(f["turn"])
	if absf(t) < 0.15:
		t = 0.15 * float(f["facing"])
	var vel: Vector2 = f["vel"]
	var tilt: float = atan2(vel.y, maxf(absf(vel.x), 80.0)) * 0.35 * signf(t)
	var pattern: int = int(look.get("pattern", 0))
	var acc: int = int(look.get("acc", 0))
	if hp <= 0:   # eliminated: spins, shrinks and floats up
		var k: float = float(f["out_t"])
		if k > 1.2:
			return
		var sc: float = 1.0 - k / 1.2
		var xo := Transform2D(k * 5.0, Vector2(t * sc, sc), 0.0, pos + Vector2(0.0, -k * 40.0))
		FishArt.draw_fish(self, xo, FISH_SIZE, 0, cols[0], cols[1], cols[2], 0.0, 0.0, 1, pattern, acc, true, look.get("spec", {}))
		return
	var slot_col: Color = SLOT_COLORS[int(f["slot"])]
	draw_arc(pos, FISH_R * 1.4, 0.0, TAU, 28, Color(slot_col.r, slot_col.g, slot_col.b, 0.8), 4.0)
	if float(f["fang_t"]) > 0.0:
		draw_circle(pos, FISH_R * (1.9 + 0.15 * sin(_time * 10.0)), Color(1.0, 0.25, 0.15, 0.22))
	if float(f["speed_t"]) > 0.0:
		var back: float = -signf(t)
		for i in 3:
			var yy: float = (float(i) - 1.0) * FISH_R * 0.7
			draw_line(pos + Vector2(back * FISH_R * 1.6, yy), pos + Vector2(back * FISH_R * 2.6, yy), Color(1.0, 0.85, 0.3, 0.6), 3.0)
	var xf := Transform2D(tilt, Vector2(t, 1.0), 0.0, pos)
	var mouth: float = 1.0 if float(f["bite_t"]) > 0.0 else 0.0
	FishArt.draw_fish(self, xf, FISH_SIZE, 0, cols[0], cols[1], cols[2], sin(float(f["anim"])), mouth, 1, pattern, acc, false, look.get("spec", {}))
	if float(f["invuln"]) > 0.0 and fmod(float(f["invuln"]), 0.2) > 0.1:
		draw_circle(pos, FISH_R * 1.3, Color(1, 1, 1, 0.35))   # flashes after a bite


func _draw_tag(f: Dictionary) -> void:
	var hp: int = int(f["hp"])
	if hp <= 0:
		return
	var pos: Vector2 = f["pos"]
	var font := ThemeDB.fallback_font
	var top: float = pos.y - FISH_R * 2.3
	for h in MAX_HP:
		_draw_heart(self, Vector2(pos.x + float(h - 2) * 18.0, top), 6.5, Color("#ff4a6a") if h < hp else Color(0, 0, 0, 0.35))
	var nm: String = str(f["name"])
	draw_string_outline(font, Vector2(pos.x - 100.0, top - 14.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 22, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(pos.x - 100.0, top - 14.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 22, Color.WHITE)
	if int(f["id"]) == _my_id:   # a small arrow marks your own fish
		var ay: float = top - 56.0 + sin(_time * 5.0) * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 12.0, ay), Vector2(pos.x + 12.0, ay), Vector2(pos.x, ay + 16.0)]), Color("#ffd23a"))


## Everything on the screen that does not move with the camera: scoreboard, countdown, controls.
func draw_hud(c: Control) -> void:
	var vp: Vector2 = c.size
	var font := ThemeDB.fallback_font
	var y := 22.0
	for id in order:
		var f: Dictionary = fishes[id]
		var hp: int = int(f["hp"])
		var col: Color = SLOT_COLORS[int(f["slot"])]
		var al: float = 1.0 if hp > 0 else 0.4
		c.draw_circle(Vector2(30.0, y + 8.0), 9.0, Color(col.r, col.g, col.b, al))
		var label: String = str(f["name"]) + (" (you)" if int(id) == _my_id else "")
		c.draw_string_outline(font, Vector2(48.0, y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, 230.0, 21, 5, Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(48.0, y + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, 230.0, 21, Color(1, 1, 1, al))
		if hp > 0:
			for h in MAX_HP:
				_draw_heart(c, Vector2(298.0 + float(h) * 17.0, y + 9.0), 6.0, Color("#ff4a6a") if h < hp else Color(0, 0, 0, 0.4))
		else:
			c.draw_string(font, Vector2(290.0, y + 16.0), "OUT", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 21, Color(1, 0.5, 0.5, 0.8))
		y += 31.0
	var big := ""
	var big_col := Color.WHITE
	if phase == PH_WAIT:
		big = "Waiting for all players..."
	elif phase == PH_COUNT:
		big = str(int(ceil(timer)))
	elif phase == PH_FIGHT and _banner_t > 0.0:
		big = "FIGHT!"
		big_col = Color("#ffd23a")
	if big != "":
		c.draw_string_outline(font, Vector2(0.0, vp.y * 0.36), big, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 96, 12, Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(0.0, vp.y * 0.36), big, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 96, big_col)
	var me = fishes.get(_my_id)
	if me != null and int(me["hp"]) > 0:
		var st := ""
		if float(me["speed_t"]) > 0.0:
			st += "SPEED %ds   " % int(ceil(float(me["speed_t"])))
		if float(me["fang_t"]) > 0.0:
			st += "DOUBLE BITE %ds" % int(ceil(float(me["fang_t"])))
		if st != "":
			c.draw_string_outline(font, Vector2(0.0, 44.0), st, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, 6, Color(0, 0, 0, 0.8))
			c.draw_string(font, Vector2(0.0, 44.0), st, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 28, Color("#ffe27a"))
	if _stick_idx >= 0:
		c.draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		c.draw_arc(_stick_origin, STICK_R, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		c.draw_circle(_stick_cur, 42.0, Color(1, 1, 1, 0.45))
	var bx: float = vp.x * (0.14 if GameState.left_handed else 0.86)
	var bc := Vector2(bx, vp.y * 0.78)
	var cd: float = 0.0
	if me != null:
		cd = clampf(float(me["bite_cd"]) / BITE_COOLDOWN, 0.0, 1.0)
	var ready_col := Color(1.0, 0.82, 0.23, 0.55) if cd <= 0.0 else Color(0.6, 0.6, 0.6, 0.4)
	c.draw_circle(bc, 82.0 + (8.0 if _bite_flash > 0.0 else 0.0), ready_col)
	c.draw_arc(bc, 82.0, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 4.0)
	if cd > 0.0:
		c.draw_arc(bc, 70.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cd), 32, Color(1, 1, 1, 0.9), 6.0)
	c.draw_string_outline(font, bc + Vector2(-80.0, 12.0), "BITE", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 36, 6, Color(0, 0, 0, 0.7))
	c.draw_string(font, bc + Vector2(-80.0, 12.0), "BITE", HORIZONTAL_ALIGNMENT_CENTER, 160.0, 36, Color.WHITE)
	if _hurt_flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 0, 0, 0.3 * _hurt_flash / 0.4))


class ArenaHud extends Control:
	var arena = null

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if arena != null:
			arena.draw_hud(self)
