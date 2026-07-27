#!/bin/bash
set -euo pipefail

# How many people have downloaded Pawprint, and how many are running it.
#
#   ./scripts/stats.sh
#
# Downloads come from the GitHub Releases API, which counts every asset fetch — no code in the
# app and nothing to host. Active users come from the optional usage endpoint (docs/ANALYTICS.md);
# that section is skipped when PAWPRINT_STATS_ENDPOINT is unset.

REPO="${PAWPRINT_REPO:-yhcho0405/Pawprint}"

if ! command -v gh >/dev/null; then
    echo "!! needs the GitHub CLI: brew install gh"
    exit 1
fi

echo "== Downloads — $REPO"
echo ""

gh api "repos/$REPO/releases" --paginate --jq '
    .[] | {
        tag: .tag_name,
        published: (.published_at | split("T")[0]),
        dmg: ([.assets[] | select(.name | endswith(".dmg")) | .download_count] | add // 0),
        zip: ([.assets[] | select(.name | endswith(".zip")) | .download_count] | add // 0)
    } | [.tag, .published, (.dmg|tostring), (.zip|tostring)] | @tsv
' | awk -F'\t' '
    BEGIN { printf "%-10s %-12s %8s %8s\n", "RELEASE", "PUBLISHED", "DMG", "ZIP" }
    { printf "%-10s %-12s %8s %8s\n", $1, $2, $3, $4; dmg += $3; zip += $4 }
    END {
        printf "%-10s %-12s %8s %8s\n", "", "", "----", "----"
        printf "%-10s %-12s %8d %8d\n", "TOTAL", "", dmg, zip
        print ""
        # The .zip is what the in-app updater fetches, so it counts upgrades as well as installs.
        # The .dmg is the closest thing to a fresh-install count.
        printf "New installs (dmg):     %d\n", dmg
        printf "Update downloads (zip): %d\n", zip
    }
'

echo ""
echo "== Repository traffic (last 14 days, needs push access)"
gh api "repos/$REPO/traffic/views" \
    --jq '"  page views: \(.count)  (unique: \(.uniques))"' 2>/dev/null \
    || echo "  unavailable"
gh api "repos/$REPO/traffic/clones" \
    --jq '"  clones:     \(.count)  (unique: \(.uniques))"' 2>/dev/null \
    || echo "  unavailable"

if [ -n "${PAWPRINT_STATS_ENDPOINT:-}" ]; then
    echo ""
    echo "== Active users"
    curl -fsS "${PAWPRINT_STATS_ENDPOINT%/}/stats" \
        | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("  today:      %d" % d.get("dau_today", 0))
print("  this month: %d" % d.get("mau_month", 0))
for row in d.get("versions", [])[:8]:
    print("    %-10s %5d" % (row["version"], row["count"]))
' || echo "  unreachable — check PAWPRINT_STATS_ENDPOINT"
else
    echo ""
    echo "== Active users: not configured (see docs/ANALYTICS.md)"
fi
