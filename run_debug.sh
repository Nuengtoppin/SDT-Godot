#!/usr/bin/env bash
# Launches the game with the debug build (Godot editor binary + debug native extension); Linux counterpart of
# run_debug.bat. The log goes to this terminal and to ~/.local/share/godot/app_userdata/SDT Godot/logs/godot.log.
# Extra arguments are passed to Godot, e.g.  ./run_debug.sh --verbose
# Godot: the GODOT environment variable, else run_debug.local.sh next to this file (not in git; it can contain e.g.
# GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64), else godot on PATH.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${GODOT:-}" ] && [ -f "$here/run_debug.local.sh" ]; then
	. "$here/run_debug.local.sh"
fi
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot was not found (\"$GODOT\")."
	echo "Install Godot 4.7.2 and create run_debug.local.sh next to this file containing:"
	echo "    GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64"
	echo "(see README.md)."
	exit 1
fi

game="$here/game"
marker="$game/.godot/sdt_import_done"
# First run after downloading: Godot imports the assets once (a few minutes) before the game can start. The marker
# is written only after a complete import, so an interrupted import is redone.
if [ ! -f "$marker" ]; then
	echo "First run: importing the game assets, this takes a few minutes..."
	if ! "$GODOT" --headless --path "$game" --import; then
		echo "The asset import failed; see the messages above."
		exit 1
	fi
	touch "$marker"
# After an update (git pull, new download): scripts newer than the marker may add classes, which Godot only
# registers during an import. A quick import (a few seconds) does that.
elif [ -n "$(find "$game/src" "$game/flash" "$game/scenes" "$game/debug" -name '*.gd' -newer "$marker" -print -quit 2>/dev/null)" ]; then
	echo "Scripts changed since the last import: updating..."
	"$GODOT" --headless --path "$game" --import >/dev/null 2>&1
	touch "$marker"
fi
exec "$GODOT" --path "$game" "$@"
