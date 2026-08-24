#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
DIST="$ROOT/dist/android"
CLEAN=false; SKIP_TESTS=false; APK=true; AAB=true
while (($#)); do
  case "$1" in
    --clean) CLEAN=true ;;
    --skip-tests) SKIP_TESTS=true ;;
    --apk-only) AAB=false ;;
    --aab-only) APK=false ;;
    -h|--help) echo "Usage: $0 [--clean] [--skip-tests] [--apk-only|--aab-only]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac; shift
done
for command in flutter java cargo python3; do command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }; done
[[ -n "${ANDROID_NDK_HOME:-}" ]] || { echo "ANDROID_NDK_HOME is required" >&2; exit 1; }
version="$(awk '/^version:/{split($2,v,"+"); print v[1]; exit}' "$APP/pubspec.yaml")"
$CLEAN && { (cd "$APP" && flutter clean); rm -rf "$DIST"; }
mkdir -p "$DIST"
"$ROOT/tools/build_android.sh"
if ! $SKIP_TESTS; then (cd "$APP" && flutter pub get && flutter analyze && flutter test); fi
if $APK; then
  (cd "$APP" && flutter build apk --release)
  cp "$APP/build/app/outputs/flutter-apk/app-release.apk" "$DIST/ClashRS-$version-android.apk"
fi
if $AAB; then
  (cd "$APP" && flutter build appbundle --release)
  cp "$APP/build/app/outputs/bundle/release/app-release.aab" "$DIST/ClashRS-$version-android.aab"
fi
flutter_output="$(flutter --version 2>&1)"; flutter_version="${flutter_output%%$'\n'*}"
java_output="$(java -version 2>&1)"; java_version="${java_output%%$'\n'*}"
cat > "$DIST/BUILD-ENVIRONMENT.txt" <<EOF
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
app_version=$version
flutter=$flutter_version
java=$java_version
EOF
python3 - "$DIST" "$version" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1]); packages=[]
for p in sorted(root.glob("ClashRS-*")):
    packages.append({"name":p.name,"size":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
(root/"BUILD-MANIFEST.json").write_text(json.dumps({"schema":1,"product":"Clash RS","version":sys.argv[2],"platform":"android","packages":packages},indent=2)+"\n")
PY
(cd "$DIST" && shasum -a 256 BUILD-ENVIRONMENT.txt BUILD-MANIFEST.json ClashRS-* > SHA256.txt)
echo "Android packages: $DIST"
