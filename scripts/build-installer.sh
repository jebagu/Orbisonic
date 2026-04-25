#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-0.1.0}"
app_name="Orbisonic"
bundle_path="$repo_root/${app_name}.app"
binary_path="$repo_root/.build/arm64-apple-macosx/debug/${app_name}"
pkg_path="$repo_root/installer/${app_name}-${version}.pkg"
root_path="$repo_root/.build/installer-root"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build

cp "$binary_path" "$bundle_path/Contents/MacOS/$app_name"
chmod +x "$bundle_path/Contents/MacOS/$app_name"

/usr/libexec/PlistBuddy -c "Set :NSMicrophoneUsageDescription macOS labels all audio input access as Microphone permission. Orbisonic uses it to capture Orbisonic Roon Input or Orbisonic Aux Cable for live sources, not the Mac mic unless you choose it." "$bundle_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier audio.orbisonic.app" "$bundle_path/Contents/Info.plist"

codesign --force --deep --sign - "$bundle_path"
codesign --verify --deep --strict --verbose=2 "$bundle_path"
plutil -lint "$bundle_path/Contents/Info.plist"

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
