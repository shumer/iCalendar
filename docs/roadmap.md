# Roadmap

## Done

- **Stage 0, design.** Four concepts on the design canvas, concept A approved, numbers fixed in
  `docs/DesignSpec.md`, toolchain decision in ADR 0001.

- **Stage 1, skeleton.** SwiftPM package, status item with a locale aware date that refreshes at
  midnight, an empty glass panel that closes on Esc and outside clicks, a settings window with
  launch at login, `LSUIElement`, `build.sh`, the test harness.

- **Stage 2, engine.** `CalendarEngine`, `CalendarNavigator`, `DateFormatting` with presets, a
  pattern validator and a formatter cache. 140 tests over 5 locales, the Gregorian, Islamic and
  Hebrew calendars, Japanese and Buddhist smoke tests, daylight saving and a day with no
  midnight. `MenuCalCore` line coverage is 97%.

## Next

- **Stage 3, calendar UI.** The panel per the DesignSpec: navigation, keyboard, scroll, motion,
  accessibility.
- **Stage 4, settings.** Four panes, format editor with live preview, localisation en, ru, uk, pl,
  reaction to locale and time zone changes.
- **Stage 5, release.** Signing, notarisation, updates, CI, DMG, Homebrew cask.

## Open questions

- The header shows the month name and the year as two pieces, month first. Locales that put the
  year first (Japanese, Chinese, Hungarian) read oddly; `MonthGrid.monthTitle` has the right
  order and the header can switch to it if those locales matter.

- Updates: Sparkle 2 has to be embedded and signed inside out in a hand-assembled bundle. Probe it
  on this toolchain before Stage 5.
- The global hotkey: probe the KeyboardShortcuts package on this toolchain before Stage 4.
- App icon artwork for the DMG and the About pane.
