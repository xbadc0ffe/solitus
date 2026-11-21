# Build notes

State on 2026-11-20, version 26.0.3. Phases 0 to 7 of DESIGN.md section 11 are built. Everything was built and tested on the Mac mini; the look and feel on a real phone is for TestFlight testing to judge.

## 1. Verified state

| Item | Value |
|---|---|
| Xcode | 27.1 (27A9275) |
| iOS SDK | 27.1 |
| Deployment target | iOS 26.4 |
| Simulators used | iPhone 17 (iOS 27.0), iPad Pro 13-inch (M5) for screenshots |
| App build | Succeeds, Debug and Release, with no compiler warnings |
| Unit tests | 162 tests in 16 suites, all pass |
| UI tests | 16 tests, all pass |

Verified by the UI tests, which drive the app in the simulator:

- Holding a card logs one (single-count, multi-count and Avoid cards). A short press does not. Lifting after a hold is not also a tap.
- Tapping a card cycles its quick stat. A double tap opens Task details.
- A drag that starts on a card scrolls the page and logs nothing.
- Task details: Undo last appears and disappears with today's count; the tracker card logs; Edit opens the sheet.
- The form: Save needs a name; switching to Avoid changes the goal options; a new task appears on Tasks and Track; preferred times open and clear; Delete removes the task.
- Tasks: dragging a handle reorders and the order is kept.
- Trends: the 30/90 switch, opening and closing the graph sheet.
- Settings: switches turn. First run: the three empty states, and "Load sample tasks".

Verified by screenshot, on the iPhone 17 and the iPad Pro 13-inch: every screen's layout with the sample tasks, the year view of the heat calendar, the sheet, and the empty state.

Verified on a device: 26.0.2 launches (26.0.1 crashed; see section 3).

## 2. Commands

Run from the repository root.

```
xcodebuild build -scheme Solitus -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -scheme Solitus -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme SolitusUITests -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
ship Solitus <version>
```

- The UI tests take about four minutes. After they finish, `xcodebuild` sometimes does not exit; once the log shows `Executed 16 tests`, it can be stopped.
- If a test run hangs at the start with "Simulator device failed to launch" on "Clone 1 of iPhone 17", stop it and add `-parallel-testing-enabled NO`.
- The UI test target is Swift 5 without MainActor-by-default, because `XCTestCase` does not fit that mode. The app and the unit tests are Swift 6.

Launch arguments for looking at a screen without tapping (debug builds only; see `Solitus/App/DebugLaunch.swift`):

```
xcrun simctl launch booted com.badc0ffe.solitus -inMemoryStore -seedSampleData -startTab trends
xcrun simctl launch booted com.badc0ffe.solitus -inMemoryStore -seedSampleData -openFirstTask -heatYearView
xcrun simctl launch booted com.badc0ffe.solitus -inMemoryStore -seedSampleData -openSheet add
xcrun simctl io booted screenshot shot.png
```

## 3. Signing and uploads

- The App ID `com.badc0ffe.solitus` and the App Group `group.com.badc0ffe.solitus` are registered and linked. `ship Solitus <version>` works.
- An API key cannot create an App Group or attach one to an App ID. If either is missing, `xcodebuild` reports "Authentication failed: Make sure a bearer token was provided". Both steps are done by hand in the developer portal.
- **26.0.1 crashed at launch on a device.** It was uploaded without the App Group entitlement. On a device, `ModelConfiguration(groupContainer: .identifier(...))` for a group the app is not entitled to stops the process instead of throwing. The simulator does not enforce entitlements and did not show this. Since 26.0.2 the factory asks `FileManager` for the group container first, and builds carry the entitlement.
- TestFlight crash logs can be read through the App Store Connect API (`betaFeedbackCrashSubmissions`), once the tester sends the crash from the TestFlight prompt.

## 4. Still unverified

- **Feel on a device.** The hold's timing (0.12 s rest, 0.6 s in all), the pop, the haptics, and the delay a double tap adds to a single tap (open question 12.7) can only be judged in the hand.
- **Look on a device.** Only simulators have been seen. Only the tab bar and the sheet blur what is behind them; the mockups blur behind every surface. The flat shadow is an approximation.
- **Reminders.** The planner is unit tested and the scheduling is wired in, but no notification has been seen to arrive, and the permission prompt has not been answered in a test.
- **CSV export.** The text is unit tested. The share sheet has not been opened in a test.
- **The time wheel, weekday chips and day stepper** for preferred times were not driven by a test beyond opening and clearing a chip.
- **Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver.** Implemented, not exercised.
- **The App Group container** has only been used in the simulator and by 26.0.2's launch on a device.
- **Schema migration.** `TasksSchemaV1` lists top-level model classes rather than nesting them. When a second version is needed, the old model classes must be copied into `TasksSchemaV1` as frozen nested types. No stored property was changed between 26.0.2 and 26.0.3.

## 5. Temporary things to remove before the public release

- The "Testing" group in Settings with "Load sample tasks", and with it the reason `SampleData` is compiled into release builds.

## 6. Interpretations made while building

These are choices where DESIGN.md was silent or two readings were possible. They are not answers to the open questions. DESIGN.md section 14 lists the screen-level ones.

1. **The clock is `AppClock`, not `Clock`.** Swift's standard library has a `Clock` protocol.
2. **Services work on values, not models.** `TaskItem` produces `TaskRules`, `TaskHistory` and slot values; the calculators never see SwiftData.
3. **"Exactly N" is met at N or more.** A count above N cannot be logged, but can appear if the target is lowered later.
4. **An Avoid task that goes over its limit ends its streak at once**, rather than when the period ends, because the period can never be met again.
5. **Track group 3 holds no-limit Do tasks only.** Every Avoid task goes to group 1 (logged and pinned) or group 4.
6. **Reminders are planned a fixed number of days ahead** (7 for daily, 14 for weekly, 35 for monthly) as one-shot notifications, capped at 60, and rebuilt on every change.
7. **The motion source `static` is spelled `.still` in code**, because `static` is a Swift keyword.
8. **The sheet is drawn by the app, not the system**, so that it can leave the strip of screen visible and blur what is behind it.
9. **The long press is a UIKit recogniser** (`SLHoldGesture`), so that it cannot stop a scroll view from scrolling.

## 7. Open questions marked in code

Search for `// OPEN:`. Each uses the default stated in DESIGN.md section 12.

| Question | Where |
|---|---|
| 12.1 Heat for Avoid tasks | `HeatCalculator.amount` |
| 12.2 Groups with few tasks | `TrendAggregator.groups` |
| 12.3 Filters on Track | `TrackView` |
| 12.4 Undo and direct entry | `EntryStore.undoOne`, `TaskDetailView` |
| 12.5 Light theme | `AppSettings`, `SLTheme`, `RootView`, `SettingsView` |
| 12.6 Holding past an "exactly" target | `EntryStore.logOne` |
| 12.7 Tap versus double tap | `TaskCard` |
| 12.8 Reminder time for weekly and monthly tasks | `ReminderPlanner` |
| 12.9 Per-task colours | `TaskItem.colorHex` |
| 12.11 Empty and first-run states | `SLEmptyState` |
| 12.12 iPad layout | `TrackView` |
| 12.13 Tunable proposals | `ScoreCalculator.dailyValue`, and the constants in `HeatCalculator` and `PriorityRanker` |

## 8. What comes next

Phase 8 (DESIGN.md section 11): the 3D glass style and device motion. Before that, a round of testing 26.0.3 on the phone and the iPad, and decisions on the open questions that testing brings up.
