extends Node2D
## Tiny particle system: bubbles, eating bursts and floating score text.

const MAX_PARTICLES := 220

# particle = [pos, vel, age, lifetime, radius, color, kind, extra]
#   kind 0 = burst dot, 1 = bubble ring, 2 = filled dot, 3 = expanding ring (extra = end radius), 4 = sparkle (extra = spin)
var _p: Array = []
var _texts: Array = []   # [pos, text, age, color, font size]


func burst(pos: Vector2, color: Color, count: int = 10, speed: float = 160.0) -> void:
	for i in count:
		if _p.size() >= MAX_PARTICLES:
			break
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed)
		_p.append([pos, v, 0.0, randf_range(0.4, 0.8), randf_range(3.0, 7.0), color, 0, 0.0])


## kind 1 = bubble ring, kind 2 = filled sparkle dot (used by shop trails)
func bubble(pos: Vector2, r: float = 4.0, color: Color = Color(1, 1, 1, 0.7), filled: bool = false) -> void:
	if _p.size() >= MAX_PARTICLES:
		return
	_p.append([pos, Vector2(randf_range(-10.0, 10.0), randf_range(-110.0, -60.0)), 0.0, randf_range(1.2, 2.2), r, color, 2 if filled else 1, 0.0])


## A shock-wave ring that expands from `r0` to `r1` (used for eating, evolving and dying).
func ring(pos: Vector2, r0: float, r1: float, color: Color, life: float = 0.45) -> void:
	_p.append([pos, Vector2.ZERO, 0.0, life, r0, color, 3, r1])


## Twinkling 4-point stars that fly outward.
func sparkles(pos: Vector2, color: Color, count: int = 6, speed: float = 220.0) -> void:
	for i in count:
		if _p.size() >= MAX_PARTICLES:
			break
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.4, speed)
		_p.append([pos, v, 0.0, randf_range(0.45, 0.8), randf_range(7.0, 14.0), color, 4, randf() * TAU])


func popup(pos: Vector2, text: String, color: Color = Color.WHITE, font_size: int = 28) -> void:
	_texts.append([pos, text, 0.0, color, font_size])


func _process(delta: float) -> void:
	if _p.is_empty() and _texts.is_empty():
		return
	for i in range(_p.size() - 1, -1, -1):
		var q: Array = _p[i]
		q[2] = float(q[2]) + delta
		if float(q[2]) >= float(q[3]):
			_p.remove_at(i)
			continue
		var pos: Vector2 = q[0]
		var vel: Vector2 = q[1]
		pos += vel * delta
		var kind := int(q[6])
		if kind == 1 or kind == 2:
			pos.x += sin(float(q[2]) * 5.0 + float(i)) * 20.0 * delta
		elif kind == 0 or kind == 4:
			vel *= maxf(1.0 - 2.5 * delta, 0.0)
		q[0] = pos
		q[1] = vel
	for i in range(_texts.size() - 1, -1, -1):
		var tx: Array = _texts[i]
		tx[2] = float(tx[2]) + delta
		if float(tx[2]) > 1.0:
			_texts.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for q in _p:
		var k: float = 1.0 - float(q[2]) / float(q[3])
		var col: Color = q[5]
		var pos: Vector2 = q[0]
		if int(q[6]) == 1:
			var rc: Color = col
			rc.a = 0.75 * k
			draw_arc(pos, float(q[4]), 0.0, TAU, 12, rc, 1.5)
		elif int(q[6]) == 2:
			col.a = k
			draw_circle(pos, float(q[4]) * (0.5 + 0.5 * k), col)
		elif int(q[6]) == 3:   # expanding ring
			var grow: float = 1.0 - k
			var rr: float = lerpf(float(q[4]), float(q[7]), grow)
			col.a = 0.9 * k
			draw_arc(pos, rr, 0.0, TAU, 40, col, maxf(1.5, 6.0 * k))
		elif int(q[6]) == 4:   # sparkle star
			var rs: float = float(q[4]) * (0.4 + 0.6 * k)
			var spin: float = float(q[7]) + float(q[2]) * 4.0
			col.a = k
			var d1 := Vector2(cos(spin), sin(spin)) * rs
			var d2 := Vector2(-d1.y, d1.x) * 0.45
			draw_line(pos - d1, pos + d1, col, 2.5)
			draw_line(pos - d2, pos + d2, col, 2.5)
			draw_circle(pos, rs * 0.22, Color(1, 1, 1, k))
		else:
			col.a *= k
			draw_circle(pos, float(q[4]) * k, col)
	var font := ThemeDB.fallback_font
	for tx in _texts:
		var age: float = tx[2]
		var pos: Vector2 = tx[0]
		pos.y -= age * 60.0
		pos.x -= 150.0   # draw_string centres text inside a 300 px wide box
		var col: Color = tx[3]
		col.a = 1.0 - age
		var fs: int = int(tx[4])
		var pop: float = maxf(0.0, 1.0 - age * 5.0)   # text "pops" bigger for the first 0.2 s
		fs = int(float(fs) * (1.0 + 0.5 * pop))
		draw_string(font, pos + Vector2(2, 2), tx[1], HORIZONTAL_ALIGNMENT_CENTER, 300.0, fs, Color(0, 0, 0, col.a * 0.5))
		draw_string(font, pos, tx[1], HORIZONTAL_ALIGNMENT_CENTER, 300.0, fs, col)
