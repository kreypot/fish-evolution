extends Node2D
## The finish line: a tall chequered wall with a glowing "FINISH" sign.

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in 6:   # soft glow on the approach side
		draw_rect(Rect2(-260.0 + float(i) * 40.0, 0.0, 40.0, 1100.0), Color(1.0, 0.95, 0.5, 0.03 + 0.03 * float(i)))
	var cell := 40.0
	for row in 28:
		for col in 2:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color(0.1, 0.1, 0.15)
			draw_rect(Rect2(float(col) * cell - cell, float(row) * cell, cell, cell), c)
	var font := ThemeDB.fallback_font
	var a := 0.8 + 0.2 * sin(_time * 4.0)
	for y in [160.0, 520.0, 860.0]:
		draw_string(font, Vector2(-250.0, y), "FINISH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 64, Color(1.0, 0.95, 0.4, a))
