#!/bin/sh
# Rescans the Godot project (updates the global class cache) and prints script errors.
cd "$(dirname "$0")/../game" || exit 1
GODOT=Godot_v4.7.2-stable_win64_console.exe
timeout 600 "$GODOT" --headless --path . --import 2>&1 | grep -E -A1 'SCRIPT ERROR|Parse Error|Compile Error' | grep -v '^--$'
timeout 300 "$GODOT" --headless --path . --quit 2>&1 | grep -E -A1 'SCRIPT ERROR|ERROR: Failed' | grep -v '^--$'
exit 0
