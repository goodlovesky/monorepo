#!/usr/bin/env bash
# 下载经过固定 SHA256 校验的 macOS arm64 + amd64 Mihomo，并合成为通用 Mach-O。
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$ROOT_DIR/app/macos/Runner/Resources"
DEST="$DEST_DIR/mihomo"
VERSION="v1.19.30"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

existing_version=""
[[ -x "$DEST" ]] && existing_version="$("$DEST" -v 2>&1 || true)"
if [[ -x "$DEST" && "$FORCE" == false ]] && \
   file "$DEST" | grep -q 'universal binary' && \
   [[ "$existing_version" == *"$VERSION"* ]]; then
  echo "已存在通用版 $VERSION: $DEST"
  exit 0
fi

mkdir -p "$DEST_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for arch in arm64 amd64; do
  if [[ "$arch" == arm64 ]]; then
    asset="mihomo-darwin-arm64-go122-v1.19.30.gz"
    expected="b87f4b02e2fa1bec7d3e1399d8bfa9f5a300610c75a98263e225144d4a85646f"
  else
    asset="mihomo-darwin-amd64-v2-go122-v1.19.30.gz"
    expected="2091e63e91d8b1aee7b24a750c5fe4a6b5271c4942315017ea9bd0f347b78c96"
  fi
  archive="$tmp/$asset"
  url="https://github.com/MetaCubeX/mihomo/releases/download/$VERSION/$asset"
  curl -fL --retry 3 --connect-timeout 30 --max-time 600 -o "$archive" "$url"
  actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    echo "SHA256 mismatch for $asset: expected=$expected actual=$actual" >&2
    exit 1
  }
  gzip -dc "$archive" > "$tmp/$arch"
  chmod 755 "$tmp/$arch"
done
lipo -create "$tmp/arm64" "$tmp/amd64" -output "$DEST"
chmod 755 "$DEST"
file "$DEST"
version_output="$("$DEST" -v 2>&1)"
echo "${version_output%%$'\n'*}"
