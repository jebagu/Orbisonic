#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_path="$repo_root/Orbisonic.app"
bundle_id="audio.orbisonic.app"

if [ ! -d "$bundle_path" ]; then
  echo "Missing app bundle: $bundle_path" >&2
  exit 1
fi

/usr/bin/osascript <<OSA >/dev/null 2>&1 || true
if application id "$bundle_id" is running then
  tell application id "$bundle_id"
    quit
  end tell
end if
OSA

for _ in {1..30}; do
  if ! /usr/bin/pgrep -x "Orbisonic" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

if /usr/bin/pgrep -x "Orbisonic" >/dev/null 2>&1; then
  echo "Orbisonic is still running; quit it manually before reopening." >&2
  exit 1
fi

/usr/bin/open "$bundle_path"

echo "Opened $bundle_path"
