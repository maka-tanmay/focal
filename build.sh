#!/bin/sh
# Builds build/Focal.app (universal, ad-hoc signed) and build/Focal.zip.
# Usage: ./build.sh [version]
set -e
cd "$(dirname "$0")"
VERSION="${1:-0.0.0}"
APP=build/Focal.app

swift build -c release --arch arm64 --arch x86_64
rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp .build/apple/Products/Release/Focal "$APP/Contents/MacOS/Focal"
sed "s/__VERSION__/$VERSION/g" Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Focal.zip
echo "Built $APP ($VERSION)"
