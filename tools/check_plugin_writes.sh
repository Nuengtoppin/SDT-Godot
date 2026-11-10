#!/bin/sh
# Lists lines in plugins (Mods/Plugins, or the folders given, e.g. game/src/ext for the built-in extensions) that write the game's state directly: `her.x = ...`,
# `g.her.x *= ...`, `him.x += ...`, `g.x = ...`. Ported mods should change the game through value points (modify),
# hook vetoes and the game's own methods instead, so that extensions combine and the game's easing still applies
# (docs/extensions.md, Value points). A write that is meant (an event's one-off impulse, the game's own state machine
# with no method for it) is marked on its line with a comment "# direct: <why>" and is not listed.
# Heuristic: writes through other names (var ik = her.rightArmIK; ik.x = ...) are not found.
cd "$(dirname "$0")/.." || exit 1
[ $# -eq 0 ] && set -- Mods/Plugins
grep -rnE --include='*.gd' \
	'(^|[^A-Za-z0-9_.])(g|her|him)\.[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*|\[[^]=]*\])*[[:space:]]*([-+*/]?=)[^=]' \
	"$@" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -v '# direct' | sed 's/^/plugin write: /'
