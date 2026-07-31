# Pawprint refactoring plan

Living document. Written before any code moved, and updated as each stage lands — the "status"
column at the end is the truth about what is done, not this paragraph.

Everything here was measured or read out of the tree at `409d1e4`, not recalled.

## 1. Baseline

Recorded before any file moved, so every later claim about regression has something to compare to.

| | |
|---|---|
| Commit | `409d1e4c14e62a75305ef5828bd2bcc75fe1f530` |
| Swift | 6.3.3 (`swift-tools-version: 5.10`, target `arm64-apple-macosx26.0`) |
| macOS | 26.5.2 |
| Source | 21,160 lines across 92 Swift files |

```
swift build -c debug            9s     exit 0
swift build -c release         25s     exit 0
./scripts/build_app.sh release 101s    exit 0
./scripts/make_dmg.sh --build   9s     exit 0
```

| Artefact | |
|---|---|
| `Pawprint.app` | 16 MB, `lipo -archs` → `x86_64 arm64` |
| `dist/Pawprint-0.4.6.dmg` | 6,367,265 bytes |
| `dist/Pawprint-0.4.6.zip` | 5,274,520 bytes |
| Real user database | 716,800 bytes |
| 132-day demo database | 2,813,952 bytes |
| Launch → probe exit, 132-day DB | 2.38s cold, then 1.47s / 1.49s |

### Workload timings

`PAWPRINT_PERF=1` against the 132-day demo database. Synthetic, seeded, single-threaded, no
sleeps; absolute values only mean something against another run of the same probe on the same
machine.

| Workload | Baseline | Per event |
|---|---|---|
| `summary 1 day` | 1.078 ms/op | — |
| `load 30 days` | 23.306 ms/op | 0.78 ms/day |
| `load 90 days` | 68.055 ms/op | 0.76 ms/day |
| `lifetime rebuild` | 100.453 ms/op | — |
| `20k keys @96wpm` | 2,639.557 ms | **132 µs** |
| `20k keys @burst` | 10,773.281 ms | **539 µs** |
| `100k cursor moves` | 4,900.729 ms | 49 µs |
| `20k clicks` | 1,019.778 ms | 51 µs |
| `5k app switches` | 490.031 ms | 98 µs |

The keystroke cost is the outlier, and it scales with typing rate rather than staying flat —
539 µs at burst against 132 µs at 96 WPM for the same 20,000 events. Cause found and recorded in
§7; it is a known inefficiency, not a bug, and it is not user-visible at human typing speeds
(132 µs × ~8 keys/s ≈ 0.1% of one core).

## 2. What exists now

### Dependency shape

```
AppDelegate ──┬── StatusItemController ── PopoverRootView ── {Today,Calendar,Gallery,Records}View
              ├── TrackingCoordinator ──── {Keyboard,Mouse,Clipboard,AppUsage,
              │                              PowerAndSleep,Network}Monitor
              ├── DebugSnapshot (2,054 lines, compiled into release)
              └── SettingsOpener ───────── SettingsRootView

                         every arrow above eventually reaches
                                        ↓
                              ActivityCenter.shared
                                        ↓
                    PawprintStore.shared ── SQLiteDatabase
```

`ActivityCenter` is the hub everything passes through: 933 lines, and the single mutation point
for every counter. That concentration is deliberate and, for the privacy rules, correct — the
pause and excluded-app gates are enforced in exactly one place. The problem is that the same type
also owns day rollover, session lifetime, settings application, lifetime-stats rebuilds, quest
level-ups, notification scheduling, retention and persistence.

### Singleton references

225 direct `.shared` lookups outside any composition root:

| Singleton | References |
|---|---|
| `ActivityCenter.shared` | 120 |
| `PawprintStore.shared` | 16 |
| `LocalizationManager.shared` | 16 |
| `PermissionsManager.shared` | 13 |
| `SummaryCache.shared` | 11 |
| `UpdateChecker.shared` | 10 |
| `NotificationManager.shared` | 10 |
| `RecordTracker.shared` | 8 |
| `AchievementEngine.shared` | 8 |
| `AnnouncementCenter.shared` | 8 |
| `BatteryHardware.shared` | 5 |

Views reach for these directly, which is why almost nothing below `AppDelegate` can be constructed
in a test.

### Who owns state

| Owner | State | Notes |
|---|---|---|
| `ActivityCenter` | `today: DailyRawCounters`, `settings`, session cursors, `recentCharKeyTimes`, streak, lifetime stats, quests | **The problem: `@Observable` but not `@MainActor`** |
| `MouseMonitor` | `pending*` accumulators | Guarded by its own `NSLock`, flushed every 0.5s |
| `PawprintStore` | SQLite handle | No explicit serial boundary |
| `SummaryCache` | Derived summaries | Keyed by day |
| `LocalizationManager` | Loaded language pack | `NSLock` + `Task { @MainActor }` |
| `AchievementEngine`, `RecordTracker`, `AnnouncementCenter` | Their own celebration/dismissal state | Each a separate singleton |

Views own no recording state, which is right. What they do own is direct singleton access.

### Execution boundaries

| Mechanism | Where |
|---|---|
| Global event monitors | `KeyboardMonitor`, `MouseMonitor` (`NSEvent.addGlobalMonitorForEvents`) |
| `NSLock` | `MouseMonitor`, `LocalizationManager` |
| `DispatchQueue.main.async` | Keyboard **per keystroke**, mouse per flush, `PowerAndSleepMonitor`, several views |
| `MainActor.assumeIsolated` | `MenuBarIconAnimator` timer |
| Timers | ActivityCenter flush 15s / tick 20s / summary refresh; MouseMonitor 0.5s; PowerAndSleep sample; Network sample; Permissions poll; icon animation |
| `@MainActor` | 32 files, mostly views |

**The central concurrency defect:** `ActivityCenter` is `@Observable`, holds all recording state,
is read by SwiftUI, and is written from timer callbacks and dispatched monitor callbacks — with no
actor isolation at all. It is main-isolated by convention only. Nothing in the type system says
so, and nothing catches it if a future caller mutates from elsewhere.

### Event path, keyboard

```
NSEvent global monitor → handleKeyDown → DispatchQueue.main.async
  → ActivityCenter.beginEvent  (pause / category / excluded-app gate)
  → recordKeyPress             (counters, per-minute buckets, app attribution)
  → updateTypingStreak
  → updateLiveWPM              ← O(window) scan, see §7
  → dirtySinceLastSummary = true
… summary timer → refreshSummary → StatsEngine.summary(…) → todaySummary → SwiftUI
… flush timer (15s) → store.saveDay(today)
```

Batching is already correct in shape: no database write and no summary rebuild per event. What is
wrong is one main-queue hop **per keystroke**, and the sliding window being an `Array` that is
rescanned and compacted on every key.

### Event path, mouse

```
NSEvent global monitor → handle(event) → NSLock → pending accumulators
… 0.5s flush timer → DispatchQueue.main.async → ActivityCenter.record*
```

Properly batched. The `NSLock` plus a main-queue hop is two mechanisms for one piece of state.

## 3. Storage and migration risk

One row per day, `day TEXT PRIMARY KEY` and `data TEXT` holding a JSON blob of
`DailyRawCounters`. Settings and achievements are single rows in `app_settings`.

**This format stays.** It suits the access pattern — days are read and written whole, never
queried by field — and normalising it would be churn with a migration risk attached and no
question it answers better.

The risks that matter:

1. **`Codable` property names are the schema.** Renaming a stored property silently drops that
   field for every existing user. The models already carry hand-written `decodeIfPresent`
   decoders for exactly this reason. Any rename must keep the old key.
2. **Blanket `try?`.** A decode failure is indistinguishable from an absent day, and a failed
   write is indistinguishable from a successful one.
3. **No schema version.** There is no `PRAGMA user_version`, so a future migration has nothing to
   branch on.
4. **One bad row is the whole app.** `allDays()` decodes everything; a single corrupt blob can
   take out the gallery, lifetime stats and percentiles together.

Mitigation before any model touching: golden fixtures of real databases in the test resources,
asserting that day-by-day raw values and derived summaries come back identical.

## 4. Statistics: definition and location

| Metric group | Computed in |
|---|---|
| Everything on `DailySummary` | `StatsEngine.summary(for:recentDays:dayStartHour:)` — 820 lines |
| Score and grade | `PawprintScore` |
| Persona, highlights, summary sentence | `PawprintScore` + `StatsEngine` |
| Fun facts and conversions | `FunConversions` |
| Focus sessions | `FocusEngine` |
| Percentiles | `PercentileEngine` |
| Lifetime totals, quest levels | `LifetimeStats`, `LevelSystem` |
| Streaks | `StreakRule` |
| Cat traits and rarity | `PawpetTraits` (in `UI/Components`, though it is pure domain) |

`StatsEngine.summary` mixes raw aggregation, per-domain arithmetic, comparison baselines, scoring,
persona selection, natural-language generation and hardware lookups in one function. Splitting it
is §S6, and the binding constraint is that **every number and every rounding must come out
identical** — characterization tests first, extraction second.

`PawpetTraits` sitting under `UI/Components` is a filing mistake: it is pure domain logic with no
SwiftUI in it, and it belongs in the core.

## 5. Stages

Each stage is independently buildable and independently revertable. No stage mixes structural
movement with behaviour change; behaviour changes get their own commits and their own tests.

| # | Stage | Rollback |
|---|---|---|
| S1 | Baseline + this document + `PAWPRINT_PERF` | Revert; nothing else depends on it |
| S2 | `PawprintCore` + `PawprintTests` targets | Revert `Package.swift` and the file moves; no logic changed |
| S3 | Characterization tests A–G | Tests only; revert freely |
| S4 | Composition root, injectable `Clock`/`DayKey`/`Scheduler` | `.shared` bridge stays until S9, so revert is local |
| S5 | Split `ActivityCenter` | Largest risk. Guarded by S3; revert restores the monolith |
| S6 | Split `StatsEngine` | Guarded by golden summaries from S3 |
| S7 | `ActivityStore` protocol, errors, migration | Format unchanged, so revert is safe; migration is additive |
| S8 | Monitor injection, concurrency, keystroke hot path | Perf probe from S1 gates it |
| S9 | Singletons out of SwiftUI | Per-view, revertable individually |
| S10 | `DebugSnapshot` out of the release target | Revert restores it to the app target |
| S11 | Release workflow hardening | Workflow-only |
| S12 | CI gates, perf comparison, `ARCHITECTURE.md` | Additive |

Features (uncapped score, continuous rarity, foil treatment) are **not** refactoring stages. They
land as separate commits after the structure they depend on, with their own tests.

## 6. Privacy invariants, as code

These are not aspirations to re-check by reading; S3 asserts them.

- No API in the tree reads `NSEvent.characters`. The keyboard path takes `keyCode` and
  `modifierFlags` only, and `KeyCodeMap` maps a code to a *category*.
- `DailyRawCounters` has no field capable of holding text the user typed, a clipboard payload, a
  window title or a cursor path. The characterization tests assert the field set.
- Clipboard tracking records counts and a type discriminator, never contents.
- The refactor adds no new network call. The only hosts remain `api.github.com` and
  `raw.githubusercontent.com`, both behind the single update switch.
- Nothing above may be logged. S7 introduces `os.Logger`; every interpolation of user-derived
  values is `privacy: .private`.

## 7. Known issues found while measuring

Recorded here so they are fixed deliberately, in their own commits, rather than smuggled into a
structural change.

1. **Live-WPM sliding window is O(n) per keystroke.**
   `updateLiveWPM` does `recentCharKeyTimes.append(date)` then
   `recentCharKeyTimes.removeAll { date.timeIntervalSince($0) > 60 }` — a full scan and array
   compaction on every key, where *n* is the number of keys in the last 60 seconds. Hence 132 µs
   per key at 96 WPM and 539 µs at burst rate. Correct, but it should be a ring buffer or an
   index-based head pointer. Fix in S8, measured against the S1 baseline.
2. **`refreshSummary` recomputes the whole summary on a timer whenever anything is dirty.**
   1.078 ms is affordable; it is listed so a regression here is noticed.
3. **`ActivityCenter` is `@Observable` with no actor isolation.** §2. Addressed in S8.
4. **`DebugSnapshot` (2,054 lines) compiles into the release binary**, including demo-data
   generation and screenshot rendering. Addressed in S10.
5. **`PawpetTraits` is pure domain logic filed under `UI/Components`.** Moves in S2.

## 8. A reordering, and why

S2 (module split) was planned before S3 (characterization tests). It is being done the other way
round, because `swift test` turned out to run against the executable target directly —
`@testable import Pawprint` reaches every `internal` symbol with no module boundary needed.

That matters, because the module split is not small. Moving the 5,491 pure lines behind a target
boundary needs an access-level modifier on roughly **1,093 declarations**, and it has to compile
all at once. Doing that *first* would mean performing the single largest mechanical edit in the
project with no test coverage underneath it.

So the tests land first and then guard the move, which is the order the tests were wanted for in
the first place. Nothing is skipped: S2 still happens, and §17's requirement that pure domain logic
be testable independently of the app target is what S2 delivers. The tests written now carry over
unchanged — `@testable import PawprintCore` instead of `Pawprint`.

## 9. Verifying that behaviour did not change

Each structural stage has to prove it changed nothing. The method, established at S2 and reused
afterwards:

1. `PAWPRINT_DIGEST=<day>` dumps every numeric field of that day's summary and then checksums the
   summaries of **every** stored day.
2. Build the pre-stage commit in a `git worktree`, run the same probe against the same database,
   and diff.

For S2 that produced, across the 115-day demo database:

```
before  DIGEST days=115 checksum=8ab4898b51151e79
after   DIGEST days=115 checksum=8ab4898b51151e79
diff of the expanded day: no field differs
```

### Performance across S2

The debug build regressed 7–12% uniformly — including `load 30 days`, which is SQLite and JSON
decoding and has nothing to do with the split. Uniformity across unrelated workloads pointed at the
build rather than the code: calls from the app target into `PawprintCore` are cross-module now, and
a debug build does not inline across a module boundary.

Measured again on the release build, which is what ships:

| Workload | Pre-split | Post-split | Δ |
|---|---|---|---|
| `summary 1 day` | 0.414 ms | 0.419 ms | +1.2% |
| `load 30 days` | 23.682 ms | 23.532 ms | −0.6% |
| `load 90 days` | 69.369 ms | 68.493 ms | −1.3% |
| `lifetime rebuild` | 96.072 ms | 95.633 ms | −0.5% |
| `20k keys @96wpm` | 1,049.836 ms | 1,053.225 ms | +0.3% |
| `20k keys @burst` | 1,304.639 ms | 1,269.689 ms | −2.7% |
| `100k cursor moves` | 4,896.887 ms | 4,899.950 ms | +0.1% |
| `20k clicks` | 995.664 ms | 993.975 ms | −0.2% |
| `5k app switches` | 491.103 ms | 489.815 ms | −0.3% |

Worst case +1.2%, several workloads slightly faster, nothing outside noise. The §14 threshold is
met on the build users run; the debug figure is recorded here so it is not rediscovered as a
mystery later.

The release figures also put the §7 keystroke finding in proportion: 52 µs per key at 96 WPM and
65 µs at burst, against 132 µs and 539 µs in debug. The sliding window is still O(n), and still
worth fixing in S8, but the shipped cost of it is a quarter of what the baseline table suggests.

## 10. Status

| Stage | State |
|---|---|
| S1 Baseline, plan, `PAWPRINT_PERF` | **Done** |
| S3 Characterization tests | **Partial** — 37 tests: privacy invariants, day boundaries + DST, stored-data compatibility, summary determinism, streak rule. Missing: recording policy (A), keyboard/mouse accumulation (C), system state (D), store-level compatibility on a real database fixture (F), update signing (G) |
| S2 Module split | **Done** — 5,491 lines in `PawprintCore`, 702 `package` declarations, 16 written-out memberwise initializers, `DisplayCalibrating` seam. Verified identical by digest and by the 37 tests |
| S10 Debug tooling out of the release | **Done** — `DebugSnapshot` and `DemoData` (2,562 lines) are `#if DEBUG`, the 36 environment branches moved from `AppDelegate` into `DebugCommand`, and the capture knobs fold to compile-time constants. Release binary 16,987,840 → 15,181,216 bytes (−10.6%), and `strings` finds no `PAWPRINT_`, `DebugSnapshot`, `DemoData` or `DebugCommand` in it. CI asserts this |
| S11 Release workflow | **Done** — no GitHub expression reaches a shell; the tag is validated before it selects a ref; `scripts/test_validate_tag.sh` and `scripts/check_workflows.py` run in CI |
| S4 – S9, S12 | Not started |
| F1 Uncapped score | **Done** — surplus kept apart from the 0–100 band, so grades and percentiles are untouched |
| F2 Continuous lustre | **Done** — `CatLustre` in the core; 26 distinct rarity values become 108 distinct lustre values over 116 days |
| F3 Foil finish | **Done** — `CatFoil`, continuous in lustre, masked away from the cat's face |

### Acceptance checks, current state

| Check | |
|---|---|
| `swift build -c debug` | Pass |
| `swift build -c release` | Pass |
| `swift test` | Pass — 37 tests, 0 failures |
| `./scripts/build_app.sh release` | Pass |
| `lipo -archs` | `x86_64 arm64` |
| Existing database loads without loss | Pass — 115-day checksum identical |
| Core summaries unchanged | Pass — no field differs |
| No significant performance regression | Pass — worst +1.2% on the release build |
| Release build free of debug tooling | Pass — asserted in CI |
| Release workflow safe from tag injection | Pass — `scripts/test_validate_tag.sh` |
| Everything else in §17 | Not yet met — the stages they depend on have not run |
