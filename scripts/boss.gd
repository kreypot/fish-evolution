extends Node2D
## A boss: a giant predator that hunts you through the second part of every 10th level.
## It never gets tired, but it is always slower than you. Every few seconds it stops, shows a red line and a "!"
## (wind-up), and then charges along that line. Swim sideways when you see the "!".
## If it touches you, you are eaten (the shield blocks one bite). Reach the finish and you beat it.

const FishArt = preload("res://scripts/fish_art.gd")

var player = null
var world_rect := Rect2()
var size_val := 130.0
var speed := 165.0
var kind := 3
var spec: Dictionary = {}
var body_color := Color(0.45, 0.1, 0.1)
var velocity := Vector2.ZERO
var facing := 1.0
var turn := 1.0
var phase := 0.0
var mouth := 0.0
var lunge_t := 0.0     # > 0 while it lunges at you after catching you
var stagger := 0.0     # seconds it is stunned after your shield blocked a bite
var gone := false      # you reached the finish: it swims away

var _delay := 1.5
var _mode := 0         # 0 hunt, 1 wind-up, 2 charge, 3 recover
var _mode_t := 0.0
var _next_dash := 4.0
var _dash_dir := Vector2.RIGHT
var _aim_dir := Vector2.RIGHT
var _level := 1


## The boss is always slower than the slowest player (195 px/s). The tests check this.
static func speed_for_level(n: int) -> float:
	return clampf(148.0 + 0.14 * float(n), 150.0, 190.0)


func setup(level_num: int, rect: Rect2, target, pred_hue: float) -> void:
	_level = level_num
	world_rect = rect
	player = target
	speed = speed_for_level(level_num)
	size_val = 125.0 + minf(float(level_num), 300.0) * 0.1
	body_color = Color.from_hsv(fposmod(pred_hue, 1.0), 0.7, 0.45)
	match (int(level_num / 10.0) - 1) % 4:
		0:   # shark
			kind = 3
			spec = {"teeth": true}
		1:   # anglerfish
			kind = 0
			spec = {"bx": 1.05, "by": 0.9, "nose": "lure", "teeth": true, "angry": true, "tail": "fan", "dorsal": "none", "eye": 1.2}
		2:   # orca
			kind = 3
			spec = {"patch": true, "teeth": true, "dorsal": "tall", "tail": "fluke"}
		_:   # swordfish
			kind = 1
			spec = {"nose": "bill", "dorsal": "sail", "angry": true, "tail": "crescent", "fin_scale": 1.3}


func hit_center() -> Vector2:
	return position + Vector2(facing * size_val * 0.5, 0.0)


func hit_radius() -> float:
	return size_val * 0.7


## Put the boss far behind the player again (after a continue or revive) and give a short pause.
func reset_to(pos: Vector2, delay_s: float) -> void:
	position = pos
	velocity = Vector2.ZERO
	_delay = delay_s
	_mode = 0
	_mode_t = 0.0
	_next_dash = 4.0
	stagger = 0.0
	lunge_t = 0.0


## The player's shield blocked a bite: the boss is thrown back and stunned for a moment.
func block() -> void:
	velocity = (position - player.position).normalized() * 520.0
	stagger = 1.8
	_mode = 0
	_next_dash = 3.0


func chomp() -> void:
	lunge_t = 0.3


func finish() -> void:
	gone = true


func _process(delta: float) -> void:
	if player == null:
		return
	phase += delta * (5.0 + velocity.length() * 0.03)
	if gone:
		modulate.a -= delta * 0.8
		position += Vector2(-140.0, 0.0) * delta
		queue_redraw()
		if modulate.a <= 0.0:
			queue_free()
		return
	if lunge_t > 0.0:
		lunge_t -= delta
		velocity = (player.position - position).normalized() * 520.0
		position += velocity * delta
		mouth = 1.0
		_face(delta)
		queue_redraw()
		return
	mouth = move_toward(mouth, 0.0, delta * 3.0)
	if player.dead or stagger > 0.0 or _delay > 0.0:
		stagger = maxf(stagger - delta, 0.0)
		_delay = maxf(_delay - delta, 0.0)
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 3.0, 0.0, 1.0))
		position += velocity * delta
		_face(delta)
		queue_redraw()
		return
	var dist: float = position.distance_to(player.position)
	if _mode == 0:   # hunt
		var lead: Vector2 = player.position + player.velocity * 0.35
		var gap: float = player.position.x - position.x
		var boost: float = 1.0 + clampf((gap - 900.0) / 1500.0, 0.0, 0.9)   # catches up when it is far behind
		velocity = velocity.lerp((lead - position).normalized() * speed * boost, clampf(delta * 1.6, 0.0, 1.0))
		_next_dash -= delta
		if _next_dash <= 0.0 and dist < 750.0:
			_mode = 1
			_mode_t = 0.0
	elif _mode == 1:   # wind-up: stops, shakes and shows where it will charge
		_mode_t += delta
		velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		_aim_dir = (player.position + player.velocity * 0.2 - position).normalized()
		mouth = 0.7
		if _mode_t >= 0.9:
			_dash_dir = _aim_dir
			_mode = 2
			_mode_t = 0.0
	elif _mode == 2:   # charge along the line
		_mode_t += delta
		velocity = _dash_dir * speed * 2.5
		mouth = 1.0
		if _mode_t >= 0.7:
			_mode = 3
			_mode_t = 0.0
	else:   # recover: slow for a moment
		_mode_t += delta
		velocity = velocity.lerp(_dash_dir * speed * 0.3, clampf(delta * 3.0, 0.0, 1.0))
		if _mode_t >= 1.2:
			_mode = 0
			_next_dash = randf_range(3.5, 6.0) - 1.5 * clampf(float(_level) / 300.0, 0.0, 1.0)
	position += velocity * delta
	position.x = clampf(position.x, world_rect.position.x, world_rect.end.x)
	position.y = clampf(position.y, world_rect.position.y + 60.0, world_rect.end.y - 60.0)
	_face(delta)
	queue_redraw()


func _face(delta: float) -> void:
	if absf(velocity.x) > 10.0:
		facing = signf(velocity.x)
	turn = move_toward(turn, facing, delta * 4.0)


func _draw() -> void:
	var t: float = turn if absf(turn) > 0.12 else 0.12 * facing
	var tilt: float = atan2(velocity.y, maxf(absf(velocity.x), 60.0)) * 0.3 * signf(t)
	draw_arc(Vector2.ZERO, size_val * 1.45, 0.0, TAU, 40, Color(1.0, 0.25, 0.2, 0.5), 4.0)   # red = dangerous
	var origin := Vector2.ZERO
	if _mode == 1 and not gone:
		origin = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))   # shakes before it charges
		draw_line(Vector2.ZERO, _aim_dir * 650.0, Color(1.0, 0.2, 0.1, 0.4), 10.0)
		draw_string(ThemeDB.fallback_font, Vector2(-14.0, -size_val * 1.15), "!", HORIZONTAL_ALIGNMENT_CENTER, 28.0, 72, Color(1.0, 0.25, 0.1))
	var xf := Transform2D(tilt, Vector2(t, 1.0), 0.0, origin)
	FishArt.draw_fish(self, xf, size_val, kind, body_color, body_color.lightened(0.45), body_color.darkened(0.35), sin(phase), mouth, 2, 0, 0, false, spec)
