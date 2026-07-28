#!/usr/bin/env python3
"""Turn open, labelled GitHub issues into the app's announcement feed.

Run by .github/workflows/announcements.yml. Writes docs/announcements.json, which the app fetches
from raw.githubusercontent.com.

Authoring an announcement is just opening an issue:

  * label it `announcement`
  * add `warning` for the orange treatment
  * add `min:0.3.0` / `max:0.3.9` to limit it to a range of app versions
  * close the issue to retract it

Only issues opened by the repository owner are published, checked here rather than trusted to the
API query alone. The body may carry both languages:

    <!--lang:ko-->
    # 한국어 제목
    본문...

    <!--lang:en-->
    # English title
    Body...

Without markers the whole body is used for every language, and the issue title is the title.
"""

import json
import os
import re
import subprocess
import sys

REPO = os.environ.get("REPO", "yhcho0405/Pawprint")
OWNER = os.environ.get("OWNER", REPO.split("/")[0])
LABEL = "announcement"
OUTPUT = "docs/announcements.json"

LANG_MARKER = re.compile(r"<!--\s*lang:([a-z]{2})\s*-->", re.IGNORECASE)


def gh_api(path):
    """Calls the API through `gh`, which the workflow authenticates for us."""
    out = subprocess.run(
        ["gh", "api", "-H", "Accept: application/vnd.github+json", path],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def split_languages(body):
    """Returns {lang: text}. Empty dict when the body carries no markers."""
    if not body:
        return {}
    parts = LANG_MARKER.split(body)
    # re.split with one capture group yields [before, lang, text, lang, text, ...].
    if len(parts) < 3:
        return {}
    sections = {}
    for index in range(1, len(parts) - 1, 2):
        sections[parts[index].lower()] = parts[index + 1].strip()
    return sections


def take_heading(text):
    """Pulls a leading '# Title' line off a section, returning (title, rest)."""
    lines = text.split("\n")
    if lines and lines[0].startswith("# "):
        return lines[0][2:].strip(), "\n".join(lines[1:]).strip()
    return None, text


def build(issue):
    labels = {label["name"].lower() for label in issue.get("labels", [])}
    body = issue.get("body") or ""
    sections = split_languages(body)

    titles, bodies = {}, {}
    if sections:
        for lang, text in sections.items():
            heading, rest = take_heading(text)
            titles[lang] = heading or issue["title"]
            bodies[lang] = rest
    else:
        titles["en"] = issue["title"]
        bodies["en"] = body.strip()

    announcement = {
        # Stable across edits, and short enough to keep in the dismissed list forever.
        "id": f"issue-{issue['number']}",
        "severity": "warning" if "warning" in labels else "info",
        "publishedAt": issue["created_at"][:10],
        "link": issue["html_url"],
        "title": titles,
        "body": bodies,
    }
    for label in labels:
        if label.startswith("min:"):
            announcement["minVersion"] = label[4:]
        elif label.startswith("max:"):
            announcement["maxVersion"] = label[4:]
    return announcement


def main():
    issues = gh_api(
        f"/repos/{REPO}/issues?state=open&labels={LABEL}&creator={OWNER}&per_page=100"
    )

    announcements = []
    for issue in issues:
        # The issues endpoint also returns pull requests; they are not announcements.
        if "pull_request" in issue:
            continue
        # Re-check the author rather than relying on the query parameter alone. Anyone can open an
        # issue on a public repo, and this file ends up on every user's screen.
        if (issue.get("user") or {}).get("login", "").lower() != OWNER.lower():
            print(f"skipping #{issue['number']}: not authored by {OWNER}", file=sys.stderr)
            continue
        if not any(label["name"].lower() == LABEL for label in issue.get("labels", [])):
            continue
        announcements.append(build(issue))

    # Newest first, so the app shows the most recent notice without having to sort.
    announcements.sort(key=lambda a: (a["publishedAt"], a["id"]), reverse=True)

    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump({"announcements": announcements}, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {len(announcements)} announcement(s) to {OUTPUT}")


if __name__ == "__main__":
    main()
