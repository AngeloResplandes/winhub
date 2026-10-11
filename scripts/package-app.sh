#!/bin/sh
# Builds dist/WinHub.app (and dist/WinHub.zip) from the Swift package.
#
# Signing:
#   - default: ad-hoc signature (runs on this Mac; other Macs need right-click → Abrir)
#   - DEVELOPER_ID="Developer ID Application: Nome (TEAMID)": signs for distribution
#   - NOTARY_PROFILE=<perfil do notarytool>: also notarizes and staples (requires DEVELOPER_ID)
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
DIST="dist"
APP="$DIST/WinHub.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/WinHub" "$APP/Contents/MacOS/WinHub"
cp -R "$BIN_DIR/WinHub_WinHub.bundle" "$APP/Contents/Resources/"

# Windows program that keeps Steam's window from staying black (see SteamWebHelperWrapper.swift).
./scripts/build-steam-wrapper.sh "$APP/Contents/Resources/steamwebhelper-wrapper.exe" >/dev/null

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>WinHub</string>
    <key>CFBundleDisplayName</key><string>WinHub</string>
    <key>CFBundleIdentifier</key><string>io.github.winhub</string>
    <key>CFBundleExecutable</key><string>WinHub</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleDevelopmentRegion</key><string>pt</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>WinHub</string>
            <key>CFBundleURLSchemes</key><array><string>winhub</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

if [ -n "${DEVELOPER_ID:-}" ]; then
    codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
else
    codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

rm -f "$DIST/WinHub.zip"
ditto -c -k --keepParent "$APP" "$DIST/WinHub.zip"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    [ -n "${DEVELOPER_ID:-}" ] || { echo "NOTARY_PROFILE requer DEVELOPER_ID" >&2; exit 1; }
    xcrun notarytool submit "$DIST/WinHub.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$DIST/WinHub.zip"
    ditto -c -k --keepParent "$APP" "$DIST/WinHub.zip"
fi

echo "Pronto: $APP e $DIST/WinHub.zip"
