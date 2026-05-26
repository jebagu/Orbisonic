#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-1.3.1}"
app_name="Orbisonic"
bundle_path="$repo_root/${app_name}.app"
binary_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}"
resource_bundle_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}_${app_name}.bundle"
icon_path="$repo_root/Sources/Orbisonic/Resources/AppIcon/${app_name}.icns"
pkg_path="$repo_root/installer/${app_name}-${version}.pkg"
plist_path="$bundle_path/Contents/Info.plist"
plist_buddy="/usr/libexec/PlistBuddy"

set_plist_string() {
  local key="$1"
  local value="$2"

  if ! "$plist_buddy" -c "Set :$key $value" "$plist_path" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :$key string $value" "$plist_path" >/dev/null
  fi
}

ensure_resource_bundle_info() {
  local bundle_dir="$1"
  local bundle_plist="$bundle_dir/Info.plist"

  if [ ! -d "$bundle_dir" ]; then
    return 0
  fi

  if [ ! -f "$bundle_plist" ]; then
    /usr/bin/plutil -create xml1 "$bundle_plist"
  fi

  if ! "$plist_buddy" -c "Print :CFBundleIdentifier" "$bundle_plist" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :CFBundleIdentifier string audio.orbisonic.resources" "$bundle_plist" >/dev/null
  fi
  if ! "$plist_buddy" -c "Print :CFBundleName" "$bundle_plist" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :CFBundleName string Orbisonic Resources" "$bundle_plist" >/dev/null
  fi
  if ! "$plist_buddy" -c "Print :CFBundlePackageType" "$bundle_plist" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :CFBundlePackageType string BNDL" "$bundle_plist" >/dev/null
  fi
  if ! "$plist_buddy" -c "Print :CFBundleShortVersionString" "$bundle_plist" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :CFBundleShortVersionString string $version" "$bundle_plist" >/dev/null
  fi
  if ! "$plist_buddy" -c "Print :CFBundleVersion" "$bundle_plist" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :CFBundleVersion string $version" "$bundle_plist" >/dev/null
  fi
  plutil -lint "$bundle_plist" >/dev/null
}

validate_component_payload() {
  local package_path="$1"
  local archive_listing

  pkgutil --payload-files "$package_path" >/dev/null
  archive_listing="$(xar -tf "$package_path")"
  case "$archive_listing" in
    *"Payload/"*)
      echo "Malformed package payload in $package_path: Payload expanded as loose archive files." >&2
      exit 1
      ;;
  esac
}

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

cp "$binary_path" "$bundle_path/Contents/MacOS/$app_name"
chmod +x "$bundle_path/Contents/MacOS/$app_name"
if [ -d "$resource_bundle_path" ]; then
  resource_bundle_name="$(basename "$resource_bundle_path")"
  resource_bundle_target="$bundle_path/Contents/Resources/$resource_bundle_name"
  rm -rf "$resource_bundle_target"
  cp -R "$resource_bundle_path" "$bundle_path/Contents/Resources/"
  ensure_resource_bundle_info "$resource_bundle_target"
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

mkdir -p "$repo_root/installer"

pkgbuild \
  --component "$bundle_path" \
  --identifier "audio.orbisonic.app.pkg" \
  --version "$version" \
  --install-location "/Applications" \
  "$pkg_path"

validate_component_payload "$pkg_path"
echo "Built $pkg_path"
