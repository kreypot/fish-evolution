extends Node
## AdService (autoload) - the ONLY place where the game talks about ads.
##
## The game works the same with or without ads:
##  * If the AdMob plugin is not installed (or on a PC), `enabled` stays false and every call does nothing,
##    so no ad buttons appear.
##  * If the plugin is installed, scripts/admob_backend.gd (copied from ads/admob_backend.gd.txt by the build) is used.
##
## Where ads appear (never during gameplay):
##  1. Startup: an App Open ad on the loading screen (not on the first 2 launches).
##  2. Between levels: an interstitial when you tap "Next Level" (frequency in ad_config.gd).
##  3. Optional rewarded videos: "Double coins" on the level-complete screen, "Free coins" in the menu and the shop.

const AdConfig = preload("res://scripts/ad_config.gd")

var enabled := false

var _backend = null
var _wins_since_interstitial := 0
var _last_ad_ms := -10000000        # when the last full-screen ad was closed
var _last_reward_ms := -10000000    # when the last rewarded video was completed
var _closed_cb: Callable = Callable()
var _pending := false
var _serial := 0
var _grant_cb: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		return
	if not ResourceLoader.exists("res://scripts/admob_backend.gd"):
		return
	var script: Script = load("res://scripts/admob_backend.gd")
	if script == null or not script.can_instantiate():
		push_warning("AdService: ads backend could not be loaded (is the AdMob plugin installed and enabled?)")
		return
	_backend = script.new()
	enabled = true
	_backend.start(AdConfig.ids())


# --- startup ad ------------------------------------------------------------------

## Should the loading screen wait for the startup ad? (Not on the very first launches.)
func startup_wait_needed() -> bool:
	return enabled and GameState.launch_count >= AdConfig.STARTUP_AD_FROM_LAUNCH


func startup_ad_ready() -> bool:
	return enabled and _backend.is_app_open_ready()


func startup_ad_failed() -> bool:
	return enabled and _backend.app_open_failed()


func show_startup_ad(on_closed: Callable) -> void:
	_show("app_open", Callable(), on_closed)


# --- between levels --------------------------------------------------------------

func register_level_win() -> void:
	_wins_since_interstitial += 1


## Call when the player taps "Next Level". Returns true if an ad is being shown;
## `on_closed` is then called when it closes. Returns false (and does NOT call on_closed) if no ad is shown.
func maybe_show_interstitial(on_closed: Callable) -> bool:
	if not enabled:
		return false
	if GameState.current_level < AdConfig.FIRST_AD_LEVEL:
		return false
	if _wins_since_interstitial < AdConfig.INTERSTITIAL_EVERY_N_WINS:
		return false
	if Time.get_ticks_msec() - _last_ad_ms < AdConfig.INTERSTITIAL_MIN_GAP_SEC * 1000:
		return false
	if not _backend.is_interstitial_ready():
		return false
	_wins_since_interstitial = 0
	_show("interstitial", Callable(), on_closed)
	return true


# --- rewarded videos -------------------------------------------------------------

func rewarded_cooldown_left() -> int:
	var left: float = float(AdConfig.REWARDED_COOLDOWN_SEC) - float(Time.get_ticks_msec() - _last_reward_ms) / 1000.0
	return maxi(0, int(ceil(left)))


func is_rewarded_ready() -> bool:
	return enabled and _backend.is_rewarded_ready() and rewarded_cooldown_left() == 0


func free_coins_amount() -> int:
	return AdConfig.free_coins(GameState.unlocked_level)


## Shows a rewarded video. `on_reward` is called ONLY if the player watched it to the end.
func show_rewarded(on_reward: Callable, on_closed: Callable = Callable()) -> void:
	if not is_rewarded_ready():
		return
	_show("rewarded", _wrap_reward.bind(on_reward), on_closed)


## "Free coins" button (menu + shop): watch a video, receive coins. `on_granted` is called after the coins are added.
func watch_for_free_coins(on_granted: Callable) -> void:
	_grant_cb = on_granted
	show_rewarded(_grant_free_coins)


func _grant_free_coins() -> void:
	GameState.add_coins(free_coins_amount())
	GameState.save_game()
	AudioManager.play_sfx("coin")
	if _grant_cb.is_valid():
		_grant_cb.call()


func _wrap_reward(on_reward: Callable) -> void:
	_last_reward_ms = Time.get_ticks_msec()
	if on_reward.is_valid():
		on_reward.call()


# --- Europe privacy options ------------------------------------------------------

func privacy_options_required() -> bool:
	return enabled and _backend.privacy_options_required()


func show_privacy_options(on_done: Callable = Callable()) -> void:
	if enabled:
		_backend.show_privacy_options(on_done)


# --- internals -------------------------------------------------------------------

func _show(kind: String, on_reward: Callable, on_closed: Callable) -> void:
	_serial += 1
	_pending = true
	_closed_cb = on_closed
	AudioServer.set_bus_mute(0, true)   # silence the game while the ad plays
	match kind:
		"app_open":
			_backend.show_app_open(_on_ad_closed)
		"interstitial":
			_backend.show_interstitial(_on_ad_closed)
		"rewarded":
			_backend.show_rewarded(on_reward, _on_ad_closed)
	get_tree().create_timer(90.0).timeout.connect(_failsafe.bind(_serial))


func _on_ad_closed() -> void:
	if not _pending:
		return
	_pending = false
	AudioServer.set_bus_mute(0, false)
	_last_ad_ms = Time.get_ticks_msec()
	var cb: Callable = _closed_cb
	_closed_cb = Callable()
	if cb.is_valid():
		cb.call()


## If an ad never reports that it closed (a rare error), carry on after 90 seconds so the game can't get stuck.
func _failsafe(serial: int) -> void:
	if _pending and serial == _serial:
		_on_ad_closed()
