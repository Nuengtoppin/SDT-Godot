#!/bin/sh
# Parse-checks every GDScript file in the project (first error per file) without running the game.
cd "$(dirname "$0")/../game" || exit 1
GODOT=${GODOT:-godot}  # path to the Godot 4.7 binary
# One Godot start per file: its log file goes to the temp folder (Godot keeps the last few there), or the
# player's logs in the user data folder would be rotated away.
LOG=${TMPDIR:-/tmp}/sdt-check-godot.log
command -v cygpath > /dev/null && LOG=$(cygpath -m "$LOG")
for f in $(find flash src scenes debug -name '*.gd' 2>/dev/null); do
	out=$("$GODOT" --headless --path . --log-file "$LOG" --check-only -s "res://$f" 2>&1 | grep -A1 'SCRIPT ERROR' | grep -v '^--$' | head -2)
	if [ -n "$out" ]; then
		echo "$out" | paste - - | sed 's/SCRIPT ERROR: //; s/\s*at: GDScript::reload//'
	fi
done
