#!/usr/bin/env bash
# Opens every scene headless for ~2 seconds and fails if Godot prints script errors.
# Usage (from the project folder):  GODOT=godot ./tools/smoke_test.sh
GODOT="${GODOT:-godot}"
status=0
$GODOT --headless --path . --import >/dev/null 2>&1
for scene in main_menu level_select shop game; do
  echo "== $scene"
  out=$($GODOT --headless --path . --quit-after 120 "res://scenes/$scene.tscn" 2>&1)
  echo "$out" | tail -n 5
  if echo "$out" | grep -Eq "SCRIPT ERROR|Parse Error|Failed to load script"; then
    echo "!! errors found in $scene"; echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Failed" ; status=1
  fi
done
$GODOT --headless --path . -s tests/test_rules.gd || status=1
exit $status
