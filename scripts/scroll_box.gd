extends VBoxContainer
## Makes anything scrollable when it does not fit on the screen.
## You get the normal scroll bar, two arrow buttons (up / down, hold them to scroll on), mouse wheel,
## and you can also drag the empty parts of the content with your finger.
## An optional `footer` (for example the Back button) stays visible under the scrolling part.
##
## Usage:   var box := ScrollBox.new()
##          box.setup(content, true, 120.0, footer)
##          parent.add_child(box)
##   fit = true : as tall as the content, but never taller than the screen minus `margin`
##   fit = false: fills all the space it is given (the content stretches, and scrolls when it is too tall)

var content: Control
var footer: Control = null
var fit := true
var margin := 120.0
var _row: HBoxContainer
var _scroll: TouchScroll
var _arrows: VBoxContainer
var _up: ScrollArrow
var _down: ScrollArrow


func setup(c: Control, fit_mode: bool = true, screen_margin: float = 120.0, footer_control: Control = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # also works while the game is paused
	content = c
	fit = fit_mode
	margin = screen_margin
	footer = footer_control
	add_theme_constant_override("separation", 14)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_row)
	_scroll = TouchScroll.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.add_child(_scroll)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not fit_mode:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(c)
	_arrows = VBoxContainer.new()
	_up = ScrollArrow.new()
	_up.is_up = true
	_down = ScrollArrow.new()
	_down.is_up = false
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.add_child(_up)
	_arrows.add_child(spacer)
	_arrows.add_child(_down)
	_arrows.visible = false
	_row.add_child(_arrows)
	_up.pressed_once.connect(_on_arrow.bind(-1))
	_down.pressed_once.connect(_on_arrow.bind(1))
	if footer != null:
		if footer.get_parent() != null:
			footer.get_parent().remove_child(footer)
		add_child(footer)
		footer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		footer.size_flags_vertical = Control.SIZE_SHRINK_END
		if fit_mode:
			footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_update_layout()


func _on_arrow(dir: int) -> void:
	_scroll.scroll_vertical += dir * 180


func _update_layout() -> void:
	if content == null:
		return
	var need: float = content.get_combined_minimum_size().y
	var avail: float
	if fit:
		var foot: float = 0.0
		if footer != null:
			foot = footer.get_combined_minimum_size().y + 14.0
		avail = maxf(get_viewport_rect().size.y - margin - foot, 160.0)
		_scroll.custom_minimum_size.y = minf(need, avail)
	else:
		avail = _scroll.size.y
	var can: bool = need > avail + 1.0
	_arrows.visible = can
	if can:
		var sv: float = float(_scroll.scroll_vertical)
		_up.dim = sv <= 0.0
		_down.dim = sv >= need - _scroll.size.y - 1.0


func _process(delta: float) -> void:
	_update_layout()
	if _arrows != null and _arrows.visible:
		for a in [_up, _down]:
			if a.held:
				a.hold_t += delta
				if a.hold_t > 0.3:   # holding an arrow keeps scrolling
					_scroll.scroll_vertical += int((-1.0 if a.is_up else 1.0) * 700.0 * delta)


## A ScrollContainer that also scrolls when you drag on empty parts of the content (buttons keep working as buttons).
class TouchScroll extends ScrollContainer:
	var _press := false
	var _drag := 0.0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_press = event.pressed
			_drag = 0.0
		elif event is InputEventMouseMotion and _press:
			_drag += absf(event.relative.y)
			if _drag > 10.0:
				scroll_vertical -= int(event.relative.y)
				accept_event()


## A round up / down arrow button.
class ScrollArrow extends Control:
	signal pressed_once

	var is_up := true
	var held := false
	var hold_t := 0.0
	var dim := false:
		set(v):
			dim = v
			queue_redraw()

	func _ready() -> void:
		custom_minimum_size = Vector2(54.0, 54.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			held = event.pressed
			hold_t = 0.0
			if event.pressed and not dim:
				pressed_once.emit()
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			held = false
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var a: float = 0.35 if dim else 1.0
		draw_circle(c, 25.0, Color(0.0, 0.1, 0.2, 0.55 * a))
		draw_arc(c, 25.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5 * a), 3.0)
		var d: float = -1.0 if is_up else 1.0
		var col := Color(1, 1, 1, 0.95 * a)
		if held:
			col = Color("#ffd23a")
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -9.0 * d), c + Vector2(-11.0, 7.0 * d), c + Vector2(11.0, 7.0 * d)]), col)
