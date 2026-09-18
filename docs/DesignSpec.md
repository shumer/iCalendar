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
not have one), events, reminders, time zones.

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
| `text.weekend`, `text.secondary` | `secondaryLabelColor` |
| `text.adjacentMonth`, `text.weekNumber` | `tertiaryLabelColor` |
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
| Weekend | secondary text, only while "Highlight weekends" is on; decided by `Calendar.isDateInWeekend` |
| Adjacent month | tertiary text, clickable, a click also moves to that month |
| Hover | `fill.hover` circle |
| Pressed | `fill.pressed` circle, scale 0.94 on the circle only, the hit area does not move |
| Selected | 1.5 pt accent ring inside the circle, semibold |
| Today | accent filled circle, white bold text |
| Today and selected | accent fill, then a 2 pt accent rim, then a 1.5 pt white inner ring |
| Today in an adjacent month | today rendering at 55% opacity |
| Keyboard focus | 3 pt `focus` ring, 1 pt outside the circle, drawn over every other state |

Today and selected differ by shape and by weight, not by colour alone (Differentiate Without
Colour). Text colour priority: today > selected > adjacent > weekend > normal.

The grid is always 6 rows of 7. A sixth row that the month does not need holds the next month's
days in the adjacent style. September 2026 with Monday first is the reference case.

## 7. Material and accessibility variants

| Case | Rendering |
|---|---|
| macOS 26 and later | `NSGlassEffectView`, corner radius 24, one glass surface, nothing glass stacked on it |
| macOS 14 and 15 | `NSVisualEffectView`, material `.popover`, blending `.behindWindow`, state `.active`, masked to the same continuous radius |
| Reduce Transparency | `surface.opaque`, no blur |
| Increase Contrast | 1 pt border in `separatorColor` around the panel, selected ring 2 pt, adjacent month uses `secondaryLabelColor` |
| Shadow | glass brings its own shadow and rim, so the window shadow is off on it: computed from the window rectangle, it shows as a square outline around the rounded glass. The material and opaque fallbacks use the system window shadow. No custom shadow anywhere |

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
- The default is text only, format template `E d MMM` resolved for the locale.
- The item shows the highlighted state while the panel is open.
- Left click toggles the panel. Right click and Control-click open the context menu: Settings,
  About, Check for Updates, Quit.

## 10. Behaviour

- Three separate pieces of state: the displayed month, the selected date, the focused date.
- Opening the panel shows the current month with today selected. With "Remember the last viewed
  month" the month is restored and the selection is still today; if today is not on screen the
  grid has no selected cell and the footer still shows the selected date.
- Header chevrons change the displayed month and keep the selection. "Today" is disabled only
  while the current month is displayed. `T` and `Cmd+T` always select today.
- Keyboard: arrows move the focus by 1 or 7 days and carry the displayed month across its edge;
  `Space` and `Return` select; `Option+arrows` change the month; `Shift+Cmd+arrows` change the
  year, clamped by `Calendar`; `Esc` closes.
- Scroll: accumulate the precise delta to a 40 pt threshold, at most one month per gesture, a new
  gesture starts after the previous one ended, momentum is ignored. A wheel without phases gets a
  250 ms cooldown. The horizontal swipe uses the same threshold, and the dominant axis is decided
  after 8 pt.
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
