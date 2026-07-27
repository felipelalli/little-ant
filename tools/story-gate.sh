#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cabal build all --ghc-options=-Werror
cabal test little-ant-test --test-show-details=direct
cabal test little-ant-v1-driver-test --test-show-details=direct

progress_report="$(mktemp "${TMPDIR:-/tmp}/little-ant-v1-progress.XXXXXX")"
trap 'rm -f -- "$progress_report"' EXIT
python3 tools/v1-progress.py --check tools/v1-baseline.txt | tee "$progress_report"

if awk '
  BEGIN { seen = 0; incomplete = 0 }
  /^(plan|scenario):/ {
    seen = 1
    split($2, count, "/")
    if (count[1] != count[2]) incomplete = 1
  }
  END { if (!seen || incomplete) exit 1 }
' "$progress_report"; then
  cabal test all --test-show-details=direct
fi
