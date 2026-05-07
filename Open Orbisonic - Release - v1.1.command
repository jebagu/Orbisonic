#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "v1.1" "release" "v1.1"
