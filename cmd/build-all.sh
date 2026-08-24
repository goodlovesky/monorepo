#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in -h|--help) echo "Usage: $0 [shared build arguments]"; exit 0;; esac
case "$(uname -s)" in
  Darwin)
    "$ROOT/cmd/build-android.sh" "$@"
    "$ROOT/cmd/build-macos.sh" "$@"
    ;;
  Linux)
    "$ROOT/cmd/build-android.sh" "$@"
    "$ROOT/cmd/build-linux.sh" "$@"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Use PowerShell for Windows: .\\cmd\\build-windows.ps1" >&2
    exit 2
    ;;
  *) echo "Unsupported host: $(uname -s)" >&2; exit 1 ;;
esac
