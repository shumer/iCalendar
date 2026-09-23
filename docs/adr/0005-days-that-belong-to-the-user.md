# ADR 0005: Days that belong to the user, and events after them

Date: 2026-09-23. Status: accepted.

## Context

The charter of the project (`CLAUDE.md`, the brief) said "no events, no reminders, no time
zones, no accounts". After living with 0.3 the customer asked for two things the charter rules
out: marking his own vacation so the days read as time off, and seeing the events of his
calendars, three accounts in System Settings, with the sources told apart by colour. A designer
worked both through (`docs/design/events-and-vacation.html`); this ADR records the decisions.

## Decision

**Vacation is in scope, and ships first.** It is the user's own data, kept in one JSON file
beside the holiday cache, and nothing outside the Mac is involved. It enters the grid through
`IndicatorProvider`, as public holidays did, so the engine does not change shape.

How it looks and behaves follows the designer's section A:

- A vacation is a background, not a text colour: a green capsule the height of the day circle,
  behind a run of days, its ends the same circle the grid is made of. The day number keeps its
  colour, so a public holiday inside a vacation is still a red number, now on green. Today's
  circle sits 2 pt inside the band, which shows as a green rim around it.
- Created by a range: click the first day, Shift-click the last, press Vacation in the footer,
  which becomes an action bar while a range is live. Shift-arrows do the same from the keyboard.
  The right-click menu of a day marks or unmarks that day for people who do not know about
  Shift. Dragging was rejected: a horizontal drag already changes the month.
- Days, not hours. Half days would need a second cell state for a rare case.
- Ranges that touch merge; removing days out of the middle of a vacation splits it.
- The list of vacations, with optional names, is in Calendar settings, with a switch to hide
  them all.

**Events are read from the system's calendars, through EventKit, read only.** Amended
2026-09-23, when they shipped. The customer's work Exchange account accepted
a native connection with calendars in System Settings, which was the risk. EventKit gives the
colours the user already chose, the recurrence expansion a school timetable needs, and the sync
the system already does, with no OAuth, no tokens and no third party code (ADR 0002). The grid
shows at most three dots per day, one per group of calendars, and a click opens the day's list
inside the panel. What shipped, after the designer's sections B to E:

- **Groups, not calendars.** A calendar belongs to one group; the group has the colour, from a
  fixed palette of six with no red, green or pink, and the slot of its dot. The first time an
  account appears it becomes a group of its own, so the accounts are told apart before anybody
  touches a setting. At most four groups; the first three that show in the grid get a slot.
- **Dots.** One per group with events that day, 4 pt in a strip under the day; the circle
  shrinks from 36 to 30 pt inside the same cell, so nothing moves. A group can be kept out of
  the grid without leaving the list: a school timetable every weekday is a dot that says
  nothing.
- **The day's list** opens inside the panel in place of the footer, which grows by 146 pt and
  then scrolls: a second window would close a transient panel the moment it took the focus.
  All-day events first, a time column, a mark in the group's colour (a three letter tag under
  Differentiate Without Colour), the title; a double click hands the event to Calendar. Esc
  closes the list before the panel.
- **The Events pane** is the fifth tab: access, the groups as name and sources with an Edit
  sheet, the marks, and the vacations table, which moved here from Calendar.
- **The permission.** The hardened runtime shows no calendar dialog without the entitlement
  `com.apple.security.personal-information.calendars`; ADR 0003 is amended.

Not done, and on the roadmap: the week view, the pin that keeps the panel open, a colour for
vacations other than green.

## Alternatives rejected

- **Importing `.ics` exports.** Manual, stale the day after, and the recurrence rules would have
  to be parsed by hand.
- **Talking to Google and Microsoft directly.** The app would hold tokens and the work account
  forbids outside clients; the system account does not.
- **Vacation as an EventKit calendar.** It would need the calendar permission for a feature that
  does not need the network, and would show up in every other calendar app.

## Consequences

- The charter line becomes "no reminders, no time zones, no accounts of its own": the app reads
  the accounts the system has, and never keeps one.
- `DayIndicator.Kind` gains `.vacation`; `DayCellModel` gains a band segment computed per row.
- `CalendarState` gains a range anchor, kept apart from the selection and the focus.
