#!/usr/bin/env bash
set -euo pipefail

APP_NAME="EnhancedSkills"
SCHEME="EnhancedSkills"
PROJECT="EnhancedSkills.xcodeproj"
CONFIGURATION="Release"

VERSION_SUFFIX="${1:-}"
MARKETING_VERSION="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"

if [[ -n "$VERSION_SUFFIX" ]]; then
    OUTPUT_DMG="$DIST_DIR/${APP_NAME}-${VERSION_SUFFIX}.dmg"
else
    OUTPUT_DMG="$DIST_DIR/${APP_NAME}.dmg"
fi

rm -rf "$STAGING_DIR" "$DERIVED_DATA_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

XCBUILD_EXTRA_ARGS=()
BUILD_TIMESTAMP=$(date +%s)
XCBUILD_EXTRA_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_TIMESTAMP")

if [[ -n "$MARKETING_VERSION" ]]; then
    XCBUILD_EXTRA_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
    echo "Stamping version: $MARKETING_VERSION"
fi

# ── Detect signing identity ──────────────────────────────────────────────────
# Priority 1: explicit env var (CI mode)
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-}"
TEAM_ID="${APPLE_DEVELOPER_TEAM_ID:-}"

# Priority 2: auto-detect from local keychain
if [[ -z "$SIGNING_IDENTITY" ]]; then
    DETECTED=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed 's/.*"\(.*\)".*/\1/' || true)
    if [[ -n "$DETECTED" ]]; then
        SIGNING_IDENTITY="$DETECTED"
        TEAM_ID=$(echo "$DETECTED" | grep -o '([A-Z0-9]*)' | tr -d '()' | head -1 || true)
        echo "Auto-detected signing identity: $SIGNING_IDENTITY"
    fi
fi

# ── Build ────────────────────────────────────────────────────────────────────
if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔨 Building $APP_NAME ($CONFIGURATION) with Developer ID signing..."
    SIGN_ARGS=(
        "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY"
        "CODE_SIGN_STYLE=Manual"
        "CODE_SIGN_ENTITLEMENTS=$ROOT_DIR/EnhancedSkills/EnhancedSkills.entitlements"
        "ENABLE_HARDENED_RUNTIME=YES"
        "AD_HOC_CODE_SIGNING_ALLOWED=NO"
        "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO"
        "OTHER_CODE_SIGN_FLAGS=--options=runtime"
        "TIMESTAMP_SERVER_URL=http://timestamp.apple.com/ts0881"
    )
    [[ -n "$TEAM_ID" ]] && SIGN_ARGS+=("DEVELOPMENT_TEAM=$TEAM_ID")

    xcodebuild \
        -project "$ROOT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        "${SIGN_ARGS[@]}" \
        "${XCBUILD_EXTRA_ARGS[@]}" \
        clean build
else
    echo "⚠️  No Developer ID identity found. Building unsigned (ad-hoc)..."
    xcodebuild \
        -project "$ROOT_DIR/$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        "${XCBUILD_EXTRA_ARGS[@]}" \
        clean build
fi

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Build failed. App not found at $APP_PATH"
    exit 1
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔁 Re-signing app bundle with secure timestamp..."
    codesign -f \
        -s "Developer ID Application: Sameer Bajaj (BZ685BB6M6)" \
        --options runtime \
        "$APP_PATH"
fi

# Ad-hoc sign only for unsigned fallback builds
if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "🔏 Ad-hoc signing…"
    codesign --force --deep --sign - "$APP_PATH"
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ── Create DMG ───────────────────────────────────────────────────────────────
echo "📦 Creating DMG..."
if command -v create-dmg >/dev/null 2>&1; then
    rm -f "$OUTPUT_DMG"
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --volicon "$ROOT_DIR/scripts/AppIcon.icns" \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        "$OUTPUT_DMG" \
        "$STAGING_DIR"
else
    TMP_DMG="$BUILD_DIR/temp-${APP_NAME}.dmg"
    rm -f "$TMP_DMG" "$OUTPUT_DMG"
    hdiutil create "$TMP_DMG" -ov -volname "$APP_NAME" -fs HFS+ -srcfolder "$STAGING_DIR"
    hdiutil convert "$TMP_DMG" -format UDZO -o "$OUTPUT_DMG"
    rm -f "$TMP_DMG"
fi

# ── Sign, notarize, staple ────────────────────────────────────────────────────
if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "🔏 Signing DMG..."
    codesign --force --sign "$SIGNING_IDENTITY" "$OUTPUT_DMG"

    echo "🚀 Submitting for notarization..."
    NOTARY_ARGS=(
        "--wait"
        "--timeout" "600s"
    )

    if [[ -n "${APPLE_ID:-}" && -n "${APPLE_ID_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
        # CI mode: use env var credentials
        xcrun notarytool submit "$OUTPUT_DMG" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$TEAM_ID" \
            "${NOTARY_ARGS[@]}"
    else
        # Local mode: use stored keychain profile
        xcrun notarytool submit "$OUTPUT_DMG" \
            --keychain-profile "EnhancedSkills-Notarize" \
            "${NOTARY_ARGS[@]}"
    fi

    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$OUTPUT_DMG"

    echo "✅ Signed, notarized, and stapled: $OUTPUT_DMG"
else
    echo "✅ DMG created (unsigned) at $OUTPUT_DMG"
fi
