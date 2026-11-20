# Build notes

State after the first Mac session (Mac mini, 2026-11-20). The code was written on a Windows PC without a Swift toolchain; this session compiled it, ran the tests and launched the app. **No source file had to change.**

## 1. Verified state

| Item | Value |
|---|---|
| Xcode | 27.1 (27A9275) |
| iOS SDK | 27.1 |
| Deployment target | iOS 26.4 (unchanged) |
| Simulator | iPhone 17, iOS 27.0 |
| App build | Succeeds with no errors and no compiler warnings |
| Tests | 135 tests in 12 suites, all pass |

Verified by running, not only by compiling:

- `xcodebuild -list` reads the hand-made project file and shows targets `Solitus` and `SolitusTests` and the scheme `Solitus`.
- Swift 6 with MainActor default isolation accepts the `nonisolated` pattern on structs, enums, protocols and extensions. The fallback of deleting the keyword was not needed.
- The SwiftData container opens in the App Group container on the simulator. `ModelConfiguration` and `ModelContainer` argument labels are right.
- `-seedSampleData` installs 10 tasks, 647 entries and 3 slots. Every entry has its task, and no task has two entries for one day, so the `@Relationship` inverses work as written.
- The shell matches the design: dark ground with soft light fields and two diagonal bands, the date ("Fri, Nov 20") at top left and the time at top right of Track, and a floating pill tab bar with Track, Trends, Tasks and Settings.
- All 14 SF Symbol names used for tabs and sample tasks exist in the installed symbol set.

## 2. Commands

Run from the repository root.

```
xcodebuild -list -project Solitus.xcodeproj
xcodebuild build -scheme Solitus -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -scheme Solitus -destination 'platform=iOS Simulator,name=iPhone 17'
```

If the test run hangs with "Simulator device failed to launch com.badc0ffe.solitus" on "Clone 1 of iPhone 17", stop it and add `-parallel-testing-enabled NO`. This happened once, on the very first run, and not again; it is a simulator clone problem, not a fault in the project.

To launch in a booted simulator with the sample tasks (nothing shows them yet; the Track grid is phase 2):

```
xcrun simctl install booted <DerivedData>/Build/Products/Debug-iphonesimulator/Solitus.app
xcrun simctl launch booted com.badc0ffe.solitus -seedSampleData
xcrun simctl io booted screenshot track.png
```

## 3. Still unverified

- **Signing and the App Group on a device.** Every build so far was unsigned or for the simulator. Before the first TestFlight build:
  - The App ID `com.badc0ffe.solitus` is registered (2026-11-20, through the App Store Connect API) with the App Groups and Data Protection (protected unless open) capabilities enabled.
  - The App Group `group.com.badc0ffe.solitus` is not registered yet and is not assigned to the App ID. The public API cannot create App Groups; do it in the developer portal or let Xcode's automatic signing do it.
  - A signed `xcodebuild` build with `-allowProvisioningUpdates` and the API key fails with "Authentication failed: Make sure a bearer token was provided", although the same key works against the App Store Connect API. Unresolved.
  - Create the app record in App Store Connect.
  - The app icon is a placeholder (a three-section card, two sections filled) drawn by script so the first upload is accepted. Replace it with a designed icon.
  - The build number. `CURRENT_PROJECT_VERSION` is the placeholder `202611200000` on the app target (and `1` on the test target). The `ship` script sets a real timestamp.
- **`ReminderScheduler`.** It compiles, but nothing calls it and it has no tests. Only `ReminderPlanner` is tested. Check it in phase 6.
- **Look on a device.** Only the iPhone 17 simulator has been seen.
  - No backdrop blur. The mockups blur what is behind each surface; `FlatSurface` draws only the tinted gradient, border, highlight and shadow.
  - The flat shadow is approximated with a blurred, inset copy of the shape, because SwiftUI has no negative shadow spread.
  - `SLBackground` scales the mockup's 390 by 844 layout to the screen. It has not been seen on an iPad.
- **Surfaces other than the tab bar.** No screen draws a card yet, so `FlatSurface` roles other than `bar`, and `SweepFill`, have compiled but have not been seen.
- **Schema migration.** `TasksSchemaV1` lists top-level model classes rather than nesting them. That works for version 1. When a second version is needed, the old model classes must be copied into `TasksSchemaV1` as frozen nested types.

## 4. What exists

**Xcode project.** `Solitus.xcodeproj`, made by copying Pull State's `project.pbxproj` and shared scheme and renaming. Two targets, file-system-synchronised groups for the `Solitus` and `SolitusTests` folders, bundle ID `com.badc0ffe.solitus`, version 26.0.1, iPhone and iPad, Swift 6 with MainActor default isolation, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` on (a file must import every module whose members it uses), team `ZWS3TP3W3Z`. `Solitus/Solitus.entitlements` holds the App Group. `Solitus/PrivacyInfo.xcprivacy` declares no tracking and no collected data.

**Core** (`Solitus/Core`)

| File | Contents |
|---|---|
| `DayKey.swift` | A calendar day as an integer day number. Parsing and printing `yyyy-MM-dd`, adding days, weekday, month lengths. No `Calendar` except at the edges. |
| `Clock.swift` | `AppClock` protocol, `SystemClock`, `FixedClock` for tests. |
| `PeriodCalculator.swift` | Daily, weekly (any week start) and monthly spans; period counts. |
| `AppSettings.swift` | The single settings record (DESIGN.md 5.4). |

**Models** (`Solitus/Features/Tasks/Models`): `TaskItem`, `Entry`, `Slot` (SwiftData), `TasksSchemaV1` and `TasksMigrationPlan`, the enums in `TaskEnums.swift`, and the value snapshots `TaskRules`, `SlotRule`, `TaskHistory` in `TaskRules.swift`.

**Services** (`Solitus/Features/Tasks/Services`)

| File | DESIGN.md | Notes |
|---|---|---|
| `ScoreCalculator.swift` | 6.2, 6.3, 6.4 | Met or not, period score, daily value. |
| `RunningAverage.swift` | 6.5 | Single average, series for the graph, fill level. |
| `TrendAggregator.swift` | 6.6 | Total average, best and worst groups, group lines, top streaks. Not in the original folder map. |
| `StreakCalculator.swift` | 6.7 | Current, best and average streak, with gap allowance. |
| `HeatCalculator.swift` | 6.8 | Per-task and all-tasks heat. Weights are named constants. |
| `PriorityRanker.swift` | 6.9 | Track order. Every number is a named constant. |
| `EntryStore.swift` | 5.2 | The only writer of entries. Log one, undo one. |
| `ReminderScheduler.swift` | 10 | `ReminderPlanner` (pure, tested) and `ReminderScheduler` (talks to the notification centre, untested). |
| `CSVExporter.swift` | 10 | Builds the CSV text. The share sheet is phase 6. |
| `SampleData.swift` | | Debug only. The ten tasks from the Track mockup with 120 days of history. |

**Design system** (`Solitus/DesignSystem`): the four seams from DESIGN.md 4.3, each with its one first implementation.

| Seam | Files |
|---|---|
| `SLTheme` | `Theme/SLTheme.swift`, `SLPalette.swift`, `SLMetrics.swift`, `SLTypography.swift` |
| `SLSurfaceStyle` | `Surface/SLSurfaceStyle.swift`, `SLSurface.swift`, `FlatSurface.swift` |
| `SLFillEffect` | `Fill/SLFillEffect.swift` (also the `SLFill` view), `SweepFill.swift` |
| `SLMotionProvider` | `Motion/SLMotionProvider.swift`, `StaticMotion.swift` |

Components: `SLBackground` and `SLTabBar` only. `SLSegmented`, `SLStepper`, `SLToggle`, `SLSheet`, `SLHeatCell` and `SLStatCard` are not written; they belong to phases 3 and 4.

**App** (`Solitus/App`): `SolitusApp`, `RootView`, `AppSection`, `ModelContainerFactory`.

**Screens.** `TrackView` shows the date and time header and nothing else. `TrendsView`, `TaskListView` and `SettingsView` show a title. `Features/Tasks/Detail` and `Features/Tasks/Edit` have no files yet, so those folders do not exist in git.

**Tests** (`SolitusTests`): 13 files (12 suites and a helper file), 135 test functions, covering every service above plus the models. All pass (section 1).

## 5. Differences from DESIGN.md and choices made

DESIGN.md and CLAUDE.md were updated for the first three.

1. **The clock is `AppClock`, not `Clock`.** Swift's standard library has a `Clock` protocol. The file is still `Core/Clock.swift`.
2. **Services work on values, not models.** `TaskItem` produces `TaskRules`, `TaskHistory` and slot values; the calculators never see SwiftData. This is what makes them testable without a container.
3. **Extra files**: `TaskEnums.swift`, `TaskRules.swift`, `TrendAggregator.swift` (section 6.6 had no service in the folder map), `SampleData.swift`.
4. **"Exactly N" is met at N or more.** A count above N cannot be logged, but can appear if the target is lowered later. Such a period counts as met rather than leaving the card stuck.
5. **An Avoid task that goes over its limit ends its streak at once.** DESIGN.md 6.7 says an unmet current period does not break a streak until it ends. That is implemented for Do tasks. For an Avoid task, a period that is over the limit can never be met again, so waiting would show a streak that is already lost.
6. **Track groups for no-limit Avoid tasks.** DESIGN.md 6.9 group 3 is "No-limit tasks". Here it holds no-limit Do tasks only; every Avoid task, with or without a limit, goes to group 1 (logged and pinned) or group 4.
7. **Reminders are planned a fixed number of days ahead** (7 for daily, 14 for weekly, 35 for monthly) as one-shot notifications, capped at 60, and rebuilt on every change. Future periods are planned as if nothing is logged.
8. **The motion source `static` is spelled `.still` in code** (raw value `"static"`), because `static` is a Swift keyword.

Items 4 to 7 are interpretations, not answers to the open questions. Change them if they are wrong.

## 6. Open questions marked in code

Search for `// OPEN:`. Each uses the default stated in DESIGN.md section 12.

| Question | Where |
|---|---|
| 12.1 Heat for Avoid tasks | `HeatCalculator.amount` |
| 12.2 Groups with few tasks | `TrendAggregator.groups` |
| 12.4 Undo and direct entry | `EntryStore.undoOne` |
| 12.5 Light theme | `AppSettings`, `SLTheme`, `RootView` |
| 12.6 Holding past an "exactly" target | `EntryStore.logOne` |
| 12.8 Reminder time for weekly and monthly tasks | `ReminderPlanner` |
| 12.9 Per-task colours | `TaskItem.colorHex` |
| 12.13 Tunable proposals | `ScoreCalculator.dailyValue`, and the constants in `HeatCalculator` and `PriorityRanker` |

## 7. What comes next

Phase 2 (DESIGN.md section 11): the Track grid, `TaskCard`, hold to fill, the tap cycle, and ordering with `PriorityRanker`.
