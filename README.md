# Fish Evolution: Ocean Run

A 2D underwater survival game for Android, made with **Godot 4.7 + GDScript**.
Eat smaller fish and **grow bigger with every bite**, dodge predators and jellyfish, collect coins, and swim to the finish wall.
**100 levels in 10 underwater worlds**, a **Fish Shop** for fish designs, fully offline, no ads, no data collection.

> **Build status (please read):** the project was written and statically checked but **has not yet been opened in Godot or compiled**
> (the authoring environment had no Godot, no Android SDK and no internet). Step 1 builds it in the cloud and runs the included tests.
> If Godot reports a script error, send me the message and I will fix it.

## Quick start
1. Create a free GitHub account + new repository, upload everything in this folder (keep the `.github` folder).
2. **Actions** tab → *Build Android* → **Run workflow** (~10 min).
3. Download artifact `FishEvolution-builds`: `…apk` (install on your phone to test) and `…aab` (the file Google Play wants).

**Publishing on Google Play:** follow `PLAY_STORE_GUIDE.md`. Store text/graphics are in `store/`. Google Play now requires AAB + target API 36;
this project uses Godot 4.7.2 which provides that.

## What's new in this version
* **Growth:** every fish you eat adds 25 % of its size, with a visible "boing" and a gentler camera zoom, so you really see yourself getting bigger.
* **Coins:** groups of 5 coins float in every level (some near predators). Finishing a level adds a bonus. Coins are kept even if you lose.
* **Fish Shop** (main menu or win screen): Skins (8, incl. animated Rainbow), Patterns (stripes, spots, scales, gold scales), Trails (pink bubbles, gold dust, rainbow sparkles) and Extras (sunglasses, crown). Tap to preview, then Buy / Equip.
  Add your own items in `scripts/game_state.gd` → `shop_items`.

## Install / test on your phone
Copy the `.apk` to the phone and tap it → allow "Install unknown apps" → Install. (Or `adb install FishEvolution-OceanRun.apk`.)

## Free sharing outside Google Play
Push a tag (`git tag v1.0.0 && git push --tags`) and the APK + AAB appear in GitHub Releases.
Enable GitHub Pages (Settings → Pages → `main` / `/docs`) for a download page and the privacy-policy URL.

## Privacy policy
`PRIVACY_POLICY.md` / `docs/privacy-policy.html` (contact: kainavako@gmail.com): the game collects nothing, has no ads, no internet, no purchases with real money.
The build requests no Android permissions; the workflow log prints the final list so you can verify it.
Saved on the device only: levels, scores, coins, unlocked designs, settings.

## Run / edit in Godot (optional)
Install **Godot 4.7.x** (standard, not .NET) → Import `project.godot` → F5. Mouse drag = joystick, arrow keys also work, Esc = pause.
Headless checks: `./tools/smoke_test.sh`. Regenerate icons/graphics: `python3 tools/make_graphics.py`.

## Game rules (all tunable in `scripts/game_state.gd`)
| Rule | Value |
|---|---|
| You eat a fish if it is smaller than | your size × 0.85 |
| A fish eats you if it is bigger than | your size × 1.15 |
| Growth per fish eaten | 25 % of its size (max size 120) |
| Bigger = slower | down to 70 % speed |
| Evolution | bigger fins at size 35, stripes at 60 |
| Rings | green = edible, red = dangerous |
| Predators | give up after 5 s, rest 2.5 s, always slower than you |
| Jellyfish (level 5+) | −12 % size + 1.6 s protection |
| Coins | ~2.2 groups of 5 per 1000 px; finish bonus 10 + level/2 |
| Score | 2 × fish size, 5 per coin, 1/sec, finish bonus 500 + 20×level, speed bonus |

**100 levels** come from one formula (`get_level_config`): level 1 is short with ~2 slow predators; level 100 is three times longer with ~38 faster, sharper-eyed predators.
Worlds (10 levels each): Sunny Shallows, Coral Reef, Kelp Forest, Deep Blue, Sunken Ship, Twilight Zone, Volcano Vents, Ice Waters, Neon Abyss, Dark Trench.

## Project layout
```
project.godot  export_presets.cfg (APK + AAB presets)  icon.svg
scenes/    main_menu, level_select, shop, game
scripts/   game_state (AUTOLOAD: save, 100 levels, shop data)   audio_manager (AUTOLOAD)
           game (level manager)  player  fish (AI)  jellyfish  coin  fx
           fish_art (drawing, patterns, accessories)  fish_preview  shop  hud  joystick  ui_theme
           main_menu  level_select  menu_bg  background  decor_chunk  finish_gate
assets/    launcher icons        store/  Play icon, feature graphic, listing text
tests/     test_rules.gd         tools/  smoke_test.sh, make_keystore.sh, make_graphics.py
docs/      download page + privacy policy (GitHub Pages)     .github/workflows/  cloud build
```

## Manual test checklist
Eating makes you visibly bigger every time · green/red rings correct · coins collected, counter rises, kept after losing ·
shop: preview, buy with enough coins, "Need N more coins" when short, equip, look appears in game, persists after restart ·
jellyfish (level 5+) · rocks · win → Next Level / Fish Shop · lose → Retry · pause/resume · Android back button · locked levels ·
music/sfx toggles persist.

## Known limitations
* Not yet compiled/play-tested (see top). Balance numbers are first guesses.
* Art and sound are generated in code (original and licence-free).
* Godot 4.7 changed some GDScript behaviours versus the 4.3 I wrote against; if the editor flags anything, send me the message.
