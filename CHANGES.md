# Version 1.1 – what changed and what YOU should change

This update starts from your current game (the version without ads) and adds:

1. **A scrolling main menu** (swipe the options up and down).
2. **A satisfying "gulp" animation** when you eat a fish, with combos, rings, sparkles and screen kick.
3. **A dramatic defeat animation** when you are eaten (slow motion, lunge, screen shake and flash, X-eyes).
4. **200 new levels:** 300 levels in 30 worlds in total.
5. **Much longer levels** (about 45 seconds at level 1, up to about 3 minutes at level 300), with **checkpoint flags** so a long level is not unfair.

> About "length": your message said "the length of running is very short. I want to make it short". I understood that you want the levels **longer**.
> If you really wanted them even shorter, see section 3 (one number to change).

---

## 1. How to put this update on GitHub

### Easy way (recommended): upload the CHANGED FILES zip
1. Unzip `FishEvolution-v1.1-changed-files.zip` on your PC. You get folders `scripts`, `tests`, `store`, `docs`, `tools` and a few files.
2. Open your repository on GitHub → **Add file → Upload files**.
3. Drag the **contents** of the unzipped folder onto the page (the folders `scripts`, `tests`, … and the loose files). GitHub keeps the folder structure and **replaces** same-named files.
4. Commit. Then check that the `scripts` folder now has **23 files** (it had 21; two are new: `scroll_menu.gd` and `checkpoint_flag.gd`).
5. **Actions → Build Android → Run workflow.** Install the new APK on your phone and test it (checklist in section 6).

### Safest way: replace everything
Upload the whole `FishEvolution-OceanRun-project.zip` content the same way. Both ways give the same result.

### Files in the update
**New files (3):**
| File | What it is |
|---|---|
| `scripts/scroll_menu.gd` | The finger-scrollable menu list |
| `scripts/checkpoint_flag.gd` | The checkpoint flags in the sea |
| `CHANGES.md` | This document |

**Changed files (17):**
| File | What changed |
|---|---|
| `scripts/game_state.gd` | 300 levels, 30 worlds, level length, harder levels 101-300, checkpoint settings, fewer coins per km |
| `scripts/game.gd` | Eat animation + combo, defeat animation + slow motion, shake, checkpoints, "continue", new speed-bonus rule, flags |
| `scripts/player.gd` | Defeat animation (spin, X-eyes, fade), revive |
| `scripts/fish.gd` | "Gulp" animation, predator lunge, per-level chase and rest times |
| `scripts/fish_art.gd` | X-eyes for a defeated fish |
| `scripts/fx.gd` | Shock-wave rings, sparkles, bigger pop-up text |
| `scripts/audio_manager.gd` | New "crunch" sound, pitch control (combos get higher) |
| `scripts/hud.gd` | Screen flash, "Continue from checkpoint" button, new texts |
| `scripts/main_menu.gd` | Scrolling list menu, "How to Play" and "Exit Game" items |
| `scripts/level_select.gd` | 30 pages, "<<" and ">>" jump buttons |
| `scripts/screenshot_tool.gd`, `tools/caption_screenshots.py` | "300 levels" wording |
| `tests/test_rules.gd` | Tests for 300 levels, rest times, level length, checkpoints |
| `export_presets.cfg` | Version name 1.1.0 |
| `store/store_listing.md`, `docs/index.html`, `README.md` | "300 levels / 30 worlds" wording and new features |

Your **saved progress stays**: unlocked levels, coins and bought designs keep working.

---

## 2. What you can change (one place for each thing)

### Levels – `scripts/game_state.gd`
| Constant / line | What it does | Default |
|---|---|---|
| `TOTAL_LEVELS` | How many levels exist | 300 |
| `LEVEL_LENGTH_SCALE` | **Multiplier for every level's length.** 0.5 = half as long, 2.0 = twice as long | 1.0 |
| `LEVEL_LENGTH_BASE`, `LEVEL_LENGTH_PER_LEVEL` | Length = (base + level x per-level) x scale, in pixels | 9000, 110 |
| `CHECKPOINT_FRACTIONS` | Where the flags stand (0.25 = a quarter of the way) | 0.25, 0.5, 0.75 |
| `CONTINUES_PER_ATTEMPT` | How many times you may continue from a flag per attempt | 3 |
| `COIN_GROUPS_PER_KM` | Coins (groups of 5) per 1000 px | 1.0 |
| `get_level_config()` | All difficulty numbers (fish per km, predator speed, jellyfish, rocks, tiredness) | see file |
| `_ensure_themes()` | The names of worlds 11-30 and how their colours are made | see file |

Speed of the fish is about 200-300 pixels per second, so **length / 200 = seconds**.
Examples: level 1 = about 46 s, level 100 = about 100 s, level 300 = about 210 s.

### How hard levels 101-300 are
`get_level_config()` has two ramps: `t` (levels 1-100, unchanged) and `u` (levels 101-300). Everything with `* u` is the extra difficulty:
more predators and medium fish, longer-sighted predators, more jellyfish and rocks, **longer chases** (`chase_time` 5 to 8 s) and **shorter rests** (`rest_time` 2.5 to 1.2 s).
Fairness rules that are always kept: predators are never faster than 200 px/s (the player is at least 200), always get tired, and never exceed size 120.
If you change these numbers, run the tests (`tools/smoke_test.sh` or the workflow) – they check these rules.

### Animations
| What | Where | What to tweak |
|---|---|---|
| Eating: gulp, ring, sparkles, popup | `game.gd` → `_eat()`; `fish.gd` → `swallow()` (`SWALLOW_TIME`) | more/less `fx.sparkles(...)` count, ring size, `_shake` strength |
| Combo | `game.gd` → `_eat()` (`_combo_timer = 1.6` = seconds to keep a combo, bonus = 5 per step) | window and bonus |
| Getting eaten | `game.gd` → `_lose()` | `Engine.time_scale = 0.35` (slow motion), `_slowmo = 0.7` (how long), `_shake = 18.0`, flash colour, `_end_delay = 1.6` |
| Predator lunge | `fish.gd` → `chomp()` / `_lunge_step()` | lunge speed (520) and time (0.3) |
| Defeated fish spin and fade | `player.gd` → `_process()` / `_draw()` | spin speed `death_t * 6.5`, fade timing |
| Screen flash | `hud.gd` → `flash()` | called from `game.gd` with colour, strength, seconds |
| Rings / sparkles / popups | `fx.gd` | `ring()`, `sparkles()`, `popup()` |
| Sound of being eaten | `audio_manager.gd` → `_chomp()` | length and noise level |

### Menu – `scripts/main_menu.gd` and `scripts/scroll_menu.gd`
* Add an option: in `_build_main()` add `list.add_item("My option", _on_my_option)` and write the function `_on_my_option()`.
* Change the order: reorder the `list.add_item(...)` lines.
* Look: in `scroll_menu.gd` change `item_w`, `item_h`, `gap`, `font_size`, `ITEM_COLOR`. The list is 480 x 470 px in `_build_main()` (`list.custom_minimum_size`).
* Scrolling feel: `DEADZONE` (how far a finger must move to count as a swipe), the glide in `_process()`.

---

## 3. Make levels shorter or longer – the quick answer
Open `scripts/game_state.gd` and change **one number**:
```
const LEVEL_LENGTH_SCALE := 1.0     # 0.6 = shorter levels, 1.5 = longer levels
```
Upload the file, run the build. Nothing else needs to change (checkpoints, coins and speed bonus adapt automatically).

## 4. New game rules explained
* **Checkpoints:** flags at 25 %, 50 % and 75 % of every level turn green when you pass them. If a predator eats you after you passed a flag, the lose screen offers
  **"Continue from checkpoint"** (3 times per attempt). You come back at the flag with the size you had there, protected for 2.5 seconds, and nearby predators are moved away.
  **"Retry level"** always starts the level from the beginning. Coins you collected are always kept.
* **Combo:** eat another fish within 1.6 seconds to build a combo: +5 points per step, a bigger popup and a higher "eat" pitch.
* **Speed bonus** at the finish: uses a "par time" of length / 200 seconds, 4 points per second saved.
* **Coins:** fewer groups per km, because levels are longer, so coins per level are about the same as before at the start and grow later.

## 5. Things I could not test (honest list)
* I cannot run Godot here. The code is statically checked and the difficulty numbers are verified for all 300 levels, but the **animations and the scrolling menu have not been seen on a real device**.
* Scrolling is my own code (not Godot's built-in scroll container) so that dragging never presses a button by accident. On a phone: swipe the list. On a PC: mouse drag or wheel.
* Very long levels create about 900 fish and 250 jellyfish at level 300. Only those near you are active, so it should be smooth, but please test a high level on an older phone.
  If it is slow, lower `LEVEL_LENGTH_SCALE` or the densities in `get_level_config()` and tell me.

## 6. Test checklist after the build
1. Main menu: the list scrolls up/down by finger; tapping an item opens it; no item opens when you drag.
2. Eat a fish: it spins into your mouth, ring + sparkles + "+points"; eat several quickly: "COMBO xN".
3. Get eaten: slow motion, shake, red flash, predator lunges, your fish spins belly-up with X-eyes; then the lose screen.
4. Pass a flag (it turns green, "Checkpoint saved!"), get eaten, tap **Continue from checkpoint**: you restart at the flag and are protected for a moment.
5. Level 1 takes roughly 45-60 seconds. Level select shows 30 pages ("World 1 of 30") and the `<<` `>>` buttons work.
6. Levels 101+: new world names/colours (e.g. "Tropical Lagoon"). Check one on a weaker phone.
7. Your old progress, coins and bought designs are still there.

## 7. Releasing on Google Play
Nothing changes in the Play Console steps. Upload the new `.aab` (the version code goes up automatically) as a new release.
You may refresh the store text with `store/store_listing.md` (now says 300 levels / 30 worlds and mentions checkpoints and combos).
The privacy policy stays the same (still no ads, no data collected).

## 8. Ads (optional, later)
The ads kit is parked in `optional_ads/` (not used by the game). When you want ads, tell me and I will apply them on top of this version.
