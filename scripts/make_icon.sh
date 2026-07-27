#!/bin/bash
set -euo pipefail

export DEVELOPER_DIR="/Library/Developer/CommandLineTools"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/build/icon"
ICONSET="$WORK_DIR/AppIcon.iconset"
OUT_DIR="$ROOT_DIR/Assets"

rm -rf "$WORK_DIR"
mkdir -p "$ICONSET" "$OUT_DIR"

echo "==> Rendering icon images"
swift "$ROOT_DIR/scripts/make_icon.swift" "$ICONSET"

echo "==> Packing .icns"
iconutil -c icns "$ICONSET" -o "$OUT_DIR/AppIcon.icns"

echo "==> Done: $OUT_DIR/AppIcon.icns"
