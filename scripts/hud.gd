extends CanvasLayer
## In-game UI: stats, progress bar, pause button, joystick and the overlay screens
## (tutorial / pause / win / lose). It runs even while the tree is paused.
## It never changes the game itself - it only emits signals that game.gd listens to.

signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal next_requested
signal tutorial_closed
signal shop_requested
signal back_requested   # Android back button or Esc
signal app_paused       # app lost focus / went to background

const UITheme = preload("res://scripts/ui_theme.gd")
const Joystick = preload("res://scripts/joystick.gd")

var joystick   # read by game.gd: joystick.direction

var _root: Control
var _size_label: Label
var _score_label: Label
var _coin_label: Label
var _level_label: Label
var _progress: ProgressBar
var _banner: Label
var _overlay: Control = null
var _last_size := -1
var _last_score := -1


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.make()

	joystick = Joystick.new()
	_root.add_child(joystick)

	# --- top bar ---
	var bar := MarginContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["margin_left", "margin_right", "margin_top"]:
		bar.add_theme_constant_override(side, 24)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(250, 0)
	_size_label = _outlined_label("Size 20")
	_score_label = _outlined_label("Score 0")
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coin_label = _outlined_label("Coins 0")
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coin_label.add_theme_color_override("font_color", Color("#ffd23a"))
	left.add_child(_size_label)
	left.add_child(_score_label)
	left.add_child(_coin_label)
	row.add_child(left)

	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_label = _outlined_label("")
	_level_label.add_theme_font_size_override("font_size", 24)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 100.0
	_progress.custom_minimum_size = Vector2(0, 26)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(13)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffcf40")
	fill.set_corner_radius_all(13)
	_progress.add_theme_stylebox_override("background", bg)
	_progress.add_theme_stylebox_override("fill", fill)
	mid.add_child(_level_label)
	mid.add_child(_progress)
	row.add_child(mid)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(UITheme.button("II", _emit_pause, 84.0, 84.0))

	# --- level banner ---
	_banner = _outlined_label("")
	_banner.add_theme_font_size_override("font_size", 44)
	_root.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 150.0
	_banner.offset_bottom = 220.0
	_banner.modulate.a = 0.0


func _emit_pause() -> void:
	pause_requested.emit()


func _emit_resume() -> void:
	resume_requested.emit()


func _emit_restart() -> void:
	restart_requested.emit()


func _emit_menu() -> void:
	menu_requested.emit()


func _emit_next() -> void:
	next_requested.emit()


func _emit_shop() -> void:
	shop_requested.emit()


func _emit_tutorial() -> void:
	tutorial_closed.emit()


func _outlined_label(text: String) -> Label:
	var l := UITheme.label(text, 30)
	l.add_theme_color_override("font_outline_color", Color(0, 0.1, 0.2, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		app_paused.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()


# --- Called by game.gd every frame ------------------------------------------

func set_level_info(level: int, theme_name: String) -> void:
	_level_label.text = "Level %d - %s" % [level, theme_name]


func update_stats(size_value: float, score: int, progress: float, coins: int = 0) -> void:
	var s := int(size_value)
	if s != _last_size:
		_last_size = s
		_size_label.text = "Size %d" % s
	if score != _last_score:
		_last_score = score
		_score_label.text = "Score %d" % score
	_coin_label.text = "Coins %d" % coins
	_progress.value = progress * 100.0


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


# --- Overlay screens ---------------------------------------------------------

func clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _show_overlay(title: String, title_color: Color, lines: Array, buttons: Array) -> void:
	clear_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.05, 0.12, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	dim.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UITheme.label(title, 52, title_color))
	for line in lines:
		var l := UITheme.label(str(line), 28)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(600, 0)
		vb.add_child(l)
	for b in buttons:
		var btn := UITheme.button(str(b[0]), b[1], 400.0, 72.0)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(btn)
	_overlay = dim


func show_pause() -> void:
	_show_overlay("Paused", Color("#ffd23a"), [], [
		["Resume", _emit_resume],
		["Restart", _emit_restart],
		["Main Menu", _emit_menu],
	])


func show_tutorial() -> void:
	_show_overlay("How to Play", Color("#ffd23a"), [
		"Touch and drag anywhere to swim - the joystick appears under your thumb.",
		"GREEN ring = you can eat it. RED ring = it can eat you!",
		"Eating makes you grow and evolve, so you can eat bigger fish later.",
		"Avoid jellyfish and reach the chequered FINISH wall on the right.",
	], [["Let's swim!", _emit_tutorial]])


func show_win(d: Dictionary) -> void:
	var lines: Array = [
		"Score: %d%s" % [d["score"], "   NEW BEST!" if d["new_best"] else "   (best %d)" % d["best"]],
		"Growth: %d  ->  %d  (+%d)" % [d["start_size"], d["size"], d["size"] - d["start_size"]],
		"Fish eaten: %d     Time: %d s" % [d["eaten"], d["time"]],
		"Coins: +%d collected  +%d bonus  (total %d)" % [d["coins_run"], d["bonus_coins"], d["coins_total"]],
	]
	var buttons: Array = []
	var title := "Level Complete!"
	if d["is_last"]:
		title = "You beat all 100 levels!"
	else:
		buttons.append(["Next Level", _emit_next])
	buttons.append(["Replay", _emit_restart])
	buttons.append(["Fish Shop", _emit_shop])
	buttons.append(["Main Menu", _emit_menu])
	_show_overlay(title, Color("#7dff9a"), lines, buttons)


func show_lose(d: Dictionary) -> void:
	_show_overlay("You were eaten!", Color("#ff7a6a"), [
		"Score: %d" % d["score"],
		"Coins you collected are kept. Watch for the red rings!",
	], [
		["Retry", _emit_restart],
		["Main Menu", _emit_menu],
	])
