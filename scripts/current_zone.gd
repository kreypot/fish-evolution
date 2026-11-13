extends Node2D
## A water current: a patch of water that pushes the player in one direction (the push itself is in game.gd).
## Arrows flow in the direction of the current. It never hurts you.

var zone_size := Vector2(500.0, 180.0)   # width and height
var dir := Vector2.RIGHT
var strength := 1000.0
var active := false: set = _set_active
var _t := 0.0


func contains(p: Vector2) -> bool:
	return Rect2(position - zone_size * 0.5, zone_size).has_point(p)


func _ready() -> void:
	set_process(active)
	visible = active


func _set_active(v: bool) -> void:
	active = v
	set_process(v)
	visible = v


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-zone_size * 0.5, zone_size), Color(1, 1, 1, 0.07))
	var along: float = absf(dir.x) * zone_size.x + absf(dir.y) * zone_size.y   # length of the zone in the flow direction
	var across: float = absf(dir.x) * zone_size.y + absf(dir.y) * zone_size.x
	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
	for i in 4:
		var x: float = -along * 0.5 + fposmod(_t * 90.0 + float(i) * along / 4.0, along)
		for j in 3:
			var y: float = -across * 0.5 + (float(j) + 0.5) * across / 3.0
			draw_polyline(PackedVector2Array([Vector2(x - 12.0, y - 12.0), Vector2(x, y), Vector2(x - 12.0, y + 12.0)]), Color(1, 1, 1, 0.4), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
