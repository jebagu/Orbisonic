#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/deprecated-orbisonic-ref.sh" "orbisonic-restart-019dce04-2026-04-27" "release"
