# Architecture

How Pawprint is put together, and why. This is the map; `REFACTORING_PLAN.md` is the record of how
it got this shape.

## The shape of it

```
┌─────────────────────────────────────────────────────────────┐
│  Pawprint            the application: AppKit and SwiftUI    │
│                                                             │
│  App/          AppDelegate, AppEnvironment, StatusItem,     │
│                the four window controllers, DebugCommand    │
│  Tracking/     six Monitors — keyboard, mouse, clipboard,   │
│                app usage, power/sleep, network              │
│  Engine/       ActivityCenter, TrackingCoordinator,         │
│                UpdateChecker, NotificationManager           │
│  UI/           the popover, settings, gallery, HUD          │
└───────────────────────────┬─────────────────────────────────┘
                            │  depends on
┌───────────────────────────▼─────────────────────────────────┐
│  PawprintCore        the domain: Foundation only            │
│                                                             │
│  Models/       DailyRawCounters, DailySummary, AppSettings, │
│                MachineFacts, RegionalReferences, …          │
│  Engine/       StatsEngine + Summary/, PawprintScore,       │
│                FocusEngine, LevelSystem, the accumulators   │
│  Storage/      ActivityStore, PawprintStore, StoreHealth    │
│  Utilities/    DayKey, Formatters, Localization             │
└─────────────────────────────────────────────────────────────┘
```

`PawprintCore` imports no AppKit and no SwiftUI. That is the rule that makes the arithmetic
testable: a summary can be computed, a day rolled over and a score built without a window server.

The dependency runs one way. When the domain needs something only the application can know — the
physical size of the display, the battery's cycle count — it *states what it needs* as a protocol
or a value and the application supplies it. `DisplayCalibrating` and `MachineFacts` are the two.

## Where things happen

### One day, end to end

```
 NSEvent (main queue)
   → KeyboardMonitor.handleKeyDown        reads keyCode and modifierFlags, never characters
   → ActivityCenter.recordKeyPress        applies the pause / category / excluded-app gate
   → KeyboardAccumulator                  streak, live WPM, per-minute buckets
   → DailyRawCounters (in memory)         counts and durations only
   → PawprintStore.saveDay                one JSON blob per day, on a timer and at rollover
```

Reading goes the other way and never touches the counters directly:

```
 DailyRawCounters
   → StatsEngine.summary(for:recentDays:dayStartHour:machine:)
   → DailySummary                         a snapshot, recomputed at most every 1.5s
   → the views
```

`ActivityCenter` deliberately keeps `today` out of Observation. It mutates tens of times a second,
and a view that read it would be invalidated at that rate — which is what made switching tabs feel
sluggish. Views read `todaySummary`, refreshed on a timer.

### The composition root

`AppEnvironment.live` is where the real store, the real clock and the real display calibration are
chosen and handed over. `TrackingCoordinator.live()` is where the six monitors are constructed.
Nothing below either is clever; that is the point. If you want to know what the running application
is made of, those two functions are the answer.

Views read what they need out of the SwiftUI environment, injected once per window by
`pawprintEnvironment()`. There are four roots: the popover, the settings window, the onboarding
window and the HUD.

### Statistics

`StatsEngine.summary` is the composition, not the arithmetic. Eight calculators in
`Engine/Summary/` each own a set of fields:

| Calculator | Owns | Needs |
|---|---|---|
| `KeyboardStats` | counts, speeds, heatmap, consistency, golden hour | — |
| `PointerStats` | clicks, cursor metres, scroll screens | the display |
| `ClipboardStats` | copies, pastes, cuts, kinds | — |
| `AppStats` | per-app time and input, concentration | — |
| `TimeStats` | active, idle, focus, the day's longest break | — |
| `DeviceStats` | sleep, power, lid, displays, screen, network | the battery |
| `DerivedIndices` | regret, chaos, the day's tags | the above |
| `HighlightBuilder` / `FunFactBuilder` / `SummarySentence` | the prose | the above |

The order between them is the only real dependency and reads as a list: the pointer figures need
the display, the tags need the pointer figures, and the closing sentence is written about
everything above it.

**Every figure is a function of its inputs.** Two are not derivable from a day's counters — the
panel it was recorded on and the battery pack — so they arrive as `MachineFacts` rather than being
fetched mid-expression. Ties break toward the smaller identifier everywhere, because the same day
must give the same answer twice.

### Storage

One row per day, one JSON blob per row, in SQLite. The `Codable` property names *are* the schema,
which is why every decoder is hand-written with `decodeIfPresent` and why a rename would silently
cost every existing user that field.

Nothing in `PawprintStore` throws to its caller: a hundred SwiftUI sites read a day to draw a
number and have nothing useful to do with an error. Failures are logged through `StoreLog` (an
`os.Logger` whose interpolations are annotated — paths are `.private`, because they contain the
user's name), recorded in `StoreHealth`, and shown as a line at the top of Today. An unopenable
file degrades to an in-memory database rather than crashing.

`PRAGMA user_version` tracks the schema. Migration runs in one transaction, after taking a copy.

## Privacy, as code

These are not conventions. Each one has a test that fails if it stops being true.

| Promise | Where it is kept |
|---|---|
| No typed characters, ever | `KeyboardMonitor` reads `keyCode` and `modifierFlags`; `event.characters` appears nowhere in the tree |
| No key order | `keyCodeCounts` is a frequency map with no sequence |
| No clipboard contents | `ClipboardMonitor` reads `changeCount` and the *type*, never the data |
| No screen or window contents | nothing imports ScreenCaptureKit; no window title is read |
| No cursor paths | `PointerAccumulator` accumulates a *distance*; there is nowhere for a route to go |
| Recording is visible | the menu bar icon and `RecordingStatusLabel` follow `RecordingPolicy` |
| Pause means pause | one gate, in `ActivityCenter`, checked by `RecordingPolicy` |
| Per-app exclusion | same gate |
| Everything can be deleted | `deleteAll`, and badges survive it deliberately |
| Nothing leaves the machine | one network call exists: the update check, off by default |

`PrivacyInvariantTests` and a CI step over `DailyRawCounters` hold the stored format to counts and
durations.

## Verification

| Question | How it is answered |
|---|---|
| Does the same database still produce the same statistics? | `PAWPRINT_DIGEST=all`, before and after, diffed |
| Are the statistics deterministic? | the same digest twice, in CI |
| Does every language render? | `PAWPRINT_LANG_PROBE=<code>`, all four, in CI |
| Are there raw keys on screen? | `PAWPRINT_L10N` |
| Do the regional conversions differ per locale? | `PAWPRINT_FACTS` |
| Did the hot path get slower? | `PAWPRINT_PERF` |
| Does the release build carry the tooling? | `strings` over the binary, in CI |
| Is it universal? | `lipo -archs`, in CI |
| Does a hostile tag get through? | `scripts/test_validate_tag.sh` |

The probes are all `#if DEBUG`. The release build contains none of them, which CI checks.

## What is deliberately not here

- **No analytics, no telemetry, no crash reporter.** Nothing is sent anywhere.
- **No external package dependencies.** SQLite is the system one; the project builds offline.
- **No server.** There is no account, no sync and nothing to sign in to.
- **No judgement.** The copy reports what happened. There is no goal, no streak to protect and no
  "you were unproductive today" anywhere in the interface — see `docs/REFACTORING_PLAN.md` for the
  chaos index, which was rewritten once precisely because it had started to read like one.
