#!/usr/bin/env bash
#
# Feeds `validate_tag.sh` the things an attacker would type into the workflow_dispatch form.
#
# The point is not that the regex looks strict. It is that a tag which tries to run a command is
# rejected *and* that nothing runs while it is being rejected: each hostile case writes to a canary
# file if the shell ever evaluates it, and the canary must stay absent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$HERE/validate_tag.sh"
CANARY="$(mktemp -u)"
failures=0

accept() {
    if out=$("$VALIDATE" "$1" 2>/dev/null); then
        if [ "$out" = "$2" ]; then
            echo "ok   accepted $1 -> $out"
        else
            echo "FAIL $1 gave '$out', wanted '$2'"; failures=$((failures + 1))
        fi
    else
        echo "FAIL rejected a valid tag: $1"; failures=$((failures + 1))
    fi
}

reject() {
    if "$VALIDATE" "$1" >/dev/null 2>&1; then
        echo "FAIL accepted: $1"; failures=$((failures + 1))
    else
        echo "ok   rejected $(printf '%q' "$1")"
    fi
}

accept "v0.5.3" "0.5.3"
accept "v1.0.0" "1.0.0"
accept "v10.20.30" "10.20.30"

reject ""
reject "0.5.3"
reject "v0.5"
reject "v0.5.3.1"
reject "vX.Y.Z"
reject "v0.5.3-beta"
reject " v0.5.3"
reject "v0.5.3 "
reject "main"
reject "refs/heads/main"

# The shapes that would have mattered when this went into a shell body unquoted.
reject "v0.5.3; touch $CANARY"
reject "v0.5.3 && touch $CANARY"
reject "v0.5.3\$(touch $CANARY)"
reject 'v0.5.3`touch '"$CANARY"'`'
reject "v0.5.3|touch $CANARY"
reject "v0.5.3
touch $CANARY"
reject "\$(touch $CANARY)"
reject "../../etc/passwd"
reject "v0.5.3/../../v9.9.9"

if [ -e "$CANARY" ]; then
    echo "FAIL a rejected tag still executed something"
    rm -f "$CANARY"
    failures=$((failures + 1))
else
    echo "ok   nothing executed while rejecting"
fi

if [ "$failures" -eq 0 ]; then
    echo
    echo "TAG VALIDATION OK"
else
    echo
    echo "TAG VALIDATION $failures FAILURES"
    exit 1
fi
