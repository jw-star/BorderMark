#!/bin/bash
# 运行测试。装了完整 Xcode 时直接 `swift test`；
# 只有 Command Line Tools 时，Swift Testing 不在默认搜索路径里，需要手动指过去；
# 它附带的 Foundation 叠加模块也不完整，所以一并关掉跨模块叠加。
set -euo pipefail
cd "$(dirname "$0")/.."

developer_dir="$(xcode-select -p)"
clt_frameworks="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
clt_macros="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"

if [[ "$developer_dir" == *CommandLineTools* && -d "$clt_frameworks/Testing.framework" ]]; then
    exec swift test "$@" \
        -Xswiftc -F -Xswiftc "$clt_frameworks" \
        -Xswiftc -plugin-path -Xswiftc "$clt_macros" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -F -Xlinker "$clt_frameworks" \
        -Xlinker -rpath -Xlinker "$clt_frameworks"
fi

exec swift test "$@"
