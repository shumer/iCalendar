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

- **Stage 3, calendar UI.** The panel of concept A: header with the navigation capsule, weekday
  row, 6 by 7 grid with every state of DesignSpec section 6, footer, directional month slide,
  today pulse, Reduce Motion and Increase Contrast variants, keyboard navigation, scroll and swipe
  through `ScrollAccumulator`, VoiceOver labels, values and selection. The status item reads its
  format from `Preferences`, and one `SystemChangeObserver` refreshes everything on a locale, time
  zone, clock or day change and on wake.

- **Stage 4, settings.** Four panes in the system tab style. General: format editor with one
  click locale templates, a hand written TR35 pattern with validation, a live preview and the
  fallback to the last valid pattern, menu bar icon (none, calendar, day number; template images),
  launch at login, a global shortcut recorder. Calendar: first weekday, week numbers, full date
  line, weekends, reopen behaviour. Appearance: theme, system or custom accent, density. About.
  Every change applies at once. Strings in en, ru, uk and pl are picked at run time, so a system
  language change needs no restart, and a test sweeps the sources against the tables in both
  directions. No third party dependencies, see ADR 0002.

## Next

- **Stage 5, release.** Self update from GitHub releases in the manner of DevDeck with its menu
  item and its settings toggle, the release and tests workflows, signing, notarisation, DMG,
  Homebrew cask, the app icon.

## Open questions

- D-8 asks for the grid to be announced as a table. SwiftUI has no table role for custom views on
  macOS; the grid is a group of row groups of labelled buttons today. A real table needs an
  `NSAccessibility` element tree beside the SwiftUI one.
- Keyboard navigation and scrolling are covered by unit tests of `CalendarState` and
  `ScrollAccumulator`, and were not driven end to end by hand yet.
- Glass over a busy, high contrast window lets large shapes show through. If that reads as noise,
  `NSGlassEffectView.tintColor` with a low alpha window background colour is the lever.

- The header shows the month name and the year as two pieces, month first. Locales that put the
  year first (Japanese, Chinese, Hungarian) read oddly; `MonthGrid.monthTitle` has the right
  order and the header can switch to it if those locales matter.

- Settings were checked by eye pane by pane and by relaunching with stored values (week numbers,
  compact density, dark theme, day number icon). Flipping them while the panel is open, the
  shortcut recorder and a live system language change were not driven by hand yet.
- App icon artwork for the DMG and the About pane.
