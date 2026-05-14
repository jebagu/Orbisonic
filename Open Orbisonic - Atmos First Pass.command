#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "76ca882ac8fc4baa2d6bf73e945a72a8ba43f0ec" "commit" "Atmos First Pass"
