#!/bin/bash
set -euo pipefail
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SOURCE_DIR/.build/module-cache"
swiftc -module-cache-path "$SOURCE_DIR/.build/module-cache" \
  "$SOURCE_DIR/NavigationPolicy.swift" "$SOURCE_DIR/NavigationTests.swift" \
  -o "$SOURCE_DIR/.build/navigation-tests"
"$SOURCE_DIR/.build/navigation-tests"
