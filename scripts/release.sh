#!/bin/bash
set -euo pipefail

# Cuts a release: bumps the version, tags it, and pushes. GitHub Actions does the rest.
#
#   ./scripts/release.sh 0.2.0

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "usage: ./scripts/release.sh <version>   e.g. ./scripts/release.sh 0.2.0"
    echo ""
    echo "current: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)"
    echo "tags:    $(git tag --sort=-v:refname | head -5 | tr '\n' ' ')"
    exit 1
fi
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "!! version must look like 1.2.3"
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "!! working tree is dirty — commit or stash first"
    git status --short
    exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "!! tag v$VERSION already exists"
    exit 1
fi

echo "==> Bumping to $VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" scripts/Info.plist

# Sanity-check that it still builds before publishing a tag nobody can undo cleanly.
echo "==> Verifying the build"
swift build -c release >/dev/null

git add scripts/Info.plist
git commit -q -m "Release $VERSION"
git tag -a "v$VERSION" -m "Pawprint $VERSION"

echo "==> Pushing"
git push -q origin main
git push -q origin "v$VERSION"

echo ""
echo "==> Tagged v$VERSION and pushed. The Release workflow is building it now:"
echo "    https://github.com/yhcho0405/Pawprint/actions"
echo "    https://github.com/yhcho0405/Pawprint/releases"
