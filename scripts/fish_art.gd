extends RefCounted
## FishArt - draws every fish in a cartoon style with Godot's 2D drawing API,
## so the game needs no image files. Fish face +X; `xf` handles flip/tilt.
##
## kind 0 = round "Bubblefin"   1 = slim "Dart"   2 = puffer "Pufferball"   3 = predator "Shark"
## stage (player only): 0 = baby, 1 = bigger dorsal fin, 2 = stripes + biggest fin ("evolved")
## pattern (shop): 0 none, 1 stripes, 2 spots, 3 scales, 4 gold scales      acc (shop): 0 none, 1 sunglasses, 2 crown

## Body/belly/fin colours for a look dictionary (GameState.get_look). `t` = time, used by the rainbow skin.
static func resolve_colors(look: Dictionary, t: float) -> Array:
	var body: Color = look.get("body", Color("#ffa534"))
	var belly: Color = look.get("belly", Color("#ffe08a"))
	var fin: Color = look.get("fin", Color("#e0661d"))
	if look.get("rainbow", false):
		body = Color.from_hsv(fposmod(t * 0.25, 1.0), 0.65, 1.0)
		belly = body.lightened(0.55)
		fin = body.darkened(0.3)
	return [body, belly, fin]


static func _map(xf: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = xf * pts[i]
	return out


static func _body_points(kind: int, s: float, mul: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if kind == 3:
		var raw: Array = [Vector2(1.45, 0.0), Vector2(0.9, 0.3), Vector2(0.2, 0.42), Vector2(-0.6, 0.3), Vector2(-1.1, 0.08), Vector2(-1.1, -0.08), Vector2(-0.6, -0.3), Vector2(0.2, -0.42), Vector2(0.9, -0.3)]
		for p in raw:
			var q: Vector2 = p
			pts.append(q * s * mul)
	else:
		var bx := 1.0
		var by := 0.62
		if kind == 1:
			bx = 1.2
			by = 0.4
		elif kind == 2:
			bx = 0.95
			by = 0.85
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * bx, sin(a) * by) * s * mul)
	return pts


static func _tri(c: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([xf * a, xf * b, xf * d]), col)


static func draw_fish(c: CanvasItem, xf: Transform2D, s: float, kind: int, body: Color, belly: Color, fin: Color, wag: float, mouth: float, stage: int, pattern: int = 0, acc: int = 0) -> void:
	var bx := 1.0
	var by := 0.62
	if kind == 1:
		bx = 1.2
		by = 0.4
	elif kind == 2:
		bx = 0.95
		by = 0.85
	elif kind == 3:
		bx = 1.4
		by = 0.42
	var rs: float = 0.45 + 0.55 * xf.x.length()   # circle radius shrinks while turning

	# --- tail (3 triangles, always valid shapes) ---
	var tip_x := -1.55 * bx * s
	var tw := wag * 0.3 * s
	var top_tip := Vector2(tip_x, -0.62 * s + tw)
	var bot_tip := Vector2(tip_x, 0.62 * s + tw)
	var notch := Vector2(tip_x * 0.82, tw * 0.6)
	var b_top := Vector2(-0.7 * bx * s, -0.14 * s)
	var b_bot := Vector2(-0.7 * bx * s, 0.14 * s)
	_tri(c, xf, b_top, top_tip, notch, fin)
	_tri(c, xf, b_bot, bot_tip, notch, fin)
	_tri(c, xf, b_top, notch, b_bot, fin)

	# --- dorsal fin (grows as the player evolves) ---
	var dm := 0.35 + 0.28 * float(stage)
	if kind == 3:
		dm = 0.9
	elif kind == 2:
		dm = 0.0
	if dm > 0.0:
		var ty := -by * s * 0.85
		_tri(c, xf, Vector2(-0.5 * bx * s, ty), Vector2(-0.2 * bx * s, ty - dm * s), Vector2(0.35 * bx * s, ty), fin)

	# --- puffer spikes ---
	if kind == 2:
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			var p0 := Vector2(cos(a) * bx, sin(a) * by) * s
			c.draw_line(xf * p0, xf * (p0 * 1.28), fin, maxf(2.0, s * 0.09))

	# --- body: outline, fill, belly ---
	c.draw_colored_polygon(_map(xf, _body_points(kind, s, 1.08)), fin.darkened(0.2))
	var body_pts := _body_points(kind, s)
	c.draw_colored_polygon(_map(xf, body_pts), body)
	var lower: PackedVector2Array = body_pts.slice(0, 5) if kind == 3 else body_pts.slice(0, 13)
	c.draw_colored_polygon(_map(xf, lower), belly)

	# --- patterns (bought in the shop) + evolved-stage stripes ---
	if kind != 3:
		var pat_col := Color(fin.r, fin.g, fin.b, 0.6)
		if pattern == 1 or (stage >= 2 and pattern == 0):
			for xo in [-0.15, 0.3]:
				var yy: float = by * s * sqrt(maxf(0.0, 1.0 - xo * xo)) * 0.92
				var x: float = float(xo) * bx * s
				c.draw_line(xf * Vector2(x, -yy), xf * Vector2(x, yy), pat_col, maxf(2.0, s * 0.14))
		elif pattern == 2:
			var spots: Array = [Vector2(-0.2, -0.22), Vector2(0.1, 0.12), Vector2(0.38, -0.14), Vector2(-0.5, 0.1), Vector2(0.0, -0.02), Vector2(0.55, 0.14)]
			for sp in spots:
				var spv: Vector2 = sp
				c.draw_circle(xf * Vector2(spv.x * bx * s, spv.y * by * s * 1.4), maxf(1.5, s * 0.09) * rs, Color(fin.r, fin.g, fin.b, 0.75))
		elif pattern >= 3:
			var scale_col := Color(1.0, 0.85, 0.3, 0.95) if pattern == 4 else Color(fin.r, fin.g, fin.b, 0.8)
			var open_right: bool = xf.x.x < 0.0   # scale arcs open toward the tail
			var a0: float = -0.45 * PI if open_right else 0.6 * PI
			var a1: float = 0.45 * PI if open_right else 1.4 * PI
			for row in range(-1, 2):
				for col in range(-3, 4):
					var px: float = (float(col) * 0.27 + (0.135 if row % 2 != 0 else 0.0)) * bx * s
					var py: float = float(row) * 0.3 * by * s * 1.3
					var nx: float = px / (bx * s * 0.82)
					var ny: float = py / (by * s * 0.82)
					if nx * nx + ny * ny < 1.0:
						c.draw_arc(xf * Vector2(px, py), maxf(2.0, s * 0.13) * rs, a0, a1, 6, scale_col, maxf(1.2, s * 0.04))

	# --- pectoral fin ---
	_tri(c, xf, Vector2(0.15 * bx * s, 0.18 * s), Vector2(-0.45 * bx * s, 0.55 * s + wag * 0.1 * s), Vector2(-0.05 * bx * s, 0.1 * s), fin)

	# --- eye ---
	var eye := Vector2(0.55 * bx * s, -by * s * 0.35)
	var er: float = maxf(2.5, 0.2 * s) * rs
	c.draw_circle(xf * eye, er, Color.WHITE)
	c.draw_circle(xf * (eye + Vector2(0.06 * s, 0.0)), er * 0.55, Color(0.08, 0.08, 0.12))
	if kind == 3:   # angry eyebrow
		c.draw_line(xf * (eye + Vector2(-0.25 * s, -0.3 * s)), xf * (eye + Vector2(0.28 * s, -0.05 * s)), Color(0.1, 0.1, 0.15), maxf(2.0, s * 0.07))

	# --- accessories (bought in the shop) ---
	if acc == 1:   # sunglasses
		c.draw_circle(xf * eye, er * 1.55, Color(0.05, 0.05, 0.1))
		c.draw_circle(xf * (eye + Vector2(-0.05 * s, -0.06 * s)), er * 0.4, Color(1, 1, 1, 0.7))
		c.draw_line(xf * eye, xf * Vector2(-0.35 * bx * s, eye.y - 0.04 * s), Color(0.05, 0.05, 0.1), maxf(2.0, s * 0.07))
	elif acc == 2:   # crown
		var ty := -by * s * 0.82
		var gold := Color(1.0, 0.84, 0.2)
		for k in 3:
			var kx: float = (0.12 + 0.17 * float(k)) * bx * s
			_tri(c, xf, Vector2(kx - 0.09 * s, ty), Vector2(kx, ty - 0.34 * s), Vector2(kx + 0.09 * s, ty), gold)
			c.draw_circle(xf * Vector2(kx, ty - 0.34 * s), maxf(1.5, s * 0.05) * rs, Color(0.9, 0.2, 0.3))

	# --- mouth ---
	var nose_x: float = 1.45 * s if kind == 3 else bx * s
	var m: float = clampf(mouth, 0.0, 1.0)
	if m > 0.08:
		_tri(c, xf, Vector2(nose_x * 0.99, 0.0), Vector2(nose_x * 0.65, -0.2 * s * m), Vector2(nose_x * 0.65, 0.22 * s * m), Color(0.45, 0.05, 0.1))
	else:
		c.draw_line(xf * Vector2(nose_x * 0.97, by * s * 0.12), xf * Vector2(nose_x * 0.72, by * s * 0.18), Color(0.2, 0.08, 0.08), maxf(1.5, s * 0.06))
