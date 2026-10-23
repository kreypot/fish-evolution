extends Node2D
## The player's fish. game.gd feeds it `input_dir`; it handles movement, growth
## animation and drawing. Collisions/eating are decided in game.gd.

const FishArt = preload("res://scripts/fish_art.gd")

var size_val: float = 20.0      # the real size used by the rules
var shown_size: float = 20.0    # smoothly follows size_val (growth animation)
var start_size: float = 20.0
var velocity := Vector2.ZERO
var input_dir := Vector2.ZERO   # -1..1 in both axes, from the joystick/keyboard
var world_rect := Rect2()
var dead := false
var finished := false           # after the finish gate the fish glides forward
var invuln := 0.0               # seconds of protection after a jellyfish sting
var mouth := 0.0
var pulse := 0.0                # grow "boing" animation
var facing := 1.0
var phase := 0.0
var turn := 1.0                 # animates smoothly between 1 (right) and -1 (left)
var look: Dictionary = {}       # shop cosmetics (GameState.get_look())
var _clock := 0.0


func max_speed() -> float:
	# Growing makes you slower (down to 70%) - the price of being big.
	return 300.0 * (1.0 - clampf((size_val - 20.0) / 300.0, 0.0, 0.35))


func body_radius() -> float:
	return shown_size * 0.8


func get_stage() -> int:
	if size_val < 35.0:
		return 0
	if size_val < 60.0:
		return 1
	return 2


func eat_fish(fish_size: float) -> void:
	var old_stage := get_stage()
	size_val = minf(size_val + fish_size * GameState.GROW_FACTOR, GameState.MAX_SIZE)
	mouth = 0.3
	pulse = 0.7 if get_stage() != old_stage else 0.35   # a visible "boing" every time you eat


func sting() -> void:
	size_val = maxf(GameState.MIN_SIZE, size_val * 0.88)
	invuln = 1.6


func _process(delta: float) -> void:
	if dead:
		velocity = velocity.lerp(Vector2(0.0, -50.0), clampf(delta * 2.0, 0.0, 1.0))
		position += velocity * delta
		modulate.a = maxf(modulate.a - delta * 0.8, 0.0)
	else:
		var target := input_dir * max_speed()
		if finished:
			target = Vector2(max_speed(), 0.0)
		velocity = velocity.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
		position += velocity * delta
		position.x = clampf(position.x, world_rect.position.x, world_rect.end.x)
		position.y = clampf(position.y, world_rect.position.y, world_rect.end.y)
		invuln = maxf(invuln - delta, 0.0)
		modulate.a = 0.4 if (invuln > 0.0 and fmod(invuln, 0.2) > 0.1) else 1.0
	shown_size = lerpf(shown_size, size_val, clampf(delta * 6.0, 0.0, 1.0))
	mouth = maxf(mouth - delta, 0.0)
	pulse = lerpf(pulse, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	_clock += delta
	phase += delta * (5.0 + velocity.length() * 0.04)
	if velocity.x > 15.0:
		facing = 1.0
	elif velocity.x < -15.0:
		facing = -1.0
	turn = move_toward(turn, facing, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var s: float = shown_size * (1.0 + pulse)
	var t: float = turn if absf(turn) > 0.12 else 0.12 * facing
	var tilt: float = atan2(velocity.y, maxf(absf(velocity.x), 60.0)) * 0.45 * signf(t)
	var xf := Transform2D(tilt, Vector2(t, 1.0), 0.0, Vector2.ZERO)
	var cols: Array = FishArt.resolve_colors(look, _clock)
	FishArt.draw_fish(self, xf, s, 0, cols[0], cols[1], cols[2], sin(phase), clampf(mouth * 4.0, 0.0, 1.0), get_stage(), int(look.get("pattern", 0)), int(look.get("acc", 0)))
