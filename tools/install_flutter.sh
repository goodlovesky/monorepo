#!/usr/bin/env bash
#
# install_flutter.sh — 一键安装 Flutter（国内镜像版）
#
# 用途:
#   绕过 Google 官方下载（国内慢/不通），用 storage.flutter-io.cn 镜像
#
# 特性:
#   - 自动探测 macOS 架构 (arm64 / x86_64)
#   - 自动选最新 stable
#   - 国内镜像下载，pub 也用国内镜像
#   - 自动配 PATH（写到 ~/.zshrc 和 ~/.bash_profile）
#   - 自动设 git safe.directory
#   - 自动跑 flutter doctor
#
# 用法:
#   ./install_flutter.sh                  # 装最新 stable
#   ./install_flutter.sh --version 3.44.9 # 装指定版本
#   ./install_flutter.sh --path ~/flutter # 装到指定目录
#   ./install_flutter.sh --doctor-only    # 跳过下载，只跑 doctor
#
# 卸载:
#   rm -rf ~/development/flutter
#   编辑 ~/.zshrc 删掉 PATH 那行

set -euo pipefail

# ==================== 颜色 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[i]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

# ==================== 默认值 ====================
DEFAULT_INSTALL_PATH="$HOME/development/flutter"
INSTALL_PATH="${FLUTTER_ROOT:-$DEFAULT_INSTALL_PATH}"
MIRROR_BASE="https://storage.flutter-io.cn"
PUB_MIRROR="https://pub.flutter-io.cn"
VERSION_OVERRIDE=""
DOCTOR_ONLY=false

# ==================== 解析参数 ====================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --doctor-only)
            DOCTOR_ONLY=true
            shift
            ;;
        -h|--help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            error "未知参数: $1"
            exit 1
            ;;
    esac
done

# ==================== 系统检查 ====================
info "检查系统..."

if [[ "$(uname -s)" != "Darwin" ]]; then
    error "本脚本只支持 macOS (检测到: $(uname -s))"
    error "Linux 用户请参考 README 改用 tar.xz 流程"
    exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
    arm64|aarch64)
        info "架构: Apple Silicon (arm64)"
        ;;
    x86_64)
        info "架构: Intel (x86_64)"
        ;;
    *)
        error "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# ==================== doctor-only 模式 ====================
if [[ "$DOCTOR_ONLY" == true ]]; then
    if [[ ! -x "$INSTALL_PATH/bin/flutter" ]]; then
        error "flutter 不在 $INSTALL_PATH/bin/flutter"
        exit 1
    fi
    info "跑 flutter doctor..."
    "$INSTALL_PATH/bin/flutter" doctor -v
    exit 0
fi

# ==================== 探测最新版本 ====================
info "从国内镜像查询 Flutter 版本列表..."

RELEASES_JSON="$(curl -fsSL --connect-timeout 10 --max-time 30 \
    "$MIRROR_BASE/flutter_infra_release/releases/releases_macos.json" 2>/dev/null || true)"

if [[ -z "$RELEASES_JSON" ]]; then
    error "无法访问镜像 $MIRROR_BASE/flutter_infra_release/releases/releases_macos.json"
    error "检查网络或代理设置"
    exit 1
fi

if [[ -n "$VERSION_OVERRIDE" ]]; then
    VERSION="$VERSION_OVERRIDE"
    info "使用指定版本: $VERSION"
    ARCHIVE_NAME="stable/macos/flutter_macos_${VERSION}-stable.zip"
else
    # 用 python 解析（macOS 默认有 python3）
    VERSION="$(echo "$RELEASES_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
seen = set()
for r in d['releases']:
    if r['channel'] == 'stable' and r['version'] not in seen:
        seen.add(r['version'])
        print(r['version'])
        break
" 2>/dev/null)"

    if [[ -z "$VERSION" ]]; then
        error "解析版本失败"
        exit 1
    fi
    info "最新 stable: $VERSION"
    ARCHIVE_NAME="stable/macos/flutter_macos_${VERSION}-stable.zip"
fi

DOWNLOAD_URL="$MIRROR_BASE/flutter_infra_release/releases/$ARCHIVE_NAME"

# macOS SDK 是 universal (arm64 + x64 都包含)，不需要分架构
EXPECTED_SIZE_MB="~700-800"

info "下载: $DOWNLOAD_URL"
info "目标: $INSTALL_PATH (${EXPECTED_SIZE_MB} MB)"

# ==================== 检查已存在 ====================
if [[ -d "$INSTALL_PATH" ]] && [[ -x "$INSTALL_PATH/bin/flutter" ]]; then
    EXISTING_VERSION="$("$INSTALL_PATH/bin/flutter" --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")"
    warn "检测到已安装 Flutter: $EXISTING_VERSION @ $INSTALL_PATH"
    read -r -p "$(echo -e ${YELLOW}是否覆盖安装？[y/N]${NC} )" REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        info "保持现有安装，退出"
        exit 0
    fi
    warn "将删除旧版本..."
    rm -rf "$INSTALL_PATH"
fi

# ==================== 下载 ====================
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

info "开始下载（用国内镜像）..."
if ! curl -fL --connect-timeout 15 --max-time 600 \
        -o flutter.zip --progress-bar "$DOWNLOAD_URL"; then
    error "下载失败"
    error "可能原因："
    error "  1. 网络问题（试一下 https_proxy=http://127.0.0.1:7890）"
    error "  2. 镜像同步延迟（等几分钟再试）"
    error "  3. 版本号不存在（--version 输错了？）"
    exit 1
fi

DOWNLOADED_SIZE_MB=$(( $(stat -f%z flutter.zip 2>/dev/null || stat -c%s flutter.zip) / 1024 / 1024 ))
success "下载完成 ($DOWNLOADED_SIZE_MB MB)"

# ==================== 解压 ====================
info "解压到 $INSTALL_PATH..."
mkdir -p "$(dirname "$INSTALL_PATH")"

if ! unzip -q flutter.zip; then
    error "解压失败"
    exit 1
fi

# zip 解压出来是 flutter/ 目录
if [[ ! -d "flutter" ]]; then
    error "解压后找不到 flutter/ 目录"
    exit 1
fi

# 移动到目标路径
mv flutter "$INSTALL_PATH"
success "解压完成"

# ==================== 配 PATH ====================
info "配置 PATH..."

# 检查是否已经配过
PATH_LINE="export PATH=\"\$PATH:\$FLUTTER_ROOT/bin\""
EXPORT_LINE="export FLUTTER_ROOT=\"${INSTALL_PATH}\""

# 写入 ~/.zshrc（macOS 默认 shell）
if [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "FLUTTER_ROOT" "$HOME/.zshrc"; then
        {
            echo ""
            echo "# Flutter (added by install_flutter.sh)"
            echo "$EXPORT_LINE"
            echo "$PATH_LINE"
        } >> "$HOME/.zshrc"
        success "已写入 ~/.zshrc"
    else
        warn "~/.zshrc 已有 Flutter 配置（跳过）"
    fi
fi

# 也写到 ~/.bash_profile 兼容 bash
if [[ -f "$HOME/.bash_profile" ]] || [[ -f "$HOME/.bashrc" ]]; then
    for f in "$HOME/.bash_profile" "$HOME/.bashrc"; do
        if [[ -f "$f" ]] && ! grep -q "FLUTTER_ROOT" "$f"; then
            {
                echo ""
                echo "# Flutter (added by install_flutter.sh)"
                echo "$EXPORT_LINE"
                echo "$PATH_LINE"
            } >> "$f"
        fi
    done
    success "已写入 ~/.bash_profile / ~/.bashrc"
fi

# 当前 shell 立即生效
export FLUTTER_ROOT="$INSTALL_PATH"
export PATH="$PATH:$INSTALL_PATH/bin"

# ==================== 配 git safe.directory ====================
info "设置 git safe.directory（避免解压后 git 警告）..."
git config --global --add safe.directory "$INSTALL_PATH" || true

# ==================== 配国内 pub 镜像 ====================
info "配置 Dart pub 国内镜像..."

PUB_HOSTED_URL_LINE="export PUB_HOSTED_URL=\"$PUB_MIRROR\""
FLUTTER_STORAGE_BASE_URL_LINE="export FLUTTER_STORAGE_BASE_URL=\"$MIRROR_BASE\""

if [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "PUB_HOSTED_URL" "$HOME/.zshrc"; then
        {
            echo ""
            echo "# Flutter pub 镜像 (added by install_flutter.sh)"
            echo "$FLUTTER_STORAGE_BASE_URL_LINE"
            echo "$PUB_HOSTED_URL_LINE"
        } >> "$HOME/.zshrc"
    fi
fi

export PUB_HOSTED_URL="$PUB_MIRROR"
export FLUTTER_STORAGE_BASE_URL="$MIRROR_BASE"

# ==================== 初始化 flutter ====================
info "运行 flutter --version 触发首次初始化..."

# 用刚解压的二进制（绝对路径）
if ! "$INSTALL_PATH/bin/flutter" --version; then
    error "flutter --version 失败"
    error "试试手动跑: $INSTALL_PATH/bin/flutter --version"
    exit 1
fi

# 关闭分析（首次跑会拉 analytics，挡一下）
"$INSTALL_PATH/bin/flutter" --disable-analytics 2>/dev/null || true
"$INSTALL_PATH/bin/flutter" config --no-analytics 2>/dev/null || true

# ==================== doctor ====================
info "跑 flutter doctor..."
"$INSTALL_PATH/bin/flutter" doctor || warn "doctor 报告有问题（一般不影响开发）"

# ==================== 完成 ====================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ Flutter $VERSION 安装成功${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  位置: $INSTALL_PATH"
echo "  版本: $VERSION"
echo ""
echo -e "  ${YELLOW}让当前 shell 立即生效:${NC}"
echo "    export FLUTTER_ROOT=\"$INSTALL_PATH\""
echo "    export PATH=\"\$PATH:\$FLUTTER_ROOT/bin\""
echo ""
echo "  新打开的 shell 自动生效（已写入 ~/.zshrc）"
echo ""
echo "  后续命令："
echo "    flutter doctor       # 检查环境"
echo "    flutter --version    # 查看版本"
echo "    flutter create myapp # 创建项目"
echo ""
echo -e "  ${YELLOW}如果 doctor 报红，按提示装缺失组件：${NC}"
echo "    CocoaPods:   sudo gem install cocoapods"
echo "    Xcode CLT:   xcode-select --install"
echo "    Android:     https://developer.android.com/studio"
echo ""
echo "  卸载:"
echo "    rm -rf $INSTALL_PATH"
echo "    编辑 ~/.zshrc 删掉 FLUTTER_ROOT 相关行"
echo ""
