#!/usr/bin/env bash
set -euo pipefail

PROJECT="senor-particle.xcodeproj"
SCHEME="senor-particle"
CONFIG="Release"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    build

APP_PATH=".build/Products/$CONFIG/senor-particle.app"

if [[ -d "$APP_PATH" ]]; then
    echo ""
    echo "Build succeeded: $APP_PATH"
else
    echo "Build failed: app bundle not found" >&2
    exit 1
fi
