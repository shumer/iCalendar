# Manual checklist

The fifteen edge cases of the brief, section 7, and the state of each. "Tests" means the unit
suite covers the logic; "By hand" means somebody watched it happen on a Mac. Dates in the second
column are when it was last watched. Everything was run on macOS 26.6 with the macOS 27 SDK;
macOS 14, 15 and 27 were not available and count as unchecked.

| # | Case | Tests | By hand |
|---|---|---|---|
| 1 | Midnight with the panel open | `CalendarState.clockChanged`, `RefreshSchedule.nextFire` | not yet |
| 2 | System language changed while running | string tables checked against each other and the sources | not yet |
| 3 | Region changed (US to PL): first weekday and format | first weekday from locale, presets per locale | not yet |
| 4 | 12 and 24 hour switch | the time preset follows the locale's hour cycle | not yet |
| 5 | Daylight saving and a time zone change | 23 hour day, Sao Paulo's day without a midnight, Warsaw to Tokyo | not yet |
| 6 | Waking after days of sleep | `didWakeNotification` refreshes item, grid and update check | not yet |
| 7 | Non-Gregorian system calendar | Islamic and Hebrew matrix, Japanese and Buddhist smoke tests | not yet |
| 8 | Right to left locale | direction logic only | not yet |
| 9 | Menu bar full, or the notch hides the item | nothing to test: the system owns this, the app never sets a length | not yet |
| 10 | Displays of different density | none | 2026-09-18: opened on a 1x external display, item and panel crisp; moving between displays with the panel open not tried |
| 11 | Leap February, four, five and six week months | yes, several | 2026-09-18: September 2026 shows its empty sixth row |
| 12 | Fast repeated trackpad scrolling | `ScrollAccumulator`, eight cases | not yet |
| 13 | Light and dark switched with the panel open | none | 2026-09-18: dark theme from settings renders correctly after relaunch; switching while open not tried |
| 14 | macOS 14 or 15 without Liquid Glass | none | no such machine |
| 15 | First launch with no stored settings | `Preferences` defaults | 2026-09-18: fresh defaults gave the locale's date and weekday preset |

## Also watched on 2026-09-18

- The status item appears without a Dock icon and stays highlighted while the panel is open.
- The panel opens centred under the item at 300 x 362 (268 x 302 in Compact with week numbers).
- Month navigation, day selection and the Today button through the accessibility tree.
- VoiceOver data: heading, labelled navigation buttons, 42 labelled day buttons, the today cell
  reports "Today" as its value and the selected trait.
- All four settings panes, in Russian, and the window following the height of the pane.
- The day number icon in the menu bar, with the 4 pt gap.
- Check for Updates against a repository with no release yet: "MenuCal is up to date".
- `./build.sh` end to end, `plutil -lint`, the SDK stamp, the disk image mounts with the app and
  the Applications link.

## Watched on 2026-09-18, after 0.1

- Region `ru_PL`: the list for Poland is fetched on launch and cached; 1 and 11 November 2026 and
  1 and 6 January 2027 are red, so the second year is fetched when the grid reaches it.
- Selecting 11 November shows "Ср, 11 нояб. · Narodowe Święto Niepodległości" in the footer, the
  name in red.
- A first launch puts the status item beside Control Center.

- "Highlight weekends" flipped through the accessibility tree while the panel was open: the grid
  redrew at once, so settings do apply to an open panel. With the switch on weekends are red, with
  it off they look like any other day.

- The panel's edge over a white window and over a dark one: a hairline rim and a soft shadow
  that follow the rounded shape, as on system menus, and nothing square in the corners.

## Never watched

- Keyboard navigation and scrolling in the panel, end to end.
- Recording a global shortcut and firing it.
- Settings other than the weekend switch flipped while the panel is open.
- Launch at login after a reboot.
- A real self update from one notarised release to the next.
- The release workflow itself: it needs the five secrets and a published tag.
- Holidays with the network off, with another country picked, and turned off in settings.
- Performance numbers of section 6.5 in Instruments.
- A full VoiceOver pass with the screen reader on.
