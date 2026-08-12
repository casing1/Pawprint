#!/usr/bin/env bash
#
# Accepts a release tag, or refuses it.
#
# The release workflow receives a tag in a repository-dispatch payload. This check rejects hostile
# input before the workflow fetches that tag. It lives in a file rather than inline in the workflow
# so it can be tested without dispatching a release — see `scripts/test_validate_tag.sh`.
#
# Prints the version (the tag without its leading `v`) on success. Exits non-zero on anything else.
set -euo pipefail

TAG="${1-}"

if [ -z "$TAG" ]; then
    echo "tag is empty" >&2
    exit 1
fi

# `grep -E` on a single line, with the anchors doing the work. A tag containing a newline fails
# because `printf` emits it verbatim and the pattern has to match the whole of it — `grep` would
# otherwise happily match the first line of a two-line string and let the second one through.
if [ "$(printf '%s' "$TAG" | wc -l | tr -d ' ')" != "0" ]; then
    echo "tag contains a newline" >&2
    exit 1
fi

if ! printf '%s' "$TAG" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "tag '$TAG' is not vMAJOR.MINOR.PATCH" >&2
    exit 1
fi

printf '%s\n' "${TAG#v}"
