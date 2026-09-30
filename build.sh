#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/Able Recorder.app"
ARCH="${ARCH:-arm64}"
if [[ "$ARCH" != arm64 && "$ARCH" != x86_64 ]]; then
  print -u2 "Unsupported ARCH: $ARCH"; exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/module-cache
xcrun clang -O2 -std=c11 -target "$ARCH-apple-macosx14.0" -c Sources/AudioBridge.c -o build/AudioBridge.o
xcrun swiftc -O -swift-version 5 -target "$ARCH-apple-macosx14.0" -module-cache-path "$PWD/build/module-cache" -import-objc-header Sources/AudioBridge.h Sources/*.swift build/AudioBridge.o -o "$APP/Contents/MacOS/AbleRecorder" -framework AppKit -framework AVFoundation -framework ScreenCaptureKit -framework AudioToolbox -framework CoreAudio -framework Carbon
cp Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE"
# Preserve the identifier and designated requirement of the initial local build.
# Changing them would invalidate permissions already granted by macOS.
codesign --force --sign - --identifier local.michael.LoopbackRecorder --requirements '=designated => identifier "local.michael.LoopbackRecorder";' "$APP"
codesign --verify --strict "$APP"
print "Built: $APP"
