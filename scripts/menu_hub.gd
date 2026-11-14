extends Control
## The main menu "hub": round glossy buttons floating around the screen so that you can see all of them at once.
## Each bubble has a colour, a small drawn icon and a label, and bobs gently in the water.
## Usage:  hub.add_bubble("play", "Play", "play", Color("#2fae5a"), Vector2(0.5, 0.82), 76.0, callback)
##   Vector2(0.5, 0.82) = where on the screen (0..1 from the left / from the top).  76.0 = radius in pixels.
## Icons: play levels shop daily missions stats wifi coins help settings about exit

var _items: Array = []
var _time := 0.0
var _down := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func add_bubble(id: String, text: String, icon: String, color: Color, frac: Vector2, radius: float, callback: Callable) -> void:
	_items.append({"id": id, "text": text, "icon": icon, "color": color, "frac": frac, "r": radius, "cb": callback, "badge": false, "phase": randf() * TAU, "press": 0.0})


func _index(id: String) -> int:
	for i in _items.size():
		if str(_items[i]["id"]) == id:
			return i
	return -1


func set_text(id: String, text: String) -> void:
	var i: int = _index(id)
	if i >= 0:
		_items[i]["text"] = text


func set_color(id: String, color: Color) -> void:
	var i: int = _index(id)
	if i >= 0:
		_items[i]["color"] = color


func set_badge(id: String, on: bool) -> void:
	var i: int = _index(id)
	if i >= 0:
		_items[i]["badge"] = on


func _center(it: Dictionary) -> Vector2:
	var f: Vector2 = it["frac"]
	var bob: float = sin(_time * 1.1 + float(it["phase"])) * 6.0
	return Vector2(f.x * size.x, f.y * size.y + bob)


func _hit(p: Vector2) -> int:
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		if p.distance_to(_center(it)) <= float(it["r"]) * 1.12:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = _hit(event.position)
		else:
			var idx: int = _down
			_down = -1
			if idx >= 0 and _hit(event.position) == idx:
				AudioManager.play_sfx("click")
				var cb: Callable = _items[idx]["cb"]
				cb.call()


func _process(delta: float) -> void:
	_time += delta
	for i in _items.size():
		var it: Dictionary = _items[i]
		it["press"] = move_toward(float(it["press"]), 1.0 if i == _down else 0.0, delta * 10.0)
	queue_redraw()


func _draw() -> void:
	for it in _items:
		_draw_bubble(it)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_bubble(it: Dictionary) -> void:
	var c: Vector2 = _center(it)
	var press: float = float(it["press"])
	var r: float = float(it["r"]) * (1.0 - 0.07 * press)
	var col: Color = it["color"]
	var font := ThemeDB.fallback_font
	# soft shadow on the "floor" under the bubble
	draw_colored_polygon(_ellipse(c + Vector2(0.0, r * 1.05), r * 0.85, r * 0.16), Color(0.0, 0.08, 0.2, 0.25))
	# a glowing ring for the Play button and for bubbles with news (badge)
	var glow: float = 0.0
	if str(it["id"]) == "play":
		glow = 0.5 + 0.5 * sin(_time * 3.0)
	elif bool(it["badge"]):
		glow = 0.5 + 0.5 * sin(_time * 4.0)
	if glow > 0.0:
		draw_circle(c, r * (1.18 + 0.08 * glow), Color(1.0, 1.0, 0.7, 0.14 + 0.12 * glow))
	# the glossy ball: dark rim, shaded body, lighter inside, shine
	draw_circle(c, r * 1.07, col.darkened(0.55))
	draw_circle(c, r, col.darkened(0.3))
	draw_circle(c + Vector2(0.0, -r * 0.05), r * 0.93, col)
	draw_circle(c + Vector2(0.0, -r * 0.18), r * 0.74, col.lightened(0.16))
	draw_colored_polygon(_ellipse(c + Vector2(-r * 0.12, -r * 0.55), r * 0.5, r * 0.2), Color(1, 1, 1, 0.38))
	draw_arc(c, r * 0.97, PI * 1.05, PI * 1.65, 20, Color(1, 1, 1, 0.4), 3.0)
	draw_arc(c, r * 0.97, PI * 0.1, PI * 0.45, 12, Color(0, 0, 0, 0.18), 3.0)
	# the icon: a dark copy slightly lower, then the white one
	var u: float = r * 0.45
	_icon(str(it["icon"]), c + Vector2(0.0, u * 0.09 + 1.5), u, Color(0.0, 0.1, 0.25, 0.4), Color(0.0, 0.1, 0.25, 0.4))
	_icon(str(it["icon"]), c, u, Color.WHITE, col.darkened(0.2))
	# the label under the bubble
	var fs: int = 34 if r >= 70.0 else (26 if r >= 50.0 else 22)
	var tpos := Vector2(c.x - 130.0, c.y + r + float(fs) + 4.0)
	draw_string_outline(font, tpos, str(it["text"]), HORIZONTAL_ALIGNMENT_CENTER, 260.0, fs, 8, Color(0.0, 0.12, 0.25, 0.9))
	draw_string(font, tpos, str(it["text"]), HORIZONTAL_ALIGNMENT_CENTER, 260.0, fs, Color.WHITE)
	if bool(it["badge"]):   # a red "!" at the top right: something is waiting
		var bp: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		var pulse: float = 1.0 + 0.12 * sin(_time * 6.0)
		draw_circle(bp, 17.0 * pulse, Color(1, 1, 1, 0.95))
		draw_circle(bp, 14.0 * pulse, Color("#ff3b4e"))
		draw_string(font, bp + Vector2(-10.0, 9.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 26, Color.WHITE)


## Small icons drawn from simple shapes. u = half the size of the icon, col = the main colour, acc = the detail colour.
func _icon(kind: String, c: Vector2, u: float, col: Color, acc: Color) -> void:
	var w: float = maxf(2.0, 0.16 * u)
	var font := ThemeDB.fallback_font
	if kind == "play":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45 * u, -0.85 * u), c + Vector2(0.95 * u, 0.0), c + Vector2(-0.45 * u, 0.85 * u)]), col)
	elif kind == "levels":   # four tiles
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				draw_rect(Rect2(c + Vector2(sx * 0.5 * u - 0.42 * u, sy * 0.5 * u - 0.42 * u), Vector2(0.84 * u, 0.84 * u)), col)
	elif kind == "shop":   # a fish
		draw_colored_polygon(_ellipse(c + Vector2(-0.15 * u, 0.0), 0.9 * u, 0.55 * u), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.6 * u, 0.0), c + Vector2(1.2 * u, -0.5 * u), c + Vector2(1.2 * u, 0.5 * u)]), col)
		draw_circle(c + Vector2(-0.6 * u, -0.12 * u), 0.11 * u, acc)
	elif kind == "daily":   # a gift
		draw_rect(Rect2(c + Vector2(-0.8 * u, -0.1 * u), Vector2(1.6 * u, 1.0 * u)), col)
		draw_rect(Rect2(c + Vector2(-0.95 * u, -0.5 * u), Vector2(1.9 * u, 0.45 * u)), col)
		draw_rect(Rect2(c + Vector2(-0.14 * u, -0.5 * u), Vector2(0.28 * u, 1.4 * u)), acc)
		draw_arc(c + Vector2(-0.35 * u, -0.78 * u), 0.3 * u, 0.0, TAU, 14, col, w)
		draw_arc(c + Vector2(0.35 * u, -0.78 * u), 0.3 * u, 0.0, TAU, 14, col, w)
	elif kind == "missions":   # a checklist
		draw_rect(Rect2(c + Vector2(-0.7 * u, -0.85 * u), Vector2(1.4 * u, 1.8 * u)), col)
		draw_rect(Rect2(c + Vector2(-0.35 * u, -1.0 * u), Vector2(0.7 * u, 0.3 * u)), acc)
		for k in 3:
			var y: float = -0.3 * u + float(k) * 0.45 * u
			draw_line(c + Vector2(-0.4 * u, y), c + Vector2(0.4 * u, y), acc, w)
	elif kind == "stats":   # a trophy
		draw_colored_polygon(PackedVector2Array([c + Vector2(-0.7 * u, -0.85 * u), c + Vector2(0.7 * u, -0.85 * u), c + Vector2(0.5 * u, 0.1 * u), c + Vector2(0.2 * u, 0.4 * u), c + Vector2(-0.2 * u, 0.4 * u), c + Vector2(-0.5 * u, 0.1 * u)]), col)
		draw_arc(c + Vector2(-0.72 * u, -0.45 * u), 0.32 * u, PI * 0.5, PI * 1.5, 10, col, w)
		draw_arc(c + Vector2(0.72 * u, -0.45 * u), 0.32 * u, -PI * 0.5, PI * 0.5, 10, col, w)
		draw_rect(Rect2(c + Vector2(-0.13 * u, 0.4 * u), Vector2(0.26 * u, 0.3 * u)), col)
		draw_rect(Rect2(c + Vector2(-0.5 * u, 0.7 * u), Vector2(1.0 * u, 0.2 * u)), col)
	elif kind == "wifi":   # Wi-Fi waves
		var base: Vector2 = c + Vector2(0.0, 0.55 * u)
		for k in 3:
			draw_arc(base, (0.55 + 0.42 * float(k)) * u, PI * 1.22, PI * 1.78, 14, col, w * 1.2)
		draw_circle(base, 0.17 * u, col)
	elif kind == "coins":   # a coin
		draw_circle(c, 0.95 * u, col)
		draw_circle(c, 0.72 * u, acc)
		draw_string(font, c + Vector2(-0.6 * u, 0.5 * u), "$", HORIZONTAL_ALIGNMENT_CENTER, 1.2 * u, int(1.5 * u), col)
	elif kind == "help":
		draw_string(font, c + Vector2(-u, 0.72 * u), "?", HORIZONTAL_ALIGNMENT_CENTER, 2.0 * u, int(2.1 * u), col)
	elif kind == "settings":   # a gear
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			var pts := PackedVector2Array()
			for off in [-0.2, -0.14, 0.14, 0.2]:
				var rad: float = 0.65 * u if absf(off) > 0.15 else 1.0 * u
				pts.append(c + Vector2(cos(a + off), sin(a + off)) * rad)
			draw_colored_polygon(pts, col)
		draw_circle(c, 0.75 * u, col)
		draw_circle(c, 0.32 * u, acc)
	elif kind == "about":   # an "i" in a ring
		draw_arc(c, 0.95 * u, 0.0, TAU, 24, col, w)
		draw_circle(c + Vector2(0.0, -0.45 * u), 0.15 * u, col)
		draw_rect(Rect2(c + Vector2(-0.11 * u, -0.15 * u), Vector2(0.22 * u, 0.8 * u)), col)
	elif kind == "exit":   # a power symbol
		draw_arc(c, 0.8 * u, -PI * 0.5 + 0.65, -PI * 0.5 + TAU - 0.65, 20, col, w * 1.3)
		draw_line(c + Vector2(0.0, -0.95 * u), c + Vector2(0.0, -0.1 * u), col, w * 1.3)
