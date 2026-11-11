extends RefCounted
## FishArt - draws every fish in a cartoon style with Godot's 2D drawing API,
## so the game needs no image files. Fish face +X; `xf` handles flip/tilt.
##
## kind 0 = round "Bubblefin"   1 = slim "Dart"   2 = puffer "Pufferball"   3 = predator "Shark"
## stage (player only): 0 = baby, 1 = bigger dorsal fin, 2 = stripes + biggest fin ("evolved")
## pattern (shop): 0 none, 1 stripes, 2 spots, 3 scales, 4 gold scales      acc (shop): 0 none, 1 sunglasses, 2 crown
##
## spec (shop "Fish" species) is an optional Dictionary that changes the SHAPE. All keys are optional:
##   "base": 0 round / 1 slim / 2 puffer / 3 shark / 4 ray (diamond) body     "bx","by": body half-length / half-height (default depends on base)
##   "tail": "fork" (default) | "crescent" | "fan" | "fluke" | "whip"
##   "dorsal": "auto" (default) | "none" | "tall" | "sail" | "hook"      "anal": true adds a lower fin
##   "nose": "none" | "bill" (swordfish) | "tusk" (narwhal) | "hammer" | "lure" (angler) | "beak" (dolphin)
##   "teeth": true    "angry": true    "bands": true (clownfish)    "patch": true (orca)    "spout": true (whale)
##   "fin_scale": size of the side fin (rays use 2.4)    "eye": eye size multiplier

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


static func _body_points(kind: int, s: float, mul: float, bx: float, by: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if kind == 4:   # ray: a flat diamond
		var ray: Array = [Vector2(1.0, 0.0), Vector2(0.2, 0.55), Vector2(-0.7, 1.0), Vector2(-1.0, 0.12), Vector2(-1.0, -0.12), Vector2(-0.7, -1.0), Vector2(0.2, -0.55)]
		for p in ray:
			var q: Vector2 = p
			pts.append(Vector2(q.x * bx, q.y * by) * s * mul)
	elif kind == 3:
		var raw: Array = [Vector2(1.45, 0.0), Vector2(0.9, 0.3), Vector2(0.2, 0.42), Vector2(-0.6, 0.3), Vector2(-1.1, 0.08), Vector2(-1.1, -0.08), Vector2(-0.6, -0.3), Vector2(0.2, -0.42), Vector2(0.9, -0.3)]
		var sx: float = bx / 1.4
		var sy: float = by / 0.42
		for p in raw:
			var q: Vector2 = p
			pts.append(Vector2(q.x * sx, q.y * sy) * s * mul)
	else:
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * bx, sin(a) * by) * s * mul)
	return pts


## A small oval, used for hammerhead heads and the orca eye patch.
static func _oval(cx: float, cy: float, rx: float, ry: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


static func _tri(c: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([xf * a, xf * b, xf * d]), col)


static func draw_fish(c: CanvasItem, xf: Transform2D, s: float, kind: int, body: Color, belly: Color, fin: Color, wag: float, mouth: float, stage: int, pattern: int = 0, acc: int = 0, dead: bool = false, spec: Dictionary = {}) -> void:
	if spec.has("base"):
		kind = int(spec["base"])
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
	elif kind == 4:
		bx = 1.0
		by = 0.85
	if spec.has("bx"):
		bx = float(spec["bx"])
	if spec.has("by"):
		by = float(spec["by"])
	var tail_kind := String(spec.get("tail", "fork"))
	var dorsal_kind := String(spec.get("dorsal", "auto"))
	var nose_kind := String(spec.get("nose", "none"))
	var fin_scale: float = float(spec.get("fin_scale", 1.0))
	var eye_scale: float = float(spec.get("eye", 1.0))
	var nose_x: float = 1.45 * s if kind == 3 else bx * s
	var rs: float = 0.45 + 0.55 * xf.x.length()   # circle radius shrinks while turning

	# --- tail (triangles only, always valid shapes) ---
	var tw := wag * 0.3 * s
	var spread := 0.62
	var tip_mul := 1.0
	var notch_mul := 0.82
	match tail_kind:
		"crescent":
			tip_mul = 1.05
			spread = 0.85
			notch_mul = 0.55
		"fan":
			tip_mul = 0.95
			spread = 0.7
			notch_mul = 1.08
		"fluke":
			tip_mul = 0.95
			spread = 0.9
			notch_mul = 0.7
	var tip_x := -1.55 * bx * s * tip_mul
	if tail_kind == "whip":   # stingray: a thin whip tail
		c.draw_line(xf * Vector2((-0.95 if kind == 4 else -0.6) * bx * s, 0.0), xf * Vector2(-2.2 * bx * s, tw), fin, maxf(3.0, s * 0.12))
	else:
		var top_tip := Vector2(tip_x, -spread * s + tw)
		var bot_tip := Vector2(tip_x, spread * s + tw)
		var notch := Vector2(tip_x * notch_mul, tw * 0.6)
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
	match dorsal_kind:
		"none":
			dm = 0.0
		"tall":
			dm = 1.0
		"sail":
			dm = 0.9
		"hook":
			dm = 0.6
	if dm > 0.0:
		var ty := -by * s * 0.85
		if dorsal_kind == "sail":
			_tri(c, xf, Vector2(-0.7 * bx * s, ty), Vector2(-0.2 * bx * s, ty - dm * s), Vector2(0.5 * bx * s, ty), fin)
		elif dorsal_kind == "hook":
			_tri(c, xf, Vector2(-0.1 * bx * s, ty), Vector2(-0.55 * bx * s, ty - dm * s), Vector2(0.3 * bx * s, ty), fin)
		else:
			_tri(c, xf, Vector2(-0.5 * bx * s, ty), Vector2(-0.2 * bx * s, ty - dm * s), Vector2(0.35 * bx * s, ty), fin)
	if bool(spec.get("anal", false)):   # a second fin under the belly (angelfish)
		var by2 := by * s * 0.85
		_tri(c, xf, Vector2(-0.5 * bx * s, by2), Vector2(-0.25 * bx * s, by2 + 0.95 * s), Vector2(0.3 * bx * s, by2), fin)

	# --- long nose: swordfish bill / narwhal tusk (drawn behind the body) ---
	if nose_kind == "bill":
		c.draw_line(xf * Vector2(nose_x * 0.9, 0.0), xf * Vector2(nose_x + 1.15 * s, -0.02 * s), fin.darkened(0.1), maxf(3.0, s * 0.13))
	elif nose_kind == "tusk":
		c.draw_line(xf * Vector2(nose_x * 0.92, -0.04 * s), xf * Vector2(nose_x + 1.0 * s, -0.22 * s), Color(0.96, 0.94, 0.85), maxf(3.0, s * 0.1))

	# --- puffer spikes ---
	if kind == 2:
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			var p0 := Vector2(cos(a) * bx, sin(a) * by) * s
			c.draw_line(xf * p0, xf * (p0 * 1.28), fin, maxf(2.0, s * 0.09))

	# --- body: outline, fill, belly ---
	c.draw_colored_polygon(_map(xf, _body_points(kind, s, 1.08, bx, by)), fin.darkened(0.2))
	var body_pts := _body_points(kind, s, 1.0, bx, by)
	c.draw_colored_polygon(_map(xf, body_pts), body)
	var lower: PackedVector2Array = body_pts.slice(0, 5) if kind == 3 else (body_pts.slice(0, 4) if kind == 4 else body_pts.slice(0, 13))
	c.draw_colored_polygon(_map(xf, lower), belly)

	# --- species details drawn on the body ---
	if nose_kind == "hammer":   # hammerhead: wide T-shaped head
		c.draw_colored_polygon(_map(xf, _oval(nose_x * 0.86, 0.0, 0.31 * s, 0.86 * s)), fin.darkened(0.2))
		c.draw_colored_polygon(_map(xf, _oval(nose_x * 0.86, 0.0, 0.26 * s, 0.8 * s)), body)
	if bool(spec.get("bands", false)):   # clownfish: three white bands
		for xo in [-0.5, 0.0, 0.5]:
			var yb: float = by * s * sqrt(maxf(0.0, 1.0 - xo * xo)) * 0.9
			var bpx: float = float(xo) * bx * s
			var bw: float = maxf(3.0, s * 0.2)
			c.draw_line(xf * Vector2(bpx, -yb), xf * Vector2(bpx, yb), Color(0.1, 0.1, 0.12), bw * 1.45)
			c.draw_line(xf * Vector2(bpx, -yb), xf * Vector2(bpx, yb), Color.WHITE, bw)
	if bool(spec.get("patch", false)):   # orca: white patch behind the eye
		c.draw_colored_polygon(_map(xf, _oval(0.2 * bx * s, -by * s * 0.5, 0.3 * s, 0.13 * s)), Color.WHITE)

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
	if kind != 4:   # (a ray's wings are its body)
		_tri(c, xf, Vector2(0.15 * bx * s, 0.18 * s), Vector2(-0.45 * bx * s * fin_scale, 0.55 * s * fin_scale + wag * 0.1 * s), Vector2(-0.05 * bx * s, 0.1 * s), fin)

	# --- eye ---
	var eye := Vector2(0.55 * bx * s, -by * s * 0.35)
	if kind == 4:
		eye = Vector2(0.5 * bx * s, -0.12 * s)
	if nose_kind == "hammer":
		eye = Vector2(nose_x * 0.9, -0.68 * s)   # eyes sit at the ends of the hammer
	var er: float = maxf(2.5, 0.2 * s) * rs * eye_scale
	if dead:   # defeated: cartoon "X" eye
		var ec: Vector2 = xf * eye
		var k: float = er * 1.0
		var xw: float = maxf(2.0, s * 0.07)
		c.draw_line(ec + Vector2(-k, -k), ec + Vector2(k, k), Color(0.08, 0.08, 0.12), xw)
		c.draw_line(ec + Vector2(-k, k), ec + Vector2(k, -k), Color(0.08, 0.08, 0.12), xw)
	else:
		c.draw_circle(xf * eye, er, Color.WHITE)
		c.draw_circle(xf * (eye + Vector2(0.06 * s, 0.0)), er * 0.55, Color(0.08, 0.08, 0.12))
	if kind == 3 or bool(spec.get("angry", false)):   # angry eyebrow
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

	# --- nose extras and details in front of the body ---
	var mouth_x: float = nose_x
	if nose_kind == "beak":   # dolphin snout
		_tri(c, xf, Vector2(nose_x * 0.8, -0.13 * s), Vector2(nose_x + 0.42 * s, 0.03 * s), Vector2(nose_x * 0.8, 0.17 * s), body)
		_tri(c, xf, Vector2(nose_x * 0.8, 0.06 * s), Vector2(nose_x + 0.36 * s, 0.07 * s), Vector2(nose_x * 0.8, 0.2 * s), belly)
		mouth_x = nose_x + 0.34 * s
	elif nose_kind == "lure":   # anglerfish: glowing lure on a stalk
		var p0 := Vector2(0.3 * bx * s, -by * s * 0.85)
		var p1 := Vector2(0.75 * bx * s, -by * s * 1.75)
		var p2 := Vector2(nose_x + 0.35 * s, -by * s * 1.4)
		var stalk: Color = fin.lightened(0.25)
		c.draw_line(xf * p0, xf * p1, stalk, maxf(2.0, s * 0.06))
		c.draw_line(xf * p1, xf * p2, stalk, maxf(2.0, s * 0.06))
		c.draw_circle(xf * p2, s * 0.32 * rs, Color(1.0, 0.95, 0.45, 0.18 + 0.1 * wag))
		c.draw_circle(xf * p2, s * 0.15 * rs, Color(1.0, 0.95, 0.5))
		c.draw_circle(xf * (p2 + Vector2(-0.04 * s, -0.04 * s)), s * 0.05 * rs, Color.WHITE)
	if bool(spec.get("teeth", false)):
		for ti in 3:
			var tx: float = mouth_x * (0.9 - 0.12 * float(ti))
			var ty2: float = by * s * 0.14
			_tri(c, xf, Vector2(tx, ty2), Vector2(tx - 0.08 * s, ty2), Vector2(tx - 0.04 * s, ty2 + 0.15 * s), Color.WHITE)
	if bool(spec.get("spout", false)):   # baby whale: water spout
		var spx: float = 0.35 * bx * s
		var spy: float = -by * s * 0.95
		var jet: float = 0.5 + 0.25 * absf(wag)
		var wcol := Color(0.75, 0.92, 1.0, 0.85)
		for dd in [-1.0, 0.0, 1.0]:
			var tp := Vector2(spx + float(dd) * 0.28 * s, spy - (0.55 * jet + 0.3 * (1.0 - absf(float(dd)))) * s)
			c.draw_line(xf * Vector2(spx, spy), xf * tp, wcol, maxf(2.0, s * 0.07))
			c.draw_circle(xf * tp, maxf(2.0, s * 0.07) * rs, wcol)

	# --- mouth ---
	var m: float = clampf(mouth, 0.0, 1.0)
	if m > 0.08:
		_tri(c, xf, Vector2(mouth_x * 0.99, 0.0), Vector2(mouth_x * 0.65, -0.2 * s * m), Vector2(mouth_x * 0.65, 0.22 * s * m), Color(0.45, 0.05, 0.1))
	else:
		c.draw_line(xf * Vector2(mouth_x * 0.97, by * s * 0.12), xf * Vector2(mouth_x * 0.72, by * s * 0.18), Color(0.2, 0.08, 0.08), maxf(1.5, s * 0.06))
