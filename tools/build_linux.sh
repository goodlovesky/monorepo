#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
DIST="$ROOT/dist/linux"
CLEAN=false
SKIP_TESTS=false
BUILD_DEB=true
BUILD_TAR=true

while (($#)); do
  case "$1" in
    --clean) CLEAN=true ;;
    --skip-tests) SKIP_TESTS=true ;;
    --deb-only) BUILD_TAR=false ;;
    --tar-only) BUILD_DEB=false ;;
    -h|--help)
      echo "Usage: $0 [--clean] [--skip-tests] [--deb-only|--tar-only]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux ]] || { echo "Linux packaging must run on Linux" >&2; exit 1; }
for command in flutter cmake ninja curl gzip tar python3 sha256sum; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done
$BUILD_DEB && command -v dpkg-deb >/dev/null || {
  $BUILD_DEB && { echo "Missing command: dpkg-deb" >&2; exit 1; }
  true
}

version="$(awk '/^version:/{split($2,v,"+"); print v[1]; exit}' "$APP/pubspec.yaml")"
build_number="$(awk '/^version:/{split($2,v,"+"); print v[2]; exit}' "$APP/pubspec.yaml")"
[[ -n "$version" && -n "$build_number" ]] || { echo "Invalid app version" >&2; exit 1; }

$CLEAN && { rm -rf "$APP/build/linux" "$DIST"; }
mkdir -p "$DIST"

if ! $SKIP_TESTS; then
  (cd "$APP" && flutter pub get && flutter analyze && flutter test)
fi
"$ROOT/tools/download_mihomo_linux.sh"
(cd "$APP" && flutter build linux --release --build-name="$version" --build-number="$build_number")

BUNDLE="$APP/build/linux/x64/release/bundle"
[[ -x "$BUNDLE/clash_rs" ]] || { echo "Missing Linux executable: $BUNDLE/clash_rs" >&2; exit 1; }
install -m 755 "$APP/linux/runner/resources/mihomo" "$BUNDLE/mihomo"
install -m 644 "$APP/linux/runner/resources/LINUX-RUNTIME.txt" "$BUNDLE/LINUX-RUNTIME.txt"

desktop="$DIST/clash-rs.desktop"
cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Clash RS
Comment=Clash RS desktop proxy client
Exec=/opt/clash-rs/clash_rs
Icon=clash-rs
Terminal=false
Categories=Network;
StartupWMClass=com.proxyapp.app
EOF

if $BUILD_TAR; then
  tarball="$DIST/ClashRS-$version-linux-x64.tar.gz"
  tar -C "$BUNDLE" -czf "$tarball" .
fi

if $BUILD_DEB; then
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  mkdir -p "$stage/DEBIAN" "$stage/opt/clash-rs" \
    "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/256x256/apps"
  cp -a "$BUNDLE/." "$stage/opt/clash-rs/"
  install -m 644 "$desktop" "$stage/usr/share/applications/clash-rs.desktop"
  install -m 644 "$APP/assets/images/app_icon.png" \
    "$stage/usr/share/icons/hicolor/256x256/apps/clash-rs.png"
  installed_size="$(du -sk "$stage/opt/clash-rs" | awk '{print $1}')"
  cat > "$stage/DEBIAN/control" <<EOF
Package: clash-rs
Version: $version
Architecture: amd64
Maintainer: Clash RS
Depends: libgtk-3-0, libblkid1, liblzma5
Installed-Size: $installed_size
Section: net
Priority: optional
Description: Clash RS Flutter desktop proxy client
EOF
  cat > "$stage/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v setcap >/dev/null 2>&1; then
  setcap cap_net_admin,cap_net_raw+ep /opt/clash-rs/mihomo || true
fi
exit 0
EOF
  cat > "$stage/DEBIAN/prerm" <<'EOF'
#!/bin/sh
pkill -TERM -f '^/opt/clash-rs/mihomo ' 2>/dev/null || true
exit 0
EOF
  chmod 755 "$stage/DEBIAN/postinst" "$stage/DEBIAN/prerm"
  dpkg-deb --root-owner-group --build "$stage" "$DIST/clash-rs_${version}_amd64.deb"
fi

cat > "$DIST/BUILD-ENVIRONMENT.txt" <<EOF
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
app_version=$version
build_number=$build_number
architecture=amd64
flutter=$(flutter --version | head -1)
linux=$(uname -srmo)
EOF

python3 - "$DIST" "$version" "$build_number" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
files = []
for path in sorted(root.iterdir()):
    if path.is_file() and path.name not in {"SHA256.txt", "BUILD-MANIFEST.json", "clash-rs.desktop"}:
        files.append({"name": path.name, "size": path.stat().st_size,
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
(root / "BUILD-MANIFEST.json").write_text(json.dumps({
    "schema": 1, "product": "Clash RS", "version": sys.argv[2],
    "build": int(sys.argv[3]), "architecture": "amd64", "packages": files,
}, ensure_ascii=False, indent=2) + "\n")
PY
(cd "$DIST" && {
  artifacts=(BUILD-ENVIRONMENT.txt BUILD-MANIFEST.json)
  while IFS= read -r name; do artifacts+=("$name"); done < <(
    find . -maxdepth 1 -type f \( -name 'ClashRS-*' -o -name 'clash-rs_*.deb' \) \
      -printf '%f\n' | sort
  )
  sha256sum "${artifacts[@]}" > SHA256.txt
})
echo "Linux packages: $DIST"
