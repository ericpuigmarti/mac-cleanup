#!/bin/bash
# Builds DiskCleaner.app.
#
# This machine only has the Xcode Command Line Tools installed (no full
# Xcode.app), and SwiftPM's `swift build` shells out to
# `xcrun --show-sdk-platform-path`, which only exists in a full Xcode
# install. SwiftUI/AppKit themselves compile and link fine under the CLT
# SDK, so this script drives `swiftc` directly instead of going through
# SwiftPM. If you ever install full Xcode, `swift build` will also work.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DiskCleaner"
BUILD_DIR="build"
APP_BUNDLE="$APP_NAME.app"

rm -rf "$BUILD_DIR" "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"

echo "Compiling..."
SOURCES=$(find Sources/DiskCleaner -name '*.swift')
# shellcheck disable=SC2086
swiftc -O -parse-as-library $SOURCES -o "$BUILD_DIR/$APP_NAME"

echo "Assembling $APP_BUNDLE..."
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Built $APP_BUNDLE"
echo "First launch: right-click $APP_BUNDLE in Finder -> Open (it's unsigned/unnotarized, so Gatekeeper needs a one-time manual override)."
