# Solitus

A personal task and habit tracker for iPhone and iPad. Hold a card to mark a task done, and see how consistently you do each task over time: running averages and heat maps first, streaks as plain numbers.

Solitus is free, open source and local only. There is no account, no server, no analytics and no network access.

**Status: in TestFlight testing.** Track, Task details, Add/Edit, the Tasks list, Trends and Settings are built in the flat style. The 3D glass style, widgets and the later feature areas are not.

## Requirements

- iOS 26.4+ / iPadOS 26.4+
- Xcode 26 or later (Swift 6 language mode)
- No third-party dependencies

## Building

1. Clone the repository.
2. Open `Solitus.xcodeproj` in Xcode.
3. Select an iOS or iPadOS simulator, or a device with provisioning set up.
4. Build and run.

From the command line:

```
xcodebuild build -scheme Solitus -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Unit tests use Swift Testing and live in `SolitusTests`:

```
xcodebuild test -scheme Solitus -destination 'platform=iOS Simulator,name=iPhone 17'
```

To launch with sample tasks in a debug build, pass the launch argument `-seedSampleData`.

## Layout

| Folder | Contents |
|---|---|
| `Solitus/App` | Entry point, model container, root shell |
| `Solitus/Core` | Day and period maths, clock, settings. No SwiftUI. |
| `Solitus/DesignSystem` | Theme, surfaces, fill effects, motion, shared components (prefix `SL`) |
| `Solitus/Features/Tasks` | Models, services and screens of the Tasks area |
| `SolitusTests` | Unit tests for every calculation rule |
| `docs` | [DESIGN.md](docs/DESIGN.md) is the specification. [BUILD_NOTES.md](docs/BUILD_NOTES.md) records the verified build state and the commands that work. |
| `design/mockups` | Reference mockups (not runnable) |

## Licence

MIT. See [LICENSE](LICENSE).
