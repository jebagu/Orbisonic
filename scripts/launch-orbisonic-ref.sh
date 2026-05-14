#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <git-ref> <branch|release|commit> <display-name>" >&2
  exit 64
fi

requested_ref="$1"
ref_kind="$2"
display_name="$3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
launch_root="$repo_root/.local/orbisonic-launch-worktrees"
bootstrap_bundle="$repo_root/Orbisonic.app"
safe_name="$(printf '%s-%s' "$ref_kind" "$display_name" | tr '/: ' '---' | tr -cd 'A-Za-z0-9._-')"
worktree_path="$launch_root/$safe_name"
app_name="Orbisonic"
bundle_path="$worktree_path/${app_name}.app"
plist_path="$bundle_path/Contents/Info.plist"
plist_buddy="/usr/libexec/PlistBuddy"

if [ "$ref_kind" != "branch" ] && [ "$ref_kind" != "release" ] && [ "$ref_kind" != "commit" ]; then
  echo "Unsupported launcher kind: $ref_kind" >&2
  exit 64
fi

if [ ! -d "$bootstrap_bundle" ]; then
  echo "Missing bootstrap app bundle: $bootstrap_bundle" >&2
  exit 1
fi

commit="$(git -C "$repo_root" rev-parse --verify "${requested_ref}^{commit}")"
short_commit="$(git -C "$repo_root" rev-parse --short "$commit")"

echo "Opening Orbisonic ${ref_kind}: ${display_name}"
echo "Commit: ${short_commit}"

mkdir -p "$launch_root"

if [ -e "$worktree_path/.git" ]; then
  git -C "$worktree_path" checkout --detach --force "$commit"
  git -C "$worktree_path" clean -fd
elif [ -e "$worktree_path" ]; then
  echo "Launcher path exists but is not a Git worktree: $worktree_path" >&2
  exit 1
else
  git -C "$repo_root" worktree add --detach "$worktree_path" "$commit"
fi

copy_bootstrap_bundle() {
  rm -rf "$bundle_path"
  cp -R "$bootstrap_bundle" "$bundle_path"
}

copy_local_build_assets() {
  local source_librespot="$repo_root/.build/orbisonic-librespot"
  local target_build="$worktree_path/.build"

  if [ -d "$source_librespot" ]; then
    mkdir -p "$target_build"
    rm -rf "$target_build/orbisonic-librespot"
    cp -R "$source_librespot" "$target_build/"
  fi
}

apply_diagnostics_overlay() {
  local diagnostics_view="$worktree_path/Sources/Orbisonic/DiagnosticsView.swift"
  local content_view="$worktree_path/Sources/Orbisonic/ContentView.swift"
  local label="${ref_kind} ${display_name}"

  if [ -f "$diagnostics_view" ]; then
    /usr/bin/python3 - "$diagnostics_view" "$label" "$short_commit" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
label = sys.argv[2]
commit = sys.argv[3]
text = path.read_text()
if "Launcher ref" in text:
    sys.exit(0)

needle = 'DiagnosticsRow(label: "Build", value: AppBuildInfo.buildNumber),'
if needle not in text:
    sys.exit(0)

replacement = (
    needle
    + "\n            DiagnosticsRow(label: \"Launcher ref\", value: "
    + json.dumps(label)
    + ", monospace: true),"
    + "\n            DiagnosticsRow(label: \"Launcher commit\", value: "
    + json.dumps(commit)
    + ", monospace: true),"
)
path.write_text(text.replace(needle, replacement, 1))
PY
    return
  fi

  if [ -f "$content_view" ]; then
    /usr/bin/python3 - "$content_view" "$label" "$short_commit" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
label = sys.argv[2]
commit = sys.argv[3]
text = path.read_text()
if 'settingsPanel(title: "Build / Launcher")' in text:
    sys.exit(0)

needle = "    private var diagnosticsTab: some View {\n        VStack(alignment: .leading, spacing: 18) {\n"
if needle not in text:
    sys.exit(0)

panel = (
    needle
    + "            settingsPanel(title: \"Build / Launcher\") {\n"
    + "                infoRow(title: \"Launcher\", value: "
    + json.dumps(label)
    + ")\n"
    + "                infoRow(title: \"Commit\", value: "
    + json.dumps(commit)
    + ")\n"
    + "            }\n\n"
)
path.write_text(text.replace(needle, panel, 1))
PY
  fi
}

find_built_binary() {
  local preferred="$worktree_path/.build/arm64-apple-macosx/debug/$app_name"
  if [ -x "$preferred" ]; then
    printf '%s\n' "$preferred"
    return
  fi

  find "$worktree_path/.build" -path "*/debug/$app_name" -type f -perm -111 | head -n 1
}

copy_resource_bundle_if_present() {
  local resource_bundle
  resource_bundle="$(find "$worktree_path/.build" -path "*/debug/${app_name}_${app_name}.bundle" -type d | head -n 1 || true)"
  if [ -n "$resource_bundle" ]; then
    local resource_bundle_name
    resource_bundle_name="$(basename "$resource_bundle")"
    rm -rf "$bundle_path/Contents/Resources/$resource_bundle_name"
    cp -R "$resource_bundle" "$bundle_path/Contents/Resources/"
  fi
}

set_plist_string() {
  local key="$1"
  local value="$2"

  if ! "$plist_buddy" -c "Set :$key $value" "$plist_path" >/dev/null 2>&1; then
    "$plist_buddy" -c "Add :$key string $value" "$plist_path" >/dev/null
  fi
}

stamp_bundle_identity() {
  set_plist_string "OrbisonicGitRefKind" "$ref_kind"
  set_plist_string "OrbisonicGitRefName" "$display_name"
  set_plist_string "OrbisonicGitCommit" "$short_commit"
  if [ "$ref_kind" = "branch" ]; then
    set_plist_string "OrbisonicGitBranch" "$display_name"
  else
    set_plist_string "OrbisonicGitBranch" "not-a-branch"
  fi
}

build_and_refresh_bundle() {
  local build_home="$worktree_path/.build/dev-home"
  local module_cache_path="$worktree_path/.build/module-cache"

  mkdir -p "$build_home" "$module_cache_path"

  env \
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    HOME="$build_home" \
    CLANG_MODULE_CACHE_PATH="$module_cache_path" \
    swift build --package-path "$worktree_path"

  local binary_path
  binary_path="$(find_built_binary)"
  if [ -z "$binary_path" ] || [ ! -x "$binary_path" ]; then
    echo "Missing built executable for $display_name" >&2
    exit 1
  fi

  cp "$binary_path" "$bundle_path/Contents/MacOS/$app_name"
  chmod +x "$bundle_path/Contents/MacOS/$app_name"
  copy_resource_bundle_if_present
  stamp_bundle_identity

  xattr -cr "$bundle_path"
  codesign --force --deep --sign - "$bundle_path"
  codesign --verify --deep --strict --verbose=2 "$bundle_path"
  plutil -lint "$plist_path"
}

quit_running_orbisonic() {
  local bundle_id="audio.orbisonic.app"

  /usr/bin/osascript <<OSA >/dev/null 2>&1 || true
if application id "$bundle_id" is running then
  tell application id "$bundle_id"
    quit
  end tell
end if
OSA

  for _ in {1..30}; do
    if ! /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1; then
      return
    fi
    sleep 0.2
  done

  if /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1; then
    echo "Orbisonic is still running; quit it manually before reopening." >&2
    exit 1
  fi
}

copy_bootstrap_bundle
copy_local_build_assets
apply_diagnostics_overlay
build_and_refresh_bundle
quit_running_orbisonic
/usr/bin/open "$bundle_path"

echo "Opened $bundle_path"
