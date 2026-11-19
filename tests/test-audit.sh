#!/bin/bash
#
# Tests for scripts/audit.sh. Run: tests/test-audit.sh
# Uses a throwaway HOME, so it never reads or touches the real one.
#
set -u
cd "$(dirname "$0")/.."
AUDIT=scripts/audit.sh
fails=0
pass() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

bash -n "$AUDIT" && pass "syntax" || fail "syntax"

# The audit must stay read-only: no deleting or modifying commands outside comments.
if grep -v '^\s*#' "$AUDIT" | grep -nE '(^|[^[:alnum:]-])(rm|rmdir|unlink|mv|truncate|shred)( |$)|simctl (delete|erase)|runtime delete|--uninstall|prune|purge|cache (clean|rm)|thinlocalsnapshots|deletelocalsnapshots|>>? *"?\$HOME'; then
  fail "audit.sh contains a modifying command (lines above)"
else
  pass "no modifying commands"
fi

"$AUDIT" --help >/dev/null 2>&1 && pass "--help exits 0" || fail "--help exits 0"
"$AUDIT" --bogus >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "unknown flag exits 2" || fail "unknown flag exits 2"
"$AUDIT" --min-mb abc >/dev/null 2>&1; [[ $? -eq 2 ]] && pass "non-numeric --min-mb exits 2" || fail "non-numeric --min-mb exits 2"

home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
mkdir -p "$home/Library/Caches/FakeApp" "$home/Library/Developer/Xcode/DerivedData/App-abc" "$home/.npm/_cacache" "$home/.Trash"
dd if=/dev/zero of="$home/Library/Caches/FakeApp/blob" bs=1048576 count=3 2>/dev/null
dd if=/dev/zero of="$home/Library/Developer/Xcode/DerivedData/App-abc/blob" bs=1048576 count=2 2>/dev/null
dd if=/dev/zero of="$home/.npm/_cacache/blob" bs=1048576 count=2 2>/dev/null
touch "$home/.Trash/old-file"
before=$(cd "$home" && find . -exec stat -f '%N %z %m' {} + | sort)

out=$(HOME="$home" "$AUDIT" --min-mb 1 2>&1); status=$?
after=$(cd "$home" && find . -exec stat -f '%N %z %m' {} + | sort)

[[ $status -eq 0 ]] && pass "audit exits 0" || fail "audit exits 0 (got $status)"
[[ "$before" == "$after" ]] && pass "fixture HOME unchanged" || fail "fixture HOME changed"
grep -q 'Library/Caches/FakeApp' <<<"$out" && pass "reports large cache" || fail "reports large cache"
grep -q 'Developer/Xcode/DerivedData' <<<"$out" && pass "reports DerivedData" || fail "reports DerivedData"
grep -q '\.npm/_cacache' <<<"$out" && pass "reports npm cache" || fail "reports npm cache"
grep -q '1 top-level items' <<<"$out" && pass "counts Trash items" || fail "counts Trash items"
grep -q 'Nothing was changed' <<<"$out" && pass "completes" || fail "completes"
if grep -q 'Library/Caches/FakeApp/blob' <<<"$out"; then fail "listed a file below the requested depth"; else pass "respects depth"; fi

echo
[[ $fails -eq 0 ]] && echo "All tests passed." || { echo "$fails test(s) failed."; exit 1; }
