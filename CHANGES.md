# Version 1.2 – what changed and what YOU have to do

This update starts from your live version 1.1 (no ads) and adds:

1. **Coins for eating fish** – bigger fish give more coins.
2. **17 fish to buy in the Fish Shop** – from a guppy to a shark and a **baby whale** (plus more skins, patterns, trails and extras). Coins only, **no in-app purchases**.
3. **Ads, ready to switch on** – a startup ad, an ad between levels, and optional rewarded videos for more coins. They stay **off** until you add the AdMob plugin (see `ADS_GUIDE.md`).
4. A loading screen at start (the place where the startup ad is shown).

You can release this version **without ads first** (nothing in Play Console changes) and switch the ads on later. That is what I recommend, see section 6.

---

## 1. Put the update on GitHub

1. Unzip `FishEvolution-v1.2-changed-files.zip`.
2. GitHub → your repository → **Add file → Upload files** → drag the **contents** of the unzipped folder (the folders `scripts`, `scenes`, `tests`, `tools`, `ads`, `store`, `docs` and the loose files). Same-named files are replaced. Commit.
3. The hidden folder **`.github/workflows/build-apk.yml`** may not upload by drag-and-drop. If you don't see it changed on GitHub, open that file on GitHub → pencil icon → replace everything with the text of the separate `build-apk.yml` I gave you → commit.
4. Check that `scripts` now has **26 files** (it had 23) and `scenes` has **6** (`splash.tscn` is new).
5. **Actions → Build Android → Run workflow**. Install the APK and test (section 7). Then upload the new AAB to Play Console as an update (same steps as before).

The build says "No AdMob plugin in this repository - building WITHOUT ads." – that is correct for now.

Players keep their progress, coins and bought designs. Everyone starts with the free fish "Goldie".

### Files in the update
**New (10):** `scenes/splash.tscn`, `scripts/splash.gd` (loading screen), `scripts/ad_config.gd`, `scripts/ad_service.gd`, `ads/admob_backend.gd.txt` (the ads, inactive until the plugin is added),
`ADS_GUIDE.md`, `PRIVACY_POLICY_WITH_ADS.md`, `docs/privacy-policy-with-ads.html`, `store/store_listing_with_ads.md`, `tools/render_species_preview.py`.

**Changed (15):**
| File | What changed |
|---|---|
| `scripts/game_state.gd` | 17 fish species, coin rule, shop categories (Fish added), launch counter, "Natural" colours logic |
| `scripts/fish_art.gd` | Drawing of all fish shapes: tails, fins, swordfish bill, hammer head, anglerfish lure, dolphin beak, whale spout, ray body… |
| `scripts/game.gd` | Coins for eating (+ popup), ad hooks (between levels, double coins) |
| `scripts/shop.gd` | Tabs for Fish/Skins/…, pages of 8, "Owned x of y", prices with commas, free-coins button |
| `scripts/main_menu.gd` | "Free Coins" item, privacy-settings button, "How to Play" text, About text (v1.2.0) |
| `scripts/hud.gd` | "Double coins" button, tutorial text |
| `scripts/player.gd`, `scripts/fish_preview.gd` | Draw the chosen fish species |
| `project.godot` | Start scene = loading screen; AdService registered |
| `export_presets.cfg` | Version name 1.2.0 |
| `.github/workflows/build-apk.yml` | Switches to "with ads" automatically when the plugin is present; blocks release builds with test ads |
| `scripts/screenshot_tool.gd`, `tests/test_rules.gd`, `store/store_listing.md` | Updated for the new features |

---

## 2. Coins from eating (what you asked for)

* Coins per fish = **size x 0.15**, at least 1. Small fish ~2 coins, medium ~4-5, big predators ~10-18. Shown as a gold "+N coins" popup and in the counter.
* Plus the old coin groups in the water and the level bonus. The level-complete screen shows the total; with ads on, "Watch ad: double coins" doubles it.
* Change the rate: `COIN_PER_SIZE` in `scripts/game_state.gd` (0.15). Double it = twice the coins.

## 3. The Fish Shop

**Tabs:** Fish · Skins · Patterns · Trails · Extras. Tap an item to preview it on the big fish, then Buy / Equip. 8 items per page, "Owned 3 of 17" counter.
The old skin "Goldie" is now called **"Natural"** = *use the fish's own colours*. Buy a skin to override the colours of any fish.
Fish are cosmetic: every fish has the same size rules, speed and hit-box, so the game stays fair.

### The 17 fish
| Fish | Price | ~Level you can afford it* | Look |
|---|---|---|---|
| Goldie | free | 1 | round goldfish (starter) |
| Guppy | 400 | 4 | small, big pink fan tail |
| Clownfish | 700 | 9 | orange with white bands |
| Pufferfish | 1,000 | 15 | round and spiky |
| Angelfish | 1,500 | 23 | tall disc with long fins |
| Koi | 2,200 | 34 | red with white spots |
| Stingray | 3,000 | 46 | diamond body, whip tail |
| Swordfish | 4,000 | 59 | long bill, sail fin |
| Piranha | 5,000 | 74 | red belly, teeth, angry eyes |
| Anglerfish | 6,500 | 89 | glowing lure, teeth |
| Dolphin | 9,000 | 107 | beak, curved fin |
| Shark | 12,000 | 128 | grey shark |
| Hammerhead | 16,000 | 152 | T-shaped head |
| Orca | 22,000 | 181 | black and white |
| Narwhal | 30,000 | 215 | long tusk |
| Baby Whale | 40,000 | 252 | big, cute, water spout |
| Golden Whale | 75,000 | after 300 | the legendary prize |

\* If a player buys the fish in this order and plays each level once. It is an **estimate**, assuming a player eats about 35% of small fish, 30% of medium and 15% of big fish and collects 70% of the coins.
Average coins per level: about 130 at level 1, 285 at level 50, 510 at level 100, 900 at level 200, 1,400 at level 300. Replaying levels and watching optional ads make it faster.
Total of all items: about 235,000 coins, so there is a long goal to keep players coming back.

### Change prices or add a fish
* **Prices:** `shop_items` in `scripts/game_state.gd` – change the `"price"` number.
* **A new fish:** copy one `sp_...` line in `shop_items`, give it a new `"id"` (starting with `sp_`), a `"name"`, a `"price"`, three colours and a `"spec"`.
  The `spec` options (tail, fin, nose, teeth, bands…) are listed in the comment at the top of `scripts/fish_art.gd`.
  Examples: `{"base": 1, "bx": 1.2, "nose": "bill", "tail": "crescent"}`. Keep `bx` between 0.8 and 1.45 so it fits the game's hit-box.
* **See all fish without running the game:** `python3 tools/render_species_preview.py scripts/game_state.gd sheet.png` (needs `pip install pillow`).
  This preview uses a Python copy of the drawing code, so tiny differences to the real game are possible.

---

## 4. Ads (all in `ADS_GUIDE.md`)
Summary: startup ad (3rd launch on), ad between levels (after every level you finish, when you tap Next Level), optional rewarded videos (double coins, free coins in menu and shop).
Everything is adjustable in `scripts/ad_config.gd`. Setup, Play Console changes, privacy policy, testing and troubleshooting are in the guide.

---

## 5. Things I could not test (honest list)
* I cannot run Godot here. The code is checked statically and the fish drawing was checked by rendering a Python copy, but **nothing has been seen on a phone**.
* **The ads code is completely untested** with the real plugin. It follows the plugin's version 5 documentation. Test with test ads first and send me any error.
* With 17 fish and long levels, check performance on an older phone (level 100+).

## 6. Two ways to release
**A) Recommended – release now without ads:** upload the AAB as an update. No Play Console changes needed (still "no ads"). Players get coins from eating and the new shop. Add ads later as version 1.3 using `ADS_GUIDE.md`.
**B) Ads straight away:** first finish AdMob setup, plugin and Play Console changes (`ADS_GUIDE.md` sections 3-7), then release once.

## 7. Test checklist
1. Start the game: logo screen for about a second, then the menu.
2. Eat fish: a gold "+N coins" popup appears, the coin counter rises. Bigger fish give more.
3. Fish Shop: five tabs; Fish tab shows pages ("Page 1 / 3"); preview a Shark or the Baby Whale; "Need N more coins" when short; buy and equip with enough coins (to test quickly, play a few levels).
4. Your chosen fish is used in the game, in the preview, and keeps its look after restarting the game.
5. Old players: coins and unlocked levels are still there; the fish is Goldie.
6. Everything from version 1.1 still works (scrolling menu, animations, checkpoints).
7. With the ad plugin later: follow `ADS_GUIDE.md`, section 5.
