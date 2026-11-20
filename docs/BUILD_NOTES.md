# Build notes: first session (Windows PC, 2026-11-20)

**Nothing in this repository has been compiled or run.** It was written on a Windows PC with no Swift toolchain. Expect compile errors. The first Mac session's only job is to make the project build and the tests pass, then report what had to change.

Delete or rewrite this file once the project builds and the tests pass.

## 1. First steps on the Mac

Run from the repository root.

1. Check that Xcode can read the project and sees both targets and the scheme:

   ```
   xcodebuild -list -project Solitus.xcodeproj
   ```

   Expected: targets `Solitus` and `SolitusTests`, scheme `Solitus`. If this fails, the hand-made project file is the problem; see section 3.1.

2. Compile the app without signing:

   ```
   xcodebuild build -scheme Solitus -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
   ```

3. Find a simulator name, then build and run the tests:

   ```
   xcrun simctl list devices available
   xcodebuild test -scheme Solitus -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

4. Fix errors in this order: project file, then `Core`, then `Features/Tasks/Models`, then `Features/Tasks/Services`, then `DesignSystem`, then `App`, then the tests. Later layers depend on earlier ones.

5. Launch in the simulator and check the shell: a dark background with soft light fields, the date and time at the top of Track, and a floating four-tab bar. Add the launch argument `-seedSampleData` to install the ten sample tasks (nothing shows them yet; the Track grid is phase 2).

6. Before the first device or TestFlight build:
   - Register the App Group `group.com.badc0ffe.solitus` and the App ID `com.badc0ffe.solitus` in the developer account (automatic signing should offer to do this).
   - Add an app icon. `AppIcon.appiconset` has an empty 1024-point slot and no image.
   - Set `CURRENT_PROJECT_VERSION` to a real `yyyyMMddHHmm` timestamp. It is the placeholder `202611200000`.

## 2. What was created

**Repository.** `LICENSE` (MIT), `README.md`, `.gitignore`, `.gitattributes`, `CLAUDE.md`, `docs/DESIGN.md`, `docs/KICKOFF.md`, `design/mockups/`.

**Xcode project.** `Solitus.xcodeproj`, made by copying Pull State's `project.pbxproj` and shared scheme and renaming. Two targets (`Solitus`, `SolitusTests`), file-system-synchronised groups for the `Solitus` and `SolitusTests` folders, bundle ID `com.badc0ffe.solitus`, version 26.0.1, iPhone and iPad, Swift 6 with MainActor default isolation, deployment target iOS 26.4, the same development team as Pull State. `Solitus/Solitus.entitlements` holds the App Group. `Solitus/PrivacyInfo.xcprivacy` declares no tracking and no collected data.

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

**Tests** (`SolitusTests`): 13 files (12 suites and a helper file), 135 test functions, covering every service above plus the models. Expected values were worked out by hand, not by running the code.

## 3. Things that may not compile or may not work

Listed with the most likely first.

### 3.1 The project file

`project.pbxproj` was produced by text substitution on Pull State's file, not by Xcode. If Xcode rejects it, the quickest fix is to create a new iOS app project named Solitus with a unit-test target in Xcode 26, then copy the build settings below into it and point it at the existing `Solitus` and `SolitusTests` folders:

`SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`, `IPHONEOS_DEPLOYMENT_TARGET = 26.4`, `TARGETED_DEVICE_FAMILY = "1,2"`, `CODE_SIGN_ENTITLEMENTS = Solitus/Solitus.entitlements`, `MARKETING_VERSION = 26.0.1`, `GENERATE_INFOPLIST_FILE = YES`.

Two settings were removed from the Pull State original because Solitus does not need them: `ENABLE_APP_SANDBOX` and `ENABLE_USER_SELECTED_FILES`. The camera and photo usage strings were removed too.

The deployment target is 26.4 because DESIGN.md says so. Pull State's project file says 26.0. If the installed SDK is older than 26.4, lower it.

### 3.2 `nonisolated` on types

The targets use MainActor default isolation. Every pure value type and calculation service is declared `nonisolated` (for example `nonisolated struct DayKey`, `nonisolated protocol AppClock`, `nonisolated extension AppClock`, `nonisolated enum TasksSchemaV1`). Pull State does not use this pattern, so there is no proven example to copy from. Likely trouble:

- If the compiler rejects `nonisolated` on a protocol or an extension, remove it from that declaration and mark the members instead.
- If a `nonisolated` service cannot call something, the callee is probably MainActor by default and needs `nonisolated` too. Everything the services touch should already be marked.
- If this becomes a fight, the fallback is to delete every `nonisolated` keyword. Everything then runs on the main actor, which is correct for this app today. Only the "values can cross actors" property is lost.

### 3.3 SwiftData

- **Versioned schema.** `TasksSchemaV1` lists top-level model classes (`TaskItem.self` and so on) rather than nesting the models inside the schema enum. That works for version 1. When a second version is needed, the old model classes must be copied into `TasksSchemaV1` as frozen nested types.
- **`ModelContainerFactory`.** Uses `ModelConfiguration(schema:isStoredInMemoryOnly:groupContainer:cloudKitDatabase:)` and `ModelContainer(for:migrationPlan:configurations:)`. Check the argument labels. If the App Group container is not available it falls back to the app's own container, then to memory.
- **`@Relationship` inverses.** `TaskItem.entries` and `TaskItem.slots` declare `inverse: \Entry.task` and `inverse: \Slot.task`. `EntryStore` inserts a new `Entry` into the context and then appends it to `task.entries`. If entries end up with a nil `task` or appear twice, this is the place to look.
- **Deleting an entry.** `EntryStore.add` removes the row from `task.entries` and then calls `context.delete`. The tests `undoToZeroDeletesTheRow` and `deletingATaskDeletesItsEntriesAndSlots` cover this and are the most likely SwiftData tests to fail.
- **The name `Entry`.** SwiftUI has an `@Entry` macro. The model class named `Entry` may shadow it, so the code declares environment values with `EnvironmentKey` and never uses `@Entry`. If the name causes any other clash, rename the model (and update DESIGN.md 5.2).

### 3.4 Notifications

`ReminderScheduler.requestAuthorization()` awaits `UNUserNotificationCenter.requestAuthorization(options:)` from the main actor. Swift 6 may complain about sending a non-Sendable value. Nothing calls the scheduler yet, so it is safe to stub it out and return to it in phase 6.

### 3.5 Imports

`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on, so a file must import every module whose members it uses. A missing `import Foundation`, `import SwiftData` or `import Observation` is an easy fix when the compiler points at it.

### 3.6 Tests

- `try` is never used inside `#expect(...)`; results are assigned to a local first. That was a deliberate precaution.
- `TestSupport.swift` declares a global `let today` and global functions `day(_:_:_:)`, `nov(_:)`, `isClose` and `ones`. If a global named `today` or `day` collides with anything, rename it.
- The suites that use a model container are marked `@Suite(.serialized)` and each test makes its own in-memory container.
- A test that fails on a number (rather than failing to compile) may be a mistake in the test's hand-worked expectation rather than in the service. Check the arithmetic against DESIGN.md section 6 before changing the service.

### 3.7 Look and layout (cannot be judged without a device)

- **No backdrop blur.** The mockups blur what is behind each surface. `FlatSurface` draws only the tinted gradient, border, highlight and shadow. Whether to add a blur, and how, should be decided on a device.
- **The flat shadow** is approximated with a blurred, inset copy of the shape, because SwiftUI has no negative shadow spread.
- **`SLBackground`** scales the mockup's 390 by 844 layout to the screen. It has not been seen on an iPad.
- **SF Symbols** used for tabs and sample tasks were chosen by name from memory: `checkmark.circle`, `chart.line.uptrend.xyaxis`, `square.grid.2x2`, `gearshape`, `wineglass`, `pills`, `dumbbell`, `figure.walk`, `book`, `dollarsign.circle`, `pencil`, `nosign`, `figure.flexibility`, `drop`. A wrong name shows as a blank image, not an error.

## 4. Differences from DESIGN.md and choices made

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

## 5. Open questions marked in code

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

## 6. What comes next

Phase 2 (DESIGN.md section 11): the Track grid, `TaskCard`, hold to fill, the tap cycle, and ordering with `PriorityRanker`. Do not start it until the project builds and every test passes.
