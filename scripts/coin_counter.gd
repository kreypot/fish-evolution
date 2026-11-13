extends Node
## Counts a number up on a Label like a cash register: every step plays a short "tick" that gets
## higher, the label pops a little, and the end plays a happy "ka-ching".
## Used for every coin reward (level complete, rewarded ads, daily reward, missions, achievements).
##
## Usage:   var cc := CoinCounter.new();  add_child(cc);  cc.run(label, from_value, to_value, text_function)
## `text_function(value) -> String` makes the text to show for the current number.

signal finished

var _label: Label
var _text_fn: Callable
var _from := 0
var _to := 0
var _t := 0.0
var _dur := 1.0
var _steps := 1
var _last_step := 0
var _running := false


func run(label: Label, from_val: int, to_val: int, text_fn: Callable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # also works while the game is paused
	_label = label
	_from = from_val
	_to = to_val
	_text_fn = text_fn
	var diff: int = absi(to_val - from_val)
	if diff == 0:
		_label.text = str(_text_fn.call(to_val))
		queue_free()
		return
	_steps = clampi(diff, 1, 28)
	_dur = clampf(0.5 + float(_steps) * 0.04, 0.6, 1.6)
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	if _label == null or not is_instance_valid(_label):
		queue_free()
		return
	_t += delta
	var k: float = clampf(_t / _dur, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - k, 2.0)   # fast at first, slow at the end
	var value: int = int(round(lerpf(float(_from), float(_to), eased)))
	_label.text = str(_text_fn.call(value))
	_label.pivot_offset = _label.size * 0.5
	_label.modulate = Color(1.0, 0.9, 0.45)
	var step: int = int(floor(eased * float(_steps)))
	if step != _last_step and k < 1.0:
		_last_step = step
		_label.scale = Vector2(1.12, 1.12)
		AudioManager.play_sfx("tick", -8.0, 0.9 + 0.7 * k)
	_label.scale = _label.scale.lerp(Vector2.ONE, clampf(delta * 14.0, 0.0, 1.0))
	if k >= 1.0:
		_running = false
		_finish()


func _finish() -> void:
	_label.text = str(_text_fn.call(_to))
	_label.modulate = Color.WHITE
	_label.scale = Vector2(1.3, 1.3)
	AudioManager.play_sfx("kaching")
	finished.emit()
	var tw := create_tween()
	tw.tween_property(_label, "scale", Vector2.ONE, 0.35)
	tw.tween_callback(queue_free)
