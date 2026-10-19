#!/bin/bash
set -euo pipefail
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SOURCE_DIR/.build"
OUTPUT_PATH="${1:-$SOURCE_DIR/../MailDesk.app}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/maildesk-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_PATH="$STAGING_DIR/MailDesk.app"
mkdir -p "$BUILD_DIR/module-cache" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
swiftc -parse-as-library -O -target arm64-apple-macosx13.0 \
  -module-cache-path "$BUILD_DIR/module-cache" -framework AppKit -framework WebKit \
  "$SOURCE_DIR/NavigationPolicy.swift" "$SOURCE_DIR/MailDesk.swift" \
  -o "$APP_PATH/Contents/MacOS/MailDesk"
swiftc -module-cache-path "$BUILD_DIR/module-cache" -framework AppKit \
  "$SOURCE_DIR/MakeIcon.swift" -o "$BUILD_DIR/make-icon"
"$BUILD_DIR/make-icon" "$BUILD_DIR/icon.png"
mkdir -p "$BUILD_DIR/MailDesk.iconset"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$BUILD_DIR/icon.png" --out "$BUILD_DIR/MailDesk.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$BUILD_DIR/icon.png" --out "$BUILD_DIR/MailDesk.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
# Package the PNG representations directly (no icon service or extra dependencies).
/usr/bin/python3 - "$BUILD_DIR/MailDesk.iconset" "$APP_PATH/Contents/Resources/MailDesk.icns" <<'PY'
import pathlib, struct, sys
source = pathlib.Path(sys.argv[1])
entries = [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'),
           ('icp6', 'icon_32x32@2x.png'), ('ic07', 'icon_128x128.png'),
           ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'),
           ('ic10', 'icon_512x512@2x.png')]
chunks = []
for kind, filename in entries:
    png = (source / filename).read_bytes()
    chunks.append(kind.encode() + struct.pack('>I', len(png) + 8) + png)
payload = b''.join(chunks)
pathlib.Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
PY
cp "$SOURCE_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"
# Finder may attach icon metadata to bundles created in a synced Documents folder.
xattr -dr com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --options runtime "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
ditto -c -k --norsrc --keepParent "$APP_PATH" "${OUTPUT_PATH%.app}.zip"
ditto --norsrc "$APP_PATH" "$OUTPUT_PATH"
# The verified ZIP preserves the bundle without cloud-provider Finder metadata.
echo "Built: $OUTPUT_PATH"
