extends CanvasLayer
## Screen-space background: depth gradient, drifting light rays, parallax hills
## and ambient bubbles. game.gd sets `cam` every frame so the hills scroll.

var theme_data: Dictionary = {}
var cam := Vector2.ZERO

var _canvas: Node2D
var _time := 0.0
var _bubbles: Array = []   # Vector3(x 0..1, y 0..1, radius)


func _ready() -> void:
	layer = -10
	_canvas = Node2D.new()
	add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	for i in (10 if GameState.low_quality else 28):
		_bubbles.append(Vector3(randf(), randf(), randf_range(2.0, 9.0)))


func _process(delta: float) -> void:
	_time += delta
	for i in _bubbles.size():
		var b: Vector3 = _bubbles[i]
		b.y -= delta * (0.03 + b.z * 0.006)
		if b.y < -0.05:
			b.y = 1.05
			b.x = randf()
		_bubbles[i] = b
	_canvas.queue_redraw()


func _on_draw() -> void:
	var vp: Vector2 = _canvas.get_viewport_rect().size
	var top: Color = theme_data["top"]
	var bottom: Color = theme_data["bottom"]
	# three-colour water: lighter near the surface, deeper below
	var mid: Color = top.lerp(bottom, 0.5)
	var hh: float = vp.y * 0.5
	var bright: Color = top.lightened(0.12)
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, hh), Vector2(0, hh)]), PackedColorArray([bright, bright, mid, mid]))
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, hh), Vector2(vp.x, hh), Vector2(vp.x, vp.y), Vector2(0, vp.y)]), PackedColorArray([mid, mid, bottom, bottom]))

	# light rays
	for i in (0 if GameState.low_quality else 5):
		var bx: float = vp.x * (float(i) + 0.5) / 5.0 + sin(_time * 0.25 + float(i) * 1.7) * 80.0 - fmod(cam.x * 0.03, 200.0)
		var ray_top := Color(1, 1, 1, 0.13)
		var ray_bot := Color(1, 1, 1, 0.0)   # rays fade out as they go down
		_canvas.draw_polygon(PackedVector2Array([Vector2(bx - 30, 0), Vector2(bx + 30, 0), Vector2(bx + 190, vp.y), Vector2(bx + 50, vp.y)]), PackedColorArray([ray_top, ray_top, ray_bot, ray_bot]))

	# faint fish far away in the water (parallax)
	if not GameState.low_quality:
		for i in 6:
			var fx: float = fposmod(float(i) * 311.0 - cam.x * 0.05 + _time * (8.0 + float(i) * 3.0), vp.x + 300.0) - 150.0
			var fy: float = vp.y * (0.18 + 0.11 * float(i % 5)) + sin(_time * 0.8 + float(i)) * 10.0
			var fs: float = 14.0 + float(i % 3) * 7.0
			var sil := Color(1, 1, 1, 0.07)
			var body := PackedVector2Array()
			for q in 12:
				var qa: float = TAU * float(q) / 12.0
				body.append(Vector2(fx + cos(qa) * fs * 1.6, fy + sin(qa) * fs * 0.8))
			_canvas.draw_colored_polygon(body, sil)
			_canvas.draw_colored_polygon(PackedVector2Array([Vector2(fx - fs * 1.4, fy), Vector2(fx - fs * 2.4, fy - fs * 0.8), Vector2(fx - fs * 2.4, fy + fs * 0.8)]), sil)

	# parallax hills (two layers)
	for layer_i in 2:
		var hills := PackedVector2Array()
		var par: float = 0.15 + 0.2 * float(layer_i)
		var base_y: float = vp.y * (0.74 + 0.08 * float(layer_i))
		var xi := 0
		while xi <= int(vp.x) + 40:
			var wx: float = float(xi) + cam.x * par
			hills.append(Vector2(float(xi), base_y - 45.0 * sin(wx * 0.004 + float(layer_i)) - 25.0 * sin(wx * 0.011 + 1.0)))
			xi += 40
		hills.append(Vector2(vp.x + 40.0, vp.y))
		hills.append(Vector2(0.0, vp.y))
		var hc: Color = bottom.lerp(Color.BLACK, 0.15 + 0.15 * float(layer_i))
		hc.a = 0.45 + 0.2 * float(layer_i)
		_canvas.draw_colored_polygon(hills, hc)

	# ambient bubbles
	for b in _bubbles:
		var bv: Vector3 = b
		var px: float = fposmod(bv.x * vp.x - cam.x * 0.08 * (bv.z / 9.0), vp.x)
		_canvas.draw_arc(Vector2(px, bv.y * vp.y), bv.z, 0.0, TAU, 12, Color(1, 1, 1, 0.3), 1.5)
