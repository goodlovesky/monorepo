#!/usr/bin/env bash
#
# gen_ffi.sh - 生成 FFI 头文件 (C / C++)
#
# 用法:
#   ./tools/gen_ffi.sh           # 生成 C 头文件
#   ./tools/gen_ffi.sh --cpp     # 生成 C++ 头文件
#
# 产物:
#   bindings/core_bridge.h
#   bindings/core_bridge.hpp     (如果传 --cpp)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# 检查 cbindgen
if ! command -v cbindgen >/dev/null 2>&1; then
    echo "==> Installing cbindgen"
    cargo install cbindgen
fi

OUTPUT_DIR="$ROOT_DIR/bindings"
mkdir -p "$OUTPUT_DIR"

# 生成 C 头文件
echo "==> Generating C header file"
cbindgen \
    --config cbindgen.toml \
    --crate core-bridge \
    --output "$OUTPUT_DIR/core_bridge.h" \
    --lang c

echo "  ✓ $OUTPUT_DIR/core_bridge.h"

# 生成 C++ 头文件 (如果传 --cpp)
if [ "${1:-}" = "--cpp" ]; then
    echo "==> Generating C++ header file"
    cbindgen \
        --config cbindgen.toml \
        --crate core-bridge \
        --output "$OUTPUT_DIR/core_bridge.hpp" \
        --lang cxx
    echo "  ✓ $OUTPUT_DIR/core_bridge.hpp"
fi

echo ""
echo "==> Done! Use these headers in:"
echo "  - Flutter/Dart (via dart:ffi + header parsing)"
echo "  - Android/JNI (Kotlin via JNI)"
echo "  - iOS/macOS (Swift via bridging header)"
echo "  - Windows (C++/WinRT)"
