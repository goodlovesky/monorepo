#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo "macOS packaging must run on macOS" >&2; exit 1; }
for command in flutter python3 xcodebuild hdiutil codesign; do command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }; done
case "${1:-}" in -h|--help) echo "Usage: $0 [--clean] [--skip-tests]"; exit 0;; esac
CLEAN=false; SKIP_TESTS=false
while (($#)); do case "$1" in --clean) CLEAN=true;; --skip-tests) SKIP_TESTS=true;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; shift; done
$CLEAN && { (cd "$ROOT/app" && flutter clean); rm -rf "$ROOT/dist/macos"; }
if $SKIP_TESTS; then
  # tools/build_macos.sh owns the release/package contract; focused CI may use
  # this flag only to avoid a duplicate test pass.
  (cd "$ROOT/app" && flutter pub get && flutter build macos --release)
  "$ROOT/tools/download_mihomo.sh"
  APP="$ROOT/app/build/macos/Build/Products/Release/Clash RS.app"
  install -m 755 "$ROOT/app/macos/Runner/Resources/mihomo" "$APP/Contents/Resources/mihomo"
  codesign --force --deep --sign - "$APP"
  mkdir -p "$ROOT/dist/macos/dmg-root"
  ditto "$APP" "$ROOT/dist/macos/Clash RS.app"
  ditto "$APP" "$ROOT/dist/macos/dmg-root/Clash RS.app"
  ln -sfn /Applications "$ROOT/dist/macos/dmg-root/Applications"
  hdiutil create -volname "Clash RS" -srcfolder "$ROOT/dist/macos/dmg-root" -ov -format UDZO "$ROOT/dist/macos/Clash-RS-macOS.dmg"
  shasum -a 256 "$ROOT/dist/macos/Clash-RS-macOS.dmg" > "$ROOT/dist/macos/SHA256.txt"
else
  "$ROOT/tools/build_macos.sh"
fi
version="$(awk '/^version:/{split($2,v,"+"); print v[1]; exit}' "$ROOT/app/pubspec.yaml")"
flutter_output="$(flutter --version 2>&1)"; flutter_version="${flutter_output%%$'\n'*}"
cat > "$ROOT/dist/macos/BUILD-ENVIRONMENT.txt" <<EOF
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
app_version=$version
flutter=$flutter_version
macos=$(sw_vers -productVersion)
EOF
python3 - "$ROOT/dist/macos" "$version" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1]); packages=[]
for p in sorted(root.glob("*.dmg")):
    packages.append({"name":p.name,"size":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
(root/"BUILD-MANIFEST.json").write_text(json.dumps({"schema":1,"product":"Clash RS","version":sys.argv[2],"platform":"macos","packages":packages},indent=2)+"\n")
PY
(cd "$ROOT/dist/macos" && shasum -a 256 BUILD-ENVIRONMENT.txt BUILD-MANIFEST.json *.dmg > SHA256.txt)
echo "macOS packages: $ROOT/dist/macos"
