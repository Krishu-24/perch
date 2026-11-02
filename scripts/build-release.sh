#!/bin/sh
# Builds Perch.app with Perch Helper inside it, and zips it for a GitHub release.
# Usage: scripts/build-release.sh   → build/release/Perch-<version>.zip
set -e
cd "$(dirname "$0")/.."
root="$(pwd)"
derived="$root/build/DerivedData"
out="$root/build/release"
mkdir -p "$out"

echo "Building Perch…"
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release \
    -derivedDataPath "$derived" CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual build -quiet
app="$derived/Build/Products/Release/Perch.app"

echo "Building Perch Helper…"
staging="$root/build/helper-staging"
helper/build.sh "$staging" >/dev/null

echo "Putting the helper inside Perch.app…"
mkdir -p "$app/Contents/Library/LoginItems"
rm -rf "$app/Contents/Library/LoginItems/Perch Helper.app"
cp -R "$staging/Perch Helper.app" "$app/Contents/Library/LoginItems/"
# Don't leave a second copy around for macOS to pick up perch-helper:// links with.
rm -rf "$staging"

# Adding the helper changed the bundle, so sign Perch again, keeping its entitlements.
codesign --force --sign - --options runtime --timestamp=none \
    --preserve-metadata=entitlements,requirements,flags "$app"
codesign --verify --deep --strict "$app"

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
zip="$out/Perch-$version.zip"
rm -f "$zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
(cd "$out" && shasum -a 256 "Perch-$version.zip" > "Perch-$version.zip.sha256")

echo "Built $app"
echo "Zipped $zip"
cat "$out/Perch-$version.zip.sha256"
