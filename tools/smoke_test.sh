#!/usr/bin/env bash
# Starts every screen of the game without a display for about 3 seconds each and FAILS if Godot prints script errors,
# a missing autoload or a missing file. The full output is written to build/smoke.log (the workflow uploads it).
# Usage (from the project folder):  GODOT=godot bash tools/smoke_test.sh
GODOT="${GODOT:-godot}"
mkdir -p build
LOG=build/smoke.log
: > "$LOG"
status=0
PATTERN='SCRIPT ERROR|Parse Error|Failed to load script|Failed to create an autoload|Failed loading resource|Attempt to open script|Cannot open file|Cannot load|Unable to load'

echo "== import" | tee -a "$LOG"
$GODOT --headless --path . --import >> "$LOG" 2>&1

for scene in splash main_menu level_select shop game lobby arena; do
  echo "== $scene" | tee -a "$LOG"
  out=$($GODOT --headless --path . --quit-after 180 "res://scenes/$scene.tscn" 2>&1)
  echo "$out" >> "$LOG"
  echo "$out" | tail -n 3
  if echo "$out" | grep -Eq "$PATTERN"; then
    echo "!!! ERRORS FOUND when starting $scene:"
    echo "$out" | grep -E "$PATTERN" -A2 | head -n 40
    status=1
  fi
done

echo "== game rules tests (informational, they never stop the build)" | tee -a "$LOG"
$GODOT --headless --path . -s tests/test_rules.gd >> "$LOG" 2>&1 || echo "(the rules tests reported a problem, see build/smoke.log)"
if [ $status = 0 ]; then echo "Smoke test passed: every screen starts without script errors."; fi
exit $status
