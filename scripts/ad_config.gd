extends RefCounted
## ALL AD SETTINGS IN ONE PLACE. Edit this file after you create your AdMob ad units.
##
## !!! Before you publish an update with ads: paste your REAL ad unit ids below and set USE_TEST_ADS := false !!!
## While USE_TEST_ADS is true the game shows Google's official TEST ads (safe to click, they pay nothing).
## NEVER tap your own real ads: AdMob can ban your account for that.

const USE_TEST_ADS := false

# Your real ad unit ids: AdMob console > Apps > your app > Ad units. They look like ca-app-pub-1234567890123456/1234567890
const REAL_APP_OPEN := "ca-app-pub-8678055881287786/1254526784"
const REAL_INTERSTITIAL := "ca-app-pub-8678055881287786/6518315965"
const REAL_REWARDED := "ca-app-pub-8678055881287786/3892152626"

# Google's public test ids (Android)
const TEST_APP_OPEN := "ca-app-pub-3940256099942544/9257395921"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"

# --- Startup ad (an "App Open" ad, shown on a loading screen when the game starts) ---------------------
const STARTUP_AD_FROM_LAUNCH := 3    # not on the first 2 launches (Google recommends this; new players should see the game first)
const STARTUP_MAX_WAIT_SEC := 4.0    # the loading screen never waits longer than this for the ad

# --- Full-screen ad between levels (an "Interstitial") ------------------------------------------------
const INTERSTITIAL_EVERY_N_WINS := 2   # 1 = after every level you finish, when you tap "Next Level". 2 = every second level...
const INTERSTITIAL_MIN_GAP_SEC := 60   # never two full-screen ads closer together than this
const FIRST_AD_LEVEL := 3              # no between-level ads before level 3

# --- Smarter ad timing (Update A1) ---------------------------------------------------------------------
const NO_INTERSTITIAL_FIRST_SEC := 240            # no between-level ads in the first 4 minutes after the game starts
const NO_INTERSTITIAL_AFTER_REWARDED_SEC := 180   # someone who just chose to watch a video is not shown a forced ad for 3 minutes
const AD_REVIVES_PER_ATTEMPT := 1                 # "Watch ad: swim on" after being eaten (per level attempt). 0 = switch it off

# --- Rewarded videos (optional, the player chooses to watch) ------------------------------------------
const REWARDED_COOLDOWN_SEC := 15      # wait this long after a rewarded video before offering the next one
const FREE_COINS_BASE := 100           # "Free coins" reward = base + per_level x your highest unlocked level
const FREE_COINS_PER_LEVEL := 1.0


static func ids() -> Dictionary:
	var app_open := TEST_APP_OPEN
	var interstitial := TEST_INTERSTITIAL
	var rewarded := TEST_REWARDED
	if not USE_TEST_ADS:
		if REAL_APP_OPEN.contains("XXXX") or REAL_INTERSTITIAL.contains("XXXX") or REAL_REWARDED.contains("XXXX"):
			push_warning("ad_config.gd: real ad unit ids are not filled in - using test ads")
		else:
			app_open = REAL_APP_OPEN
			interstitial = REAL_INTERSTITIAL
			rewarded = REAL_REWARDED
	return {"app_open": app_open, "interstitial": interstitial, "rewarded": rewarded}


static func free_coins(highest_level: int) -> int:
	return FREE_COINS_BASE + int(round(FREE_COINS_PER_LEVEL * float(highest_level)))
