extends Control
## Fish Shop: spend coins on skins, patterns, trails and extras.
## Tap an item to preview it on the fish, then Buy / Equip.
## Items come from GameState.shop_items - add more there and they appear here.

const UITheme = preload("res://scripts/ui_theme.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")
const FishPreview = preload("res://scripts/fish_preview.gd")

var _cat := "skin"
var _selected := ""
var _coin_label: Label
var _tabs: HBoxContainer
var _grid: GridContainer
var _info: Label
var _action: Button
var _preview


func _ready() -> void:
	theme = UITheme.make()
	add_child(MenuBg.new())

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# header: title + coin balance
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UITheme.label("Fish Shop", 52, Color("#ffd23a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_coin_label = UITheme.label("", 40, Color("#ffd23a"))
	header.add_child(_coin_label)

	# body: preview on the left, items on the right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_preview = FishPreview.new()
	_preview.custom_minimum_size = Vector2(400, 330)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_preview)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	right.add_child(_tabs)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	right.add_child(_grid)

	_info = UITheme.label("", 26)
	_info.custom_minimum_size = Vector2(0, 40)
	right.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	right.add_child(row)
	_action = UITheme.button("", _on_action, 400.0, 72.0)
	row.add_child(_action)
	row.add_child(UITheme.button("Back", _on_back, 200.0, 72.0))

	_select_category("skin")


func _select_category(cat: String) -> void:
	_cat = cat
	_selected = ""
	for it in GameState.items_in(cat):
		if GameState.is_equipped(it["id"]):
			_selected = it["id"]
	_refresh()


func _refresh() -> void:
	_coin_label.text = "Coins: %d" % GameState.coins

	for c in _tabs.get_children():
		c.queue_free()
	for cat in GameState.CATEGORY_ORDER:
		var tb := UITheme.button(GameState.CATEGORY_NAMES[cat], _on_tab.bind(cat), 150.0, 62.0)
		tb.add_theme_font_size_override("font_size", 26)
		if cat == _cat:
			tb.add_theme_stylebox_override("normal", UITheme.selected_box())
		_tabs.add_child(tb)

	for c in _grid.get_children():
		c.queue_free()
	for it in GameState.items_in(_cat):
		var id: String = it["id"]
		var status := ""
		if GameState.is_equipped(id):
			status = "EQUIPPED"
		elif GameState.is_owned(id):
			status = "OWNED"
		else:
			status = "%d coins" % int(it["price"])
		var b := UITheme.button("%s\n%s" % [it["name"], status], _on_item.bind(id), 175.0, 92.0)
		b.add_theme_font_size_override("font_size", 22)
		if id == _selected:
			b.add_theme_stylebox_override("normal", UITheme.selected_box())
		_grid.add_child(b)

	_preview.look = GameState.get_look(_selected)
	_update_action()


func _update_action() -> void:
	if _selected == "":
		_info.text = "Pick an item to preview it"
		_action.text = "-"
		_action.disabled = true
		return
	var it := GameState.get_item(_selected)
	var price := int(it["price"])
	if GameState.is_equipped(_selected):
		_info.text = "%s is on your fish right now." % it["name"]
		_action.text = "Equipped"
		_action.disabled = true
	elif GameState.is_owned(_selected):
		_info.text = "You own %s." % it["name"]
		_action.text = "Equip"
		_action.disabled = false
	elif GameState.coins >= price:
		_info.text = "%s costs %d coins." % [it["name"], price]
		_action.text = "Buy for %d coins" % price
		_action.disabled = false
	else:
		_info.text = "Collect coins in levels to unlock %s." % it["name"]
		_action.text = "Need %d more coins" % (price - GameState.coins)
		_action.disabled = true


func _on_tab(cat: String) -> void:
	_select_category(cat)


func _on_item(id: String) -> void:
	_selected = id
	_refresh()


func _on_action() -> void:
	if _selected == "":
		return
	if not GameState.is_owned(_selected):
		if not GameState.buy(_selected):
			return
		AudioManager.play_sfx("grow")
	GameState.equip(_selected)
	_refresh()


func _on_back() -> void:
	GameState.go_to("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
