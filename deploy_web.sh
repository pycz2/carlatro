#!/bin/sh
# Make a release: bump the version, commit and tag it, push, then publish the
# website (site/ landing page + the web build in /play/) to the gh-pages branch.
# Usage: ./deploy_web.sh [patch|minor|major]   (default: patch)
set -e
cd "$(dirname "$0")"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PART="${1:-patch}"
TRAILER="${COMMIT_TRAILER:-}"

if [ -n "$(git status --porcelain)" ]; then
	echo "Commit or stash your changes first: the release must match the code in git." >&2
	exit 1
fi

OLD="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
NEW="$(echo "$OLD" | awk -F. -v p="$PART" '{
	if (p == "major") { $1++; $2 = 0; $3 = 0 }
	else if (p == "minor") { $2++; $3 = 0 }
	else { $3++ }
	print $1 "." $2 "." $3 }')"
if ! grep -q "\"version\": \"$NEW\"" scripts/changelog.gd; then
	echo "Add a changelog entry for v$NEW to scripts/changelog.gd first." >&2
	exit 1
fi
sed -i '' "s/^config\/version=\".*\"/config\/version=\"$NEW\"/" project.godot
sed -i '' "s/^application\/short_version=\".*\"/application\/short_version=\"$NEW\"/; s/^application\/version=\".*\"/application\/version=\"$NEW\"/" export_presets.cfg
git add project.godot export_presets.cfg
git commit -q -m "Release v$NEW${TRAILER:+

$TRAILER}"
git tag "v$NEW"
git push -q origin HEAD "v$NEW"
echo "Released v$OLD -> v$NEW"

mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
# site layout: landing page at the root, the game in /play/
TMP="$(mktemp -d)"
cp -R site/. "$TMP"
rm -f "$TMP/.gdignore"
sed -i '' "s/{{VERSION}}/$NEW/g" "$TMP/index.html"
mkdir -p "$TMP/screenshots" "$TMP/play"
cp docs/screenshots/*.png "$TMP/screenshots/"
cp -R build/web/. "$TMP/play"
rm -f "$TMP"/play/*.import
touch "$TMP/.nojekyll"
REMOTE="$(git remote get-url origin)"
cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "Deploy web build v$NEW${TRAILER:+

$TRAILER}"
git push -q -f "$REMOTE" gh-pages
cd - >/dev/null
rm -rf "$TMP"
echo "Published v$NEW to gh-pages: https://pycz2.github.io/carlatro/"
