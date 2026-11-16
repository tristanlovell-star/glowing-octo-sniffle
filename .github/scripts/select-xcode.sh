#!/bin/bash
# Picks the newest Xcode installed on the GitHub macOS runner.
# App Store Connect only accepts builds made with a recent SDK, so newest is safest.
set -euo pipefail
newest=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -v -i beta | sort -V | tail -1 || true)
if [ -n "$newest" ]; then
  sudo xcode-select -s "$newest/Contents/Developer"
fi
xcodebuild -version
