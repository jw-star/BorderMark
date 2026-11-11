#!/bin/bash
# 先打出 .app，再装进带“应用程序”快捷方式的压缩磁盘镜像。
# 用法：scripts/dmg.sh [版本号]   产物：build/边框水印大师-<版本>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-0.1.0}"
app_name="边框水印大师"
app_dir="build/${app_name}.app"
staging="build/dmg-staging"
dmg_path="build/${app_name}-${version}.dmg"

"$(dirname "$0")/bundle.sh" "$version"

rm -rf "$staging"
mkdir -p "$staging"
ditto "$app_dir" "$staging/${app_name}.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg_path"
hdiutil create \
    -volname "$app_name" \
    -srcfolder "$staging" \
    -ov \
    -format UDZO \
    "$dmg_path"

rm -rf "$staging"
echo "已生成 $dmg_path"
