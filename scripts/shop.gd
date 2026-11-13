extends Control
## Fish Shop: spend coins on fish species, skins, patterns, trails and extras.
## Tap an item to preview it on the fish, then Buy / Equip.
## Items come from GameState.shop_items - add more there and they appear here.

const UITheme = preload("res://scripts/ui_theme.gd")
const CoinCounter = preload("res://scripts/coin_counter.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")
const FishPreview = preload("res://scripts/fish_preview.gd")
const ITEMS_PER_PAGE := 8   # 4 columns x 2 rows; more items = more pages

var _cat := "species"
var _page := 0
var _page_label: Label
var _count_label: Label
var _prev_btn: Button
var _next_btn: Button
var _ad_btn: Button = null
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

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	_prev_btn = UITheme.button("<", _on_prev_page, 90.0, 54.0)
	_next_btn = UITheme.button(">", _on_next_page, 90.0, 54.0)
	_page_label = UITheme.label("", 24)
	_count_label = UITheme.label("", 24, Color("#ffd23a"))
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_prev_btn)
	nav.add_child(_page_label)
	nav.add_child(_next_btn)
	nav.add_child(_count_label)
	right.add_child(nav)

	_info = UITheme.label("", 26)
	_info.custom_minimum_size = Vector2(0, 40)
	right.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	right.add_child(row)
	_action = UITheme.button("", _on_action, 400.0, 72.0)
	row.add_child(_action)
	row.add_child(UITheme.button("Back", _on_back, 200.0, 72.0))

	# Optional "free coins" rewarded video (only exists when ads are active)
	if AdService.enabled:
		_ad_btn = UITheme.button("", _on_watch_ad, 620.0, 62.0)
		_ad_btn.add_theme_font_size_override("font_size", 28)
		right.add_child(_ad_btn)
		_update_ad_button()

	_select_category("species")


func _process(_delta: float) -> void:
	if _ad_btn != null:
		_update_ad_button()


func _update_ad_button() -> void:
	var wait: int = AdService.rewarded_cooldown_left()
	if AdService.is_rewarded_ready():
		_ad_btn.text = "Watch ad: +%s free coins" % _fmt(AdService.free_coins_amount())
		_ad_btn.disabled = false
	elif wait > 0:
		_ad_btn.text = "Next free coins in %d s" % wait
		_ad_btn.disabled = true
	else:
		_ad_btn.text = "Loading ad..."
		_ad_btn.disabled = true


func _on_watch_ad() -> void:
	AdService.watch_for_free_coins(_on_ad_coins)


## After the ad: the coin number counts up with a tick sound for every step and a "ka-ching" at the end.
func _on_ad_coins() -> void:
	var before: int = maxi(0, GameState.coins - AdService.free_coins_amount())
	_refresh()
	var cc := CoinCounter.new()
	add_child(cc)
	cc.run(_coin_label, before, GameState.coins, _coin_text)


func _coin_text(v: int) -> String:
	return "Coins: %s" % _fmt(v)


func _select_category(cat: String) -> void:
	_cat = cat
	_selected = ""
	_page = 0
	var items: Array = GameState.items_in(cat)
	for i in items.size():
		if GameState.is_equipped(items[i]["id"]):
			_selected = items[i]["id"]
			_page = floori(float(i) / float(ITEMS_PER_PAGE))   # open the page that has your equipped item
	_refresh()


func _refresh() -> void:
	_coin_label.text = "Coins: %s" % _fmt(GameState.coins)

	for c in _tabs.get_children():
		c.queue_free()
	for cat in GameState.CATEGORY_ORDER:
		var tb := UITheme.button(GameState.CATEGORY_NAMES[cat], _on_tab.bind(cat), 140.0, 62.0)
		tb.add_theme_font_size_override("font_size", 26)
		if cat == _cat:
			tb.add_theme_stylebox_override("normal", UITheme.selected_box())
		_tabs.add_child(tb)

	for c in _grid.get_children():
		c.queue_free()
	var all_items: Array = GameState.items_in(_cat)
	var pages: int = maxi(1, ceili(float(all_items.size()) / float(ITEMS_PER_PAGE)))
	_page = clampi(_page, 0, pages - 1)
	var first: int = _page * ITEMS_PER_PAGE
	var owned_count := 0
	for it in all_items:
		if GameState.is_owned(it["id"]):
			owned_count += 1
	_page_label.text = "Page %d / %d" % [_page + 1, pages]
	_count_label.text = "Owned %d of %d" % [owned_count, all_items.size()]
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= pages - 1
	_prev_btn.visible = pages > 1
	_next_btn.visible = pages > 1
	_page_label.visible = pages > 1
	for idx in range(first, mini(first + ITEMS_PER_PAGE, all_items.size())):
		var it: Dictionary = all_items[idx]
		var id: String = it["id"]
		var status := ""
		if GameState.is_equipped(id):
			status = "EQUIPPED"
		elif GameState.is_owned(id):
			status = "OWNED"
		else:
			status = "%s coins" % _fmt(int(it["price"]))
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
		_info.text = "%s costs %s coins." % [it["name"], _fmt(price)]
		_action.text = "Buy for %s coins" % _fmt(price)
		_action.disabled = false
	else:
		_info.text = "Collect coins in levels to unlock %s." % it["name"]
		_action.text = "Need %s more coins" % _fmt(price - GameState.coins)
		_action.disabled = true


func _on_prev_page() -> void:
	_page -= 1
	_refresh()


func _on_next_page() -> void:
	_page += 1
	_refresh()


## 12000 -> "12,000"
func _fmt(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


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
