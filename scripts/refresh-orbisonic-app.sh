#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_name="Orbisonic"
bundle_path="$repo_root/${app_name}.app"
binary_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}"
resource_bundle_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}_${app_name}.bundle"
build_home="$repo_root/.build/dev-home"
module_cache_path="$repo_root/.build/module-cache"

if [ ! -d "$bundle_path" ]; then
  echo "Missing app bundle: $bundle_path" >&2
  exit 1
fi

mkdir -p "$build_home" "$module_cache_path"

env \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  HOME="$build_home" \
  CLANG_MODULE_CACHE_PATH="$module_cache_path" \
  swift build

if [ ! -x "$binary_path" ]; then
  echo "Missing built executable: $binary_path" >&2
  exit 1
fi

cp "$binary_path" "$bundle_path/Contents/MacOS/$app_name"
chmod +x "$bundle_path/Contents/MacOS/$app_name"

if [ -d "$resource_bundle_path" ]; then
  resource_bundle_name="$(basename "$resource_bundle_path")"
  rm -rf "$bundle_path/Contents/Resources/$resource_bundle_name"
  cp -R "$resource_bundle_path" "$bundle_path/Contents/Resources/"
fi

xattr -cr "$bundle_path"
codesign --force --deep --sign - "$bundle_path"
codesign --verify --deep --strict --verbose=2 "$bundle_path"
plutil -lint "$bundle_path/Contents/Info.plist"

echo "Refreshed $bundle_path"
