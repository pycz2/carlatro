#!/bin/sh
# Export the web build and publish it to the gh-pages branch (served by GitHub Pages).
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
MSG="${DEPLOY_MSG:-Deploy web build}"
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
TMP="$(mktemp -d)"
cp -R build/web/. "$TMP"
rm -f "$TMP"/*.import
touch "$TMP/.nojekyll"
REMOTE="$(git remote get-url origin)"
cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "$MSG"
git push -q -f "$REMOTE" gh-pages
cd - >/dev/null
rm -rf "$TMP"
echo "Published to gh-pages: https://pycz2.github.io/carlatro/"
