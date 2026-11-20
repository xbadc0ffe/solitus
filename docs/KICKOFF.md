# Kickoff prompt for the first Claude Code session (Windows PC)

Paste the text below into Claude Code, started in the folder where this bundle was unzipped.

---

You are starting a new iOS app called Solitus. This folder contains the specification and reference material:

- `docs/DESIGN.md`: the full design guide. Read all of it first.
- `CLAUDE.md`: the rules for working in this repository.
- `design/mockups/`: reference mockups (see the README there).

This machine is a Windows PC. It cannot build or run Swift, so everything you write here is unverified. A later session on a Mac will build and test it. Write code that is likely to compile cleanly: keep it simple, avoid clever generics, and prefer APIs you are certain of.

Do the following, in order, and stop when done:

1. Initialise a git repository here. Add an MIT `LICENSE` (copyright holder: badc0ffe), a `.gitignore` for Xcode and Swift, and a short `README.md` (what the app is, requirements, how to build, licence).
2. Create the Xcode project `Solitus.xcodeproj` with an app target `Solitus` and a unit-test target `SolitusTests`, using file-system-synchronised groups, the bundle ID and App Group from `CLAUDE.md`, version 26.0.1, iPhone and iPad.
3. Create the folder layout from DESIGN.md section 4.2.
4. Implement phase 1 from DESIGN.md section 11: the SwiftData models and versioned schema (section 5), and every service in section 6, each with Swift Testing unit tests. Include debug-only sample data matching the tasks shown in the mockups.
5. Implement the skeleton of the design-system seams from section 4.3 (`SLTheme`, `SLSurface` with the flat style, `SLFillEffect` with the sweep effect, `SLMotionProvider` with the static provider) and a minimal `RootView` with the four tabs, so the app launches to an empty Track screen.
6. Write `docs/BUILD_NOTES.md` listing: what was created, anything you were unsure would compile, and the exact first steps for the Mac session (open or build command, running tests, expected failures).
7. Commit in small steps. Create the GitHub repository `xbadc0ffe/solitus` as public if it does not exist, and push.

Do not start phase 2 screens beyond the empty shell. Do not decide any open question in DESIGN.md section 12; use the stated defaults and mark them with `// OPEN: 12.x`.

Before writing code, give me a short plan and wait for my go-ahead.

---

# First Mac session (CoffeeDev), for reference

Pull the repository, read `docs/BUILD_NOTES.md`, then: build with `xcodebuild`, fix compile errors, run the unit tests until they pass, and report what had to change. Only then continue with phase 2.
