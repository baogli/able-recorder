#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/build/Able Recorder.app"
[[ -x "$APP/Contents/MacOS/AbleRecorder" ]] || ./build.sh
codesign --verify --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/AbleRecorder")
mkdir -p dist
NAME="Able-Recorder-$VERSION-macOS-$ARCH.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$NAME"
(cd dist && shasum -a 256 "$NAME" > "$NAME.sha256")
print "Packaged: $PWD/dist/$NAME"
