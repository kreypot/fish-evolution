extends Node2D
## Underwater hazards. They never eat you, but touching them hurts (rules in game.gd):
##   "mine"   = floats and bobs, blinks red. Blows up when touched: you shrink a lot and are thrown back.
##   "urchin" = a spiky ball that sits on the sea floor. Like a jellyfish sting: you shrink a little.

var kind := "mine"
var base_pos := Vector2.ZERO
var phase := 0.0
var active := false: set = _set_active
var _t := 0.0


func hit_radius() -> float:
	return 26.0 if kind == "mine" else 24.0


func _ready() -> void:
	position = base_pos
	_t = phase
	set_process(active)
	visible = active


func _set_active(v: bool) -> void:
	active = v
	set_process(v)
	visible = v


func _process(delta: float) -> void:
	_t += delta
	if kind == "mine":
		position = base_pos + Vector2(sin(_t * 0.8) * 18.0, sin(_t * 1.1) * 34.0)
	queue_redraw()


func _draw() -> void:
	if kind == "mine":
		var blink: float = 0.5 + 0.5 * sin(_t * 6.0)
		draw_circle(Vector2.ZERO, 46.0, Color(1.0, 0.2, 0.2, 0.08 + 0.1 * blink))
		for i in 8:
			var d := Vector2(cos(TAU * float(i) / 8.0), sin(TAU * float(i) / 8.0))
			draw_line(d * 16.0, d * 30.0, Color(0.55, 0.58, 0.65), 6.0)
			draw_circle(d * 30.0, 4.0, Color(0.8, 0.82, 0.88))
		draw_circle(Vector2.ZERO, 22.0, Color(0.13, 0.15, 0.2))
		draw_circle(Vector2.ZERO, 20.0, Color(0.25, 0.28, 0.36))
		draw_circle(Vector2(-7.0, -8.0), 5.0, Color(1, 1, 1, 0.35))
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.2, 0.2, 0.45 + 0.55 * blink))
	else:
		for i in 14:
			var a: float = TAU * float(i) / 14.0
			var d := Vector2(cos(a), sin(a))
			var l: float = 26.0 + 3.0 * sin(_t * 3.0 + float(i))
			draw_line(d * 10.0, d * l, Color(0.62, 0.25, 0.85), 5.0)
		draw_circle(Vector2.ZERO, 16.0, Color(0.22, 0.08, 0.32))
		draw_circle(Vector2.ZERO, 14.0, Color(0.4, 0.15, 0.55))
		draw_circle(Vector2(-5.0, -6.0), 4.0, Color(1, 1, 1, 0.3))
