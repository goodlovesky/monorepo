#!/usr/bin/env bash
#
# build_android.sh - 编译 Android 平台 (arm64-v8a, armeabi-v7a, x86, x86_64)
#
# 依赖:
#   - Android NDK (ANDROID_NDK_HOME 环境变量)
#   - cargo-ndk (cargo install cargo-ndk)
#
# 用法:
#   ./tools/build_android.sh              # 编译所有架构
#   ./tools/build_android.sh arm64-v8a    # 只编译 arm64-v8a
#   ANDROID_API_LEVEL=24 ./tools/build_android.sh
#
# 产物:
#   app/android/app/src/main/jniLibs/arm64-v8a/libcore_bridge.so
#   app/android/app/src/main/jniLibs/armeabi-v7a/libcore_bridge.so
#   app/android/app/src/main/jniLibs/x86/libcore_bridge.so
#   app/android/app/src/main/jniLibs/x86_64/libcore_bridge.so

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# 默认架构
ARCHS_ALL=(
    "arm64-v8a"
    "armeabi-v7a"
    "x86"
    "x86_64"
)

# 只编译传入的架构
if [ $# -gt 0 ]; then
    ARCHS=("$@")
else
    ARCHS=("${ARCHS_ALL[@]}")
fi

# API Level
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-24}"

# 检查 NDK
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "Error: ANDROID_NDK_HOME environment variable not set"
    echo "  export ANDROID_NDK_HOME=/path/to/android-ndk-r26"
    exit 1
fi

# 检查 cargo-ndk
if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "==> Installing cargo-ndk"
    cargo install cargo-ndk
fi

# 目标映射
declare -A TARGET_MAP=(
    ["arm64-v8a"]="aarch64-linux-android"
    ["armeabi-v7a"]="armv7-linux-androideabi"
    ["x86"]="i686-linux-android"
    ["x86_64"]="x86_64-linux-android"
)

# 输出目录
JNI_LIBS_DIR="$ROOT_DIR/app/android/app/src/main/jniLibs"
mkdir -p "$JNI_LIBS_DIR"

# 编译
for arch in "${ARCHS[@]}"; do
    target="${TARGET_MAP[$arch]}"
    if [ -z "$target" ]; then
        echo "Warning: unknown arch $arch, skipping"
        continue
    fi

    echo ""
    echo "==> Building for Android $arch (target: $target, API: $ANDROID_API_LEVEL)"

    cargo ndk \
        --target "$target" \
        --android-api "$ANDROID_API_LEVEL" \
        --output-dir "$JNI_LIBS_DIR" \
        build --release -p core-bridge

    if [ -f "$JNI_LIBS_DIR/$arch/libcore_bridge.so" ]; then
        echo "  ✓ $JNI_LIBS_DIR/$arch/libcore_bridge.so"
    else
        echo "  ✗ build failed for $arch"
        exit 1
    fi
done

echo ""
echo "==> Done! All .so files:"
find "$JNI_LIBS_DIR" -name "*.so" -exec ls -lh {} \;
