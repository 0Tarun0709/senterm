#!/usr/bin/env bash
set -euo pipefail

app=$1
output=$2
repo=$(cd "$(dirname "$0")/.." && pwd)
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

plist="$app/Contents/Info.plist"
identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist")
if [[ "$identifier" != io.github.0tarun0709.senterm ]]; then
    echo "expected a release build of senterm, got $identifier" >&2
    exit 1
fi
executable=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$plist")
lipo "$app/Contents/MacOS/$executable" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"

ditto "$app" "$staging/senterm.app"
ln -s /Applications "$staging/Applications"
cp "$repo/LICENSE" "$staging/license.txt"
hdiutil create -srcfolder "$staging" -volname senterm -format UDZO "$output"
hdiutil verify "$output"
(cd "$(dirname "$output")" && shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256")
