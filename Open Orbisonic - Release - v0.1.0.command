#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "v0.1.0" "release" "v0.1.0"
