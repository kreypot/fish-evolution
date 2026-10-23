extends Node2D
## One 800 px wide slice of the sea floor: sand, swaying kelp, coral and rocks.
## The level is made of many chunks so off-screen ones are skipped by the renderer
## and only nearby ones animate (see `active`).

var x0 := 0.0
var width := 800.0
var theme_data: Dictionary = {}
var rocks: Array = []        # Vector3(x, y, radius) - the same data game.gd uses for collision
var active := false: set = _set_active

var _kelp: Array = []        # [x, height, phase, thickness]
var _coral: Array = []       # [x, size, color, branches]
var _time := 0.0


## Shared by game.gd so rocks sit exactly on the sand.
static func floor_y(x: float) -> float:
	return 965.0 + 16.0 * sin(x * 0.004) + 9.0 * sin(x * 0.013 + 1.3)


func setup(p_x0: float, p_width: float, p_theme: Dictionary, p_seed: int, p_rocks: Array) -> void:
	x0 = p_x0
	width = p_width
	theme_data = p_theme
	rocks = p_rocks
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var coral_col: Color = theme_data["coral"]
	for i in rng.randi_range(3, 5):
		_kelp.append([x0 + rng.randf_range(0.0, width), rng.randf_range(120.0, 320.0), rng.randf() * TAU, rng.randf_range(6.0, 11.0)])
	for i in rng.randi_range(1, 3):
		var c := coral_col
		c = Color.from_hsv(fposmod(c.h + rng.randf_range(-0.06, 0.06), 1.0), c.s, c.v)
		_coral.append([x0 + rng.randf_range(0.0, width), rng.randf_range(35.0, 80.0), c, rng.randi_range(3, 5)])


func _set_active(v: bool) -> void:
	active = v
	set_process(v)


func _ready() -> void:
	set_process(active)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# sand
	var sand: Color = theme_data["sand"]
	var floor_pts := PackedVector2Array()
	var x := x0
	while x <= x0 + width + 1.0:
		floor_pts.append(Vector2(x, floor_y(x)))
		x += 40.0
	var poly := PackedVector2Array(floor_pts)
	poly.append(Vector2(x0 + width, 1200.0))
	poly.append(Vector2(x0, 1200.0))
	draw_colored_polygon(poly, sand)
	draw_polyline(floor_pts, sand.lightened(0.25), 6.0)

	# rocks
	var rock_col: Color = theme_data["rock"]
	for r in rocks:
		var rv: Vector3 = r
		draw_circle(Vector2(rv.x + rv.z * 0.7, rv.y + rv.z * 0.25), rv.z * 0.6, rock_col.darkened(0.1))
		draw_circle(Vector2(rv.x, rv.y), rv.z, rock_col)
		draw_circle(Vector2(rv.x - rv.z * 0.25, rv.y - rv.z * 0.3), rv.z * 0.5, rock_col.lightened(0.15))

	# coral (static)
	for c in _coral:
		var cx: float = c[0]
		var size: float = c[1]
		var col: Color = c[2]
		var n: int = c[3]
		var base := Vector2(cx, floor_y(cx) + 4.0)
		for b in n:
			var ang: float = -PI * 0.5 + (float(b) - float(n - 1) * 0.5) * 0.5
			var length: float = size * (0.75 + 0.15 * float((b * 7) % 3))
			var tip: Vector2 = base + Vector2(cos(ang), sin(ang)) * length
			draw_line(base, tip, col, size * 0.18)
			draw_circle(tip, size * 0.16, col.lightened(0.25))
			var mid: Vector2 = base.lerp(tip, 0.6)
			draw_line(mid, mid + Vector2(cos(ang + 0.7), sin(ang + 0.7)) * length * 0.35, col, size * 0.1)

	# kelp (sways)
	var plant: Color = theme_data["plant"]
	for k in _kelp:
		var kx: float = k[0]
		var kh: float = k[1]
		var kp: float = k[2]
		var kt: float = k[3]
		var pts := PackedVector2Array()
		for j in 9:
			var f: float = float(j) / 8.0
			pts.append(Vector2(kx + sin(_time * 1.2 + kp + f * 2.5) * 18.0 * f, floor_y(kx) + 4.0 - kh * f))
		draw_polyline(pts, plant, kt, true)
