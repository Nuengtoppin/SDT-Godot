#!/bin/sh
# Parse-checks every GDScript file in the project (first error per file) without running the game.
cd "$(dirname "$0")/../game" || exit 1
GODOT=${GODOT:-godot}  # path to the Godot 4.7 binary
for f in $(find flash src scenes debug -name '*.gd' 2>/dev/null); do
	out=$("$GODOT" --headless --path . --check-only -s "res://$f" 2>&1 | grep -A1 'SCRIPT ERROR' | grep -v '^--$' | head -2)
	if [ -n "$out" ]; then
		echo "$out" | paste - - | sed 's/SCRIPT ERROR: //; s/\s*at: GDScript::reload//'
	fi
done
