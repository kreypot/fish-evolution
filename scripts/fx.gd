extends Node2D
## Tiny particle system: bubbles, eating bursts and floating score text.

const MAX_PARTICLES := 220

# particle = [pos, vel, age, lifetime, radius, color, kind]  (kind 0 = burst, 1 = bubble)
var _p: Array = []
var _texts: Array = []   # [pos, text, age, color]


func burst(pos: Vector2, color: Color, count: int = 10, speed: float = 160.0) -> void:
	for i in count:
		if _p.size() >= MAX_PARTICLES:
			break
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed)
		_p.append([pos, v, 0.0, randf_range(0.4, 0.8), randf_range(3.0, 7.0), color, 0])


## kind 1 = bubble ring, kind 2 = filled sparkle dot (used by shop trails)
func bubble(pos: Vector2, r: float = 4.0, color: Color = Color(1, 1, 1, 0.7), filled: bool = false) -> void:
	if _p.size() >= MAX_PARTICLES:
		return
	_p.append([pos, Vector2(randf_range(-10.0, 10.0), randf_range(-110.0, -60.0)), 0.0, randf_range(1.2, 2.2), r, color, 2 if filled else 1])


func popup(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	_texts.append([pos, text, 0.0, color])


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
		if int(q[6]) >= 1:
			pos.x += sin(float(q[2]) * 5.0 + float(i)) * 20.0 * delta
		else:
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
		else:
			col.a *= k
			draw_circle(pos, float(q[4]) * k, col)
	var font := ThemeDB.fallback_font
	for tx in _texts:
		var age: float = tx[2]
		var pos: Vector2 = tx[0]
		pos.y -= age * 60.0
		pos.x -= 100.0   # draw_string centres text inside a 200 px wide box
		var col: Color = tx[3]
		col.a = 1.0 - age
		draw_string(font, pos + Vector2(2, 2), tx[1], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 28, Color(0, 0, 0, col.a * 0.5))
		draw_string(font, pos, tx[1], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 28, col)
