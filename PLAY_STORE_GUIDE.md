# Publishing Fish Evolution: Ocean Run on Google Play

Google Play (as of Oct 2026) requires **an AAB file** (not an APK) and **target API level 36**. This project is set up for both
(Godot 4.7.2, `export_presets.cfg` preset "Android AAB"). The GitHub workflow builds the AAB for you.

## 0. What you need
1. A **Google Play Developer account**: one-time US$25 fee plus identity verification at <https://play.google.com/console>.
2. A free GitHub account (to build the AAB in the cloud).
3. Rules for new personal developer accounts change over time. At the time of writing, a new personal account must run a
   **closed test with at least 12 testers for 14 days** before it can publish to production. Check the Console for the current rule.

## 1. Choose your package name (permanent!)
The app id is `com.kainavako.fishevolution` (in `export_presets.cfg`, both presets). It must be globally unique and
**can never change after your first upload**. Change it now if you want something else.

## 2. Make your upload key (once)
Run `./tools/make_keystore.sh` (needs Java). It creates `release.keystore`. Back it up somewhere safe (a lost upload key can be reset
through Play support, but it is a hassle). Then in GitHub → repo → Settings → Secrets and variables → Actions add:
`ANDROID_KEYSTORE_BASE64` (output of `base64 -w0 release.keystore`), `ANDROID_KEYSTORE_ALIAS` (`fishkey`), `ANDROID_KEYSTORE_PASSWORD`.
Without these secrets the workflow signs with a throw-away key. **Never upload such a build to Play.**

## 3. Build the AAB
Upload the project to GitHub → Actions → *Build Android* → Run workflow → download artifact `FishEvolution-builds`.
It contains `FishEvolution-OceanRun.aab` (for Play) and `FishEvolution-OceanRun.apk` (install it on your phone first and play-test!).
The version code goes up automatically on every run, as Play requires.

## 4. Create the app in Play Console
1. *Create app*: name "Fish Evolution: Ocean Run", language, **Game**, **Free**.
2. *Store listing*: paste text from `store/store_listing.md`; upload `store/play_icon_512.png`, `store/feature_graphic_1024x500.png` and 2+ phone screenshots.
3. *Policy / App content*: privacy policy URL (host `docs/privacy-policy.html` with GitHub Pages: repo → Settings → Pages → `main` branch, `/docs` folder),
   Ads = No, App access, Content rating questionnaire, Target audience, **Data safety = no data collected** (answers listed in `store/store_listing.md`).

## 5. Release
1. *Testing → Closed testing → Create track/release*. Accept **Play App Signing** when asked (Google keeps the final signing key; yours is the upload key).
2. Upload `FishEvolution-OceanRun.aab`, add release notes, save, and send for review.
3. Add your testers (email list or Google Group) and ask them to install from the opt-in link. Keep the test running as long as the Console requires.
4. Then *Production → Create release → Promote/Upload the same AAB* → send for review. First reviews can take several days.

## 6. Updating later
Change the code, push to GitHub, download the new AAB (version code is already higher), create a new release in Play Console.

## 7. Honest checklist of what is NOT verified yet
* The project has not yet been compiled or run in Godot. Run the workflow once and play the APK on a phone before submitting.
* SDK component versions in the workflow follow Godot 4.7 conventions; if the export log names a missing component, adjust the `packages:` line
  in `.github/workflows/build-apk.yml` to what the Godot 4.7 "Exporting for Android" documentation lists.
* Check the APK permission output in the workflow log: it should list none. The privacy policy and Data safety form assume that.
* Take real screenshots; Google rejects mock-ups that don't match the game.
