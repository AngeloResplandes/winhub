#!/bin/sh
# Builds dist/WinHub.app (and dist/WinHub.zip) from the Swift package.
#
# Signing:
#   - default: ad-hoc signature (runs on this Mac; other Macs need right-click → Abrir)
#   - DEVELOPER_ID="Developer ID Application: Nome (TEAMID)": signs for distribution
#   - NOTARY_PROFILE=<perfil do notarytool>: also notarizes and staples (requires DEVELOPER_ID)
set -eu

cd "$(dirname "$0")/.."
# The release workflow passes VERSION=<VERSION file>.<run number>; local builds end in .0.
VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION).0}"
# Repository the app checks for updates (forks update from themselves).
REPOSITORY="${GITHUB_REPOSITORY:-AngeloResplandes/winhub}"
BUILD="${BUILD:-1}"
DIST="dist"
APP="$DIST/WinHub.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/WinHub" "$APP/Contents/MacOS/WinHub"
cp -R "$BIN_DIR/WinHub_WinHub.bundle" "$APP/Contents/Resources/"
# The interface's translations (Sources/WinHub/Resources/Localizable.xcstrings, compiled into the resource
# bundle) go into the app's own bundle, where SwiftUI and String(localized:) look by default, from every module.
# The bundle is flat with SwiftPM's native build system and has Contents/Resources with swift-build.
for lproj in "$BIN_DIR/WinHub_WinHub.bundle/"*.lproj "$BIN_DIR/WinHub_WinHub.bundle/Contents/Resources/"*.lproj; do
    if [ -d "$lproj" ]; then cp -R "$lproj" "$APP/Contents/Resources/"; fi
done
for language in en es; do
    test -f "$APP/Contents/Resources/$language.lproj/Localizable.strings" || { echo "$language strings missing from the app" >&2; exit 1; }
done
# Wine processes count as WinHub for macOS privacy checks: without a usage description, macOS refuses the
# microphone without asking and ends the thread that asked (games with voice chat hang).
printf '"NSMicrophoneUsageDescription" = "Windows programs and games opened by WinHub can use the microphone, for example for voice chat.";\n' \
    > "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
printf '"NSMicrophoneUsageDescription" = "Los programas y juegos de Windows abiertos por WinHub pueden usar el micrófono, por ejemplo para el chat de voz.";\n' \
    > "$APP/Contents/Resources/es.lproj/InfoPlist.strings"

# App icon, drawn from code (see scripts/make-icon.swift).
swift scripts/make-icon.swift "$APP/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleDevelopmentRegion</key><string>pt</string>
    <key>CFBundleLocalizations</key><array><string>pt</string><string>en</string><string>es</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Tells other WinHub copies this one records the bottles it uses (BottleGuard.hasGuard). -->
    <key>WinHubBottleGuard</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Programas e jogos do Windows abertos pelo WinHub podem usar o microfone, por exemplo para chat de voz.</string>
    <key>WinHubUpdateRepository</key><string>$REPOSITORY</string>
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
