extends Control
## Main menu: Play, Level Selection, Settings, About. The panels are built in code
## so the whole screen lives in one readable file.

const UITheme = preload("res://scripts/ui_theme.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")
const ScrollMenu = preload("res://scripts/scroll_menu.gd")

var _menu_box: Control
var _settings_panel: Control
var _about_panel: Control
var _help_panel: Control
var _hint_label: Label
var _coins_label: Label
var _toast_label: Label
var _privacy_btn: Button
var _music_btn: Button
var _sfx_btn: Button
var _reset_btn: Button
var _hand_btn: Button
var _joy_btn: Button
var _quality_btn: Button
var _list                # the scrolling main list
var _daily_index := 3    # position of the Daily Reward item in the list
var _reset_armed := false


func _ready() -> void:
	theme = UITheme.make()
	add_child(MenuBg.new())
	_build_main()
	_build_settings()
	_build_about()
	_build_help()
	_toast_label = UITheme.label("", 32, Color("#ffd23a"))
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	_toast_label.add_theme_constant_override("outline_size", 8)
	add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.offset_left = -400.0
	_toast_label.offset_right = 400.0
	_toast_label.offset_top = -120.0
	_toast_label.offset_bottom = -70.0
	_toast_label.modulate.a = 0.0
	if GameState.daily_can_claim():
		_toast("Your daily reward is ready!")
	AudioManager.start_music()


func _centered(content: Control) -> Control:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(content)
	return center


func _build_main() -> void:
	# Left: logo. Right: a list of options that you can scroll up and down with your finger.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(560, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UITheme.label("Fish Evolution", 84, Color("#ffd23a"))
	title.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	title.add_theme_constant_override("outline_size", 14)
	var sub := UITheme.label("Ocean Run", 48, Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	sub.add_theme_constant_override("outline_size", 10)
	_coins_label = UITheme.label("Coins: %d" % GameState.coins, 32, Color("#ffd23a"))
	_coins_label.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	_coins_label.add_theme_constant_override("outline_size", 8)
	_hint_label = UITheme.label("Swipe the list up and down  >", 26, Color(1, 1, 1, 0.85))
	left.add_child(title)
	left.add_child(sub)
	left.add_child(_coins_label)
	left.add_child(_hint_label)
	row.add_child(left)

	var list := ScrollMenu.new()
	list.custom_minimum_size = Vector2(480, 470)
	list.scrolled_first_time.connect(_on_first_scroll)
	var play_text := "Play" if GameState.unlocked_level == 1 else "Continue (Level %d)" % GameState.unlocked_level
	list.add_item(play_text, _on_play)
	list.add_item("Level Selection", _on_levels)
	list.add_item("Fish Shop", _on_shop)
	list.add_item(_daily_text(), _on_daily)   # must stay the 4th item (index 3, see _daily_index)
	if AdService.enabled:
		list.add_item("Free Coins (watch ad)", _on_free_coins)
	list.add_item("How to Play", _on_help)
	list.add_item("Settings", _on_settings)
	list.add_item("About", _on_about)
	list.add_item("Exit Game", _on_quit)
	row.add_child(list)
	_list = list
	_menu_box = _centered(row)


func _on_first_scroll() -> void:
	if _hint_label != null:
		var tw := create_tween()
		tw.tween_property(_hint_label, "modulate:a", 0.0, 0.6)   # the hint fades once you have scrolled


func _build_help() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UITheme.label("How to Play", 52, Color("#ffd23a")))
	var text := "Touch and drag anywhere to swim - the joystick appears under your thumb.\n\nGREEN ring = you can eat it. RED ring = it can eat you!\n\nEat fish to grow and evolve. Every fish gives coins, and eating several quickly gives a COMBO bonus.\n\nCollect coins and spend them in the Fish Shop on new fish: from guppies to sharks and a baby whale!\n\nAvoid jellyfish and reach the chequered FINISH wall. Flags save your progress: if you get eaten after a flag you can continue from it."
	var l := UITheme.label(text, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	vb.add_child(l)
	var back := UITheme.button("Back", _show_menu, 320.0, 70.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	_help_panel = _centered(panel)
	_help_panel.visible = false


func _build_settings() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Settings", 52, Color("#ffd23a")))
	_music_btn = UITheme.button("", _on_toggle_music, 420.0, 72.0)
	_sfx_btn = UITheme.button("", _on_toggle_sfx, 420.0, 72.0)
	_hand_btn = UITheme.button("", _on_toggle_hand, 420.0, 72.0)
	_joy_btn = UITheme.button("", _on_cycle_joystick, 420.0, 72.0)
	_quality_btn = UITheme.button("", _on_toggle_quality, 420.0, 72.0)
	_reset_btn = UITheme.button("Reset Level Progress", _on_reset, 420.0, 72.0)
	_privacy_btn = UITheme.button("Ad Privacy Settings", _on_privacy_settings, 420.0, 72.0)
	_privacy_btn.visible = false
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	vb.add_child(grid)
	for b in [_music_btn, _sfx_btn, _hand_btn, _joy_btn, _quality_btn, _reset_btn, _privacy_btn]:
		grid.add_child(b)
	var back := UITheme.button("Back", _show_menu, 420.0, 72.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	_settings_panel = _centered(panel)
	_settings_panel.visible = false
	_refresh_settings()


func _build_about() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UITheme.label("About", 52, Color("#ffd23a")))
	var privacy := "Privacy: this game collects no information from your device. It has no ads, no analytics, no accounts, needs no internet and asks for no permissions. Your progress is saved only on your phone."
	if AdService.enabled:
		privacy = "Ads: this game shows ads from Google AdMob (when the game starts, between levels, and optional videos for bonus coins). AdMob may use your device's advertising ID; you can reset or opt out in Android Settings > Google > Ads. Your progress is saved only on your phone. See the privacy policy on the store page."
	var text := "Fish Evolution: Ocean Run  v1.3.0\n\nEat smaller fish to grow, dodge bigger predators, avoid jellyfish and reach the finish wall. 300 levels across 30 underwater worlds, and 17 fish to collect.\n\n" + privacy + "\n\nMade with the Godot Engine (MIT licence). All art and sound are generated in code."
	var l := UITheme.label(text, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	vb.add_child(l)
	var back := UITheme.button("Back", _show_menu, 320.0, 70.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	_about_panel = _centered(panel)
	_about_panel.visible = false


func _refresh_settings() -> void:
	_music_btn.text = "Music: %s" % ("ON" if GameState.music_on else "OFF")
	_sfx_btn.text = "Sound effects: %s" % ("ON" if GameState.sfx_on else "OFF")
	_reset_btn.text = "Tap again to confirm" if _reset_armed else "Reset Level Progress"
	_hand_btn.text = "Left-handed: %s" % ("ON" if GameState.left_handed else "OFF")
	_joy_btn.text = "Joystick: %s" % str(GameState.JOYSTICK_NAMES[GameState.joystick_size])
	_quality_btn.text = "Low quality: %s" % ("ON" if GameState.low_quality else "OFF")


func _show_menu() -> void:
	_menu_box.visible = true
	_settings_panel.visible = false
	_about_panel.visible = false
	_help_panel.visible = false
	_reset_armed = false
	_refresh_settings()


func _on_play() -> void:
	GameState.current_level = GameState.unlocked_level
	GameState.go_to("res://scenes/game.tscn")


func _on_levels() -> void:
	GameState.go_to("res://scenes/level_select.tscn")


func _on_shop() -> void:
	GameState.go_to("res://scenes/shop.tscn")


## "Free Coins (watch ad)" in the main menu
func _on_free_coins() -> void:
	if AdService.is_rewarded_ready():
		AdService.watch_for_free_coins(_on_coins_granted)
	elif AdService.rewarded_cooldown_left() > 0:
		_toast("Next free coins in %d seconds" % AdService.rewarded_cooldown_left())
	else:
		_toast("The ad is still loading, try again in a moment")


func _on_coins_granted() -> void:
	_coins_label.text = "Coins: %d" % GameState.coins
	_toast("+%d coins!" % AdService.free_coins_amount())


func _on_privacy_settings() -> void:
	AdService.show_privacy_options()


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _on_help() -> void:
	_menu_box.visible = false
	_help_panel.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _on_settings() -> void:
	_privacy_btn.visible = AdService.privacy_options_required()   # only where the law requires it (Europe / UK)
	_menu_box.visible = false
	_settings_panel.visible = true


func _on_about() -> void:
	_menu_box.visible = false
	_about_panel.visible = true


func _on_toggle_music() -> void:
	AudioManager.set_music_on(not GameState.music_on)
	_refresh_settings()


func _on_toggle_sfx() -> void:
	AudioManager.set_sfx_on(not GameState.sfx_on)
	_refresh_settings()


func _on_toggle_hand() -> void:
	GameState.left_handed = not GameState.left_handed
	GameState.save_game()
	_refresh_settings()


func _on_cycle_joystick() -> void:
	GameState.joystick_size = (GameState.joystick_size + 1) % 3
	GameState.save_game()
	_refresh_settings()


func _on_toggle_quality() -> void:
	GameState.low_quality = not GameState.low_quality
	GameState.apply_quality()
	GameState.save_game()
	_refresh_settings()


## Daily reward item in the main list.
func _daily_text() -> String:
	if GameState.daily_can_claim():
		return "Daily Reward  +%d" % GameState.daily_reward_for(GameState.daily_next_streak())
	return "Daily Reward (done)"


func _on_daily() -> void:
	if GameState.daily_can_claim():
		var day: int = GameState.daily_next_streak()
		var gain: int = GameState.claim_daily()
		AudioManager.play_sfx("coin")
		_coins_label.text = "Coins: %d" % GameState.coins
		_list.set_item_text(_daily_index, _daily_text())
		_toast("Day %d reward: +%d coins!" % [day, gain])
	else:
		var next_day: int = GameState.daily_streak + 1
		if next_day > GameState.DAILY_REWARDS.size():
			next_day = 1
		_toast("Come back tomorrow for +%d coins (day %d)" % [GameState.daily_reward_for(next_day), next_day])


func _on_reset() -> void:
	if _reset_armed:
		GameState.reset_progress()
		get_tree().reload_current_scene()
	else:
		_reset_armed = true
		_refresh_settings()


## Android back button: close a sub-panel, or quit from the main menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _menu_box != null and not _menu_box.visible:
			_show_menu()
		else:
			get_tree().quit()
