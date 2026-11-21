# Solitus: rules for Claude Code sessions

Read `docs/DESIGN.md` before changing anything. It is the specification. Once code exists and the two disagree, the code wins and the document gets updated in the same change.

## Project

- iOS and iPadOS app. SwiftUI, SwiftData, Swift Charts. Swift 6 language mode, MainActor default isolation.
- Bundle ID `com.badc0ffe.solitus`. App Group `group.com.badc0ffe.solitus`.
- Version scheme `<year>.<major>.<minor>`. Minor goes up by one on every upload. Build number is a `yyyyMMddHHmm` timestamp set by `ship`.
- MIT licence. Repository `xbadc0ffe/solitus`.

## Hard rules

- First-party Apple frameworks only. No third-party packages.
- No network requests, analytics or accounts.
- No force unwraps in shipped code.
- No SwiftUI `Form` or `List`. Build screens from `ScrollView`, stacks and `SLSurface`.
- Never call `.navigationBarBackButtonHidden(true)`.
- The task model is `TaskItem`, never `Task`.
- Views never apply a material, shadow, border or colour directly. Surfaces come from `SLSurface(role:)`, colours from `SLTheme`, progress from an `SLFillEffect`, tilt from an `SLMotionProvider` (DESIGN.md section 4.3).
- Every pop-up page uses `SLSheet` (`.slSheet(item:)`), which is drawn in the view tree and passes the theme, surface style and motion tilt on. A system sheet, if one is ever needed, must be given all three explicitly; system sheets do not inherit custom environment values.
- A long press inside a scroll view uses `SLHoldGesture`, never `.onLongPressGesture`, which can stop the scroll view from scrolling.
- Do not add, remove or rename a stored property of a SwiftData model without a new schema version and a migration stage; TestFlight installs already hold a version 1 store.
- "Today" comes from the injectable `AppClock` (`Core/Clock.swift`), never from `Date()` inside a service.
- Do not use SwiftUI's `@Entry` macro; the model class `Entry` shadows it. Declare environment values with an `EnvironmentKey`.
- Calculation services take plain values (`TaskRules`, `TaskHistory`, `[DayKey: Int]`), not SwiftData models. Pure value types and services are marked `nonisolated`.
- Every rule in DESIGN.md section 6 lives in a service with no SwiftUI import and has unit tests (Swift Testing). Form and card logic lives in plain values (`TaskDraft`, `CardStatusFormatter`, `TrendData`) and is unit tested too.
- Gestures and flows are covered by UI tests in `SolitusUITests`. Run them after touching a gesture, the sheet, navigation or the form: `xcodebuild test -scheme SolitusUITests -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Entries are keyed by a `yyyy-MM-dd` string, never by `Date`.
- Use file-system-synchronised groups in the Xcode project so new files need no project edits.

## Working method

- Follow the build order in DESIGN.md section 11. Finish and verify a phase before starting the next.
- One feature per version increment. Describe the plan before implementing anything not covered by DESIGN.md.
- Do not decide the open questions in DESIGN.md section 12. Implement the stated default and leave a `// OPEN: 12.x` comment.
- Items marked "v1 proposal" keep their numbers as named constants in one place, so they can be tuned.
- The mockups in `design/mockups/` are reference for layout and values. They are not runnable and are not to be ported line by line.

## Machines

- **Windows PC**: writes code and pushes. It cannot build or run Swift. State clearly in the commit message that the code is unverified.
- **Mac mini (CoffeeDev)**, headless over SSH: builds and tests with `xcodebuild`, archives, and uploads to TestFlight with `ship Solitus <version>`. Nothing can tap the simulator by hand there; use the UI tests, and the launch arguments in `App/DebugLaunch.swift` for screenshots. Testing by a person happens on a physical phone through TestFlight, not over USB.

## Commits

Small, focused commits with a plain summary line. Do not commit build products, user data or signing material.
