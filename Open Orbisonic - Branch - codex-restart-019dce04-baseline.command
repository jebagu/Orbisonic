#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/scripts/launch-orbisonic-ref.sh" "codex/restart-019dce04-baseline" "branch" "codex/restart-019dce04-baseline"
