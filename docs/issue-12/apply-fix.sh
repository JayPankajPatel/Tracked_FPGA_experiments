#!/usr/bin/env bash
# Apply the issue #12 fabric IO-placement fix to a FABulous v2.0.0b5 checkout.
#
# The FABulous checkout is gitignored (clean-room), so the fix lives here as a
# tracked patch and is applied on top of the pinned ref. Idempotent: re-running
# is a no-op once applied.
#
# Usage:  docs/issue-12/apply-fix.sh <path-to-FABulous-checkout>
#   e.g.  docs/issue-12/apply-fix.sh FABulous_work/fabulous-v2
set -euo pipefail

CKO="${1:?usage: apply-fix.sh <path-to-FABulous-checkout>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/patches/fabric_io_place-overlap-iterm.patch"
TARGET="fabulous/fabric_generator/gds_generator/script/fabric_io_place.py"

[ -f "$CKO/$TARGET" ] || { echo "ERROR: $CKO is not a FABulous checkout ($TARGET missing)"; exit 1; }

if git -C "$CKO" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
  echo "Already applied: $TARGET"
  exit 0
fi

git -C "$CKO" apply --check "$PATCH"
git -C "$CKO" apply "$PATCH"
echo "Applied issue #12 IO-placement fix to $CKO/$TARGET"
