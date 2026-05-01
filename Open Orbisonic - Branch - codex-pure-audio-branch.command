#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "codex/pure-audio-branch" "branch" "codex/pure-audio-branch"
