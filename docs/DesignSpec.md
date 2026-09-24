# MenuCal - DesignSpec

Version 1.0, 2026-09-18. Status: **approved**.

This is the design contract for v1. `Sources/MenuCal/Design/Tokens.swift` mirrors the numbers in
this file; when the two disagree, this file wins and the code is the bug.

## 1. Decision record

| Question | Decision (customer, 2026-09-18) |
|---|---|
| Concept | **A, Liquid Glass Native**, from the Stage 0 canvas |
| Today vs selected | Today is a filled accent circle, selected is an accent ring |
| Name and bundle id | MenuCal, `com.shumenko.menucal` |
| Repository | public, so the appcast can live in GitHub releases or Pages |
| Toolchain | SwiftPM only, no Xcode project, see `docs/adr/0001-spm-only-toolchain.md` |

Not part of v1, by design: the month and year quick picker (NAV-4 of the brief, concept A does
not have one), reminders, time zones, accounts of the app's own. Public holidays were added
after 0.1, vacations after 0.3 and events from the system's calendars after 0.4, at the
customer's request (ADR 0005).

## 2. Container

- A borderless `NSPanel` in the manner of Control Center, no arrow. This is the alternative the
  brief allows in PV-1, so closing on an outside click, on Esc and on losing key status is ours
  to handle.
- The panel is centred under the status item, 6 pt below the menu bar, and clamped to the
  screen's visible frame with an 8 pt margin. It opens on the screen that holds the status item.
- The panel can become key without activating the app (`.nonactivatingPanel`), so keyboard
  navigation works and the frontmost app keeps its menu bar.
- The panel never changes size while the month changes. It changes size only when a setting that
  affects layout changes (week numbers, footer, density).

## 3. Geometry

All values are points. "Regular" is the default density; "Compact" is the second value of the
Density setting and keeps the same layout.

| Token | Regular | Compact |
|---|---:|---:|
| `panelWidth` | 300 | 242 |
| `panelWidth` with week numbers | 332 | 268 |
| `panelCornerRadius` (continuous) | 24 | 20 |
| `panelPadding` | 12 | 10 |
| `innerCornerRadius` = radius - padding | 12 | 10 |
| `sectionSpacing` (between header, weekdays, grid, footer) | 8 | 6 |
| `headerHeight` | 32 | 28 |
| `headerLeadingInset` (title only) | 6 | 4 |
| `navCapsuleHeight` | 28 | 24 |
| `navCapsulePadding` | 2 | 2 |
| `navButtonSize` (chevrons) | 28 x 24 | 24 x 20 |
| `todayButtonHorizontalPadding` | 8 | 6 |
| `weekdayRowHeight` | 20 | 16 |
| `dayCellSize` (circle) | 36 | 30 |
| `gridColumnSpacing` | 4 | 2 |
| `gridRowSpacing` | 2 | 2 |
| `weekNumberColumnWidth` | 28 | 24 |
| `footerHeight` | 36 | 30 |
| `dayCircleWithDots` | 30 | 26 |
| `eventDotSize` / `eventDotSpacing` | 4 / 3 | 4 / 2 |
| `dayListHeight` (the panel grows by this, in place of the footer) | 164 | 144 |
| `eventRowHeight` / `eventTimeWidth` | 32 / 52 | 28 / 46 |
| `eventMarkSize` | 3 x 16 | 3 x 14 |
| `groupChipRowHeight` / `groupChipPaddingH` / `groupChipSpacing` | 20 / 8 / 4 | 18 / 6 / 4 |
| `groupChipMaxWidth` / `groupChipDot` | 64 / 6 | 56 / 6 |
| `menuBarGap` | 6 | 6 |
| `screenEdgeMargin` | 8 | 8 |

Derived heights, Regular: 12 + 32 + 8 + 20 + 8 + 226 + 8 + 36 + 12 = **362**; with the footer
hidden 362 - 44 = **318**. Compact: 10 + 28 + 6 + 16 + 6 + 190 + 6 + 30 + 10 = **302**; without
the footer **266**.

Concentric radii: the only nested rounded surface is the footer, and its radius is the panel
radius minus the panel padding. Day cells and the navigation capsule are full capsules, which are
concentric by construction. Nothing else gets a radius picked by eye.

## 4. Typography

System fonts only, through `Font.system` and `NSFont.systemFont`.

| Role | Regular | Compact |
|---|---|---|
| Month | 17 semibold, first letter capitalised by locale rules | 15 semibold |
| Year | 17 regular, secondary | 15 regular, secondary |
| Today button | 12 medium | 11 medium |
| Weekday symbols (`shortWeekdaySymbols`) | 11 semibold, secondary | 10 semibold |
| Day number | 14 regular, `monospacedDigit` | 12 regular |
| Day number, selected | 14 semibold | 12 semibold |
| Day number, today | 14 bold | 12 bold |
| Week number | 10 medium, tertiary, `monospacedDigit` | 9 medium |
| Footer date | 12 medium, secondary | 11 medium |
| Menu bar | 13 medium, `monospacedDigit` | same |

## 5. Colours

Semantic colours only. There are no hex values in the app; `Tokens.swift` holds none.

| Token | AppKit |
|---|---|
| `text.primary` | `labelColor` |
| `text.secondary` | `secondaryLabelColor` |
| `text.adjacentMonth`, `text.weekNumber` | `tertiaryLabelColor` |
| `text.dayOff` (highlighted weekends, public holidays) | `systemRed` |
| `group.palette` (event groups) | `systemIndigo`, `systemOrange`, `systemTeal`, `systemPurple`, `systemBrown`, `systemYellow`, in that order |
| `band.vacation` | `systemGreen` at 13% (dark: 19%) fill, 1 pt line at 42% (dark: 52%) |
| `accent` | `controlAccentColor` |
| `text.onAccent` | `white` |
| `fill.hover`, `fill.footer`, `fill.navCapsule` | `quaternarySystemFill` |
| `fill.pressed` | `tertiarySystemFill` |
| `separator` | `separatorColor` |
| `focus` | `keyboardFocusIndicatorColor` |
| `surface.opaque` (Reduce Transparency) | `windowBackgroundColor` |

## 6. Day cell states

| State | Rendering |
|---|---|
| Normal | primary text |
| Weekend | `text.dayOff` while "Highlight weekends in red" is on, primary text otherwise; decided by `Calendar.isDateInWeekend`. The weekday symbols of weekend columns follow. Changed on 2026-09-18: the first version dimmed weekends to secondary text, which the customer read as the setting doing nothing |
| Adjacent month | tertiary text, clickable, a click also moves to that month |
| Public holiday | `text.dayOff`, the same red as a highlighted weekend, because both mean a day off; at 45% opacity in an adjacent month, and so is a weekend there. The name is the cell's tooltip and part of its VoiceOver label |
| Vacation | a `band.vacation` capsule behind the day, the height of the day circle and the width of the cell (not of the circle, which is narrower when dots are on), joined across the column spacing to the next vacation day in the row; a single day is a full capsule. The number keeps its colour. 45% opacity in an adjacent month. The name (or "Vacation") is the tooltip, part of the VoiceOver label and in the footer |
| Today in a vacation | the today circle inset 2 pt, so the band shows as a green rim around it |
| Range selection | every day from the anchor to the selection gets the selected ring |
| Event dots | with events on, the day circle is 30 pt (Compact: 26) at the top of the 36 pt cell and a strip of 4 pt dots with 3 pt spacing sits under it, one dot per group in the group's slot, at most three; 45% opacity in an adjacent month, or none when the setting says so |
| Hover | `fill.hover` circle |
| Pressed | `fill.pressed` circle, scale 0.94 on the circle only, the hit area does not move |
| Selected | 1.5 pt accent ring inside the circle, semibold |
| Today | accent filled circle, white bold text |
| Today and selected | accent fill, then a 2 pt accent rim, then a 1.5 pt white inner ring |
| Today in an adjacent month | today rendering at 55% opacity |
| Keyboard focus | 3 pt `focus` ring, 1 pt outside the circle, drawn over every other state |

Today and selected differ by shape and by weight, not by colour alone (Differentiate Without
Colour). Text colour priority: today > day off (holiday or highlighted weekend) > adjacent > normal; a selected day keeps
the colour it had.

The grid is always 6 rows of 7. A sixth row that the month does not need holds the next month's
days in the adjacent style. September 2026 with Monday first is the reference case.

## 7. Material and accessibility variants

| Case | Rendering |
|---|---|
| macOS 26 and later | `NSGlassEffectView`, corner radius 24, one glass surface, nothing glass stacked on it |
| macOS 14 and 15 | `NSVisualEffectView`, material `.popover`, blending `.behindWindow`, state `.active`, masked to the same continuous radius |
| Reduce Transparency | `surface.opaque`, no blur |
| Increase Contrast | 1 pt border in `separatorColor` around the panel, selected ring 2 pt, adjacent month uses `secondaryLabelColor` |
| Shadow and rim | the system window shadow, which also draws the hairline rim that menus have. The window is a rectangle and the surface is not, so the content is clipped to the continuous rounded shape: what a surface draws outside it, glass casts a shadow of its own there, would otherwise show in the corners as pieces of a square, and the window shadow would follow that square. No custom shadow anywhere |

## 8. Motion

| Event | Animation | Detail |
|---|---|---|
| Panel opens | 0.18 s, cubic bezier (0.2, 0.9, 0.3, 1) | opacity 0 to 1 while the panel settles 6 pt down from the menu bar. Glass is drawn by the window server and cannot be scaled with its content, so there is no scale |
| Panel closes | ease out, 0.12 s | opacity only |
| Month changes | `spring(response: 0.24, dampingFraction: 0.90)` | directional slide of 28 pt with a fade, forward moves left; mirrored in RTL |
| Back to today | the month slide in the chronological direction, then `spring(response: 0.28, dampingFraction: 0.65)` | one transition, never a run through the months; the today circle pulses 1 to 1.18 to 1 |
| Hover and press | ease out, 0.12 s | fill and scale |
| Reduce Motion | ease out, 0.15 s | cross fade everywhere, no slide, no scale, no pulse |

The status item's width is never animated.

## 9. Menu bar item

- `NSStatusItem` with `variableLength`; text is 13 pt medium with monospaced digits.
- Height comes from `NSStatusBar.system.thickness`, never from a constant per OS version.
- Optional icon to the left of the text, 4 pt gap: SF Symbol `calendar`, or a drawn calendar
  outline with today's day number. Both are template images.
- The default is text only, format template `E d MMM` resolved for the locale, which reads
  "Пт, 18 сент." in Russian: the date the system clock can then leave out, with the time left to
  the clock, so that the menu bar does not show two clocks.
- On a first launch the item takes the rightmost place macOS gives a third party item, beside
  Control Center. Nothing can go to the right of Control Center and the clock. After that the
  place is wherever the user Command-drags it.
- The item shows the highlighted state while the panel is open.
- Left click toggles the panel. Right click and Control-click open the context menu: Settings,
  About, Quit; Check for Updates joins them with the updater in Stage 5.
- The button leaves about 2 pt between its image and its title, so the icon image carries the
  other 2 pt as transparent space at its trailing edge.

## 10. Behaviour

- Three separate pieces of state: the displayed month, the selected date, the focused date.
- Opening the panel shows the current month with today selected. With "Remember the last viewed
  month" the month is restored and the selection is still today; if today is not on screen the
  grid has no selected cell and the footer still shows the selected date.
- Header chevrons change the displayed month and keep the selection. "Today" is disabled only
  while the current month is displayed. `T` and `Cmd+T` always select today.
- Keyboard: arrows move the focus by 1 or 7 days and carry the displayed month across its edge;
  `Shift+arrows` extend a range; `Space` and `Return` select; `Option+arrows` change the month; `Shift+Cmd+arrows` change the
  year, clamped by `Calendar`; `Esc` closes.
- Scroll: accumulate the precise delta to a 40 pt threshold, at most one month per gesture, a new
  gesture starts after the previous one ended, momentum is ignored. A wheel without phases gets a
  250 ms cooldown. The horizontal swipe uses the same threshold, and the dominant axis is decided
  after 8 pt.
- The footer shows the full date. When the selected day is a public holiday it shows a short
  date, a middle dot and the holiday's name in `text.dayOff`; the date comes first so that a
  long name is what gets truncated.
- While a range is selected, or the selected day is a vacation, the footer is an action bar: the
  range ("23 Sep - 2 Oct  ·  10 days") on the left, Cancel and Vacation or Remove on the right.
  Esc drops the range before it closes the panel. ADR 0005 has the interaction.
- A click on a day with events, or Return on it, opens the day's list in place of the footer;
  the list follows the selection while open and closes with its chevron or Esc. Under the
  header, with two groups or more, a row of chips, one per group that is not hidden: a click
  adds the group to the filter or takes it out, so several can be looked at together;
  Command-click keeps only that group; no chip chosen means all. A chip widens to its full name
  under the pointer. The filter lives for this run of the app, is not stored, and the chips
  show it. Rows: the start over the
  end in the time column (11 pt secondary over 10 pt tertiary, right aligned; a short date
  instead of a time when the event began or ends on another day; all-day rows first with the
  word for it), a 3 x 16 pt mark in the group's colour, the title, or "Untitled" in tertiary
  when there is none. The tooltip carries the range, the duration and the calendar; a double
  click opens the event in Calendar. ADR 0005.
- Public holidays are official days off for the whole country of the system region, or of the
  country picked in settings. See `docs/adr/0004-public-holidays.md`.
- Midnight, a time zone change and waking from sleep recompute today. A date the user picked stays
  where it is; a selection that was only following today moves with it.
- RTL: leading and trailing everywhere, chevrons and the slide direction mirror.
- Week numbers come from the active `Calendar`, so they follow `firstWeekday` and
  `minimumDaysInFirstWeek`. They are ISO 8601 only when the calendar is.

## 11. Settings window

An `NSTabViewController` in the toolbar style with four SwiftUI panes: General, Calendar,
Appearance, About. Grouped form style, the system window chrome, nothing custom in it. The
window is ordered front by itself as well as through activation, because an agent app's request
to activate can be refused. Every change applies immediately. The
format field shows a live preview of the menu bar item and keeps the last valid format when the
pattern is invalid; the field is outlined in the system red and a one line message explains why.

## 12. Corrections to the source brief

1. PV-1 says "arrow at the bottom". A popover under the menu bar points up at the status item.
   Concept A has no arrow at all.
2. MB-7 rules out one second timers, but a custom format with `ss` needs one. Seconds are allowed
   only in a custom format, and only then does the timer fire every second; a date only format
   wakes at midnight and a format with minutes wakes on the minute.
3. PV-8 promises ISO week numbers from the European locale. That depends on
   `minimumDaysInFirstWeek` too, so the promise is "whatever the active calendar says".
4. B-1 asks for XcodeGen or Tuist. The project is a SwiftPM package with a `build.sh` that
   assembles the bundle, which removes the `.xcodeproj` altogether. See the ADR.
5. LOC-6 asks for a String Catalog. `.xcstrings` needs Xcode to compile, so the app ships plain
   `.lproj/Localizable.strings` tables for en, ru, uk and pl.
6. Section 8 asks for XCTest style unit tests. Without Xcode there is no XCTest and no
   swift-testing, so the suite is an executable target run by `./run-tests.sh`.
7. Section 4.6 asks for the SwiftUI `Settings` scene. It cannot be opened from an AppKit menu
   in an agent app without private selectors, so the window is AppKit's toolbar style tab
   controller hosting SwiftUI panes, which is the same look.
8. SwiftUI's `@State` is a macro from the macOS 27 SDK on, and its plugin ships only with Xcode.
   View state lives in `@Observable` models owned by the AppKit controllers.

## 13. Visual acceptance

- Snapshots of the panel in light and dark, with and without Reduce Transparency and Increase
  Contrast. Tolerance against this file: 1 pt.
- Reference dates: 2026-09-18 as today, selected and not selected; February 2024; February 2021
  (exactly four weeks with Monday first); August 2026 (six weeks with Monday first); December to
  January.
- The panel height does not change during navigation; there are always 42 cells; adjacent days
  are clickable; focus is never lost on a month edge.
- The Stage 0 canvas is the visual reference for proportions. Browser glass is an imitation, so
  the native material is judged on a Mac, not against the canvas.
