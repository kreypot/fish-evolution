extends Node2D
## A spinning gold coin. Collect coins to buy fish designs in the shop.

const RADIUS := 16.0

var value := 1
var active := false: set = _set_active
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU
	set_process(active)
	visible = active


func _set_active(v: bool) -> void:
	active = v
	set_process(v)
	visible = v


func _process(delta: float) -> void:
	_t += delta * 4.0
	queue_redraw()


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw() -> void:
	var rx: float = RADIUS * (0.25 + 0.75 * absf(cos(_t)))   # spin: squash the width
	draw_colored_polygon(_ellipse(rx + 2.5, RADIUS + 2.5), Color("#b8860b"))
	draw_colored_polygon(_ellipse(rx, RADIUS), Color("#ffd23a"))
	draw_colored_polygon(_ellipse(rx * 0.6, RADIUS * 0.6), Color("#ffe98a"))
	draw_circle(Vector2(-rx * 0.3, -RADIUS * 0.35), 2.5, Color(1, 1, 1, 0.8))
