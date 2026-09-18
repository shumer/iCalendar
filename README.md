# MenuCal

A calendar in the macOS menu bar. It shows the date the way you want it and opens a month grid
under it, in the Liquid Glass language of macOS 26 and later, with a material fallback down to
macOS 14. No events, no accounts, no network: a date and a calendar, finished properly.

Status: in development. See `docs/roadmap.md` for what works today.

## Build

Requirements: macOS 14 or later and the Swift 6 toolchain. The Command Line Tools are enough;
Xcode is not needed and there is no Xcode project.

```bash
./build.sh              # tests, release build, sign, install to /Applications, launch
./build.sh --no-install # the same, but leave MenuCal.app in this folder
```

`build.sh` signs with the Developer ID in your keychain when there is one and ad-hoc otherwise.
Force ad-hoc with `CODESIGN_IDENTITY=- ./build.sh`.

## Tests

```bash
./run-tests.sh              # the suite
./run-tests.sh --coverage   # the suite with a line coverage report for MenuCalCore, 80% minimum
```

The suite is a plain executable, `MenuCalTests`, because the Command Line Tools ship neither
XCTest nor swift-testing. The reasons are in `docs/adr/0001-spm-only-toolchain.md`.

## Layout

| Path | What lives there |
|---|---|
| `Sources/MenuCalCore` | calendar maths, formatting, scheduling: everything testable without a window server |
| `Sources/MenuCal` | the app: status item, panel, settings, design tokens |
| `Sources/MenuCalTests` | the suite |
| `Resources/Localizations` | one `.lproj` per language |
| `docs/DesignSpec.md` | the design contract; `Design/Tokens.swift` mirrors it |
