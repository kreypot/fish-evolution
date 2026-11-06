extends Node2D
## A checkpoint flag standing on the sea floor at 25 %, 50 % and 75 % of every level.
## White = not reached yet, green = reached. If you get eaten after reaching one,
## you can "Continue from checkpoint" instead of restarting the whole level.

var reached := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col := Color(0.35, 1.0, 0.45) if reached else Color(1.0, 0.95, 0.7)
	draw_rect(Rect2(-35.0, -1000.0, 70.0, 1000.0), Color(col.r, col.g, col.b, 0.06 + 0.03 * sin(_t * 3.0)))   # soft beam of light
	draw_line(Vector2(0, 0), Vector2(0, -300.0), Color(0.85, 0.85, 0.9), 8.0)                                 # pole
	var wave := sin(_t * 4.0) * 12.0
	draw_colored_polygon(PackedVector2Array([Vector2(4, -300), Vector2(110 + wave, -270), Vector2(4, -235)]), col)   # waving flag
	draw_circle(Vector2(0, -304.0), 9.0, Color(1.0, 0.85, 0.3))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-60.0, -330.0), "CHECKPOINT" if not reached else "SAVED!", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 22, Color(1, 1, 1, 0.85))
