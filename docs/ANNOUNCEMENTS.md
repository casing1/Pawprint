# Announcements

In-app notices are **GitHub issues**. Open one to publish it; close it to retract it.

## Publishing

1. Open an issue on this repository.
2. Add the `announcement` label.
3. That's it — within about half a minute it appears in every running copy of Pawprint.

Optional labels:

| Label | Effect |
|---|---|
| `warning` | Orange treatment instead of the neutral one |
| `min:0.3.0` | Hide from versions below this |
| `max:0.3.9` | Hide from versions above this |

Only issues **opened by the repository owner** are published, checked in the generator rather than
trusted to the API query — anyone can open an issue on a public repo, and this text lands on every
user's screen.

Closing the issue removes the notice. Reopening brings it back. Editing the body updates it.

## Writing in two languages

Split the body with language markers. They are HTML comments, so they stay invisible in the
rendered issue:

```markdown
<!--lang:ko-->
# 한국어 제목
본문...

<!--lang:en-->
# English title
Body...
```

The first `# ` line of a section becomes that language's title; without one, the issue title is
used. Without any markers, the whole body is used for every language.

`**bold**`, `*italic*` and links render in the app. Headings, tables and code blocks do not —
they appear as literal text, so keep notices to prose and simple numbered steps.

## How it reaches the app

`.github/workflows/announcements.yml` reads the open, labelled issues and writes
`docs/announcements.json`. The app fetches that file from `raw.githubusercontent.com` when it
starts and hourly after that, behind the same setting as the update check.

**The app does not call the issues API itself, on purpose.** Unauthenticated GitHub API access is
60 requests per hour *per IP address*, and conditional requests do not help — a `304` still
decrements the counter (measured, not assumed). Behind a shared NAT — an office, a university —
a few dozen installs would exhaust the quota for everyone on it, breaking announcements *and* the
update check, with nothing on screen to explain why. Reading the issues once in CI and serving a
static file from a CDN gives the same authoring workflow with none of that exposure.

The cost is a delay of roughly half a minute between closing an issue and the feed catching up,
plus a daily scheduled run in case an issue event is ever missed.

## Dismissal

A notice keeps appearing until the user presses **don't show again**; opening and closing the
detail sheet does not dismiss it. A notice exists to ask the reader to do something, and one that
disappears on sight is missed by exactly the people who need it. Dismissals are stored per issue
id, so a new notice always shows even if every previous one was dismissed.
