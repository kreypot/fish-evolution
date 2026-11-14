extends RefCounted

const ScrollBox = preload("res://scripts/scroll_box.gd")
## Shared look for all menus: chunky rounded buttons with a soft shadow, readable outlined text, clean panels.
## Usage: some_control.theme = UITheme.make()

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	t.set_font_size("font_size", "Button", 32)
	t.set_font_size("font_size", "Label", 28)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.5))
	t.set_color("font_outline_color", "Button", Color(0.0, 0.12, 0.25, 0.85))
	t.set_constant("outline_size", "Button", 6)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_stylebox("normal", "Button", _box(Color("#1fa2c9")))
	t.set_stylebox("hover", "Button", _box(Color("#33b8e0")))
	t.set_stylebox("pressed", "Button", _box(Color("#147a99"), 22, 14, true, true))
	t.set_stylebox("disabled", "Button", _box(Color("#3a5568"), 22, 14, true, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _panel_box())
	# thick scroll bars that are easy to see and to drag with a finger
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.28)
	track.set_corner_radius_all(9)
	track.content_margin_left = 9
	track.content_margin_right = 9
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	for nm in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(1, 1, 1, 0.55) if nm == "grabber" else (Color("#ffd23a") if nm == "grabber_pressed" else Color(1, 1, 1, 0.8))
		grab.set_corner_radius_all(9)
		grab.content_margin_left = 9
		grab.content_margin_right = 9
		grab.content_margin_top = 24
		grab.content_margin_bottom = 24
		t.set_stylebox(nm, "VScrollBar", grab)
	return t


## A chunky "3D" button face: outline, thicker bottom edge and a soft shadow (flat and lower when pressed).
static func _box(color: Color, radius: int = 22, margin: int = 14, border: bool = true, pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border:
		sb.set_border_width_all(3)
		sb.border_width_bottom = 3 if pressed else 8
		sb.border_color = color.darkened(0.35)
		if pressed:
			sb.content_margin_top = margin + 4
		else:
			sb.shadow_color = Color(0, 0, 0, 0.28)
			sb.shadow_size = 5
			sb.shadow_offset = Vector2(0, 4)
	return sb


## Dark glass panel with a light-blue edge and a soft shadow.
static func _panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.15, 0.27, 0.95)
	sb.set_corner_radius_all(30)
	sb.set_content_margin_all(32)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.25, 0.78, 0.94, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	return sb


## Highlighted look for the currently selected shop item.
static func selected_box() -> StyleBoxFlat:
	var sb := _box(Color("#2a7fd6"))
	sb.set_border_width_all(5)
	sb.border_color = Color(1.0, 0.82, 0.23)
	return sb


## Makes the content of a panel scroll when it does not fit on the screen. The Back button (or the row of buttons)
## at the bottom stays visible under the scrolling part.
static func make_scrollable(panel: PanelContainer, screen_margin: float = 110.0) -> void:
	if panel.get_child_count() != 1:
		return
	var inner: Control = panel.get_child(0)
	var footer: Control = null
	if inner.get_child_count() > 1:
		var last: Node = inner.get_child(inner.get_child_count() - 1)
		if last is Button or last is HBoxContainer:
			footer = last
			inner.remove_child(footer)
	panel.remove_child(inner)
	var box := ScrollBox.new()
	box.setup(inner, true, screen_margin, footer)
	panel.add_child(box)


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
