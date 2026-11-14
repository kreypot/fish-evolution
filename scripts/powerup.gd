extends Node2D
## A power-up orb floating in the water. Swim into it to collect it (the rules are in game.gd).
##   magnet = coins fly to you      shield = blocks ONE bite or sting      speed = you swim faster      boost = coins x2
## It glows on purpose, so that you can see it from far away: a big additive halo, turning light rays, a ring that
## keeps expanding, a white rim and little stars that circle around it.

const RADIUS := 32.0
const KINDS := ["magnet", "shield", "speed", "boost"]
const NAMES := {"magnet": "MAGNET", "shield": "SHIELD", "speed": "SPEED", "boost": "COINS x2"}
const HINTS := {"magnet": "Coins fly to you!", "shield": "Blocks the next bite!", "speed": "Swim faster!", "boost": "All coins count double!"}
const DURATIONS := {"magnet": 10.0, "shield": 15.0, "speed": 6.0, "boost": 12.0}   # seconds
const COLORS := {"magnet": Color("#c070ff"), "shield": Color("#3cd0ff"), "speed": Color("#ffb020"), "boost": Color("#3ddc6a")}

var kind := "shield"
var active := false: set = _set_active
var _t := 0.0
var _halo: Halo = null


func _ready() -> void:
	_t = randf() * TAU
	_halo = Halo.new()
	_halo.col = COLORS[kind]
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # light adds up: the halo really shines
	_halo.material = glow_mat
	_halo.show_behind_parent = true
	add_child(_halo)
	set_process(active)
	visible = active


func _set_active(v: bool) -> void:
	active = v
	set_process(v)
	visible = v


func _process(delta: float) -> void:
	_t += delta
	if _halo != null:
		_halo.t = _t
		_halo.queue_redraw()
	queue_redraw()


func _star(p: Vector2, r: float, col: Color) -> void:
	draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 2.5)
	draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 2.5)


func _draw() -> void:
	var col: Color = COLORS[kind]
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var bob := Vector2(0.0, sin(_t * 2.0) * 5.0)
	# little stars circling around the orb
	for i in 4:
		var a: float = _t * 1.6 + TAU * float(i) / 4.0
		var tw: float = 0.5 + 0.5 * sin(_t * 5.0 + float(i) * 1.7)
		_star(bob + Vector2(cos(a), sin(a)) * (RADIUS + 22.0 + 6.0 * pulse), 4.0 + 5.0 * tw, Color(1, 1, 1, 0.5 + 0.5 * tw))
	# the orb: white rim, dark edge, coloured body, bright centre, shine
	draw_circle(bob, RADIUS * 1.16, Color(1, 1, 1, 0.95))
	draw_circle(bob, RADIUS * 1.04, col.darkened(0.35))
	draw_circle(bob, RADIUS, col)
	draw_circle(bob + Vector2(0.0, -RADIUS * 0.06), RADIUS * 0.74, col.lightened(0.3))
	draw_circle(bob + Vector2(-RADIUS * 0.3, -RADIUS * 0.38), RADIUS * 0.2, Color(1, 1, 1, 0.75))
	# the icon (drawn a little bigger than before)
	draw_set_transform(bob, 0.0, Vector2(1.3, 1.3))
	var white := Color.WHITE
	if kind == "magnet":
		draw_arc(Vector2(0.0, 1.0), 9.0, 0.0, PI, 14, white, 5.0)
		draw_line(Vector2(-9.0, 1.0), Vector2(-9.0, -9.0), Color("#ff5050"), 5.0)
		draw_line(Vector2(9.0, 1.0), Vector2(9.0, -9.0), Color("#5080ff"), 5.0)
	elif kind == "shield":
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 2), Vector2(0, 12), Vector2(-10, 2)]), white)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 1), Vector2(0, 8), Vector2(-6, 1)]), col.darkened(0.1))
	elif kind == "speed":
		draw_colored_polygon(PackedVector2Array([Vector2(3, -12), Vector2(-8, 2), Vector2(-1, 2), Vector2(-4, 12), Vector2(8, -4), Vector2(1, -4)]), white)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-17.0, 8.0), "x2", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 24, white)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The glow behind the orb. It is drawn with "additive" blending, so it shines like light.
class Halo extends Node2D:
	var col := Color.WHITE
	var t := 0.0

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		for i in 7:   # a soft, big glow
			draw_circle(Vector2.ZERO, 120.0 - float(i) * 15.0 + 8.0 * pulse, Color(col.r, col.g, col.b, 0.05 + 0.014 * float(i)))
		for i in 8:   # light rays that turn slowly
			var a: float = t * 0.8 + TAU * float(i) / 8.0
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			var ray_len: float = 105.0 + 18.0 * pulse
			draw_colored_polygon(PackedVector2Array([d * 34.0 + n * 3.0, d * ray_len + n * 9.0, d * ray_len - n * 9.0, d * 34.0 - n * 3.0]), Color(col.r, col.g, col.b, 0.2))
		for k in 2:   # two rings that keep expanding
			var f: float = fposmod(t * 0.8 + float(k) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, 40.0 + 90.0 * f, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.6 * (1.0 - f)), 4.0)
