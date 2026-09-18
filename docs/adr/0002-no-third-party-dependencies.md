# ADR 0002: No third party dependencies

Date: 2026-09-18. Status: accepted.

## Context

The brief allows exactly two packages: Sparkle 2 for updates and KeyboardShortcuts for the global
shortcut. Both were looked at on this toolchain (ADR 0001).

- **KeyboardShortcuts 2.4** does not build without Xcode: its recorder uses `@State` and
  `#Preview`, whose macro plugins ship only with Xcode.
- **Sparkle 2** is a binary framework with an XPC service, an updater app and a helper inside
  it. In a bundle assembled by a script every one of them has to be copied, given an rpath and
  signed inside out before the app, or notarisation fails against the inner path. The sibling
  project DevDeck updates itself from GitHub releases with a few hundred lines and a release
  pipeline that is already proven.

## Decision

1. The global shortcut is ours: Carbon's `RegisterEventHotKey`, which needs no accessibility
   permission, and a recorder built from a SwiftUI button and a key event monitor. The shortcut
   itself is a value type in `MenuCalCore` with tests.
2. Updates follow DevDeck: the app asks the GitHub releases API for the latest tag, downloads the
   notarised zip, verifies its signature against its own, and replaces itself. This lands with
   Stage 5, together with the "Check for Updates" menu item and the automatic check toggle, so
   that no control exists before it does something.
3. `Package.swift` has no `dependencies`.

## Consequences

- The bundle holds one Mach-O, so signing is one `codesign` call and notarisation has nothing
  nested to reject.
- No appcast and no EdDSA key: the trust anchor of an update is the Developer ID signature and
  Apple's notarisation of the downloaded app, checked with `SecStaticCode` before anything is
  replaced. B-6 of the brief is superseded by this.
- A shortcut that another app already owns is refused by the system at registration; the
  settings pane says so instead of storing a shortcut that never fires.
