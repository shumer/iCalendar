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

**Events come next, read only, through EventKit.** The customer's work Exchange account accepted
a native connection with calendars in System Settings, which was the risk. EventKit gives the
colours the user already chose, the recurrence expansion a school timetable needs, and the sync
the system already does, with no OAuth, no tokens and no third party code (ADR 0002). The grid
will show at most three dots per day, one per group of calendars, and a click will open the
day's list inside the panel. This ADR only records the direction; the details land with their
own pull request and an amendment here.

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
