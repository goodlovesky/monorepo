#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT/app/linux/runner/resources"
DEST="$DEST_DIR/mihomo"
VERSION="v1.19.30"
ASSET="mihomo-linux-amd64-v1.19.30.gz"
SHA256="cf06ce2c7d1421bdbda14ee4a5b6046672dc35ebf8eecd8e77504ec3c0ed9a84"
URL="https://github.com/MetaCubeX/mihomo/releases/download/$VERSION/$ASSET"

mkdir -p "$DEST_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/$ASSET"
curl -fL --retry 3 --connect-timeout 30 --max-time 600 -o "$archive" "$URL"
actual="$(sha256sum "$archive" | awk '{print $1}')"
[[ "$actual" == "$SHA256" ]] || {
  echo "SHA256 mismatch for $ASSET: expected=$SHA256 actual=$actual" >&2
  exit 1
}
gzip -dc "$archive" > "$DEST"
chmod 755 "$DEST"
version_output="$("$DEST" -v 2>&1)"
echo "${version_output%%$'\n'*}"
cat > "$DEST_DIR/LINUX-RUNTIME.txt" <<EOF
mihomo_version=$VERSION
mihomo_asset=$ASSET
mihomo_archive_sha256=$SHA256
architecture=amd64
EOF
echo "Linux runtime ready: $DEST"
