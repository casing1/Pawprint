<div align="center">

<img src="docs/images/banner.png" alt="Pawprint" width="100%">

**English** · [한국어](docs/README.ko.md)

<br>

<a href="https://github.com/yhcho0405/Pawprint/releases/latest/download/Pawprint.dmg">
<img src="https://img.shields.io/badge/Download%20for%20macOS-.dmg-1a7f37?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="42">
</a>

<br><br>

<img src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.10">
<img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square" alt="Apache 2.0">
<a href="https://github.com/yhcho0405/Pawprint/releases/latest"><img src="https://img.shields.io/github/v/release/yhcho0405/Pawprint?style=flat-square&color=8957e5" alt="Latest release"></a>

</div>

<br>

Pawprint sits in your menu bar and quietly notes how you use your Mac — keys pressed, distance
scrolled, time spent in focus, battery burned. At the end of the day it hands all of that back to
you as a cat.

**It never records what you type.** Only counts, durations and aggregates. Everything stays on
your Mac.

<br>

## The cat

Every day generates one cat. Its coat is fixed by the date, so it stays the same animal from
midnight to midnight — but its expression, hat, glasses, prop, collar and surroundings each track
a *different* metric, so the drawing reads as a summary of the whole day rather than one number
restyled eight ways.

A handful of traits have to be **earned**. Type enough and a glowing charm appears at its paw —
which charm is a surprise, drawn from the date. Cover enough distance and it grows wings. Score
well and it gets a frame: bronze, silver, gold, or the rainbow one.

<div align="center">
<img src="docs/images/cats.png" alt="Top-tier cats" width="620">
<br>
<sub>Top-grade cats: rainbow frames, paw charms, wings and sunburst backdrops</sub>
</div>

<br>

Each one is scored out of 100 for rarity and graded S through D. They collect in a **gallery**
you can sort by rarity, date or score, and filter down to just the days you earned something.

There are around **171 trillion** reachable combinations.

<br>

## What else it does

| | |
|---|---|
| **Endless levels** | 11 tracks — typing, scrolling, focus, power and more — with targets that keep growing. No checklist that runs out. |
| **Live HUD** | A floating panel with your current WPM, session time and whichever stats you pick. |
| **Activity calendar** | Every day coloured by any metric you choose. |
| **Pawprint Wrapped** | A monthly retrospective, slide by slide. |
| **Share cards** | Turn today or your lifetime totals into an image, copied straight to the clipboard. |
| **Keyboard heatmap** | A real keyboard layout showing which keys you lean on — counts only, never characters. |
| **Percentile ranking** | Where today sits against every day you've recorded. |

<br>

## What it never stores

- The characters you type, or the order you typed them
- Passwords
- Clipboard **contents**
- Screenshots, window titles, document or web page contents
- Long-term raw cursor paths

Data lives in `~/Library/Application Support/Pawprint/` and goes nowhere else. Pawprint works
entirely offline; the one network request it makes is checking for a new version, which you can
turn off in Settings → Updates.

<br>

## Permissions

| Permission | Why |
|---|---|
| **Accessibility** | Detect mouse events and app switches |
| **Input Monitoring** | Detect *that* a key was pressed — never which one |

A setup wizard walks you through both on first launch, and you can reopen it any time from
Settings → General.

<br>

## Updates

Pawprint checks for new versions on its own and offers them in the popover. One click downloads,
verifies and installs.

Every release archive is signed with an Ed25519 key whose public half is compiled into the app.
Nothing is unpacked, let alone run, until that signature checks out — so a substituted download
URL cannot become a substituted app.

<br>

## Building from source

```bash
git clone https://github.com/yhcho0405/Pawprint.git
cd Pawprint
./scripts/build_app.sh release
open ./build/Pawprint.app
```

To package a `.dmg`:

```bash
./scripts/make_dmg.sh --build
```

The release process is documented in [docs/RELEASING.md](docs/RELEASING.md).

<br>

## Troubleshooting

<details>
<summary>macOS won't open the app on first launch</summary>

<br>

Right-click Pawprint in Applications and choose **Open**, then confirm. This is only needed once.

</details>

<details>
<summary>Every counter reads zero</summary>

<br>

Accessibility or Input Monitoring was probably revoked. Settings → General shows the live status
of both, and the setup wizard can be reopened from the same place.

</details>

<br>

## License

[Apache 2.0](LICENSE)
