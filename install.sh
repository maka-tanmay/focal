#!/bin/sh
# One-line install:  curl -fsSL https://raw.githubusercontent.com/maka-tanmay/focal/main/install.sh | sh
set -e
REPO="maka-tanmay/focal"
TMP="$(mktemp -d)"

echo "Downloading latest Focal..."
curl -fsSL "https://github.com/$REPO/releases/latest/download/Focal.zip" -o "$TMP/Focal.zip"

pkill -x Focal 2>/dev/null || true
rm -rf /Applications/Focal.app
ditto -x -k "$TMP/Focal.zip" /Applications
xattr -dr com.apple.quarantine /Applications/Focal.app 2>/dev/null || true
rm -rf "$TMP"

open /Applications/Focal.app
echo "Installed. Look for the ◐ icon in your menu bar. Toggle with ⌃⌥⌘F."
