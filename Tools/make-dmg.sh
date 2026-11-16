#!/bin/zsh
# Builds Phew in Release and packs it into a disk image with a background and an Applications shortcut.
# Usage: Tools/make-dmg.sh <version> <output folder>. Needs Finder to lay out the window (macOS asks once).
set -euo pipefail
version=$1; out=$2
root=${0:A:h:h}; work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
xcodebuild -project "$root/Phew.xcodeproj" -scheme Phew -configuration Release -derivedDataPath "$work/dd" build -quiet
app="$work/dd/Build/Products/Release/Phew.app"
codesign --verify --deep --strict "$app"
stage="$work/stage"; mkdir -p "$stage/.background"
cp -R "$app" "$stage/"; ln -s /Applications "$stage/Applications"
swift "$root/Tools/make-dmg-background.swift" "$stage/.background"
tiffutil -cathidpicheck "$stage/.background/background.png" "$stage/.background/background@2x.png" -out "$stage/.background/background.tiff" >/dev/null
rm "$stage/.background/background.png" "$stage/.background/background@2x.png"
hdiutil create -quiet -volname "Phew" -srcfolder "$stage" -fs HFS+ -format UDRW "$work/rw.dmg"
mount=$(hdiutil attach -readwrite -noverify -noautoopen "$work/rw.dmg" | awk -F'\t' '/\/Volumes\//{print $3}')
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
sync; hdiutil detach -quiet "$mount"
mkdir -p "$out"; rm -f "$out/Phew-$version.dmg"
hdiutil convert -quiet "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$out/Phew-$version.dmg"
echo "$out/Phew-$version.dmg"
