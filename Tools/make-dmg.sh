#!/bin/zsh
# Builds Phew in Release and packs it into a disk image with a background and an Applications shortcut.
# Usage: Tools/make-dmg.sh <version> <output folder>. Needs Finder to lay out the window (macOS asks once).
# Refuses uncommitted changes, a version other than the app's own, a debuggable app (get-task-allow) or one without
# the hardened runtime, and another disk named Phew already mounted (Finder would dress that one).
set -euo pipefail
(( $# == 2 )) || { echo "Usage: Tools/make-dmg.sh <version> <output folder>" >&2; exit 2; }
version=$1; out=$2
root=${0:A:h:h}; work=$(mktemp -d); mount=""
trap 'if [[ -n $mount ]]; then hdiutil detach -quiet -force "$mount" || true; fi; rm -rf "$work"' EXIT
fail() { echo "make-dmg: $1" >&2; exit 1; }
[[ -z $(git -C "$root" status --porcelain) ]] || fail "uncommitted changes: the image must be the committed code"
[[ ! -e /Volumes/Phew ]] || fail "a disk named Phew is mounted: eject it first"
xcodebuild -project "$root/Phew.xcodeproj" -scheme Phew -configuration Release -derivedDataPath "$work/dd" build -quiet
app="$work/dd/Build/Products/Release/Phew.app"
codesign --verify --deep --strict "$app"
built=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ $built == "$version" ]] || fail "the app is version $built, not $version"
# The debugger door must be shut: get-task-allow lets any program of the user read Phew's memory (R14).
# The helper's Node program goes inside the app (Tools/fetch-node.sh fetched it), signed by the same certificate with
# only what Node needs to run: the copy from nodejs.org also carries get-task-allow, the debugger door. Then the app
# is signed again, since its contents changed. Without Node the image is not made: skills would silently not run.
node="$root/Vendor/node/node"
[[ -x $node ]] || fail "no Node program: run Tools/fetch-node.sh first"
[[ -f $app/Contents/Resources/engine.js ]] || fail "the helper (engine.js) is not in the app: run Tools/build-engine.sh"
identity=$(security find-identity -v -p codesigning | awk '/Apple Development/{print $2; exit}')
[[ -n $identity ]] || fail "no signing certificate found"
mkdir -p "$app/Contents/Helpers"; cp "$node" "$app/Contents/Helpers/node"
codesign --force --options runtime --entitlements "$root/Engine/node.entitlements" --sign "$identity" "$app/Contents/Helpers/node"
codesign --force --options runtime --entitlements "$root/Phew.entitlements" --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
[[ $(codesign -d --entitlements - "$app/Contents/Helpers/node" 2>/dev/null) != *get-task-allow* ]] || fail "Node carries get-task-allow"
# Read into variables first: with pipefail, a grep -q that stops early would fail the pipe and flip the answer.
ents=$(codesign -d --entitlements - "$app" 2>/dev/null); sig=$(codesign -d --verbose "$app" 2>&1)
[[ $ents != *get-task-allow* ]] || fail "the app carries get-task-allow"
[[ $sig == *flags=*runtime* ]] || fail "the hardened runtime is off"
stage="$work/stage"; mkdir -p "$stage/.background"
cp -R "$app" "$stage/"; ln -s /Applications "$stage/Applications"
swift "$root/Tools/make-dmg-background.swift" "$stage/.background"
tiffutil -cathidpicheck "$stage/.background/background.png" "$stage/.background/background@2x.png" -out "$stage/.background/background.tiff" >/dev/null
rm "$stage/.background/background.png" "$stage/.background/background@2x.png"
hdiutil create -quiet -volname "Phew" -srcfolder "$stage" -fs HFS+ -format UDRW "$work/rw.dmg"
mount=$(hdiutil attach -readwrite -noverify -noautoopen "$work/rw.dmg" | awk -F'\t' '/\/Volumes\//{print $3}')
# Finder finds the disk by name, so it must be this one.
[[ $mount == /Volumes/Phew ]] || fail "the new image mounted at $mount, not /Volumes/Phew"
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "Phew"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 160, 840, 588}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Phew.app" of container window to {170, 200}
    set position of item "Applications" of container window to {470, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
sync; hdiutil detach -quiet "$mount"; mount=""
# Made beside, then moved into place: the earlier image goes only once the new one exists.
hdiutil convert -quiet "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$work/Phew.dmg"
mkdir -p "$out"; mv -f "$work/Phew.dmg" "$out/Phew-$version.dmg"
echo "$out/Phew-$version.dmg"
