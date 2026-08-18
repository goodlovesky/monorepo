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

# 默认值
BUILD_MODE="debug"
DO_RUN=false
RUST_ONLY=false
FLUTTER_ONLY=false

# ==================== 解析参数 ====================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --run) DO_RUN=true; shift ;;
        --release) BUILD_MODE="release"; shift ;;
        --debug) BUILD_MODE="debug"; shift ;;
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

# PATH 里加 cargo（rustup）路径
if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

if ! command -v cargo >/dev/null 2>&1; then
    print_err "cargo 未找到，请先装 rustup"
    exit 1
fi

if command -v rustup >/dev/null 2>&1; then
    RUSTC_VER=$(rustc --version 2>/dev/null | awk '{print $2}')
    print_step "使用 rustc $RUSTC_VER (来自 rustup)"
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

# ==================== 1. Build Rust ====================
if [[ "$FLUTTER_ONLY" == false ]]; then
    print_step "Building Rust core-bridge (mode: $BUILD_MODE)..."
    cd "$ROOT_DIR"

    if [[ "$BUILD_MODE" == "release" ]]; then
        TARGET_SUBDIR="release"
    else
        TARGET_SUBDIR="debug"
    fi

    # clash-lib 0.8.2 用了 #![feature(cfg_version)]，需要 RUSTC_BOOTSTRAP=1
    export RUSTC_BOOTSTRAP=1
    if [[ "$BUILD_MODE" == "release" ]]; then
        cargo build -p core-bridge --release
    else
        cargo build -p core-bridge
    fi

    DYLIB_PATH="$TARGET_DIR/$TARGET_SUBDIR/libcore_bridge.dylib"
    if [[ ! -f "$DYLIB_PATH" ]]; then
        print_err "dylib 没生成: $DYLIB_PATH"
        exit 1
    fi

    print_ok "Rust build done: $DYLIB_PATH ($(du -h "$DYLIB_PATH" | cut -f1))"
fi

# ==================== 2. 拷 dylib 到 macOS bundle ====================
if [[ "$RUST_ONLY" == false ]]; then
    APP_FRAMEWORKS_DIR="$APP_DIR/macos/Runner/Frameworks"
    mkdir -p "$APP_FRAMEWORKS_DIR"

    print_step "Copying dylib to Flutter bundle..."
    if [[ -f "$DYLIB_PATH" ]]; then
        cp "$DYLIB_PATH" "$APP_FRAMEWORKS_DIR/libcore_bridge.dylib"
        install_name_tool -id "@rpath/libcore_bridge.dylib" "$APP_FRAMEWORKS_DIR/libcore_bridge.dylib" 2>/dev/null || true
        print_ok "dylib copied to: $APP_FRAMEWORKS_DIR/libcore_bridge.dylib"
    else
        print_err "找不到 dylib: $DYLIB_PATH"
        exit 1
    fi
fi

# ==================== 3. Flutter build ====================
if [[ "$FLUTTER_AVAILABLE" == false ]]; then
    print_warn "flutter 不在 PATH，跳过 Flutter build"
    print_warn "装好 flutter 后跑: cd $APP_DIR && flutter run -d macos"
    exit 0
fi

if [[ "$RUST_ONLY" == false ]]; then
    print_step "Running flutter build macos --$BUILD_MODE..."
    cd "$APP_DIR"
    flutter build macos --"$BUILD_MODE" 2>&1 | tail -20

    # 重要：Flutter build 不会自动把 libcore_bridge.dylib 拷到 .app/Contents/Frameworks/
    # 我们手动复制一次（Xcode 不知道这个 dylib）
    APP_BUILD_DIR="$APP_DIR/build/macos/Build/Products/$BUILD_MODE/app.app/Contents/Frameworks"
    if [[ -d "$APP_BUILD_DIR" ]]; then
        if [[ -f "$APP_FRAMEWORKS_DIR/libcore_bridge.dylib" ]]; then
            cp "$APP_FRAMEWORKS_DIR/libcore_bridge.dylib" "$APP_BUILD_DIR/libcore_bridge.dylib"
            print_ok "dylib injected into .app: $APP_BUILD_DIR/libcore_bridge.dylib"
        fi
    fi
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
