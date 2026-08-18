#!/usr/bin/env bash
#
# build_apple.sh - 编译 Apple 平台 (iOS / iOS Simulator / macOS)
#
# 依赖: cargo, rustup (需要安装 apple targets)
#
# 用法:
#   ./tools/build_apple.sh           # 编译所有 Apple 平台
#   ./tools/build_apple.sh ios       # 只编译 iOS
#   ./tools/build_apple.sh macos     # 只编译 macOS
#
# 产物:
#   target/aarch64-apple-ios/release/libcore_bridge.a
#   target/aarch64-apple-ios-sim/release/libcore_bridge.a
#   target/aarch64-apple-darwin/release/libcore_bridge.a
#   target/x86_64-apple-darwin/release/libcore_bridge.a

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# 默认编译所有
TARGETS_ALL=(
    "aarch64-apple-ios"           # iOS 真机 (M1+)
    "aarch64-apple-ios-sim"       # iOS Simulator (M1+)
    "x86_64-apple-ios"            # iOS Simulator (Intel)
    "aarch64-apple-darwin"        # macOS (M1+)
    "x86_64-apple-darwin"         # macOS (Intel)
)

# 只编译 iOS
TARGETS_IOS=(
    "aarch64-apple-ios"
    "aarch64-apple-ios-sim"
    "x86_64-apple-ios"
)

# 只编译 macOS
TARGETS_MACOS=(
    "aarch64-apple-darwin"
    "x86_64-apple-darwin"
)

case "${1:-all}" in
    ios)
        TARGETS=("${TARGETS_IOS[@]}")
        ;;
    macos)
        TARGETS=("${TARGETS_MACOS[@]}")
        ;;
    all|*)
        TARGETS=("${TARGETS_ALL[@]}")
        ;;
esac

# 安装缺失的 targets
echo "==> Checking rustup targets"
for target in "${TARGETS[@]}"; do
    if ! rustup target list --installed | grep -q "^${target}$"; then
        echo "  Installing target: $target"
        rustup target add "$target"
    fi
done

# 编译
for target in "${TARGETS[@]}"; do
    echo ""
    echo "==> Building for $target"
    cargo build --release --target "$target" -p core-bridge
done

echo ""
echo "==> Done! Output files:"
for target in "${TARGETS[@]}"; do
    for libname in libcore_bridge.a libcore_bridge.dylib; do
        if [ -f "target/${target}/release/${libname}" ]; then
            echo "  target/${target}/release/${libname}"
        fi
    done
done

echo ""
echo "==> Next step: build xcframework for iOS/macOS"
echo "  See: docs/building.md"
