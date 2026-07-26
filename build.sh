#!/usr/bin/env bash
set -euo pipefail

PROJECT="senor-particle.xcodeproj"
SCHEME="senor-particle"
APP_NAME="Senor Particle"
BUILD_ROOT="Build"
LOCAL_OUTPUT_DIR="${BUILD_ROOT}/Local"
DERIVED_DATA_PATH="${BUILD_ROOT}/DerivedData/CLI"
PACKAGE_CACHE_DIR="${BUILD_ROOT}/SourcePackages"
ARCHIVE_PATH="${LOCAL_OUTPUT_DIR}/Archives/${APP_NAME}.xcarchive"
EXPORT_PATH="${LOCAL_OUTPUT_DIR}/Export"
EXPORT_PLIST="exportOptions.plist"
NOTARIZE_PROFILE="SenorParticle-Notarize"
DESTINATION="generic/platform=macOS"

CLEAN=false
NOTARIZE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build, export, and optionally notarize Senor Particle for direct distribution.

Options:
    --clean       Clean build artifacts before building
    --notarize    Submit the exported app for notarization and staple
    -h, --help    Show this help message

Examples:
    $(basename "$0")                  # Archive and export only
    $(basename "$0") --clean          # Clean first, then archive and export
    $(basename "$0") --notarize       # Archive, export, notarize, and staple
    $(basename "$0") --clean --notarize
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --clean)    CLEAN=true ;;
        --notarize) NOTARIZE=true ;;
        -h|--help)  usage ;;
        *)          echo "Unknown option: $arg"; usage ;;
    esac
done

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" -clonedSourcePackagesDirPath "$PACKAGE_CACHE_DIR" \
    -showBuildSettings 2>/dev/null \
    | awk '/MARKETING_VERSION/ { print $3; exit }')
BUILD_NUMBER=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" -clonedSourcePackagesDirPath "$PACKAGE_CACHE_DIR" \
    -showBuildSettings 2>/dev/null \
    | awk '/CURRENT_PROJECT_VERSION/ { print $3; exit }')

echo "==> Senor Particle ${VERSION} (${BUILD_NUMBER})"
echo ""

# Clean
if [ "$CLEAN" = true ]; then
    echo "==> Cleaning..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -clonedSourcePackagesDirPath "$PACKAGE_CACHE_DIR" \
        clean -quiet
    rm -rf "$LOCAL_OUTPUT_DIR" "$DERIVED_DATA_PATH"
    echo "    Done."
    echo ""
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"

# Resolve packages into the same deterministic location used by release CI and Sparkle tooling.
echo "==> Resolving package dependencies..."
xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$PACKAGE_CACHE_DIR" \
    -quiet
test -x "$PACKAGE_CACHE_DIR/artifacts/sparkle/Sparkle/bin/generate_appcast"
echo "    Done."
echo ""

# Archive
echo "==> Archiving (Release)..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$PACKAGE_CACHE_DIR" \
    -archivePath "$ARCHIVE_PATH" \
    -quiet
echo "    Archive: ${ARCHIVE_PATH}"
echo ""

# Export
echo "==> Exporting with Developer ID signing..."
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -quiet
echo "    App: ${EXPORT_PATH}/${APP_NAME}.app"
echo ""

# Notarize
if [ "$NOTARIZE" = true ]; then
    ZIP_PATH="${LOCAL_OUTPUT_DIR}/Notarization/${APP_NAME}.zip"

    echo "==> Creating zip for notarization..."
    mkdir -p "$(dirname "$ZIP_PATH")"
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "${EXPORT_PATH}/${APP_NAME}.app" "$ZIP_PATH"
    echo "    Zip: ${ZIP_PATH}"
    echo ""

    echo "==> Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait
    echo ""

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "${EXPORT_PATH}/${APP_NAME}.app"
    echo ""

    echo "==> Verifying..."
    spctl -a -vvv "${EXPORT_PATH}/${APP_NAME}.app" 2>&1 | head -5
    echo ""

    rm -f "$ZIP_PATH"
fi

echo "==> Build complete: ${EXPORT_PATH}/${APP_NAME}.app"
