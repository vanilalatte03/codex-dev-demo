#!/usr/bin/env bash
set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
exec /usr/bin/python3 "$repo_root/scripts/guard.py" "${1:-}"
