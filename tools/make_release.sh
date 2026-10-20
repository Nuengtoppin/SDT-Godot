#!/usr/bin/env bash
# Builds a Windows release: release/SDT-Godot-<date>-<commit>-windows/ and the .zip of it.
#   GODOT=<Godot 4.7.2 editor binary> bash tools/make_release.sh
# Needs the 4.7.2.stable export templates (Editor > Manage Export Templates) and the export preset in
# game/export_presets.cfg. Builds from the working tree: commit first, so the name's commit matches the contents.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PY=tools/.venv/Scripts/python.exe
[ -x "$PY" ] || PY=python3

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "warning: uncommitted changes are in this build" >&2
fi
NAME="SDT-Godot-$(date -u +%Y-%m-%d)-$(git rev-parse --short HEAD)-windows"
OUT="release/$NAME"
if [ -e "$OUT" ] || [ -e "$OUT.zip" ]; then
	echo "$OUT already exists" >&2
	exit 1
fi
mkdir -p "$OUT"

"$GODOT" --headless --path game --export-release "Windows Desktop" "$PWD/$OUT/SDT.exe"
[ -f "$OUT/SDT.pck" ] || { echo "export failed" >&2; exit 1; }

# the Mods folder: the game's folders, with the plugins the repository ships (tracked files only)
for d in Clothing Hair Backgrounds Characters Dialogue Plugins; do
	mkdir -p "$OUT/Mods/$d"
done
git ls-files -z Mods/Plugins | while IFS= read -r -d '' f; do
	mkdir -p "$OUT/$(dirname "$f")"
	cp "$f" "$OUT/$f"
done
cp tools/release_readme.txt "$OUT/README.txt"

"$PY" -I -c '
import os, sys, zipfile
out = sys.argv[1]
base = os.path.dirname(out)
with zipfile.ZipFile(out + ".zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
	for root, dirs, files in os.walk(out):
		rel = os.path.relpath(root, base)
		if not files and not dirs:
			z.writestr(rel.replace(os.sep, "/") + "/", "")   # keep the empty mod folders
		for f in files:
			p = os.path.join(root, f)
			z.write(p, os.path.relpath(p, base))
' "$OUT"
ls -la "$OUT" "$OUT.zip"
