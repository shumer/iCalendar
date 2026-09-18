# Working in this repository

## What this app is

MenuCal is a macOS menu bar agent that shows a configurable date and opens a month calendar
under it, in the Liquid Glass language of macOS 26 and later. It is deliberately narrow: no
events, no reminders, no time zones, no accounts; public holidays are the one thing it downloads
(ADR 0004). Its one reason to exist is finish, so a change
that works but departs from `docs/DesignSpec.md` by more than a point is not done. It must never
wake the CPU on a timer it does not need, and never hard-code a calendar fact (first weekday,
month names, days per month).

## Before every commit - not optional

```bash
./run-tests.sh                                                        # must end with no failures
swift build 2>&1 | grep "warning:" | grep -v "ld: warning: search path"   # must print nothing
```

The linker's "search path not found" lines are the Command Line Tools looking for Xcode folders
that do not exist here. They are not ours and do not appear on the CI runner.

Then, before writing the commit:

1. **Tests.** New behaviour in `MenuCalCore` has a test. A fixed bug has a test that fails without
   the fix. A red suite is never committed.
2. **README.** Update it whenever user-visible behaviour or a prerequisite changed.
3. **`docs/`.** A design number changes in `docs/DesignSpec.md` first and in `Tokens.swift`
   second. Add an ADR when a decision was made rather than a detail implemented.
4. **`docs/roadmap.md`.** Move what shipped into the done list; add what the change revealed.
5. **Commit message.** Conventional Commits. Say what was wrong and why the fix is the right
   shape, not which files moved.

## Toolchain constraints

- **Command Line Tools only, no Xcode**, macOS 27 SDK. See `docs/adr/0001-spm-only-toolchain.md`.
- **No `@State`.** From the macOS 27 SDK on it is a macro whose plugin ships only with Xcode.
  View state lives in `@Observable` models owned by the AppKit controllers. `@Bindable`,
  `@Binding`, `@Environment`, `@FocusState` and `@Namespace` are fine.
- **No XCTest and no swift-testing.** The suite is the `MenuCalTests` executable, run by
  `./run-tests.sh`.
- **No `.xcstrings`.** Localisation is `Resources/Localizations/<lang>.lproj/Localizable.strings`.
- **Deployment target macOS 14.0.** `build.sh` corrects the SDK stamp at link time so the app
  gets the window chrome of the SDK it was built with.
- Probe a third party package on this toolchain before adopting it.

## Release and distribution

- **`./build.sh` is the only thing that assembles the app**, locally and in CI alike. It signs
  with `CODESIGN_IDENTITY` when one is set, with the Developer ID in the keychain when it is not,
  and ad-hoc with `CODESIGN_IDENTITY=-`.
- **Nothing is built on a push.** `.github/workflows/release.yml` runs when a release is
  published, builds that tag's commit, signs, hardens, notarises, staples, packs a zip and a disk
  image and writes the install notes itself. See `docs/release.md`.
- **The updater trusts the signature, not the feed.** A download replaces the app only when it
  has the same bundle identifier and Developer ID team as the running copy and is newer. Do not
  relax any of the three, and keep the asset URL pinned to this repository's releases.
- **The zip asset is named `MenuCal-<version>-<build>.zip`.** The updater looks for that shape;
  rename it in the workflow and in `ReleaseFeed` together or not at all.
- **No sandbox, no entitlements, no third party code**: ADR 0002 and ADR 0003.
- **Versions.** `VERSION` is the marketing number, bumped by hand. The build number is
  `git rev-list --count HEAD`.

## Invariants

- **Every calendar fact comes from `Calendar` and `Locale`**, the autoupdating ones at run time
  and injected ones in tests. `CalendarEngine` is a pure function and never calls `Date()`.
- **Day arithmetic goes through `Calendar.date(byAdding:)`**, never through 86400 seconds.
- **Colours are semantic `NSColor`s.** There is no hex value in the app.
- **Every number in a view comes from `Tokens`**, and every token comes from the DesignSpec.
- **Every word on screen is a key, never a literal**: `L("key")`, the same key in every table,
  English as the table the others are measured against.
- **Settings apply on change, not on a button**, and are read through `Preferences`, never through
  `@AppStorage` scattered over views.
- **The status item's width changes only when its text changes**, and is never animated.
- **Logging is `os.Logger`.** No `print()` in the app target.
- **Swift 6 strict concurrency with no `@unchecked Sendable`** and no disabled checks.

## Style

- Comments in English, ending with a period. They explain why.
- Communication with the user is in Russian; code, comments and documentation are in English.
- Never mention an AI or a model in commit messages, in code or in documentation, and never add a
  `Co-Authored-By` trailer for one.
- No typographic dashes anywhere. A plain hyphen, a comma, or two sentences.
- No TODO comments and no commented-out code in a merge.
