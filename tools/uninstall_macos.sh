#!/bin/zsh
set -euo pipefail

EXECUTE=false
PURGE_DATA=false
for arg in "$@"; do
  case "$arg" in
    --execute) EXECUTE=true ;;
    --purge-data) PURGE_DATA=true ;;
    -h|--help)
      echo "Usage: $0 --execute [--purge-data]"
      exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$EXECUTE" != true ]]; then
  echo "Preview only: add --execute to remove Clash RS runtime state."
  echo "Profiles and settings are preserved unless --purge-data is supplied."
  exit 0
fi

UID_VALUE=$(/usr/bin/id -u)
PLIST="$HOME/Library/LaunchAgents/com.proxyapp.clashrs.plist"
/bin/launchctl bootout "gui/$UID_VALUE/com.proxyapp.clashrs" >/dev/null 2>&1 || true
/bin/rm -f "$PLIST"

# Stop only the bundled mihomo whose executable path belongs to Clash RS.
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  command=$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)
  if [[ "$command" == *"/Clash RS.app/Contents/Resources/mihomo"* ]]; then
    /usr/bin/osascript -e "do shell script \"/bin/kill -TERM $pid\" with administrator privileges"
  fi
done < <(/usr/bin/pgrep -x mihomo 2>/dev/null || true)

# Remove the legacy setuid helper shipped by pre-1.0 development builds.
if [[ -e /Library/PrivilegedHelperTools/com.proxyapp.clashrs.helper ]]; then
  /usr/bin/osascript -e 'do shell script "/bin/rm -f /Library/PrivilegedHelperTools/com.proxyapp.clashrs.helper" with administrator privileges'
fi

SUPPORT="$HOME/Library/Application Support/ClashRS"
/bin/rm -f "$SUPPORT/desktop-runtime.json" "$SUPPORT/tun-recovery.json"
if [[ "$PURGE_DATA" == true ]]; then
  /bin/rm -rf "$SUPPORT"
  /bin/rm -rf "$HOME/Library/Preferences/com.proxyapp.clashrs.plist"
  /bin/rm -rf "$HOME/Library/Logs/ClashRS"
fi

echo "Clash RS runtime cleanup complete. Data purged: $PURGE_DATA"
