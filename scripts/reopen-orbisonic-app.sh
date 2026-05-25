#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_path="$repo_root/Orbisonic.app"
bundle_id="${ORBISONIC_BUNDLE_IDENTIFIER:-audio.orbisonic.app.current}"

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

sleep 0.6

/usr/bin/open -n -F "$bundle_path"

echo "Opened $bundle_path"
