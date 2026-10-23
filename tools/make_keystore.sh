#!/usr/bin/env bash
# Creates the signing keys for your APK. Run ONCE and keep the files + passwords safe:
# you need the SAME release key for every future update of your game.
set -e
command -v keytool >/dev/null || { echo "Install a JDK (17+) first"; exit 1; }
read -rsp "Choose a password for the release key (min 6 chars): " PASS; echo
keytool -genkeypair -v -keystore release.keystore -alias fishkey -keyalg RSA -keysize 2048 \
  -validity 10000 -storepass "$PASS" -keypass "$PASS" -dname "CN=Fish Evolution,O=Your Name,C=US"
# Debug key (only for testing from the Godot editor)
[ -f debug.keystore ] || keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey \
  -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android \
  -dname "CN=Android Debug,O=Android,C=US"
echo
echo "Created release.keystore (alias: fishkey) and debug.keystore."
echo "For GitHub Actions, add these repository secrets:"
echo "  ANDROID_KEYSTORE_BASE64 = $(base64 -w0 release.keystore | cut -c1-20)...  (run: base64 -w0 release.keystore)"
echo "  ANDROID_KEYSTORE_ALIAS  = fishkey"
echo "  ANDROID_KEYSTORE_PASSWORD = (the password you just typed)"
