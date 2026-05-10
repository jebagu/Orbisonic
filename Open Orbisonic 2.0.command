#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

./scripts/refresh-orbisonic-app.sh 2.0
./scripts/reopen-orbisonic-app.sh
