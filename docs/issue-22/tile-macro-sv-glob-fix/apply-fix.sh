#!/usr/bin/env bash
# Apply the tile-macro-flow .sv-file-discovery fix to a FABulous v2.0.0b5 checkout.
#
# The FABulous checkout is gitignored (clean-room), so the fix lives here as a
# tracked patch and is applied on top of the pinned ref. Idempotent: re-running
# is a no-op once applied.
#
# Usage:  docs/issue-22/tile-macro-sv-glob-fix/apply-fix.sh <path-to-FABulous-checkout>
#   e.g.  docs/issue-22/tile-macro-sv-glob-fix/apply-fix.sh FABulous_work/fabulous-v2
set -euo pipefail

CKO="${1:?usage: apply-fix.sh <path-to-FABulous-checkout>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/patches/tile_macro_flow-include-sv-files.patch"
TARGET="fabulous/fabric_generator/gds_generator/flows/tile_macro_flow.py"

[ -f "$CKO/$TARGET" ] || { echo "ERROR: $CKO is not a FABulous checkout ($TARGET missing)"; exit 1; }

if git -C "$CKO" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "Already applied: $TARGET"
  exit 0
fi

git -C "$CKO" apply --check "$PATCH"
git -C "$CKO" apply "$PATCH"
echo "Applied .sv-file-discovery fix to $CKO/$TARGET"
