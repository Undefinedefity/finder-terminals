#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
app="$PWD/build/Finder Terminals.app"
extension="$app/Contents/PlugIns/Finder Terminals Extension.appex"
mkdir -p "$app/Contents/MacOS" "$extension/Contents/MacOS"

python3 - "$app" "$extension" <<'PY'
from pathlib import Path
import plistlib
import sys

app, extension = map(Path, sys.argv[1:])
prefix = "local.finder-terminals"

def write_plist(bundle, metadata):
    base = {
        "CFBundleVersion": "2",
        "CFBundleShortVersionString": "1.1",
        "CFBundleSupportedPlatforms": ["MacOSX"],
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
        "NSPrincipalClass": "NSApplication",
    }
    (bundle / "Contents" / "Info.plist").write_bytes(
        plistlib.dumps(base | metadata)
    )

write_plist(app, {
    "CFBundleIdentifier": prefix,
    "CFBundleDisplayName": "Finder Terminals",
    "CFBundleName": "Finder Terminals",
    "CFBundleExecutable": "FinderTerminalsHost",
    "CFBundlePackageType": "APPL",
})
write_plist(extension, {
    "CFBundleIdentifier": prefix + ".extension",
    "CFBundleDisplayName": "Finder Terminals",
    "CFBundleName": "Finder Terminals",
    "CFBundleExecutable": "FinderTerminals",
    "CFBundlePackageType": "XPC!",
    "NSExtension": {
        "NSExtensionPointIdentifier": "com.apple.FinderSync",
        "NSExtensionPrincipalClass": "FinderTerminals",
    },
})
Path("build/sandbox.plist").write_bytes(
    plistlib.dumps({
        "com.apple.security.app-sandbox": True,
        "com.apple.security.temporary-exception.files.home-relative-path.read-write":
            ["/Library/Application Support/Finder Terminals/Requests/"],
    })
)
PY

xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 \
    -framework AppKit Host.m -o "$app/Contents/MacOS/FinderTerminalsHost"
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 \
    -framework AppKit -framework FinderSync -framework ExtensionFoundation \
    -Wl,-e,_NSExtensionMain FinderTerminals.m -o "$extension/Contents/MacOS/FinderTerminals"

codesign --force --sign - --entitlements build/sandbox.plist "$extension"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
