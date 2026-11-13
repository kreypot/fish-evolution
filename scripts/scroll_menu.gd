extends Control
## A menu list that is NOT fixed in place: drag it up and down with your finger (or the mouse),
## flick it and it keeps gliding, and it bounces softly at both ends. Tap an item to select it.
## It draws its own buttons, so a drag never triggers a button by accident.
## Works with the mouse wheel on desktop too.

signal scrolled_first_time

const DEADZONE := 14.0          # finger must move this many pixels before it counts as a scroll, not a tap
const ITEM_COLOR := Color("#1fa2c9")
const ITEM_PRESSED := Color("#147a99")

var item_w := 440.0
var item_h := 84.0
var gap := 16.0
var font_size := 32

var _items: Array = []          # [text, Callable]
var _offset := 0.0              # how far the list is scrolled (pixels)
var _vel := 0.0                 # scroll speed after a flick (pixels per second)
var _touching := false
var _dragging := false
var _press_index := -1
var _press_y := 0.0
var _last_y := 0.0
var _last_ms := 0
var _told_scrolled := false
var _time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func add_item(text: String, callback: Callable) -> void:
	_items.append([text, callback])
	queue_redraw()


## Change the text of an item that was already added (used by the daily reward item).
func set_item_text(index: int, text: String) -> void:
	if index >= 0 and index < _items.size():
		_items[index][0] = text
		queue_redraw()


func _content_height() -> float:
	return float(_items.size()) * (item_h + gap) - gap


func _max_offset() -> float:
	return maxf(0.0, _content_height() - size.y)


func _index_at(pos: Vector2) -> int:
	var x0: float = (size.x - item_w) * 0.5
	if pos.x < x0 or pos.x > x0 + item_w:
		return -1
	var y: float = pos.y + _offset
	var i: int = floori(y / (item_h + gap))
	if i < 0 or i >= _items.size():
		return -1
	if y - float(i) * (item_h + gap) > item_h:   # finger is in the gap between two items
		return -1
	return i


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touching = true
				_dragging = false
				_vel = 0.0
				_press_y = mb.position.y
				_last_y = mb.position.y
				_last_ms = Time.get_ticks_msec()
				_press_index = _index_at(mb.position)
			else:
				if _touching and not _dragging and _press_index >= 0 and _index_at(mb.position) == _press_index:
					var cb: Callable = _items[_press_index][1]
					AudioManager.play_sfx("click")
					_touching = false
					_press_index = -1
					queue_redraw()
					cb.call()
					return
				_touching = false
				_press_index = -1
			queue_redraw()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-(item_h + gap) * 0.8)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by((item_h + gap) * 0.8)
	elif event is InputEventMouseMotion and _touching:
		var mm: InputEventMouseMotion = event
		if not _dragging and absf(mm.position.y - _press_y) > DEADZONE:
			_dragging = true
			_press_index = -1
			if not _told_scrolled:
				_told_scrolled = true
				scrolled_first_time.emit()
		if _dragging:
			var dy: float = mm.position.y - _last_y
			var now: int = Time.get_ticks_msec()
			var dt: float = maxf(float(now - _last_ms) / 1000.0, 0.001)
			# soft resistance when pulling past the top or bottom
			var resist: float = 1.0
			if _offset < 0.0 or _offset > _max_offset():
				resist = 0.4
			_offset -= dy * resist
			_vel = lerpf(_vel, -dy / dt, 0.5)
			_last_ms = now
		_last_y = mm.position.y
		queue_redraw()


func _scroll_by(amount: float) -> void:
	_offset = clampf(_offset + amount, 0.0, _max_offset())
	if not _told_scrolled:
		_told_scrolled = true
		scrolled_first_time.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not _touching:
		var max_off := _max_offset()
		if _offset < 0.0 or _offset > max_off:
			# bounce back softly
			var target: float = 0.0 if _offset < 0.0 else max_off
			_offset = lerpf(_offset, target, clampf(delta * 12.0, 0.0, 1.0))
			_vel = 0.0
		elif absf(_vel) > 8.0:
			# keep gliding after a flick, slowing down smoothly
			_offset += _vel * delta
			_vel = move_toward(_vel, 0.0, (absf(_vel) * 3.0 + 120.0) * delta)
		else:
			_vel = 0.0
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var x0: float = (size.x - item_w) * 0.5
	for i in _items.size():
		var y: float = float(i) * (item_h + gap) - _offset
		if y > size.y or y + item_h < 0.0:
			continue
		var pressed: bool = _touching and not _dragging and _press_index == i
		var col: Color = ITEM_PRESSED if pressed else ITEM_COLOR
		var box := StyleBoxFlat.new()
		box.bg_color = col
		box.set_corner_radius_all(22)
		box.border_width_bottom = 5
		box.border_color = col.darkened(0.3)
		draw_style_box(box, Rect2(x0, y + (3.0 if pressed else 0.0), item_w, item_h))
		var text: String = _items[i][0]
		draw_string(font, Vector2(x0, y + item_h * 0.5 + float(font_size) * 0.35 + (3.0 if pressed else 0.0)), text, HORIZONTAL_ALIGNMENT_CENTER, item_w, font_size, Color.WHITE)

	# little arrows tell the player there is more above / below
	var pulse: float = 0.55 + 0.35 * sin(_time * 4.0)
	var cx: float = size.x * 0.5
	if _offset > 6.0:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 18, 26), Vector2(cx + 18, 26), Vector2(cx, 6)]), Color(1, 1, 1, pulse))
	if _offset < _max_offset() - 6.0:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 18, size.y - 26), Vector2(cx + 18, size.y - 26), Vector2(cx, size.y - 6)]), Color(1, 1, 1, pulse))

	# thin scroll bar on the right
	if _max_offset() > 1.0:
		var track: float = size.y - 20.0
		var bar_h: float = maxf(40.0, track * size.y / _content_height())
		var frac: float = clampf(_offset / _max_offset(), 0.0, 1.0)
		var bar_y: float = 10.0 + (track - bar_h) * frac
		draw_rect(Rect2(size.x - 10.0, bar_y, 5.0, bar_h), Color(1, 1, 1, 0.45))
