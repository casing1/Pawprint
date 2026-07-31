# Security Policy

Pawprint runs with Accessibility and Input Monitoring granted, which is about as much trust as a
Mac gives an application. It also replaces itself when it updates. Both are taken seriously here,
and both are why this document is more specific than a template.

## Supported Versions

| | |
| --- | --- |
| **The latest published release** | :white_check_mark: |
| Anything older | :x: |

Read it as *fixes land in the next release*, not as a promise to patch older ones in place.
Pawprint is distributed outside the App Store and updates itself, so there is no long-lived release
branch to back-port to: a fix ships as the next version, usually within a day, and you receive it
by updating. Being on an older build when the fix is out means updating, not waiting for a patch to
that build.

The current release is always at
[Releases](https://github.com/yhcho0405/Pawprint/releases/latest), including when automatic update
checks are turned off.

## Reporting a Vulnerability

**Please do not open a public issue.**

Use GitHub's private reporting, which is enabled on this repository:

**[Report a vulnerability →](https://github.com/yhcho0405/Pawprint/security/advisories/new)**

That page is private between you and the maintainer until an advisory is published.

Useful things to include, roughly in order of usefulness: the version and macOS version, what an
attacker would gain, and the smallest set of steps that shows it. A proof of concept is welcome but
not required — a clear description of the flaw is enough to act on.

### What to expect

| | |
|---|---|
| First response | Within 3 days |
| Assessment — accepted, declined, or needs more detail | Within 7 days |
| Fix released, if accepted | Usually the same week; a release goes out as soon as the fix is verified |
| Credit | Named in the advisory and the release notes, unless you'd rather not be |

If a report is declined, you will get the reasoning, not a form letter. If you disagree, say so —
a wrong call here is worse than an argument.

## Scope

Pawprint's security surface is small but not trivial. These are the parts worth attacking, and
what already stands in the way.

### The updater

The app downloads an archive and replaces itself with the contents. Two checks stand between a
download and running code:

1. **The archive's Ed25519 signature is verified before anything is unpacked.** The public key is
   compiled into the app, so a substituted download URL cannot become a substituted app — an
   attacker would need the private key, not merely control of the network or the release page.
2. **The unpacked app must satisfy the running app's designated code requirement**
   (`SecStaticCodeCheckValidity` across all architectures). An archive signed with a different
   identity is rejected even if step 1 somehow passed.

Anything that gets past either check, or skips them, is a serious finding. So is any path that
executes code from the archive before both have run.

### The permissions

Accessibility and Input Monitoring let the process observe global input events. The app reads only
`keyCode` and `modifierFlags`, never `event.characters`, so typed text is not observable to it at
all — but any way to make it record, retain, or transmit more than counts is in scope.

### Local data

Statistics live in `~/Library/Application Support/Pawprint/` in a SQLite database with no
encryption, protected by the file permissions of the user's home directory. That is a deliberate
choice for data that is counts and durations, and it is not a vulnerability on its own. A way for
another process to reach it that the file system would not otherwise allow **is**.

### Network

Every request Pawprint can make goes to GitHub, and all of them are behind one setting
(Settings → Updates). Turning it off leaves the app entirely offline.

| When | Request |
|---|---|
| Hourly, and shortly after launch | The release check, `api.github.com` |
| Hourly, and shortly after launch | The announcement feed, `raw.githubusercontent.com` |
| Only while installing an update | The release archive and its `.sig`, from the release assets |

All four are `GET`s that send nothing about the user or the machine — no identifier, no counters,
no usage data. Announcement text is rendered as inline markdown into a `Text` view; there is no
`WKWebView` anywhere in the app and no HTML is ever parsed.

Links (the update page, an announcement's issue, System Settings panes) open in the user's own
browser via `NSWorkspace`, only in response to a click, and are not requests Pawprint makes.

Any request outside that table, or any data leaving the machine, is a finding regardless of how
harmless the content looks.

### Out of scope

- **Gatekeeper warning on first launch.** Pawprint is signed with a self-signed certificate rather
  than an Apple Developer ID, so macOS warns on first open. This is known and expected, not a
  vulnerability.
- **An attacker who already has code execution as the user**, or root, or physical access with the
  machine unlocked. Anyone in that position can read the database directly; no application-level
  control changes that.
- Findings that require the user to be talked into disabling a protection.
- Reports from automated scanners with no analysis attached. A tool's output describing a
  theoretical issue in a dependency Pawprint does not use is noise; if you have looked at it and
  believe it is reachable, say why and it will be treated as a real report.

## Verifying a release yourself

Everything needed to check a download is public:

```bash
# Whatever is current. Set V by hand to check a specific release instead.
V=$(gh release view -R yhcho0405/Pawprint --json tagName -q .tagName | tr -d v)
gh release download "v$V" -R yhcho0405/Pawprint -p "Pawprint-$V.zip*"

# The archive signature — the same check the app performs before unpacking anything.
# The public key is the one compiled into the app (UpdateDistribution.publicKey).
swift scripts/updatekeys.swift verify \
  "Pawprint-$V.zip" \
  "$(cat "Pawprint-$V.zip.sig")" \
  "WFrwhuof35wfjgGTjm5WwGXW8BlHb6DnXYKNcfoOiBc="
# -> OK

# Who signed the app, and that both architectures are intact.
codesign -dvvv /Applications/Pawprint.app
codesign --verify --deep --strict /Applications/Pawprint.app
lipo -archs /Applications/Pawprint.app/Contents/MacOS/Pawprint   # x86_64 arm64
```

The signature is over the `.zip`, not the `.dmg`: the `.zip` is what the updater downloads, so it
is the artifact whose authenticity actually gates code execution.

Releases are built by GitHub Actions from a tagged commit; the workflow is in
[`.github/workflows/release.yml`](.github/workflows/release.yml) and its logs are public.
