#!/bin/sh
# Brings Sources/WinHub/Resources/Localizable.xcstrings up to date with the code: the compiler lists every
# localizable string (SwiftUI literals and String(localized:)) of all targets, and xcstringstool adds new
# keys and marks the ones no longer used as stale. Translate the new keys afterwards (Xcode or a text editor).
# Needs Xcode (xcstringstool). Run from the repository root.
set -eu

catalog="Sources/WinHub/Resources/Localizable.xcstrings"
build=".build/strings"
rm -rf "$build"
swift build --scratch-path "$build" -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path \
    -Xswiftc "$build/stringsdata" >/dev/null

if [ ! -f "$catalog" ]; then
    printf '{\n  "sourceLanguage" : "pt",\n  "strings" : {},\n  "version" : "1.0"\n}\n' > "$catalog"
fi
# The generated resource accessors have no user-facing text.
find "$build" -name '*.stringsdata' ! -name 'resource_bundle_accessor.stringsdata' -print0 |
    xargs -0 printf -- '--stringsdata\0%s\0' | xargs -0 xcrun xcstringstool sync "$catalog"
echo "$(xcrun xcstringstool print "$catalog" | wc -l | tr -d ' ') strings in $catalog"
