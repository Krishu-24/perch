#!/bin/sh
# Builds "Perch Helper.app" from this package.
# Usage: helper/build.sh [output folder]   (default: build/)
set -e
cd "$(dirname "$0")"
out="${1:-../build}"
mkdir -p "$out"

swift build -c release --product PerchHelper
bin="$(swift build -c release --show-bin-path)/PerchHelper"

app="$out/Perch Helper.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/PerchHelper"
cp Resources/Info.plist "$app/Contents/Info.plist"

# Signed for this Mac only (no developer identity), with the hardened runtime.
# It runs outside the App Sandbox on purpose: a sandboxed shell couldn't see your files.
codesign --force --sign - --options runtime --timestamp=none "$app"
echo "$app"
