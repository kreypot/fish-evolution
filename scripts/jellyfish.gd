extends Node2D
## Jellyfish obstacle: drifts up and down. Touching it shrinks the player a little
## and gives a short invulnerability window (handled in game.gd).

const RADIUS := 30.0

var base_pos := Vector2.ZERO
var bob := 100.0
var speed := 0.8
var phase := 0.0
var active := false: set = _set_active
var _t := 0.0


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
	_t += delta * speed
	position = base_pos + Vector2(sin(_t * 0.7) * 50.0, sin(_t) * bob)
	queue_redraw()


func _draw() -> void:
	var r := RADIUS
	draw_circle(Vector2.ZERO, r * 1.5, Color(0.9, 0.5, 1.0, 0.12))   # glow
	for k in 5:                                                       # tentacles
		var x0 := -r * 0.7 + float(k) * r * 0.35
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2(x0 + sin(_t * 4.0 + float(i) * 0.8 + float(k)) * 5.0, float(i) * r * 0.32))
		draw_polyline(pts, Color(0.95, 0.65, 1.0, 0.8), 3.0, true)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(Vector2(cos(a) * r, sin(a) * r * 0.85))
	draw_colored_polygon(dome, Color(0.9, 0.45, 0.95, 0.85))
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.5))
