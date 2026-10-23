extends Node2D
## A non-player fish with simple AI.
##   WANDER : drift to random nearby targets
##   PATROL : swim back and forth between two points (some fish only)
##   CHASE  : bigger fish hunt the player (and get tired after 5 s)
##   FLEE   : smaller fish run away from the player
## Whether a fish is food, neutral or a threat depends only on size vs the player's size.

const FishArt = preload("res://scripts/fish_art.gd")

enum State { WANDER, CHASE, FLEE, PATROL }

const MAX_CHASE_TIME := 5.0   # a predator gives up after this many seconds...
const REST_TIME := 2.5        # ...and rests this long, so you can always escape

var size_val: float = 12.0
var kind: int = 0
var body_color := Color.CORNFLOWER_BLUE
var wander_speed := 80.0
var chase_speed := 150.0
var flee_speed := 190.0
var detect_range := 350.0
var flee_range := 280.0
var patroller := false
var patrol_a := Vector2.ZERO
var patrol_b := Vector2.ZERO
var world_rect := Rect2()
var player = null          # set by game.gd (untyped on purpose: avoids a circular preload)

var state: int = State.WANDER
var relation: int = 0      # 0 = neutral, 1 = edible, 2 = dangerous (updated every frame)
var velocity := Vector2.ZERO
var mouth := 0.0
var facing := 1.0
var turn := 1.0
var phase := 0.0
var active := false: set = _set_active

var _dist := 9999.0
var _chase_time := 0.0
var _rest_time := 0.0
var _patrol_to_b := true
var _wander_target := Vector2.ZERO
var _wander_timer := 0.0


func _ready() -> void:
	phase = randf() * TAU
	_pick_wander_target()
	set_process(active)
	visible = active


func _set_active(v: bool) -> void:
	active = v
	set_process(v)
	visible = v


func _process(delta: float) -> void:
	if player == null:
		return
	phase += delta * (5.0 + velocity.length() * 0.05)
	_update_state(delta)
	velocity = velocity.lerp(_desired_velocity(delta), clampf(delta * 2.5, 0.0, 1.0))
	position += velocity * delta
	# stay inside the ocean
	if position.y < world_rect.position.y or position.y > world_rect.end.y:
		position.y = clampf(position.y, world_rect.position.y, world_rect.end.y)
		velocity.y = 0.0
		_pick_wander_target()
	if position.x < world_rect.position.x or position.x > world_rect.end.x:
		position.x = clampf(position.x, world_rect.position.x, world_rect.end.x)
		velocity.x = 0.0
		_pick_wander_target()
	if absf(velocity.x) > 10.0:
		facing = signf(velocity.x)
	turn = move_toward(turn, facing, delta * 6.0)
	var want_mouth := 1.0 if (state == State.CHASE and _dist < size_val * 4.0) else 0.0
	mouth = move_toward(mouth, want_mouth, delta * 6.0)
	queue_redraw()


func _update_state(delta: float) -> void:
	var to_player: Vector2 = player.position - position
	_dist = to_player.length()
	var psize: float = player.size_val
	var is_dead: bool = player.dead
	if size_val < psize * GameState.EAT_RATIO:
		relation = 1
	elif size_val > psize * GameState.DANGER_RATIO:
		relation = 2
	else:
		relation = 0

	var idle_state: int = State.PATROL if patroller else State.WANDER
	if relation == 2 and not is_dead:
		if _rest_time > 0.0:
			_rest_time -= delta
			state = idle_state
		elif _dist < detect_range:
			state = State.CHASE
			_chase_time += delta
			if _chase_time > MAX_CHASE_TIME:
				_chase_time = 0.0
				_rest_time = REST_TIME
		else:
			state = idle_state
			_chase_time = maxf(_chase_time - delta, 0.0)
	elif relation == 1 and _dist < flee_range:
		state = State.FLEE
	else:
		state = idle_state


func _desired_velocity(delta: float) -> Vector2:
	match state:
		State.CHASE:
			var lead: Vector2 = player.position + player.velocity * 0.25
			return (lead - position).normalized() * chase_speed
		State.FLEE:
			var away: Vector2 = (position - player.position).normalized()
			# near the top/bottom edge, turn toward open water instead of getting cornered
			if position.y < world_rect.position.y + 90.0:
				away.y = absf(away.y) + 0.6
			elif position.y > world_rect.end.y - 90.0:
				away.y = -absf(away.y) - 0.6
			return away.normalized() * flee_speed
		State.PATROL:
			var target: Vector2 = patrol_b if _patrol_to_b else patrol_a
			if position.distance_to(target) < 40.0:
				_patrol_to_b = not _patrol_to_b
			return (target - position).normalized() * wander_speed
		_:
			_wander_timer -= delta
			if _wander_timer <= 0.0 or position.distance_to(_wander_target) < 30.0:
				_pick_wander_target()
			return (_wander_target - position).normalized() * wander_speed


func _pick_wander_target() -> void:
	var t := position + Vector2(randf_range(-300.0, 300.0), randf_range(-200.0, 200.0))
	_wander_target = Vector2(clampf(t.x, world_rect.position.x, world_rect.end.x), clampf(t.y, world_rect.position.y, world_rect.end.y))
	_wander_timer = randf_range(2.0, 4.0)


func _draw() -> void:
	var t: float = turn if absf(turn) > 0.12 else 0.12 * facing
	var tilt: float = atan2(velocity.y, maxf(absf(velocity.x), 60.0)) * 0.4 * signf(t)
	var xf := Transform2D(tilt, Vector2(t, 1.0), 0.0, Vector2.ZERO)
	# Hint ring: green = you can eat it, red = it can eat you
	if _dist < 700.0:
		if relation == 1:
			draw_arc(Vector2.ZERO, size_val * 1.35, 0.0, TAU, 28, Color(0.3, 1.0, 0.4, 0.55), 3.0)
		elif relation == 2:
			draw_arc(Vector2.ZERO, size_val * 1.35, 0.0, TAU, 28, Color(1.0, 0.25, 0.2, 0.6), 3.0)
	FishArt.draw_fish(self, xf, size_val, kind, body_color, body_color.lightened(0.55), body_color.darkened(0.3), sin(phase), mouth, 0)
