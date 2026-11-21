# Solitus design guide

Written 2026-11-20 from the planning and mockup session. Updated the same day for version 26.0.3, in which phases 2 to 7 of section 11 were built; section 14 lists what was decided while building.

Solitus is a personal task and habit tracker for iPhone and iPad. You hold a card to mark a task done, and the app shows how consistently you do each task over time. It is free, open source (MIT), local-only, and published under the GitHub handle `xbadc0ffe`.

**How to read this document**

- Sections 1 to 4 set scope, platform and architecture. Sections 5 and 6 are the data model and the calculation rules. Sections 7 to 9 specify the screens, gestures and look. Section 11 is the build order.
- Items marked **(v1 proposal)** are reasonable defaults that have not been tested on a device. Expect to tune them.
- Items marked **(not mocked)** have no mockup. Build them from the text, in the same style as the mocked screens.
- Section 12 lists the open questions. Do not silently decide them; implement the stated default and leave a `// OPEN:` comment that names the question number.
- Once code exists, if the code and this document disagree, the code is the source of truth and this document should be updated.

---

## 1. Principles

1. **Tracking is simple; the feel is the product.** The data is small and the logic is modest. The spare processing power goes into material, light and motion, used with restraint.
2. **Trends over streaks.** Running averages and heat maps are the main feedback. Streaks are tracked and shown as plain numbers, never as the headline.
3. **Flat first, then glass.** A flat, fully functional app ships first. The 3D glass style is the next step, built as a layer that can be switched off.
4. **Styles and effects must be easy to add.** New surface styles (wood, leaves), new fill effects (water, fire, crumble) and new card shapes are planned. No view may hard-code a material, colour or animation. See section 4.3.
5. **Respect the phone's settings.** Reduce Motion, Reduce Transparency, Increase Contrast, Dynamic Type and Low Power Mode all change behaviour. See section 9.5.
6. **Good defaults, deep options.** Everything is configurable, but a new user should never need Settings.
7. **Local only.** No account, no server, no analytics, no network requests. First-party Apple frameworks only.
8. **Built to grow.** Tasks are the first feature area. Scheduling and Finances are planned later (section 2). The app shell must be able to host more areas without a rewrite.

## 2. Scope and roadmap

| Stage | Contents |
|---|---|
| **Now: Tasks (26.0.x)** | Track, Task details, Add/Edit, Trends, Tasks list, Settings, notifications, CSV export. Flat style. Testing continues through 26.0.x and possibly 27.0.x. |
| **Next** | 3D glass style with device motion. More styles, fill effects and card shapes after that. Widgets. |
| **Later: Schedule** | A day view that places tasks alongside the phone's Calendar events and Reminders (EventKit, optional, read-only at first). The earlier "day ring" idea belongs here, on its own page, not on Track. |
| **Far future: Finances** | A manual finance section modelled on the owner's existing spreadsheet system. No bank sync. |

Out of scope for now: iCloud sync, Apple Watch, sharing, any account system, and the tip jar (to be added after release, as in Pull State).

## 3. Platform and project setup

| Item | Value |
|---|---|
| App name | Solitus (store name and home-screen name) |
| Bundle ID | `com.badc0ffe.solitus` |
| App Group | `group.com.badc0ffe.solitus` (shared SwiftData container, for widgets later) |
| Platforms | iOS and iPadOS only. iPhone first; iPad layout is an open question (12.12). |
| Minimum OS and tools | Match Pull State's current requirements (iOS 26.4+, Xcode 26+). |
| Language | Swift 6 language mode, MainActor default isolation. Cross-actor value types are `nonisolated` and `Sendable`. |
| UI and storage | SwiftUI and SwiftData. Swift Charts for the trend graph. |
| Dependencies | None. No third-party packages. |
| Licence and repo | MIT, `xbadc0ffe/solitus` |
| Tests | Swift Testing, unit tests for every service in section 6 (`SolitusTests`). XCTest UI tests that drive the gestures and flows in the simulator (`SolitusUITests`, its own scheme). |

**Versioning.** `<year>.<major>.<minor>`, starting at **26.0.1**. Testing builds stay on major 0. The public release happens on a major-0 version; later major changes to the app increment the major number. The build number is a timestamp (`yyyyMMddHHmm`), as in Pull State.

**Development flow.**

1. A Claude Code session on the Windows PC creates the repository and the initial code, and pushes to GitHub. That machine cannot compile Swift, so nothing it writes is verified.
2. The repository is pulled on the Mac mini (CoffeeDev), driven headless over SSH. The first Mac session's job is to make the project build and the tests pass with `xcodebuild`.
3. Builds go to TestFlight and are tested on the phone, later the iPad.

**Xcode project.** Use file-system-synchronised groups (Xcode 16 and later) so that adding a Swift file never requires editing `project.pbxproj`. The project has an app target `Solitus`, a unit-test target `SolitusTests` and a UI-test target `SolitusUITests`. The App Group entitlement is present from the first commit.

## 4. Architecture

### 4.1 Layers

- **Core**: date and period maths, settings, shared utilities. No SwiftUI.
- **DesignSystem**: theme, surfaces, fill effects, motion, shared components. Prefix `SL`.
- **Features**: one folder per feature area. Only `Tasks` exists now.
- **App**: the entry point, the model container, and the root shell.

Services are plain types with no SwiftUI imports, so every rule in section 6 can be unit tested without a simulator.

### 4.2 Folder map

```
Solitus/
  App/                SolitusApp, RootView, AppSection, ModelContainerFactory,
                      AppNow (today and the minute, in the environment), AppRouter (the open sheet),
                      DebugLaunch (launch arguments for checking screens; debug builds only)
  Core/               DayKey.swift, PeriodCalculator.swift, AppSettings.swift, Clock.swift (AppClock)
  DesignSystem/
    Theme/            SLTheme.swift, SLPalette.swift, SLTypography.swift, SLMetrics.swift
    Surface/          SLSurface.swift, SLSurfaceStyle.swift, FlatSurface.swift
    Fill/             SLFillEffect.swift, SweepFill.swift
    Motion/           SLMotionProvider.swift, StaticMotion.swift
    Components/       SLBackground, SLTabBar, SLScreen (page frame, title, empty state),
                      SLControls (SLSegmented, SLStepper, SLToggle, SLChip, SLTextField, SLGroup, SLNote),
                      SLSheet, SLHoldGesture, SLHeatCell (and SLYearTile),
                      SLStatCard (and SLFillCard, SLButton, SLSwatch)
  Features/
    Tasks/
      Models/         TaskItem.swift, Entry.swift, Slot.swift, TasksSchema.swift,
                      TaskEnums.swift, TaskRules.swift (value snapshots for the services)
      Services/       EntryStore, ScoreCalculator, RunningAverage, StreakCalculator, HeatCalculator,
                      PriorityRanker, TrendAggregator, ReminderScheduler, ReminderCoordinator, CSVExporter,
                      TaskCalc (the calculators built together, and a task's snapshot),
                      CardStatus (the words and numbers on a card), SampleData
      Track/          TrackView, TaskCard
      Detail/         TaskDetailView, HeatCalendar, YearHeatView
      Edit/           TaskEditSheet, TaskDraft (the form's rules, as a value), SymbolCatalog
      Trends/         TrendsView, TrendGraph, TrendSheet, TrendData (the graph's lines)
      List/           TaskListView
      Settings/       SettingsView
  Resources/          Assets.xcassets
SolitusTests/         unit tests
SolitusUITests/       UI tests
docs/                 DESIGN.md, BUILD_NOTES.md
design/               mockups (reference only), icon (the script that draws the app icon)
```

### 4.3 Extension points for styles and effects

These four seams exist from the first build, even though each has one implementation at first.

| Seam | Purpose | First implementation | Planned |
|---|---|---|---|
| `SLTheme` | Colour tokens, radii, type sizes, glass tint. A value passed through the SwiftUI environment. | Dark neutral theme (section 9.1) | Light theme, user tints, per-task colours |
| `SLSurfaceStyle` | Draws a surface for a given role: `card`, `panel`, `statCard`, `row`, `well`, `bar`, `sheet`, `heatCell`, `raised`. Receives the role, corner radius, and the current motion tilt. | `flat` | `glass3D`, then `wood`, `leaves` and others |
| `SLFillEffect` | Draws progress inside a surface, given a fraction from 0 to 1, the number of sections, and an animation phase. | `sweep` (section 8.2) | `water`, `fire`, `crumble`, driven by physics and device tilt |
| `SLMotionProvider` | Publishes a tilt vector with x and y between -1 and 1. | `static` (always zero) | `device` (Core Motion) |

Rules:

- Views ask `SLSurface(role:)` for their background. They never apply a material, shadow or border directly.
- Views never read colours except from `SLTheme`.
- Prefer an enum of styles with one renderer file per case over protocol existentials. Adding a style should mean adding one enum case and one file.
- A card's outline is a parameter (`SLCardShape`, rectangle only for now), so circles and other shapes can be added later.
- System sheets do not inherit custom environment values (a real bug source in Pull State). Every pop-up page therefore uses `SLSheet` (`.slSheet(item:)`), which is drawn inside the presenting view rather than by the system and sets the theme, surface style and motion tilt on its content itself. If a system sheet is ever used, it must be given all three explicitly.
- A long press on anything inside a scroll view uses `SLHoldGesture`. SwiftUI's own long-press gesture can swallow the drag that should scroll.

### 4.4 App shell

`RootView` builds its tab bar from a list of `AppSection` values. Today the list is the four Tasks tabs: Track, Trends, Tasks, Settings. When Schedule and Finances arrive, the navigation will be redesigned; nothing should assume there are exactly four tabs or that every tab belongs to Tasks.

Follow Pull State's conventions: no SwiftUI `Form` or `List` (build with `ScrollView`, stacks and `SLSurface`), no force unwraps, and never hide the navigation back button.

## 5. Data model

SwiftData models live in the App Group container. Use a `VersionedSchema` and a `SchemaMigrationPlan` from version 1, because this app will evolve for years. Store enums as raw strings.

Do not name a model `Task`; it collides with Swift concurrency's `Task`. The model is `TaskItem`.

### 5.1 `TaskItem`

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | String | |
| `symbol` | String | SF Symbol name |
| `colorHex` | String? | Reserved. Unused until per-task colours are designed. |
| `kind` | enum | `do` or `avoid` |
| `period` | enum | `daily`, `weekly`, `monthly` |
| `goalMode` | enum | `exactly`, `atLeast` (Do only), `atMost` (Avoid only), `noLimit` (either) |
| `target` | Int | N. Ignored for `noLimit`. Default 1 for Do, 0 for Avoid. |
| `unit` | String? | Optional label such as "glasses" |
| `slots` | [Slot] | Preferred times or days, cascade delete |
| `remindersEnabled` | Bool | |
| `pinWhenLogged` | Bool | Avoid only, default true |
| `streakGap` | Int | Periods a streak may skip, default 0 |
| `fullAt` | Double | Running average that counts as full, default 0.85 |
| `heatMax` | Int? | Top of the heat scale for count-based heat; nil means automatic |
| `quickStat` | enum | Which stat the Track card shows: `progress`, `avg30`, `avg90`, `streak` |
| `sortOrder` | Int | Manual order, used as a tiebreak |
| `isArchived` | Bool | |
| `createdAt` | Date | |
| `entries` | [Entry] | Cascade delete |

### 5.2 `Entry`

One row per task per calendar day on which something was logged.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `task` | TaskItem | |
| `dayKey` | String | `yyyy-MM-dd` in the device's local calendar at the time of logging. A string, not a `Date`, so that time zone changes never move an entry to another day. |
| `count` | Int | Running total for that day |
| `updatedAt` | Date | |

There is at most one entry per task and `dayKey`. `EntryStore` enforces this: incrementing finds or creates the row; decrementing to zero deletes it.

### 5.3 `Slot`

A preferred time or day for one of a task's repetitions. A suggestion used for ordering and reminders, never a requirement.

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `task` | TaskItem | |
| `index` | Int | 0-based position |
| `minutes` | Int? | Daily tasks: minutes after midnight |
| `weekday` | Int? | Weekly tasks: 1 (Sunday) to 7 |
| `dayOfMonth` | Int? | Monthly tasks: 1 to 31, clamped to the month's length |

A task has at most `target` slots, and at most 4. Tasks with no limit, or a target above 4, have none.

### 5.4 `AppSettings`

A single stored record.

| Field | Default |
|---|---|
| `weekStart` (1 to 7, 1 is Sunday) | 1 |
| `appearance` (`system`, `dark`, `light`) | `dark` until a light theme exists |
| `surfaceStyle` | `flat` |
| `effectsEnabled` | true (has no visible effect while the style is `flat`) |
| `glassTintHex` | `#DCE6F5` |
| `streakEmphasis` | true |
| `streakPriorityBoost` | true |
| `trendGroupSize` | 5 |
| `notificationsRequested` | false |

## 6. Rules and calculations

Each rule below is a service with unit tests. "Today" always comes from an injectable clock (`AppClock` in `Core/Clock.swift`; the name avoids Swift's own `Clock` protocol), never from `Date()` directly.

The calculation services do not read the SwiftData models. They work on plain values (`TaskRules`, `SlotRule`, `TaskHistory`, and a `[DayKey: Int]` of counts) that `TaskItem` produces on request, so every rule can be tested without a model container.

### 6.1 Periods

- **Daily**: one local calendar day.
- **Weekly**: seven days beginning on `weekStart`. Any weekday is allowed; the default is Sunday. Changing it regroups history, which is fine because entries are stored per day.
- **Monthly**: one calendar month.

A period's **count** is the sum of its entries' counts.

### 6.2 Goal and status

| Kind | Goal mode | Met when | Card shows |
|---|---|---|---|
| Do | exactly N | count = N | `count/N`, then "Done" |
| Do | at least N | count >= N | `count/N`, then "Done"; further holds keep counting |
| Do | no limit | never "done" | the count |
| Avoid | at most N | count <= N | the count; "clear" while 0 |
| Avoid | no limit | not scored | the count |

For `exactly`, a hold at the target does nothing except a soft haptic (open question 12.6).

### 6.3 Score

A period's **score** is between 0 and 1.

- Do with a target: `min(count / N, 1)`.
- Avoid with a limit: 1 if `count <= N`, otherwise 0.
- No limit: no score. These tasks are left out of every average and show totals instead.

### 6.4 Daily value **(v1 proposal)**

Averages and heat are computed per day, so each day needs a value.

- Daily task: that day's score.
- Weekly or monthly task: the score of the period containing the day.
- Current, unfinished weekly or monthly period, Do: pace so far, `min(1, count / max(1, ceil(N * daysElapsed / daysInPeriod)))`.
- Current, unfinished period, Avoid: 1 while within the limit, otherwise 0.
- Days before `createdAt` have no value.

### 6.5 Running average

`RA(W, d)` is the mean of the daily values from day `d - W + 1` to day `d`, for W of 30 or 90. Days with no value are skipped. If no day in the window has a value, the average is undefined and the UI shows a dash.

- The **30-day and 90-day cards** on Task details show `RA(30, today)` and `RA(90, today)`.
- The **trend graph** plots `RA(W, d)` for each day `d`, so every point is the average of the W days ending on that day.

**Fill colour.** A running-average fill is coloured by `min(RA / fullAt, 1)` on the heat ramp (section 9.3). At the default `fullAt` of 0.85, anything at or above 85% is at maximum.

### 6.6 Trends aggregates

Computed over scored, unarchived tasks.

- **Total average**: the mean of the tasks' running averages.
- **Best group** and **worst group**: rank tasks by today's `RA(W, today)` for the selected window. Take the top K and the bottom K, where K is `min(trendGroupSize, taskCount)`. Each group's line is the mean of its members' running averages on every plotted day. Membership is fixed by today's ranking so the lines are continuous.
- With five or fewer tasks, both groups contain every task and the three lines coincide. This is accepted for now (open question 12.2).
- The **Most completed** and **Most neglected** lists show the same groups, up to K rows each.
- **Top streaks**: the three longest current streaks.

### 6.7 Streaks

Streaks are counted in periods (days, weeks or months, matching the task).

- A period is **met** as in 6.2. A no-limit Do task's period is met when its count is at least 1.
- The **current streak** is the number of met periods counting back from now. The current period counts if already met. If it is not yet met, it does not break the streak until it ends.
- `streakGap` G: up to G consecutive unmet periods are forgiven. Forgiven periods do not add to the length.
- **Best** is the longest streak ever. **Average** is the mean length of all streaks of length 1 or more, including the current one.

### 6.8 Heat

One heat value per day combines that day's amount with recent momentum, so a single day after a long gap is only warm.

```
a(d) = the day's amount, 0 to 1
m(d) = 0.55 * m(d-1) + 0.45 * a(d)      momentum; m before the first day equals a of the first day
k(d) = 0.6 * a(d) + 0.4 * m(d)          heat
step = round(k * 5)                     0 to 5, mapped to the ramp in section 9.3
```

The weights are a **v1 proposal**. Keep them as named constants.

- Do task with a target: `a(d)` is the daily value (6.4).
- No-limit task: `a(d) = min(count / heatMax, 1)`. Automatic `heatMax` is the largest daily count in the last 90 days, with a floor of 3.
- Avoid task: unresolved (open question 12.1). Default: `a(d) = min(count / heatMax, 1)`, so heat shows occurrences.
- **All-tasks heat** on Trends: `a(d)` is the mean daily value across scored tasks.

The **year view** uses the same `k(d)` per day, drawn as a soft glow per day position with no cell outlines (section 7.3).

### 6.9 Track order **(v1 proposal)**

Cards are sorted into five groups, top to bottom. There are no group headings on screen.

1. **Logged Avoid tasks** with `pinWhenLogged` on and a count above 0 this period.
2. **Do tasks with a target, not yet met**, by urgency, highest first.
3. **No-limit tasks**, untouched ones above ones already logged this period.
4. **Clear Avoid tasks** (count 0), plus logged Avoid tasks with pinning off.
5. **Met tasks**, dimmed.

Urgency within group 2 is the sum of:

| Component | Value |
|---|---|
| Daily, next unmet slot is overdue | 3, plus up to 1 as the hours overdue approach 24 |
| Daily, next unmet slot within 2 hours | 2 |
| Daily, slot later today | between 0 and 1, rising as the time approaches |
| Daily, no slots | 1 |
| Weekly or monthly, remaining repetitions exceed days left | 4 (behind) |
| Weekly or monthly, remaining equals days left | 3 (must act today) |
| Weekly or monthly, today is a preferred day | 2.5 |
| Weekly or monthly, otherwise | remaining divided by days left |
| Streak at risk: current streak of 3 or more and the period unmet | +0.5, only if `streakPriorityBoost` is on |

Ties fall back to `sortOrder`. The order is recomputed when an entry changes, when the app comes to the foreground, and on a one-minute timer while Track is visible.

## 7. Screens

Mockups are in `design/mockups/` (reference only; see that folder's README). Sizes below are in points on a 390-point-wide phone.

### 7.1 Navigation

- A floating pill tab bar at the bottom: **Track**, **Trends**, **Tasks**, **Settings** (gear icon). Content scrolls underneath it.
- Track to Task details is a push, inside a `NavigationStack` (Trends has its own, for its task rows). The details page uses the system navigation bar with no background: the system back button on the left and Edit on the right. The tab bar stays visible.
- Anything that pops up over a screen is a **sheet** (section 7.6): Add/Edit task and the trend graph detail.

### 7.2 Track

The main screen. It answers one question: what is done, and what is left?

- **Header**: the date at top left ("Fri, Nov 20") and the live time at top right. No title.
- **Grid**: two columns of cards, each 108 high, filling the column width. Column gap 12, row gap 16. Ordered by 6.9.
- **Card contents**:
  - Title, top left, one line. 17 semibold, shrinking to a minimum of 12 to fit. Never wraps.
  - Period under the title: "Daily", "Weekly" or "Monthly".
  - Status, bottom left: 22 semibold, with a small caption beside it ("today", "this week", "this month").
  - The task's icon, large and faint, behind the text at bottom right.
- **Progress is the whole card.** The fill grows from the left edge to `count / N` of the card's width.
  - Targets of 2 to 4 divide the card into equal sections with a seam between them (section 9.2).
  - Targets above 4 fill smoothly with no seams.
  - The edge of a partial fill is a faint line, not a bright one.
- **States**:

| State | Appearance |
|---|---|
| Not started | Empty surface, status `0/N` |
| In progress | Partial fill, status `count/N` |
| Done | Full fill, status "Done", whole card dimmed to about 55% |
| No limit | No fill, status is the count, caption "today, no limit" |
| Avoid, clear | Full but very faint fill, status `0`, caption "clear today", slightly dimmed |
| Avoid, logged | Full red-tinted fill with a red edge, status is the count |

- **Gestures** (section 8): tap cycles the quick stat, double tap opens details, long press completes or adds one.
- **Filters** are not on this screen yet (open question 12.3).

### 7.3 Task details

Pushed from a card. Top to bottom:

1. **Bar**: back to Track on the left, Edit on the right (opens the Add/Edit sheet).
2. **Tracker card** (112 high): the title, the period, and the status. The entire card fills in sections exactly like the Track card. A long press here also logs.
3. **Undo control** **(not mocked)**: a small "Undo last" button under the tracker card that subtracts one from today's count. Hidden when today's count is 0. See open question 12.4.
4. **Last 30 days** and **Last 90 days**: two separate cards (58 high), stacked. Each shows its label on the left and the percentage on the right. The card's own background is the fill: a gradient that brightens toward the level and then fades out over a short distance. There is no hard line and no inner bar. Colour follows 6.5.
5. **Streak**: three cards in a row, number over label: **Current**, **Average**, **Best**. Numbers only. If `streakEmphasis` is off, this row moves to the bottom of the screen.
6. **Heat calendar**:
   - A title bar with previous and next arrows. Tapping the title switches between the two views.
   - **Month view**: weekday initials (starting on `weekStart`), then a grid of square, numbered day cells. Each cell's colour is its heat step, and hotter cells glow. Today has a white outline. Future days are empty outlines. There is no legend.
   - **Year view**: twelve month tiles in a 4-by-3 grid. Each tile has the month's short name and, below it, a soft bloom of heat laid out where that month's days fall on a seven-column grid. There are no day cells and no numbers; the aim is a feel for each month's trend. The current month is outlined. Tapping a month opens it in month view.

There is no line graph on this screen.

### 7.4 Add / Edit task

One form for both. Presented as a sheet (the mockup draws it as a full screen; build it as a sheet). Cancel on the left, Save on the right. Editing an existing task adds Archive and Delete at the bottom; Delete asks for confirmation.

| Group | Controls |
|---|---|
| **Name** | Icon button (opens an SF Symbol picker, not mocked) and a text field |
| **Type** | Segmented: **Do** or **Avoid**. A one-line explanation sits underneath. |
| **Repeats** | Segmented: **Daily**, **Weekly**, **Monthly** |
| **Goal** | Segmented. For Do: **Exactly**, **At least**, **No limit**. For Avoid: **At most**, **No limit**. Below it, a stepper labelled "Times per day" (or week, month; "Allowed per day" for Avoid). The stepper is hidden for No limit. |
| **Preferred times / days** | One chip per repetition, up to 4. Daily tasks pick a time, weekly a weekday, monthly a day of the month. Tapping a chip opens the matching picker (not mocked). A note says these are suggestions. A **Remind me** switch. Hidden for Avoid tasks, for No limit, and for targets above 4. |
| **Avoid only** | A switch: **Move to the top once logged** |
| **Scoring** | Stepper: **Streak allows a gap of** (None, 1 day, 2 days and so on, in the task's period unit). Stepper: **Average is full at** (50% to 100% in steps of 5, default 85%). |

Switching Type resets the goal: Avoid becomes "At most 0"; Do becomes "Exactly 1" for a new task.

Controls are custom components in the app's style: a segmented control is a recessed track with a raised selected piece; steppers are round raised buttons; switches are a recessed track with a bead.

### 7.5 Trends

A scrolling page about all tasks together. Top to bottom:

1. **Title**: "Trends".
2. **All-tasks heat calendar**: the same component as on Task details, including the month and year toggle, fed with all-tasks heat (6.8).
3. **Running average graph**:
   - A 30 days / 90 days switch.
   - Three lines only: **Total**, **Best 5** and **Worst 5** (6.6), each with its current value in a small legend above the plot. The number in the label follows `trendGroupSize`.
   - The x-axis shows exactly one window (30 or 90 days) with today at the right edge. The plot scrolls left through older history.
   - The y-axis is fixed at 0% to 100%.
   - Tapping the graph opens the trend sheet (7.6).
4. **All tasks, last 30 days** and **last 90 days**: two fill cards as in 7.3.
5. **Most completed** and **Most neglected**: up to K rows each. A row is a small fill card with the task name and its 30-day average. Tapping a row opens that task's details.
6. **Top streaks**: three number cards.

Lines must be distinguishable without relying on colour alone: Total is white and thickest, Best is orange and solid, Worst is grey and dotted.

### 7.6 Sheets

All pop-up pages share one presentation, `SLSheet`:

- Drawn by the root view over everything, including the tab bar. It is not a system sheet (section 4.3).
- Slides up from the bottom over the current screen.
- Leaves about 64 points of the screen behind it visible at the top, dimmed by roughly 50% black.
- The sheet itself is transparent with a strong blur of whatever is behind it, rounded top corners (28), and a small grabber.
- Dismissed by dragging the grabber down or by tapping the visible strip at the top. (Only the grabber drags, so that the sheet's own content can scroll.)
- On a wide screen the sheet is at most 640 points wide and centred.
- With Reduce Transparency on, the sheet becomes an opaque dark surface.

**Trend sheet.** Opened from the Trends graph. It contains the 30/90 switch, a taller version of the same scrolling graph, and a **Lines** list. Each line has a sample of its stroke, a name, its current value and a switch. Total, Best and Worst are present by default. **Add a task** opens a picker to add any task's own line. Changes here affect this sheet only and are remembered between openings (in `UserDefaults`, key `trendSheetLines`; the privacy manifest declares this); the graph on the Trends page always shows the three default lines. Every added line needs its own colour and dash pattern.

### 7.7 Tasks **(not mocked)**

The management list.

- Every unarchived task as a row (icon, name, a one-line summary such as "Daily, 3 times"), in `sortOrder`.
- Drag to reorder.
- An add button opens the Add sheet. Tapping a row opens the Edit sheet.
- An Archived section at the bottom, collapsed by default. Archived tasks keep their history and can be restored.

### 7.8 Settings **(not mocked)**

| Group | Controls |
|---|---|
| **Appearance** | Style (Flat now; 3D glass later). **Motion and effects** switch. Glass tint. Appearance (system, dark, light) once a light theme exists. |
| **Tracking** | Week starts on (any weekday). |
| **Streaks** | Emphasise streaks. Let streaks raise priority on Track. |
| **Trends** | Tasks in the best and worst groups (default 5). |
| **Notifications** | Status of the system permission, with a link to system Settings if denied. |
| **Data** | Export CSV. |
| **About** | Version and build, GitHub link, MIT licence. |

## 8. Interaction

### 8.1 Card gestures

| Gesture | Action |
|---|---|
| Tap | Cycle the quick stat shown in the card's status line: progress, 30-day average, 90-day average, streak. The choice is saved per task (`quickStat`). The streak option is skipped when `streakEmphasis` is off. |
| Double tap | Open Task details. |
| Long press | Log one. For a single-count task this completes it. For Avoid tasks it records an occurrence. |

Recognising a double tap delays the single tap slightly. If that feels sluggish on the device, see open question 12.7.

### 8.2 Hold to fill

The long press is the app's signature moment.

- While the finger is down, the fill advances toward the next step. It starts fast and eases out, slowing as it nears the end.
- When it arrives, the fill settles with a small "pop" (a brief scale overshoot) and a success haptic. The entry is saved at that moment.
- Lifting early cancels: the fill drains back and nothing is saved.
- Total hold time is about 0.6 seconds (a named constant; tune on the device).
- With Reduce Motion on, there is no travel animation: a short hold commits with a cross-fade and the haptic.

This behaviour is the `sweep` fill effect. It must sit behind `SLFillEffect` so later effects (water pouring in, fire, cracking and crumbling, all reacting to how the phone is held) can replace it per the user's choice.

### 8.3 Undo and direct entry

Undo is on Task details (7.3). Entering an arbitrary number in one go is not designed yet (open question 12.4).

### 8.4 Day rollover

When the local day changes while the app is open (or on returning to the foreground), every screen recomputes "today". Listen for the system's day-changed notification and scene-phase changes.

## 9. Visual design

The design language: dark, neutral, quiet. Colour appears only where it carries meaning (heat, and red for a logged Avoid task). The mockups use Inter as a stand-in; the app uses the system font.

### 9.1 Tokens (flat style)

**Colour**

| Token | Value |
|---|---|
| Ground | `#08090B` |
| Text, primary | `#FFFFFF` |
| Text, secondary | white at 74% |
| Text, faint (future days, disabled) | white at 62% |
| Glass tint (default) | `#DCE6F5` |
| Surface | gradient at 160 degrees, tint at 11% to tint at 3%, over a background blur |
| Surface border | white at 12%, 1 point |
| Progress fill | vertical gradient, tint at 24% to tint at 11% |
| Raised control (selected segment, stepper button, chip) | vertical gradient, tint at 30% to tint at 14% |
| Recessed well (segmented track, text field, switch track, year tile) | black at 30% with an inner shadow |
| Faint fill (clear Avoid) | tint at 10% to tint at 4% |
| Alert fill (logged Avoid) | `rgb(226, 92, 72)` at 34% to 16% |
| Alert edge | `rgb(240, 128, 108)` at 65% |
| Partial-fill edge | white at 16%, 1 point |
| Sheet scrim | black at 50% |

**Background.** The ground is not flat black. A few very soft, large, neutral light fields and two faint diagonal bands of light sit behind everything, so that translucent surfaces have something to blur. Build it once as `SLBackground`.

**Shape**

| Element | Corner radius |
|---|---|
| Cards and panels | 20 |
| Stat and fill cards | 18 |
| Rows | 16 |
| Segmented track, text field | 14 (selected piece 11) |
| Heat cell | 7 |
| Year tile | 12 |
| Tab bar | fully rounded (height 62) |
| Sheet | 28, top corners only |

**Type** (system font)

| Use | Size and weight |
|---|---|
| Screen header, date and time | 19 semibold |
| Card title | 17 semibold, scales down to 12 |
| Tracker title on details | 24 semibold |
| Status on a card | 22 semibold |
| Large numbers (averages, streaks) | 24 to 26 semibold |
| Body and row labels | 15 medium |
| Secondary text | 12 to 13 medium |
| Tab labels, weekday initials, axis labels | 11 medium |

Sizes follow Dynamic Type. Card titles are the exception: they shrink to stay on one line.

**Spacing.** Screen margin 16. Panel spacing 15. Inner padding 14 to 16. Every tappable control is at least 44 by 44.

**Flat surface depth.** A top inner highlight (white at 18%) and one soft drop shadow (black at 75%, offset 10 down, blur 18, pulled in by 12).

### 9.2 Seams

A multi-count card looks like panes of glass joined edge to edge. Each seam is a clean vertical line made of a 1-point dark line (black at 50%) beside a 1-point light line (white at 36%), with a faint glow fading out a few points to either side. It should read as a join or a perfectly clean crack, not as a divider drawn on top.

### 9.3 Heat ramp

Black to bright orange, six steps. There is no red or burgundy.

| Step | RGB | Number colour |
|---|---|---|
| 0 | 12, 12, 14 | `#F2F3F5` |
| 1 | 44, 22, 6 | `#F2F3F5` |
| 2 | 96, 44, 8 | `#F2F3F5` |
| 3 | 150, 70, 8 | `#F2F3F5` |
| 4 | 232, 120, 16 | `#1A0E05` |
| 5 | 255, 164, 44 | `#1A0E05` |

Cells at step 2 and above glow in their own colour; the glow's radius and strength grow with the step. Continuous uses (fill colour, year-view bloom) interpolate between the stops.

### 9.4 The 3D glass style (next stage, not the first build)

This is the target look shown in the mockups with effects on. Do not build it in the first pass, but keep the seams in 4.3 ready for it.

- **Material**: every surface is a slab of transparent glass with a strong background blur.
- **Depth**: a visible edge about 5 points thick along the bottom, a bevel (light on the top-left edges, dark on the bottom-right), and a cast shadow.
- **Reflection**: a soft highlight in the top-left corner of each slab.
- **Motion**: the phone's tilt drives a very small rotation of each slab (about 1.3 degrees at most), shifts the reflection (about 10% of the slab's width), and shifts the cast shadow (about 4 points). The motion is subtle; it should be noticed only when looked for.
- **Heat cells**: cut-glass buttons with a bevel, a glint across one corner, and a light inside that moves with tilt.
- **Implementation**: Core Motion for device attitude, low-pass filtered. SwiftUI shader effects (Metal) for refraction and lighting where layered views are not enough. The longer-term aim is lightly simulated physics for light and fills.

### 9.5 System settings

| Setting | Behaviour |
|---|---|
| Reduce Motion | No tilt, no moving reflections, no fill travel. Effects that depend on motion fall back to their still form. The flat style is used if the chosen style cannot be still. |
| Reduce Transparency | Surfaces and sheets become opaque dark panels; no background blur. |
| Increase Contrast | Stronger borders (white at 30%); secondary text becomes primary. |
| Dynamic Type | Text scales, except one-line card titles. Cards grow taller rather than truncate status text. |
| Low Power Mode | Motion updates pause. |
| VoiceOver | Every card is one element: name, period, status, and the actions "Log one" and "Open details". Heat cells read their date and level. Graph lines have text summaries. |

The app's own **Motion and effects** switch turns the same things off regardless of system settings.

Text contrast must stay at 4.5:1 or better against whatever is behind it, including on fills and heat cells. The number colours in 9.3 are chosen for this.

## 10. Notifications, export, widgets

**Notifications.** Local only. Permission is requested the first time a user turns on **Remind me**, never at launch. If denied, the switch explains how to enable it in system Settings and the app works normally without reminders.

- Daily task with timed slots: a notification at each slot's time, only if that repetition is not yet done.
- Weekly and monthly tasks: a notification on the preferred day (the time of day is open question 12.8; default 9:00 AM), only if still needed.
- Reminders are rescheduled whenever a task is saved, an entry changes, or the app comes to the foreground.

**CSV export.** One row per entry: `task_name, kind, period, goal_mode, target, date, count`. Shared through the system share sheet.

**Widgets.** Not in the first builds. The shared App Group container exists from the start so widgets can be added without moving the database.

## 11. Build order

Each phase should leave the app runnable. Do not start the next until the current one works on a device.

| Phase | Contents |
|---|---|
| **0. Scaffold** | Repository, licence, README, this document, the mockups, the Xcode project with both targets, App Group entitlement. |
| **1. Core** | Models and schema (section 5). All services in section 6 with unit tests. Debug-only sample data. |
| **2. Design system and Track** | `SLTheme`, `SLSurface` (flat), `SLBackground`, tab bar, the Track grid, the card, hold to fill, tap cycle, ordering. |
| **3. Task details** | Tracker card, average cards, streak cards, heat calendar with month and year views, undo. |
| **4. Add/Edit and Tasks** | `SLSheet`, the form and its controls, the Tasks list, archive and delete. |
| **5. Trends** | All-tasks calendar, graph, lists, the trend sheet. |
| **6. Settings and system** | Settings, notifications, CSV export, section 9.5 behaviours. |
| **7. TestFlight polish** | Empty and first-run states, iPad pass, performance. |
| **8. 3D glass** | The style in 9.4 and device motion. |
| **9. Beyond** | More styles, fill effects, shapes, widgets. |

The first Windows session should complete phases 0 and 1 and may begin phase 2. The first Mac session builds, fixes and runs the tests before anything else.

## 12. Open questions

1. **Heat for Avoid tasks.** Should heat mean occurrences (hot is bad), or staying clear (hot is good)? Should it use a different colour? Default: occurrences, same ramp.
2. **Best and worst groups with few tasks.** Accept identical lines, or cap each group at half the task count? Default: accept.
3. **Filters on Track.** Wanted (daily, weekly, monthly, expiring, neglected, plus custom), but placement is undecided. Default: omit.
4. **Undo and direct entry.** Where undo lives, and how to enter a number larger than one at once. Default: "Undo last" on Task details; no direct entry.
5. **Light theme.** Not designed. Default: dark only.
6. **Holding past an "exactly" target.** Ignore, warn, or allow and mark as over? Default: ignore with a soft haptic.
7. **Tap versus double tap.** If the single-tap delay is annoying, alternatives are a visible details affordance or swapping the gestures.
8. **Reminder time for weekly and monthly tasks.** Default: 9:00 AM.
9. **Per-task colours.** Deferred. The `colorHex` field is reserved.
10. **Tasks and Settings screens.** Specified in text only; mock them before or after building.
11. **Empty and first-run states.** Not designed.
12. **iPad layout.** Not designed. Default: the phone layout, with more grid columns on wide screens.
13. **Daily value for weekly and monthly tasks** (6.4), **heat weights** (6.8) and **Track ordering** (6.9) are proposals to tune on a device.

## 13. Later ideas

- Fill effects: water pouring in, fire, cracking and crumbling, all responding to device orientation.
- A warm or fire effect on tasks in a streak, and a cold or ice effect on neglected ones (optional).
- Surface styles beyond glass: wood, leaves, others.
- Card shapes: circles and other outlines.
- A customisable Track screen with saved filters and sorts.
- A day view with Calendar events and Reminders (the Schedule area).
- Widgets: a today list, a single-task card, a heat map, a trend.
- Tip jar, added after release as in Pull State.
- Finances area.

## 14. As built (26.0.3)

Phases 2 to 7 were built in one pass on 2026-11-20. Where the text above left something open, this is what the code does. None of these answers an open question in section 12; each uses the stated default.

**Track and the card**

- The grid uses as many columns as fit cards at least 160 points wide: two on a phone, more on an iPad.
- The quick stat cycles only through stats the task has. No-limit tasks have no averages; a no-limit Avoid task has no streak. A saved stat that no longer applies falls back to progress.
- An "at least" task past its target shows "Done" with the count in the caption ("9 today").
- The hold: the finger rests for 0.12 seconds, then the fill travels for the rest of the 0.6 seconds and the entry is saved when it arrives. Moving the finger more than 18 points turns the hold into a scroll. Lifting after a hold is not also a tap.
- For an Avoid card the hold sweeps the red fill across the faint one. For a no-limit card the fill sweeps across and lands empty with the count one higher.
- Track reorders with an animation when an entry changes and when the minute changes.

**Task details**

- No-limit tasks show totals for the last 30 and 90 days in place of the averages.
- A task with no streak (no-limit Avoid) shows dashes in the streak row.
- The heat calendar cannot move past the current month or year. On a wide screen its grid is at most 440 points wide.

**Add / Edit**

- The icon picker is a grid that opens inside the Name group, from a fixed list of 48 symbols (`SymbolCatalog`).
- Each repetition's chip starts as "Add". Tapping it gives it a default and opens its picker under the chips: a time wheel for daily tasks, seven weekday chips for weekly, a day stepper for monthly. "Clear this one" empties it again. Changing how often a task repeats clears the chips.
- Targets run from 1 to 99 (0 to 99 for Avoid). The streak gap runs from none to 14.
- "Move to the top once logged" sits in its own group, "When logged". Archive and Delete sit in a group called "Manage".
- Save is disabled until the task has a name.

**Tasks**

- Each row has a handle on the right; dragging the handle reorders. VoiceOver has "Move up" and "Move down" on the handle.
- Archived rows have Restore and an edit button.

**Trends**

- The graph reaches back to the earliest scored task, at most two years.
- The Most completed and Most neglected lists rank by the 30-day average whichever window the graph shows.
- Top streaks is hidden when streaks are not emphasised.

**Settings**

- Style is a one-option control (Flat) until the 3D glass style exists. The glass tint is chosen from five presets.
- The Appearance choice (system, dark, light) is left out until a light theme exists (12.5).
- **Temporary:** while there are no tasks, a "Testing" group offers "Load sample tasks", which installs the ten mockup tasks with four months of invented history. It exists so TestFlight builds can be tried with data. Remove it before the public release.

**System settings (9.5)**

- Reduce Motion or the app's own Motion and effects switch: no fill travel and no pop; the sheet fades instead of sliding.
- Reduce Transparency: every surface gets an opaque dark base and nothing is blurred.
- Increase Contrast: borders at white 30%, secondary text becomes primary.
- Only the tab bar and the sheet blur what is behind them. The other surfaces do not, pending a look on a device.

**Empty and first-run states (12.11) and iPad (12.12)**

- Not designed, so the plainest form was built: an icon, a line and a sentence in a panel, with an "Add a task" button on Track. Marked `// OPEN: 12.11`.
- iPad uses the phone layout with more grid columns; other pages are at most 720 points wide and centred, and the tab bar at most 480.

**App icon**

Four glass squares in red, yellow, green and blue on the dark ground, covering half the icon's area. Drawn by `design/icon/make_icon.swift`.
