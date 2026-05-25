#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_name="Orbisonic"
app_version="${1:-1.3}"
bundle_identifier="${ORBISONIC_BUNDLE_IDENTIFIER:-audio.orbisonic.app.current}"
bundle_path="$repo_root/${app_name}.app"
binary_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}"
resource_bundle_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}_${app_name}.bundle"
icon_path="$repo_root/Sources/Orbisonic/Resources/AppIcon/${app_name}.icns"
build_home="$repo_root/.build/dev-home"
module_cache_path="$repo_root/.build/module-cache"
plist_path="$bundle_path/Contents/Info.plist"
plist_buddy="/usr/libexec/PlistBuddy"

set_plist_string() {
  local key="$1"
  local value="$2"

  if ! "$plist_buddy" -c "Set :$key $value" "$plist_path" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :$key string $value" "$plist_path" >/dev/null
  fi
}

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

if [ -f "$icon_path" ]; then
  cp "$icon_path" "$bundle_path/Contents/Resources/${app_name}.icns"
fi

git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'not-available')"
if ! git diff --quiet --ignore-submodules -- 2>/dev/null || ! git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
  git_commit="${git_commit}-dirty"
fi
git_branch="$(git branch --show-current 2>/dev/null || true)"
if [ -n "$git_branch" ]; then
  set_plist_string "OrbisonicGitRefKind" "branch"
  set_plist_string "OrbisonicGitRefName" "$git_branch"
  set_plist_string "OrbisonicGitBranch" "$git_branch"
else
  set_plist_string "OrbisonicGitRefKind" "commit"
  set_plist_string "OrbisonicGitRefName" "$git_commit"
  set_plist_string "OrbisonicGitBranch" "detached"
fi
set_plist_string "OrbisonicGitCommit" "$git_commit"
set_plist_string "CFBundleIdentifier" "$bundle_identifier"
set_plist_string "CFBundleShortVersionString" "$app_version"
set_plist_string "CFBundleVersion" "$app_version"
set_plist_string "NSMicrophoneUsageDescription" "macOS labels all audio input access as Microphone permission. Orbisonic uses it to capture Orbisonic Roon Input or Orbisonic Aux Cable for live sources, not the Mac mic unless you choose it."

xattr -cr "$bundle_path"
codesign --force --deep --sign - "$bundle_path"
codesign --verify --deep --strict --verbose=2 "$bundle_path"
plutil -lint "$plist_path"

echo "Refreshed $bundle_path"
