import Foundation
import MenuCalCore

func calendarStateTests(_ run: TestRun) {
  let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
  let now = Fixtures.date(2026, 9, 18, 21, 30, in: calendar)
  func day(_ y: Int, _ m: Int, _ d: Int) -> Date { Fixtures.date(y, m, d, 0, in: calendar) }

  run.test("a new state shows the current month with today selected and focused") { t in
    let state = CalendarState(now: now, calendar: calendar)
    t.expectEqual(state.displayedMonth, day(2026, 9, 1))
    t.expectEqual(state.selectedDate, day(2026, 9, 18))
    t.expectEqual(state.focusedDate, day(2026, 9, 18))
    t.expect(state.selectionFollowsToday)
    t.expect(state.isShowingCurrentMonth(now: now, calendar: calendar))
  }

  run.test("chevrons change the month and keep the selection") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.showMonth(byAdding: 1, calendar: calendar)
    t.expectEqual(state.displayedMonth, day(2026, 10, 1))
    t.expectEqual(state.selectedDate, day(2026, 9, 18))
    t.expect(state.lastDirection == .forward)
    t.expectEqual(state.focusedDate, day(2026, 10, 1), "focus starts at the first of an unvisited month")
    t.expect(!state.isShowingCurrentMonth(now: now, calendar: calendar))

    state.showMonth(byAdding: -1, calendar: calendar)
    t.expect(state.lastDirection == .backward)
    t.expectEqual(state.focusedDate, day(2026, 9, 18), "and returns to the selection when it is on screen")
    t.expectEqual(state.monthChangeCount, 2)
  }

  run.test("a year step moves twelve months") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.showYear(byAdding: -1, calendar: calendar)
    t.expectEqual(state.displayedMonth, day(2025, 9, 1))
    t.expect(state.lastDirection == .backward)
  }

  run.test("arrow keys carry the month across its edge") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.moveFocus(byDays: 7, calendar: calendar)
    t.expectEqual(state.focusedDate, day(2026, 9, 25))
    t.expectEqual(state.monthChangeCount, 0)
    state.moveFocus(byDays: 7, calendar: calendar)
    t.expectEqual(state.focusedDate, day(2026, 10, 2))
    t.expectEqual(state.displayedMonth, day(2026, 10, 1))
    t.expect(state.lastDirection == .forward)
    t.expectEqual(state.selectedDate, day(2026, 9, 18), "moving the focus selects nothing")
  }

  run.test("Space selects the focused day") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.moveFocus(byDays: -1, calendar: calendar)
    state.selectFocused(calendar: calendar)
    t.expectEqual(state.selectedDate, day(2026, 9, 17))
    t.expect(!state.selectionFollowsToday)
  }

  run.test("clicking a day of an adjacent month moves there") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.select(Fixtures.date(2026, 8, 31, 15, in: calendar), calendar: calendar)
    t.expectEqual(state.selectedDate, day(2026, 8, 31), "normalised to the start of the day")
    t.expectEqual(state.displayedMonth, day(2026, 8, 1))
    t.expect(state.lastDirection == .backward)
  }

  run.test("Today always selects today and pulses, even on the current month") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.select(day(2026, 9, 3), calendar: calendar)
    state.goToToday(now: now, calendar: calendar)
    t.expectEqual(state.selectedDate, day(2026, 9, 18))
    t.expectEqual(state.todayPulseCount, 1)
    t.expectEqual(state.monthChangeCount, 0, "no month change, so no slide")

    state.showYear(byAdding: 3, calendar: calendar)
    state.goToToday(now: now, calendar: calendar)
    t.expectEqual(state.displayedMonth, day(2026, 9, 1))
    t.expect(state.lastDirection == .backward, "one transition in the chronological direction")
    t.expectEqual(state.monthChangeCount, 2)
  }

  run.test("reopening resets to today unless the month is remembered") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.select(day(2026, 11, 5), calendar: calendar)

    var fresh = state
    fresh.reopen(now: now, calendar: calendar, remembersMonth: false)
    t.expectEqual(fresh.displayedMonth, day(2026, 9, 1))
    t.expectEqual(fresh.selectedDate, day(2026, 9, 18))

    var remembered = state
    remembered.reopen(now: now, calendar: calendar, remembersMonth: true)
    t.expectEqual(remembered.displayedMonth, day(2026, 11, 1))
    t.expectEqual(remembered.selectedDate, day(2026, 9, 18), "the selection is today all the same")
    t.expectEqual(remembered.focusedDate, day(2026, 11, 1))
    t.expect(remembered.lastDirection == .none, "opening never slides")
  }

  run.test("at midnight a selection that follows today moves with it") { t in
    var state = CalendarState(now: Fixtures.date(2026, 9, 30, 23, 59, in: calendar), calendar: calendar)
    state.clockChanged(now: Fixtures.date(2026, 10, 1, 0, 0, 5, in: calendar), calendar: calendar)
    t.expectEqual(state.selectedDate, day(2026, 10, 1))
    t.expectEqual(state.displayedMonth, day(2026, 10, 1), "and takes the month along")
    t.expectEqual(state.focusedDate, day(2026, 10, 1))
  }

  run.test("at midnight a date the user picked stays") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.select(day(2026, 9, 3), calendar: calendar)
    state.clockChanged(now: Fixtures.date(2026, 9, 19, 0, 0, 5, in: calendar), calendar: calendar)
    t.expectEqual(state.selectedDate, day(2026, 9, 3))
  }

  run.test("at midnight a month the user browsed to stays") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.showMonth(byAdding: 4, calendar: calendar)
    state.clockChanged(now: Fixtures.date(2026, 9, 19, 0, 0, 5, in: calendar), calendar: calendar)
    t.expectEqual(state.displayedMonth, day(2027, 1, 1))
    t.expectEqual(state.selectedDate, day(2026, 9, 19))
  }

  run.test("a time zone change renormalises the dates to the new day starts") { t in
    var state = CalendarState(now: now, calendar: calendar)
    let tokyo = Fixtures.calendar(.gregorian, locale: "ru_RU", timeZone: "Asia/Tokyo")
    state.clockChanged(now: now, calendar: tokyo)
    // 21:30 in Warsaw on the 18th is 04:30 on the 19th in Tokyo.
    t.expectEqual(state.selectedDate, Fixtures.date(2026, 9, 19, 0, in: tokyo))
    t.expectEqual(state.displayedMonth, Fixtures.date(2026, 9, 1, 0, in: tokyo))
  }
}
