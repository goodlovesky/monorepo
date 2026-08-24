#!/usr/bin/env bash
#
# build_macos_app.sh — 一键 build + run macOS Flutter app
#
# 流程：
#   1. cargo build (Rust core-bridge → libcore_bridge.dylib)
#   2. 拷贝 dylib 到 Flutter macOS bundle
#   3. (可选) build Flutter app
#   4. (可选) run Flutter app
#
# 用法:
#   ./tools/build_macos_app.sh                    # build Rust + 拷 dylib + flutter build
#   ./tools/build_macos_app.sh --run              # build + flutter run
#   ./tools/build_macos_app.sh --release          # release 模式
#   ./tools/build_macos_app.sh --rust-only        # 只 build Rust
#
# 注意: 函数名避开 Unix 命令 (info, log, error) 避免 PATH 冲突

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
TARGET_DIR="$ROOT_DIR/target"

# 默认值。注意:Flutter 实际产出的目录是 `Build/Products/Debug`(大写 D),
# 即使传 --debug 小写;这里统一用大写避免路径错位。
BUILD_MODE="Debug"
DO_RUN=false
RUST_ONLY=false
FLUTTER_ONLY=false

# ==================== 解析参数 ====================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run) DO_RUN=true; shift ;;
        --release) BUILD_MODE="Release"; shift ;;
        --debug) BUILD_MODE="Debug"; shift ;;
        --rust-only) RUST_ONLY=true; shift ;;
        --flutter-only) FLUTTER_ONLY=true; shift ;;
        -h|--help)
            head -25 "$0" | tail -20
            exit 0
            ;;
        *) printf "[✗] 未知参数: %s\n" "$1"; exit 1 ;;
    esac
done

# ==================== 颜色 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 用独特前缀避免和 unix 命令冲突
print_step()  { printf "${BLUE}[i]${NC} %s\n" "$*"; }
print_ok()    { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
print_warn()  { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
print_err()   { printf "${RED}[✗]${NC} %s\n" "$*"; }

# ==================== 检查环境 ====================
if [[ "$(uname -s)" != "Darwin" ]]; then
    print_err "只支持 macOS"
    exit 1
fi

# 优先使用 rustup stable，避免 Homebrew 的旧 rustc 抢在前面。
if [[ -x "$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin/rustc" ]]; then
    export PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH"
elif [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

if [[ -n "${FLUTTER_ROOT:-}" ]] && [[ -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    export PATH="$FLUTTER_ROOT/bin:$PATH"
fi

# 如果还没找到，尝试从 ~/.zshrc 或 ~/development 推断
if ! command -v flutter >/dev/null 2>&1; then
    for guess in \
        "$HOME/development/flutter" \
        "$HOME/flutter" \
        "/opt/flutter" \
        "/usr/local/flutter"; do
        if [[ -x "$guess/bin/flutter" ]]; then
            export FLUTTER_ROOT="$guess"
            export PATH="$guess/bin:$PATH"
            break
        fi
    done
fi

if ! command -v flutter >/dev/null 2>&1; then
    print_warn "flutter 不在 PATH（继续 build Rust，但 skip flutter）"
    FLUTTER_AVAILABLE=false
else
    FLUTTER_AVAILABLE=true
    print_step "使用 flutter $(flutter --version 2>/dev/null | head -1)"
fi

# ==================== 1. Desktop runtime ====================
if [[ "$FLUTTER_ONLY" == false ]]; then
    print_step "桌面端使用随包 mihomo，不构建常驻特权 helper"
fi

# ==================== 2. dylib 跳过(桌面端不依赖 FFI) ====================
# 桌面端不再注入 libcore_bridge.dylib:
#   - FFI 路径已废弃,运行时不会 DynamicLibrary.open
#   - Android 端 dylib 由 build_android.sh 单独处理
if [[ "$RUST_ONLY" == false ]]; then
    DYLIB_PATH=""  # 桌面端不构建 dylib
    print_step "桌面端跳过 dylib 注入(走 mihomo HTTP API)"
fi

# ==================== 3. Flutter build ====================
if [[ "$FLUTTER_AVAILABLE" == false ]]; then
    print_warn "flutter 不在 PATH，跳过 Flutter build"
    print_warn "装好 flutter 后跑: cd $APP_DIR && flutter run -d macos"
    exit 0
fi

if [[ "$RUST_ONLY" == false ]]; then
    # flutter CLI 接受小写 --debug/--release,但实际产出目录用大写 Debug/Release
    FLUTTER_BUILD_MODE=$(echo "$BUILD_MODE" | tr '[:upper:]' '[:lower:]')
    print_step "Running flutter build macos --$FLUTTER_BUILD_MODE..."
    cd "$APP_DIR"
    flutter build macos --"$FLUTTER_BUILD_MODE" 2>&1 | tail -20

    # 桌面端不注入 libcore_bridge.dylib(走 mihomo HTTP API,不走 FFI)
    APP_BUILD_DIR="$APP_DIR/build/macos/Build/Products/$BUILD_MODE/Clash RS.app/Contents/Frameworks"

    APP_RESOURCES_DIR="$APP_DIR/build/macos/Build/Products/$BUILD_MODE/Clash RS.app/Contents/Resources"
    mkdir -p "$APP_RESOURCES_DIR"
    rm -f "$APP_RESOURCES_DIR/clash-rs-helper"

    # mihomo binary(TUN 模式核心,Go 写的,自 GitHub release 下载)
    # 放 Resources/ 下，TUN 启动时按次请求管理员权限运行该固定二进制。
    MIHOMO_SRC="$APP_DIR/macos/Runner/Resources/mihomo"
    MIHOMO_DST="$APP_DIR/build/macos/Build/Products/$BUILD_MODE/Clash RS.app/Contents/Resources/mihomo"
    if [[ -x "$MIHOMO_SRC" ]]; then
        mkdir -p "$(dirname "$MIHOMO_DST")"
        cp "$MIHOMO_SRC" "$MIHOMO_DST"
        chmod +x "$MIHOMO_DST"
        MIHOMO_VERSION="$("$MIHOMO_DST" -v 2>&1 | head -1 || echo unknown)"
        print_ok "mihomo injected: $MIHOMO_DST (version: $MIHOMO_VERSION)"
    else
        print_warn "mihomo binary 不在 $MIHOMO_SRC,跳注入"
        print_warn "TUN 模式需要 mihomo,请跑: ./tools/download_mihomo.sh"
    fi

    # 注入资源后重新签名，确保本地 Release App 可通过完整性校验。
    codesign --force --sign - "$MIHOMO_DST"
    codesign --force --deep --sign - "$APP_DIR/build/macos/Build/Products/$BUILD_MODE/Clash RS.app"
    codesign --verify --deep --strict "$APP_DIR/build/macos/Build/Products/$BUILD_MODE/Clash RS.app"
fi

# ==================== 4. Flutter run ====================
if [[ "$DO_RUN" == true ]]; then
    print_step "Launching flutter run -d macos..."
    cd "$APP_DIR"
    flutter run -d macos
fi

print_ok "All done!"
echo ""
echo "下次修改后跑："
echo "  ./tools/build_macos_app.sh --run              # debug 模式 run"
echo "  ./tools/build_macos_app.sh --release --run   # release 模式 run"
