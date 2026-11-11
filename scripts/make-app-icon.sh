#!/bin/bash
# 重新生成 App 图标：先画 1024 的 PNG，再切出各尺寸打成 Packaging/AppIcon.icns。
# iconutil 和 sips 是 macOS 自带的，不需要 Xcode。
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/make-app-icon.swift Packaging/AppIcon.png

iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Packaging/AppIcon.icns
echo "已生成 Packaging/AppIcon.icns"
