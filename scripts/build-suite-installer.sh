#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-1.3.1}"
app_pkg="$repo_root/installer/Orbisonic-${version}.pkg"
suite_pkg="$repo_root/installer/OrbisonicSuite-${version}.pkg"
template_suite_pkg="${2:-$repo_root/installer/OrbisonicSuite-1.1.pkg}"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

validate_expanded_component_payload() {
  local expanded_component_path="$1"
  local payload_path="$expanded_component_path/Payload"
  local payload_type

  if [ ! -f "$payload_path" ]; then
    echo "Malformed component package: missing compressed Payload file at $payload_path" >&2
    exit 1
  fi

  payload_type="$(file "$payload_path")"
  case "$payload_type" in
    *"gzip compressed data"*|*"bzip2 compressed data"*|*"xz compressed data"*|*"cpio archive"*)
      ;;
    *)
      echo "Malformed component package: Payload is not a compressed archive at $payload_path" >&2
      echo "$payload_type" >&2
      exit 1
      ;;
  esac
}

if [ ! -f "$app_pkg" ]; then
  "$repo_root/scripts/build-installer.sh" "$version"
fi

if [ ! -f "$template_suite_pkg" ]; then
  echo "Missing suite template package: $template_suite_pkg" >&2
  exit 1
fi

component_dir="$tmpdir/components"
template_expanded="$tmpdir/template-suite"
distribution_path="$tmpdir/Distribution"
app_expanded="$tmpdir/app"
suite_expanded="$tmpdir/final-suite"

mkdir -p "$component_dir"
pkgutil --payload-files "$app_pkg" >/dev/null
pkgutil --expand "$app_pkg" "$app_expanded"
pkgutil --expand "$template_suite_pkg" "$template_expanded"
pkgutil --flatten "$template_expanded/OrbisonicInputsComponent-0.2.0.pkg" "$component_dir/OrbisonicInputsComponent-0.2.0.pkg"
pkgutil --payload-files "$component_dir/OrbisonicInputsComponent-0.2.0.pkg" >/dev/null
cp "$app_pkg" "$component_dir/Orbisonic-${version}.pkg"
cp "$template_expanded/Distribution" "$distribution_path"

install_kbytes="$(
  sed -n 's/.*installKBytes="\([^"]*\)".*/\1/p' "$app_expanded/PackageInfo" | head -n 1
)"
if [ -z "$install_kbytes" ]; then
  echo "Could not read app package installKBytes." >&2
  exit 1
fi

perl -0pi -e "s#<title>Orbisonic [^<]+</title>#<title>Orbisonic ${version}</title>#" "$distribution_path"
perl -0pi -e "s#<pkg-ref id=\"audio\\.orbisonic\\.app\\.pkg\" version=\"[^\"]+\" onConclusion=\"none\" installKBytes=\"[^\"]+\" updateKBytes=\"0\">#<pkg-ref id=\"audio.orbisonic.app.pkg\" version=\"${version}\" onConclusion=\"none\" installKBytes=\"${install_kbytes}\" updateKBytes=\"0\">#" "$distribution_path"
perl -0pi -e "s#>\\#Orbisonic-[^<]+\\.pkg</pkg-ref>#>\\#Orbisonic-${version}.pkg</pkg-ref>#" "$distribution_path"
perl -0pi -e "s#<bundle CFBundleShortVersionString=\"[^\"]+\" CFBundleVersion=\"[^\"]+\" id=\"audio\\.orbisonic\\.app\" path=\"Applications/Orbisonic\\.app\"/>#<bundle CFBundleShortVersionString=\"${version}\" CFBundleVersion=\"${version}\" id=\"audio.orbisonic.app\" path=\"Applications/Orbisonic.app\"/>#" "$distribution_path"

productbuild \
  --distribution "$distribution_path" \
  --package-path "$component_dir" \
  "$suite_pkg"

pkgutil --expand "$suite_pkg" "$suite_expanded"
validate_expanded_component_payload "$suite_expanded/Orbisonic-${version}.pkg"
validate_expanded_component_payload "$suite_expanded/OrbisonicInputsComponent-0.2.0.pkg"

archive_listing="$(xar -tf "$suite_pkg")"
case "$archive_listing" in
  *"/Payload/"*)
    echo "Malformed suite package payload in $suite_pkg: a component Payload expanded as loose archive files." >&2
    exit 1
    ;;
esac

echo "Built $suite_pkg"
