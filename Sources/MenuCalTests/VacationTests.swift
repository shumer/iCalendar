import Foundation
import MenuCalCore

func vacationTests(_ run: TestRun) {
  let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
  func key(_ y: Int, _ m: Int, _ d: Int) -> Int { y * 10_000 + m * 100 + d }
  func day(_ y: Int, _ m: Int, _ d: Int) -> Date { Fixtures.date(y, m, d, 0, in: calendar) }

  run.test("a range is stored with its ends in order") { t in
    let range = VacationRange(startKey: key(2026, 10, 2), endKey: key(2026, 9, 23), name: "Море")
    t.expectEqual(range.startKey, key(2026, 9, 23))
    t.expectEqual(range.endKey, key(2026, 10, 2))
    t.expect(range.contains(key(2026, 9, 30)))
    t.expect(!range.contains(key(2026, 10, 3)))
    t.expectEqual(VacationCalendar.dayCount(from: range.startKey, to: range.endKey, calendar: calendar), 10)
  }

  run.test("adding a range that touches another merges the two") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 23), endKey: key(2026, 9, 25), name: "Море"), calendar: calendar)
    list.add(VacationRange(startKey: key(2026, 9, 26), endKey: key(2026, 9, 28)), calendar: calendar)
    t.expectEqual(list.ranges.count, 1)
    t.expectEqual(list.ranges[0].endKey, key(2026, 9, 28))
    t.expectEqual(list.ranges[0].name, "Море", "the name survives the merge")
    list.add(VacationRange(startKey: key(2026, 12, 30), endKey: key(2027, 1, 2)), calendar: calendar)
    t.expectEqual(list.ranges.count, 2, "a range elsewhere stays separate")
    t.expect(list.ranges[1].contains(key(2027, 1, 1)), "and crosses the year")
  }

  run.test("overlapping ranges become one") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 20), endKey: key(2026, 9, 25)), calendar: calendar)
    list.add(VacationRange(startKey: key(2026, 9, 24), endKey: key(2026, 9, 30)), calendar: calendar)
    list.add(VacationRange(startKey: key(2026, 9, 10), endKey: key(2026, 9, 21)), calendar: calendar)
    t.expectEqual(list.ranges.map { ($0.startKey, $0.endKey) }.map { "\($0)-\($1)" }, ["\(key(2026, 9, 10))-\(key(2026, 9, 30))"])
  }

  run.test("removing days from the middle splits a vacation") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 20), endKey: key(2026, 9, 30), name: "Море"), calendar: calendar)
    list.remove(VacationRange(startKey: key(2026, 9, 24), endKey: key(2026, 9, 25)), calendar: calendar)
    t.expectEqual(list.ranges.count, 2)
    t.expectEqual(list.ranges[0].endKey, key(2026, 9, 23))
    t.expectEqual(list.ranges[1].startKey, key(2026, 9, 26))
    t.expect(list.ranges.allSatisfy { $0.name == "Море" })
    list.remove(VacationRange(startKey: key(2026, 9, 1), endKey: key(2026, 9, 30)), calendar: calendar)
    t.expect(list.isEmpty)
  }

  run.test("delete and rename work by id") { t in
    var list = VacationList()
    let added = list.add(VacationRange(startKey: key(2026, 9, 20), endKey: key(2026, 9, 21)), calendar: calendar)
    list.rename(id: added.id, to: "Горы")
    t.expectEqual(list.ranges[0].name, "Горы")
    list.delete(id: added.id)
    t.expect(list.isEmpty)
  }

  run.test("the list survives a round trip through JSON") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 20), endKey: key(2026, 9, 21), name: "Море"), calendar: calendar)
    let decoded = try JSONDecoder().decode(VacationList.self, from: JSONEncoder().encode(list))
    t.expectEqual(decoded, list)
  }

  run.test("the grid gets band segments per row, split at the row's edge") { t in
    // 23 September 2026 is a Wednesday; with Monday first the range runs Wed..Sun, Mon..Fri.
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 23), endKey: key(2026, 10, 2), name: "Море"), calendar: calendar)
    let reference = day(2026, 9, 18)
    let grid = CalendarEngine.makeGrid(
      for: reference, today: reference, calendar: calendar, locale: Locale(identifier: "ru_RU"),
      indicatorProvider: VacationCalendar(list))
    let week4 = grid.weeks[3].days.map(\.vacationSegment)
    t.expectEqual(week4, [nil, nil, .start, .middle, .middle, .middle, .end])
    let week5 = grid.weeks[4].days.map(\.vacationSegment)
    t.expectEqual(week5, [.start, .middle, .middle, .middle, .end, nil, nil])
    t.expectEqual(grid.weeks[3].days[2].vacationName, "Море")
    t.expect(grid.weeks[3].days[2].accessibilityLabel.hasSuffix(", Море"))
  }

  run.test("a one day vacation is a single capsule") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 9, 24), endKey: key(2026, 9, 24)), calendar: calendar)
    let reference = day(2026, 9, 18)
    let grid = CalendarEngine.makeGrid(
      for: reference, today: reference, calendar: calendar, locale: Locale(identifier: "ru_RU"),
      indicatorProvider: VacationCalendar(list))
    t.expectEqual(grid.weeks[3].days.map(\.vacationSegment), [nil, nil, nil, .single, nil, nil, nil])
    t.expectEqual(grid.weeks[3].days[3].vacationName, "", "a vacation without a name")
    t.expect(!grid.weeks[3].days[3].accessibilityLabel.hasSuffix(", "), "and no dangling comma")
  }

  run.test("a vacation and a holiday on the same day are both there") { t in
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 11, 10), endKey: key(2026, 11, 12)), calendar: calendar)
    let holidays = HolidayCalendar([Holiday(year: 2026, month: 11, day: 11, localName: "Święto", name: "Holiday")])
    let reference = day(2026, 11, 5)
    let grid = CalendarEngine.makeGrid(
      for: reference, today: reference, calendar: calendar, locale: Locale(identifier: "pl_PL"),
      indicatorProvider: CompositeIndicatorProvider([holidays, VacationCalendar(list)]))
    let eleventh = grid.days.first { $0.isInCurrentMonth && $0.dayNumber == "11" }!
    t.expectEqual(eleventh.holidayName, "Święto")
    t.expect(eleventh.isVacation)
    t.expectEqual(eleventh.vacationSegment, .middle)
  }

  run.test("vacation days are Gregorian whatever the grid's calendar is") { t in
    let hebrew = Fixtures.calendar(.hebrew, locale: "he_IL")
    var list = VacationList()
    list.add(VacationRange(startKey: key(2026, 1, 1), endKey: key(2026, 1, 1)), calendar: hebrew)
    let newYear = Fixtures.date(2026, 1, 1, in: calendar)
    t.expectEqual(VacationCalendar(list).indicators(for: hebrew.startOfDay(for: newYear), calendar: hebrew).count, 1)
    t.expectEqual(VacationCalendar.key(for: newYear, calendar: hebrew), key(2026, 1, 1))
    t.expectEqual(VacationCalendar.date(for: key(2026, 1, 1), calendar: hebrew), Fixtures.date(2026, 1, 1, 0, in: calendar))
  }

  // MARK: Range selection

  let now = Fixtures.date(2026, 9, 18, 21, 30, in: calendar)

  run.test("Shift-click makes a range from the selection, and a plain click ends it") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.select(day(2026, 9, 23), calendar: calendar)
    t.expect(!state.hasRange)
    state.extendSelection(to: day(2026, 10, 2), calendar: calendar)
    t.expect(state.hasRange)
    t.expectEqual(state.selectedRange, day(2026, 9, 23)...day(2026, 10, 2))
    t.expectEqual(state.displayedMonth, day(2026, 10, 1), "the range crosses the month's edge and shows it")
    state.extendSelection(to: day(2026, 9, 10), calendar: calendar)
    t.expectEqual(state.selectedRange, day(2026, 9, 10)...day(2026, 9, 23), "the anchor stays, the other end moves")
    state.select(day(2026, 9, 15), calendar: calendar)
    t.expect(!state.hasRange)
    t.expectEqual(state.selectedRange, day(2026, 9, 15)...day(2026, 9, 15))
  }

  run.test("Shift-arrows extend the range a day or a week at a time") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.extendSelection(byDays: 1, calendar: calendar)
    state.extendSelection(byDays: 7, calendar: calendar)
    t.expectEqual(state.selectedRange, day(2026, 9, 18)...day(2026, 9, 26))
    state.clearRange()
    t.expect(!state.hasRange)
    t.expectEqual(state.selectedDate, day(2026, 9, 26), "the selection is the last day reached")
  }

  run.test("today, reopening and a plain click all drop the range") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.extendSelection(to: day(2026, 9, 20), calendar: calendar)
    state.goToToday(now: now, calendar: calendar)
    t.expect(!state.hasRange)
    state.extendSelection(to: day(2026, 9, 20), calendar: calendar)
    state.reopen(now: now, calendar: calendar, remembersMonth: true)
    t.expect(!state.hasRange)
  }

  run.test("Shift-click on the selected day itself is not a range") { t in
    var state = CalendarState(now: now, calendar: calendar)
    state.extendSelection(to: day(2026, 9, 18), calendar: calendar)
    t.expect(!state.hasRange)
    t.expectEqual(state.selectedRange.lowerBound, state.selectedRange.upperBound)
  }
}
