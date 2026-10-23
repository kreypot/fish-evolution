extends Control
## Animated backdrop for menu screens: gradient, bubbles and a few swimming fish.

const FishArt = preload("res://scripts/fish_art.gd")

var _fish: Array = []   # [pos, speed, size, kind, color, phase]
var _bubbles: Array = []
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 7:
		var col := Color.from_hsv(randf(), 0.6, 1.0)
		_fish.append([Vector2(randf() * 1400.0, randf_range(80.0, 650.0)), randf_range(25.0, 70.0), randf_range(16.0, 46.0), randi() % 3, col, randf() * TAU])
	for i in 30:
		_bubbles.append(Vector3(randf(), randf(), randf_range(2.0, 8.0)))


func _process(delta: float) -> void:
	_time += delta
	for f in _fish:
		var pos: Vector2 = f[0]
		pos.x += float(f[1]) * delta
		if pos.x > size.x + 150.0:
			pos.x = -150.0
			pos.y = randf_range(80.0, size.y - 80.0)
		f[0] = pos
	for i in _bubbles.size():
		var b: Vector3 = _bubbles[i]
		b.y -= delta * (0.03 + b.z * 0.005)
		if b.y < -0.05:
			b.y = 1.05
		_bubbles[i] = b
	queue_redraw()


func _draw() -> void:
	var top := Color("#4fd1f5")
	var bottom := Color("#0f5f9a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, bottom, bottom]))
	for b in _bubbles:
		var bv: Vector3 = b
		draw_arc(Vector2(bv.x * size.x, bv.y * size.y), bv.z, 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.5)
	for f in _fish:
		var pos: Vector2 = f[0]
		var col: Color = f[4]
		var xf := Transform2D(0.0, Vector2(1, 1), 0.0, pos)
		FishArt.draw_fish(self, xf, float(f[2]), int(f[3]), col, col.lightened(0.5), col.darkened(0.3), sin(_time * 6.0 + float(f[5])), 0.0, 0)
