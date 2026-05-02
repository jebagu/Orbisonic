#!/usr/bin/env bash
set -euo pipefail

deprecated_ref="${1:?deprecated ref required}"
deprecated_kind="${2:-version}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '\nOrbisonic notice:\n'
printf '  %s "%s" is preserved but deprecated.\n' "$deprecated_kind" "$deprecated_ref"
printf '  The canonical build is main, promoted from pure-audio-branch-2.\n'
printf '  Opening main instead.\n\n'

exec "$repo_root/scripts/launch-orbisonic-ref.sh" "main" "branch" "main"
