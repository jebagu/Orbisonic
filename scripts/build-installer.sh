#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-1.3}"
app_name="Orbisonic"
bundle_path="$repo_root/${app_name}.app"
binary_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}"
resource_bundle_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}_${app_name}.bundle"
icon_path="$repo_root/Sources/Orbisonic/Resources/AppIcon/${app_name}.icns"
pkg_path="$repo_root/installer/${app_name}-${version}.pkg"
root_path="$repo_root/.build/installer-root"
plist_path="$bundle_path/Contents/Info.plist"
plist_buddy="/usr/libexec/PlistBuddy"

set_plist_string() {
  local key="$1"
  local value="$2"

  if ! "$plist_buddy" -c "Set :$key $value" "$plist_path" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :$key string $value" "$plist_path" >/dev/null
  fi
}

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

cp "$binary_path" "$bundle_path/Contents/MacOS/$app_name"
chmod +x "$bundle_path/Contents/MacOS/$app_name"
if [ -d "$resource_bundle_path" ]; then
  rm -rf "$bundle_path/Contents/Resources/$(basename "$resource_bundle_path")"
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
set_plist_string "NSMicrophoneUsageDescription" "macOS labels all audio input access as Microphone permission. Orbisonic uses it to capture Orbisonic Roon Input or Orbisonic Aux Cable for live sources, not the Mac mic unless you choose it."
set_plist_string "CFBundleIdentifier" "audio.orbisonic.app"
set_plist_string "CFBundleShortVersionString" "$version"
set_plist_string "CFBundleVersion" "$version"

xattr -cr "$bundle_path"
codesign --force --deep --sign - "$bundle_path"
codesign --verify --deep --strict --verbose=2 "$bundle_path"
plutil -lint "$plist_path"

rm -rf "$root_path"
mkdir -p "$root_path/Applications" "$repo_root/installer"
cp -R "$bundle_path" "$root_path/Applications/$app_name.app"

pkgbuild \
  --root "$root_path" \
  --identifier "audio.orbisonic.app.pkg" \
  --version "$version" \
  --install-location "/" \
  "$pkg_path"

echo "Built $pkg_path"
