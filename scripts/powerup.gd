extends Node2D
## A glowing power-up orb floating in the water. Swim into it to collect it (the rules are in game.gd).
##   magnet = coins fly to you      shield = blocks ONE bite or sting      speed = you swim faster      boost = coins x2

const RADIUS := 26.0
const KINDS := ["magnet", "shield", "speed", "boost"]
const NAMES := {"magnet": "MAGNET", "shield": "SHIELD", "speed": "SPEED", "boost": "COINS x2"}
const HINTS := {"magnet": "Coins fly to you!", "shield": "Blocks the next bite!", "speed": "Swim faster!", "boost": "All coins count double!"}
const DURATIONS := {"magnet": 10.0, "shield": 15.0, "speed": 6.0, "boost": 12.0}   # seconds
const COLORS := {"magnet": Color("#b05cff"), "shield": Color("#3cc8ff"), "speed": Color("#ffb020"), "boost": Color("#3ddc6a")}

var kind := "shield"
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
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col: Color = COLORS[kind]
	draw_set_transform(Vector2(0.0, sin(_t * 2.0) * 5.0), 0.0, Vector2.ONE)
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, RADIUS * (1.7 + 0.25 * pulse), Color(col.r, col.g, col.b, 0.14))
	draw_circle(Vector2.ZERO, RADIUS * 1.3, Color(col.r, col.g, col.b, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, col.darkened(0.35))
	draw_circle(Vector2.ZERO, RADIUS * 0.88, col)
	draw_circle(Vector2(-RADIUS * 0.3, -RADIUS * 0.35), RADIUS * 0.2, Color(1, 1, 1, 0.55))
	var white := Color.WHITE
	if kind == "magnet":
		draw_arc(Vector2(0.0, 1.0), 9.0, 0.0, PI, 14, white, 5.0)
		draw_line(Vector2(-9.0, 1.0), Vector2(-9.0, -9.0), Color("#ff5050"), 5.0)
		draw_line(Vector2(9.0, 1.0), Vector2(9.0, -9.0), Color("#5080ff"), 5.0)
	elif kind == "shield":
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 2), Vector2(0, 12), Vector2(-10, 2)]), white)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 1), Vector2(0, 8), Vector2(-6, 1)]), col)
	elif kind == "speed":
		draw_colored_polygon(PackedVector2Array([Vector2(3, -12), Vector2(-8, 2), Vector2(-1, 2), Vector2(-4, 12), Vector2(8, -4), Vector2(1, -4)]), white)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-17.0, 8.0), "x2", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 24, white)
