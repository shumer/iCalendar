# Roadmap

## Done

- **Stage 0, design.** Four concepts on the design canvas, concept A approved, numbers fixed in
  `docs/DesignSpec.md`, toolchain decision in ADR 0001.

## Next

- **Stage 1, skeleton.** SwiftPM package, status item, empty glass panel, launch at login,
  `LSUIElement`, `build.sh`.
- **Stage 2, engine.** `CalendarEngine` and `DateFormatting` with the test matrix of locales and
  calendars.
- **Stage 3, calendar UI.** The panel per the DesignSpec: navigation, keyboard, scroll, motion,
  accessibility.
- **Stage 4, settings.** Four panes, format editor with live preview, localisation en, ru, uk, pl,
  reaction to locale and time zone changes.
- **Stage 5, release.** Signing, notarisation, updates, CI, DMG, Homebrew cask.

## Open questions

- Updates: Sparkle 2 has to be embedded and signed inside out in a hand-assembled bundle. Probe it
  on this toolchain before Stage 5.
- The global hotkey: probe the KeyboardShortcuts package on this toolchain before Stage 4.
- App icon artwork for the DMG and the About pane.
