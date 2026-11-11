# Showing ads in Fish Evolution: Ocean Run (Google AdMob) – complete guide

Version 1.2 contains everything in the game code. Ads switch on **only when you add the AdMob plugin and your ad ids** (steps below).
Until then the game runs exactly as now: no ads, no ad buttons, no extra permissions.

---------------------------------------------------------------------------------------------------

## 1. What players will see

| # | Where | Ad type | When |
|---|---|---|---|
| 1 | **Game start** (loading screen with the logo) | App Open ad | Only from the **3rd launch** on. If no ad is ready within 4 seconds the game just continues. |
| 2 | **Between levels** | Interstitial (full screen) | When the player taps **Next Level** after finishing a level. Never before level 3, at most one per 60 seconds. Default: after **every** level. |
| 3 | **Level-complete screen** | Rewarded video (optional) | Button **"Watch ad: double coins (+N)"** |
| 4 | **Main menu** (list item) and **Fish Shop** (button) | Rewarded video (optional) | **"Free Coins (watch ad)"**: 100 coins + 1 per unlocked level (so 100 to 400). 15-second cool-down between videos. |

Never during gameplay. Game sound is muted while an ad plays. If an ad is not ready, the game continues without waiting (except the startup ad, which waits max 4 s).

All numbers are in **`scripts/ad_config.gd`** (see section 9).

> My honest advice: an ad after *every* level (as you asked) earns more per player but makes some players quit earlier and write worse reviews.
> If your ratings fall, set `INTERSTITIAL_EVERY_N_WINS := 2` (every second level). It is one number.

---------------------------------------------------------------------------------------------------

## 2. Before you start (decisions and rules)

* **Audience 13+.** The consent setting in the code says "not under age of consent". In Play Console choose target age groups 13 and older.
  If you target children under 13, Google's *Families* rules apply (ads must use child-directed settings) and this setup must change. Ask me first.
* **Never tap your own real ads** and don't ask friends to. AdMob can ban the account for invalid activity. Use **test ads** while developing (the default).
* **Money:** AdMob pays after you pass its payment threshold and verify your address and tax details. A new game with few players earns very little at first.
* **Your game is already public**, so you can link it in AdMob right now (section 3, step 5).

---------------------------------------------------------------------------------------------------

## 3. AdMob account, app and ad units  (admob.google.com)

1. **Sign in** with your Google account → accept terms → choose country and time zone. Later: **Payments** → add payment details, tax information, and verify your address (a PIN letter may arrive).
2. **Add your app:** *Apps → Add app → Android* → "Is the app listed on a supported app store?" → **Yes** → search *Fish Evolution* or paste the Play link
   `https://play.google.com/store/apps/details?id=com.kainavako.fishevolution` → *Add*.
   (If it is not found yet, choose "No", enter the package name `com.kainavako.fishevolution` exactly, and link it later in *App settings*.)
3. Copy your **App ID** (format `ca-app-pub-1234567890123456~1234567890`, note the **~**).
4. **Create 3 ad units** (*Apps → your app → Ad units → Add ad unit*):
   * **App open** → name "Startup" → copy its Ad unit ID.
   * **Interstitial** → name "Between levels" → copy the id.
   * **Rewarded** → name "Free coins" → reward amount 1, reward item "coins" (the game decides the real amount) → copy the id.
   Ad unit ids look like `ca-app-pub-1234567890123456/1234567890` (note the **/**).
5. **Link to Google Play** (if you did not in step 2): *Apps → your app → App settings → App info → pencil icon → link to the store*. The link cannot be changed later.
6. **Consent message for Europe (important):** *Privacy & messaging → European regulations → Create message*, choose your app, publish it.
   Without it, players in the EU/UK may get no ads. (Optional: also create the "US states regulations" message.)
7. **Blocking controls (optional but recommended):** *Blocking controls → Ad content* → block categories you don't want next to a family-friendly fish game (e.g. dating, gambling, alcohol).
8. **Test device (optional):** *Settings → Test devices → Add* with your phone's **Advertising ID** (Android *Settings → Google → Ads* shows it). Then even real ads show as test ads on your phone.
9. **app-ads.txt (optional):** only needed if your Play listing shows a developer website. Then publish the file AdMob gives you at the root of that site.

---------------------------------------------------------------------------------------------------

## 4. Install the plugin and set your App ID (needs the Godot editor on your PC)

The plugin is **"AdMob" by Poing Studios, version 5.x** (free, MIT). (Version 5 changed a lot from version 4; this project is written for version 5.)

**Order matters (otherwise you overwrite your own settings):**

1. **First** upload the v1.2 update files to GitHub (see `CHANGES.md`, section 1), including `project.godot`. Then download your repository (Code → Download ZIP) or keep your local folder in sync.
2. Install the **Godot 4.7.x editor** (standard version, not .NET) from godotengine.org (a zip you just unpack; no installer).
3. In Godot: **Import** → select `project.godot` of your project.
4. Top tab **AssetLib** → search **AdMob** (Poing Studios) → **Download → Install** (install everything).
5. **Project → Project Settings → Plugins** → tick **AdMob** (Enable).
6. **Project → Project Settings → General** → turn on *Advanced Settings* (top right) → find the **AdMob** section → **Android**:
   tick *Enabled* and paste your **App ID** (with the ~).
   While testing you may use Google's test App ID `ca-app-pub-3940256099942544~3347511713`.
7. Save. **Upload the new `addons` folder (all of it) and the changed `project.godot` to GitHub.** Do not upload the hidden `.godot` folder.
   The Android part of the plugin is downloaded automatically by the GitHub build (the plugin does this when it runs without a screen).
   If you want to run/export on your own PC, use the plugin's menu *Project → Tools → AdMob Manager* to download it.

When the build finds `addons/admob`, it automatically: copies `ads/admob_backend.gd.txt` to `scripts/admob_backend.gd`, switches on the internet permission, and builds with Gradle. Nothing else for you to do.

---------------------------------------------------------------------------------------------------

## 5. Test with TEST ads first (the default)

`scripts/ad_config.gd` ships with `USE_TEST_ADS := true`. Build in GitHub Actions and install the **APK** on your phone.
Test ads have a "Test Ad" label.

1. **Startup ad:** appears from the 3rd launch. To see it sooner, set `STARTUP_AD_FROM_LAUNCH := 1` temporarily (set it back to 3 before releasing).
   Close the game completely (swipe it away) and open it again. You should see the loading screen, then the ad, then the menu.
2. **Between levels:** win level 3 (or set `FIRST_AD_LEVEL := 1` while testing), tap *Next Level* → full-screen ad → the next level starts when you close it.
3. **Rewarded:** on the win screen tap *Watch ad: double coins*; in the main menu and shop tap *Free coins*. Watch to the end → coins are added.
   Close early → no coins.
4. Europe: with a VPN or a test device you may see the consent form on first start (only if you published the message in section 3.6).

If nothing shows: see section 11 (Troubleshooting).

---------------------------------------------------------------------------------------------------

## 6. Go live with real ads

1. In `scripts/ad_config.gd`: paste your **3 real ad unit ids** and set **`USE_TEST_ADS := false`**.
2. In Godot Project Settings → AdMob → Android: your **real App ID** (not the test one). Upload `project.godot` again.
3. **Release build:** push a tag such as `v1.2.0` on GitHub (or run the workflow). Builds for tags **stop with an error** if test ads or the test App ID are still in, so you cannot ship them by accident.
4. Download the **AAB** from the finished build and upload it in Play Console (section 7).
5. New ad units can take up to an hour (sometimes longer) to start filling. AdMob also reviews new apps, so real ads may be sparse for the first days.
   Do not tap them to check. Use your test device (section 3.8) if you want to see real ad formats safely.

---------------------------------------------------------------------------------------------------

## 7. Update Google Play Console BEFORE you submit the version with ads

If you skip these, Google can reject the update or remove the app.

**Policy and programs → App content:**
1. **Ads:** change to **"Yes, my app contains ads"**.
2. **Advertising ID:** "Yes", purposes: **Advertising or marketing** (and Analytics). The ads SDK adds the `AD_ID` permission by itself.
3. **Data safety → Manage → edit.** The app now **collects and shares** some data with Google (AdMob). Follow Google's own table for the AdMob SDK:
   <https://developers.google.com/admob/android/privacy/play-data-disclosure>.
   In short, declare as *collected* and *shared* (purposes: Advertising or marketing, Analytics, Fraud prevention, security and compliance):
   **Device or other IDs** (advertising ID) · **Approximate location** (from IP address) · **App interactions** · **Diagnostics** (crash logs, performance).
   Data is encrypted in transit: yes. Your own game still stores nothing but progress on the phone.
4. **Target audience and content:** keep ages **13+**. Re-answer the **content rating questionnaire** (mention ads, no real-money purchases).
5. **Privacy policy URL:** the policy must now describe ads. Use `PRIVACY_POLICY_WITH_ADS.md`. On GitHub Pages: replace the content of `docs/privacy-policy.html`
   with `docs/privacy-policy-with-ads.html` at the moment you release (same URL, new text). Open the page and check it.
6. **Store listing:** use `store/store_listing_with_ads.md` (says "contains ads", 300 levels, 17 fish). Google shows the "Contains ads" label automatically.

**Release:** *Test and release → Production (or your testing track) → Create new release* → upload the AAB → release notes (in the listing file) → review → roll out.
Version code goes up automatically with each build.

---------------------------------------------------------------------------------------------------

## 8. After it is live

* AdMob → *Apps*: check the app shows as **linked** and has no warnings (*Policy center*).
* Watch *Reports*: impressions, eCPM, match rate. Ads can take days to ramp up.
* In Play Console watch **ratings and reviews**. Many complaints about ads = lower the frequency (section 9).
* Keep the Data safety form, privacy policy and store text in sync with the app whenever you change anything about ads.

---------------------------------------------------------------------------------------------------

## 9. Change how often ads appear: `scripts/ad_config.gd`

| Setting | Meaning | Default |
|---|---|---|
| `USE_TEST_ADS` | true = Google test ads; **false for release** | true |
| `REAL_APP_OPEN`, `REAL_INTERSTITIAL`, `REAL_REWARDED` | your real ad unit ids | placeholders |
| `STARTUP_AD_FROM_LAUNCH` | startup ad only from this launch number on | 3 |
| `STARTUP_MAX_WAIT_SEC` | loading screen waits at most this long for the ad | 4.0 |
| `INTERSTITIAL_EVERY_N_WINS` | 1 = after every level, 2 = every second level, … | 1 |
| `INTERSTITIAL_MIN_GAP_SEC` | minimum seconds between two full-screen ads | 60 |
| `FIRST_AD_LEVEL` | no between-level ads before this level | 3 |
| `REWARDED_COOLDOWN_SEC` | wait between rewarded videos | 15 |
| `FREE_COINS_BASE`, `FREE_COINS_PER_LEVEL` | free-coins reward = base + per_level × unlocked level | 100, 1.0 |

Where in the code: `scripts/ad_service.gd` (rules), `scripts/splash.gd` (startup), `scripts/game.gd` (`_next_level`, `_on_double_coins`), `scripts/shop.gd` and `scripts/main_menu.gd` (free coins).

---------------------------------------------------------------------------------------------------

## 10. Rules that protect your account

* Don't tap your own ads or encourage clicks. Don't put ads where players tap by accident (the game never shows ads during play).
* Rewarded videos must be optional and pay the reward only after completion (the code does exactly that).
* The startup ad is an *App Open* ad shown on a loading screen with your logo, as Google recommends. Don't show normal interstitials at launch.
* Keep privacy policy, Data safety and the real behaviour of the app consistent.
* If AdMob limits ad serving ("invalid traffic"), contact AdMob support. Don't create another account.

---------------------------------------------------------------------------------------------------

## 11. Troubleshooting

| Problem | Likely reason and fix |
|---|---|
| The build says "plugin is not ENABLED" | In Godot: Project Settings → Plugins → tick AdMob, upload `project.godot`. |
| No ad buttons anywhere | The plugin/backend is not active. Check the build log for "building WITH ads", the plugin is in `addons/admob`, and that you installed the **APK/AAB built after** adding it. |
| Buttons say "Loading ad…" forever | No internet, wrong ad unit id, or AdMob has no ad yet. With test ads this should work within seconds. Check section 6.5 for real ids. |
| No startup ad | It starts from the 3rd launch, needs an ad within 4 s, and not on every device/time. For testing set `STARTUP_AD_FROM_LAUNCH := 1`. |
| Need to see the plugin's messages | Connect the phone (USB debugging) and run `adb logcat -s godot` and send me the lines. |
| Build fails after adding the plugin | Send me the last 40 lines of the failing step. The Android SDK versions may need an update. |

---------------------------------------------------------------------------------------------------

## 12. Honest limits of this delivery

* I could not run Godot or the plugin here, so **the ad code is untested on a device**. It follows the plugin's version 5 documentation (checked method by method).
  **Test with test ads and send me any error text** before you publish.
* A bad plugin call would make the ads switch off (the game still works). It would not crash the game.
* Plugin versions change. If AssetLib offers a newer major version than 5.x, tell me before upgrading.
* No ads are shown on a PC or in the editor. Only on an Android phone.
