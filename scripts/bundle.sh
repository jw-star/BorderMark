#!/bin/bash
# 把 SwiftPM 编出的可执行文件包成 macOS 的 .app，并做 ad-hoc 签名。
# 用法：scripts/bundle.sh [版本号]   产物：build/边框水印大师.app
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-0.1.0}"
app_name="边框水印大师"
bundle_id="com.bordermark.app"
app_dir="build/${app_name}.app"

swift build -c release --product BorderMark
swift build -c release --product bordermark-cli
bin_dir="$(swift build -c release --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/BorderMark" "$app_dir/Contents/MacOS/BorderMark"
cp "$bin_dir/bordermark-cli" "$app_dir/Contents/Resources/bordermark-cli"
cp "Packaging/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
# 内置 Logo 直接放进 Resources，应用和命令行工具都从这里读
cp -R "Sources/BorderMarkCore/Resources/Logos" "$app_dir/Contents/Resources/Logos"

cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${app_name}</string>
    <key>CFBundleDisplayName</key><string>${app_name}</string>
    <key>CFBundleIdentifier</key><string>${bundle_id}</string>
    <key>CFBundleExecutable</key><string>BorderMark</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${version}</string>
    <key>CFBundleVersion</key><string>${version}</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# ad-hoc 签名：本机可直接运行；分发给别人需要开发者证书签名并公证
codesign --force --deep --sign - "$app_dir"
echo "已生成 $app_dir"
