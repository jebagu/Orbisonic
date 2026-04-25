#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_dir="$repo_root/Sources/Orbisonic/Resources/RoonBridge"
target_dir="${HOME}/Library/Application Support/Orbisonic/RoonBridge"

mkdir -p "$target_dir"
cp "$source_dir/package.json" "$target_dir/package.json"
cp "$source_dir/bridge.js" "$target_dir/bridge.js"

cd "$target_dir"
npm install --omit=dev

printf '%s\n' "Installed Orbisonic Roon Bridge dependencies."
