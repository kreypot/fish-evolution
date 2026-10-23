extends Control
## Floating one-thumb joystick: press anywhere, drag to swim in that direction.
## Reads mouse events, which Android generates from touches (see project.godot),
## so the same code works on a phone and with a mouse on desktop.

const RADIUS := 110.0

var direction := Vector2.ZERO   # length 0..1, read by game.gd

var _active := false
var _origin := Vector2.ZERO
var _current := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func reset() -> void:
	_active = false
	direction = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_active = true
			_origin = event.position
			_current = event.position
			direction = Vector2.ZERO
		else:
			reset()
		queue_redraw()
	elif event is InputEventMouseMotion and _active:
		_current = event.position
		var d: Vector2 = _current - _origin
		if d.length() > RADIUS:
			_origin = _current - d.normalized() * RADIUS   # base follows the thumb
			d = _current - _origin
		direction = d / RADIUS
		if direction.length() < 0.12:
			direction = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_origin, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(_current, 42.0, Color(1, 1, 1, 0.45))
