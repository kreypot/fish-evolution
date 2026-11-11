extends Control
## Loading screen shown when the game starts. It is where the startup ad (an App Open ad) is shown:
## if an ad is ready within a few seconds it plays, otherwise the game simply continues to the menu.
## Without ads (plugin not installed, or on a PC) it just shows the logo for a moment.

const UITheme = preload("res://scripts/ui_theme.gd")
const MenuBg = preload("res://scripts/menu_bg.gd")
const AdConfig = preload("res://scripts/ad_config.gd")

const MIN_TIME := 1.2   # the logo is always visible at least this long

var _t := 0.0
var _done := false
var _label: Label


func _ready() -> void:
	theme = UITheme.make()
	add_child(MenuBg.new())
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	var title := UITheme.label("Fish Evolution", 96, Color("#ffd23a"))
	title.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	title.add_theme_constant_override("outline_size", 14)
	var sub := UITheme.label("Ocean Run", 52, Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color(0, 0.15, 0.3))
	sub.add_theme_constant_override("outline_size", 10)
	_label = UITheme.label("Loading", 32, Color(1, 1, 1, 0.9))
	vb.add_child(title)
	vb.add_child(sub)
	vb.add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	_label.text = "Loading" + ".".repeat(int(_t * 3.0) % 4)
	if _done or _t < MIN_TIME:
		return
	if not AdService.startup_wait_needed():
		_go()
		return
	if AdService.startup_ad_ready():
		_done = true
		AdService.show_startup_ad(_go)   # continues to the menu when the ad closes
		return
	if AdService.startup_ad_failed() or _t >= AdConfig.STARTUP_MAX_WAIT_SEC:
		_go()   # no ad in time: never make the player wait


func _go() -> void:
	_done = true
	GameState.go_to("res://scenes/main_menu.tscn")
