#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "no-router-tab" "branch" "no-router-tab"
