extends Control
## Animated backdrop for the menu screens: deep-sea gradient, sun glow, light rays, swimming fish in
## two depth layers, sea-floor hills with swaying kelp, bubbles and plankton.
## With `show_hero = true` (main menu) your own fish floats large on the left, with sparkles and bubbles.

const FishArt = preload("res://scripts/fish_art.gd")

const TOP := Color("#5fe3ff")
const MID := Color("#1c9ee0")
const BOTTOM := Color("#0a4a8a")

var show_hero := false   # set to true BEFORE adding this node to the scene

var _fish: Array = []          # [pos, speed, size, kind, color, phase, direction (1 or -1), depth 0..1]
var _bubbles: Array = []       # Vector3(x 0..1, y 0..1, radius)
var _plankton: Array = []      # Vector3(x 0..1, y 0..1, speed)
var _hero_bubbles: Array = []  # [pos, velocity, radius, age]
var _time := 0.0
var _hero_acc := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = 7 if GameState.low_quality else 13
	for i in count:
		var depth: float = randf()   # 0 = far away, 1 = close
		var col := Color.from_hsv(randf(), 0.55, 1.0).lerp(MID, 0.55 * (1.0 - depth))   # far fish fade into the water
		var dir: float = 1.0 if randf() < 0.7 else -1.0
		_fish.append([Vector2(randf() * 1400.0, randf_range(70.0, 600.0)), randf_range(25.0, 60.0) * (0.6 + 0.8 * depth), lerpf(12.0, 40.0, depth), randi() % 3, col, randf() * TAU, dir, depth])
	_fish.sort_custom(func(a, b): return float(a[7]) < float(b[7]))
	for i in (12 if GameState.low_quality else 30):
		_bubbles.append(Vector3(randf(), randf(), randf_range(2.0, 8.0)))
	if not GameState.low_quality:
		for i in 40:
			_plankton.append(Vector3(randf(), randf(), randf_range(4.0, 14.0)))


func _hero_pos() -> Vector2:
	# The main menu keeps its text on the left and the list on the right; the fish sits under the title.
	return Vector2(size.x * 0.5 - 260.0, size.y * 0.5 + 140.0 + sin(_time * 1.3) * 12.0)


func _process(delta: float) -> void:
	_time += delta
	for f in _fish:
		var pos: Vector2 = f[0]
		var dir: float = float(f[6])
		pos.x += float(f[1]) * dir * delta
		pos.y += sin(_time * 0.8 + float(f[5])) * 6.0 * delta
		if dir > 0.0 and pos.x > size.x + 160.0:
			pos.x = -160.0
			pos.y = randf_range(70.0, maxf(size.y - 110.0, 100.0))
		elif dir < 0.0 and pos.x < -160.0:
			pos.x = size.x + 160.0
			pos.y = randf_range(70.0, maxf(size.y - 110.0, 100.0))
		f[0] = pos
	for i in _bubbles.size():
		var b: Vector3 = _bubbles[i]
		b.y -= delta * (0.03 + b.z * 0.005)
		if b.y < -0.05:
			b.y = 1.05
			b.x = randf()
		_bubbles[i] = b
	for i in _plankton.size():
		var p: Vector3 = _plankton[i]
		p.x = fposmod(p.x + delta * p.z * 0.0006, 1.0)
		p.y = fposmod(p.y - delta * 0.004, 1.0)
		_plankton[i] = p
	if show_hero:
		_hero_acc += delta
		if _hero_acc > 0.55:
			_hero_acc = 0.0
			_hero_bubbles.append([_hero_pos() + Vector2(95.0, -6.0), Vector2(randf_range(-6.0, 10.0), randf_range(-75.0, -45.0)), randf_range(3.0, 8.0), 0.0])
		for i in range(_hero_bubbles.size() - 1, -1, -1):
			var hb: Array = _hero_bubbles[i]
			var hp: Vector2 = hb[0]
			var hv: Vector2 = hb[1]
			hp += hv * delta
			hb[0] = hp
			hb[3] = float(hb[3]) + delta
			if float(hb[3]) > 2.2:
				_hero_bubbles.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var low: bool = GameState.low_quality
	# water: three colours, bright at the top and deep at the bottom
	var hh: float = size.y * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, hh), Vector2(0, hh)]), PackedColorArray([TOP, TOP, MID, MID]))
	draw_polygon(PackedVector2Array([Vector2(0, hh), Vector2(size.x, hh), size, Vector2(0, size.y)]), PackedColorArray([MID, MID, BOTTOM, BOTTOM]))
	# sun glow at the top
	for r in 5:
		draw_circle(Vector2(size.x * 0.2, -60.0), 420.0 - 70.0 * float(r), Color(1, 1, 1, 0.04))
	# light rays that fade out downwards
	if not low:
		var ray_top := Color(1, 1, 1, 0.16)
		var ray_bot := Color(1, 1, 1, 0.0)
		for i in 5:
			var bx: float = size.x * (float(i) + 0.5) / 5.0 + sin(_time * 0.3 + float(i) * 1.7) * 70.0
			draw_polygon(PackedVector2Array([Vector2(bx - 34.0, 0.0), Vector2(bx + 34.0, 0.0), Vector2(bx + 210.0, size.y), Vector2(bx + 40.0, size.y)]), PackedColorArray([ray_top, ray_top, ray_bot, ray_bot]))
	for f in _fish:
		if float(f[7]) < 0.45:
			_draw_one_fish(f)
	_draw_floor()
	for f in _fish:
		if float(f[7]) >= 0.45:
			_draw_one_fish(f)
	if show_hero:
		_draw_hero()
	for b in _bubbles:
		var bv: Vector3 = b
		draw_arc(Vector2(bv.x * size.x, bv.y * size.y), bv.z, 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.5)
	for p in _plankton:
		var pv: Vector3 = p
		draw_circle(Vector2(pv.x * size.x, pv.y * size.y), 1.6, Color(1, 1, 1, 0.3))


func _draw_one_fish(f: Array) -> void:
	var pos: Vector2 = f[0]
	var col: Color = f[4]
	var xf := Transform2D(0.0, Vector2(float(f[6]), 1.0), 0.0, pos)
	FishArt.draw_fish(self, xf, float(f[2]), int(f[3]), col, col.lightened(0.5), col.darkened(0.3), sin(_time * 6.0 + float(f[5])), 0.0, 0)


## Two rows of sea-floor hills and a few swaying kelp plants along the bottom.
func _draw_floor() -> void:
	for layer_i in 2:
		var pts := PackedVector2Array()
		var base_y: float = size.y * (0.84 + 0.06 * float(layer_i))
		var amp: float = 26.0 + 10.0 * float(layer_i)
		var xi := 0.0
		while xi <= size.x + 40.0:
			pts.append(Vector2(xi, base_y - amp * sin(xi * 0.006 + float(layer_i) * 2.0) - amp * 0.5 * sin(xi * 0.017 + 1.0)))
			xi += 40.0
		pts.append(Vector2(size.x + 40.0, size.y))
		pts.append(Vector2(0.0, size.y))
		var hc: Color = BOTTOM.lerp(Color.BLACK, 0.25 + 0.2 * float(layer_i))
		hc.a = 0.55 + 0.25 * float(layer_i)
		draw_colored_polygon(pts, hc)
	if GameState.low_quality:
		return
	for k in 9:
		var kx: float = size.x * (float(k) + 0.5) / 9.0 + sin(float(k) * 5.3) * 40.0
		var kh: float = 90.0 + 70.0 * absf(sin(float(k) * 2.1))
		var stem := PackedVector2Array()
		for j in 7:
			var fr: float = float(j) / 6.0
			stem.append(Vector2(kx + sin(_time * 1.1 + float(k) + fr * 2.4) * 14.0 * fr, size.y - 8.0 - kh * fr))
		draw_polyline(stem, Color(0.05, 0.4, 0.35, 0.85), 10.0, true)
		draw_polyline(stem, Color(0.2, 0.7, 0.5, 0.9), 5.0, true)


func _draw_hero() -> void:
	var hp: Vector2 = _hero_pos()
	# soft glow behind the fish
	for r in 6:
		draw_circle(hp, 190.0 - 24.0 * float(r), Color(1, 1, 1, 0.04))
	var look: Dictionary = GameState.get_look()
	var cols: Array = FishArt.resolve_colors(look, _time)
	var xf := Transform2D(sin(_time * 1.1) * 0.07, Vector2(1, 1), 0.0, hp)
	FishArt.draw_fish(self, xf, 78.0, 0, cols[0], cols[1], cols[2], sin(_time * 5.0), 0.0, 1, int(look["pattern"]), int(look["acc"]), false, look["spec"])
	for hb in _hero_bubbles:
		var h: Array = hb
		var fade: float = clampf(1.0 - float(h[3]) / 2.2, 0.0, 1.0)
		draw_arc(h[0], float(h[2]), 0.0, TAU, 12, Color(1, 1, 1, 0.6 * fade), 2.0)
	# twinkling stars around the fish
	for k in 6:
		var a: float = _time * 0.6 + float(k) * 1.047
		var sp := Vector2(hp.x + cos(a) * (150.0 + 20.0 * sin(float(k))), hp.y + sin(a * 1.3) * 100.0)
		var tw: float = 0.5 + 0.5 * sin(_time * 3.0 + float(k) * 2.0)
		_star(sp, 3.0 + 7.0 * tw, Color(1, 1, 1, 0.75 * tw))


func _star(p: Vector2, r: float, col: Color) -> void:
	draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 2.0)
	draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 2.0)
