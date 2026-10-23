extends RefCounted
## Shared look for all menus: rounded buttons, readable fonts, panels.
## Usage: some_control.theme = UITheme.make()

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	t.set_font_size("font_size", "Button", 32)
	t.set_font_size("font_size", "Label", 28)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_stylebox("normal", "Button", _box(Color("#1fa2c9")))
	t.set_stylebox("hover", "Button", _box(Color("#33b8e0")))
	t.set_stylebox("pressed", "Button", _box(Color("#147a99")))
	t.set_stylebox("disabled", "Button", _box(Color("#3a5568")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.03, 0.15, 0.25, 0.94), 28, 32, false))
	return t


static func _box(color: Color, radius: int = 20, margin: int = 14, border: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border:
		sb.border_width_bottom = 5
		sb.border_color = color.darkened(0.3)
	return sb


## Highlighted look for the currently selected shop item.
static func selected_box() -> StyleBoxFlat:
	var sb := _box(Color("#2a7fd6"))
	sb.set_border_width_all(5)
	sb.border_color = Color("#ffd23a")
	return sb


static func button(text: String, callback: Callable, w: float = 360.0, h: float = 76.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_pressed.bind(callback))
	return b


static func _on_pressed(callback: Callable) -> void:
	AudioManager.play_sfx("click")
	callback.call()


static func label(text: String, font_size: int = 28, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
