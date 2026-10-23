extends Control
## Big animated preview of the player's fish, used by the shop.

const FishArt = preload("res://scripts/fish_art.gd")

var look: Dictionary = {}
var stage := 1
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.12, 0.25, 0.55)
	box.set_corner_radius_all(28)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var center := size * 0.5 + Vector2(0.0, sin(_t * 1.6) * 8.0)
	var cols: Array = FishArt.resolve_colors(look, _t)
	var tilt: float = sin(_t * 1.2) * 0.08
	var xf := Transform2D(tilt, Vector2(1.0, 1.0), 0.0, center)
	FishArt.draw_fish(self, xf, minf(size.x, size.y) * 0.24, 0, cols[0], cols[1], cols[2], sin(_t * 5.0), 0.0, stage, int(look.get("pattern", 0)), int(look.get("acc", 0)))
