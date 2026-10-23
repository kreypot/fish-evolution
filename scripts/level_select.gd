extends Control
## Level selection: 10 pages of 10 levels (one page per underwater world).
## Locked levels are greyed out until the previous level is completed.

const UITheme = preload("res://scripts/ui_theme.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")
const PER_PAGE := 10

var _page := 0
var _title: Label
var _world: Label
var _grid: GridContainer
var _prev: Button
var _next: Button


func _ready() -> void:
	theme = UITheme.make()
	add_child(MenuBg.new())
	_page = floori((GameState.unlocked_level - 1) / float(PER_PAGE))

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	_title = UITheme.label("", 52, Color("#ffd23a"))
	_world = UITheme.label("", 30)
	vb.add_child(_title)
	vb.add_child(_world)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(_grid)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 18)
	_prev = UITheme.button("< Prev", _on_prev, 200.0, 70.0)
	_next = UITheme.button("Next >", _on_next, 200.0, 70.0)
	nav.add_child(_prev)
	nav.add_child(UITheme.button("Back", _on_back, 240.0, 70.0))
	nav.add_child(_next)
	vb.add_child(nav)
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var first := _page * PER_PAGE + 1
	var info := GameState.get_theme_for_level(first)
	_title.text = "Levels %d - %d" % [first, first + PER_PAGE - 1]
	_world.text = "World %d: %s" % [_page + 1, info["name"]]
	for i in PER_PAGE:
		var n := first + i
		var unlocked := n <= GameState.unlocked_level
		var txt := str(n)
		if unlocked and GameState.best_scores.has(n):
			txt += "\nBest %d" % GameState.best_scores[n]
		elif not unlocked:
			txt += "\nLocked"
		var b := UITheme.button(txt, _on_level.bind(n), 200.0, 118.0)
		b.disabled = not unlocked
		b.add_theme_font_size_override("font_size", 30)
		_grid.add_child(b)
	_prev.disabled = _page <= 0
	_next.disabled = (_page + 1) * PER_PAGE >= GameState.TOTAL_LEVELS


func _on_level(n: int) -> void:
	GameState.current_level = n
	GameState.go_to("res://scenes/game.tscn")


func _on_prev() -> void:
	_page = maxi(_page - 1, 0)
	_refresh()


func _on_next() -> void:
	_page = mini(_page + 1, floori(GameState.TOTAL_LEVELS / float(PER_PAGE)) - 1)
	_refresh()


func _on_back() -> void:
	GameState.go_to("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
