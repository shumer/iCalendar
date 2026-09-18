import Foundation
import MenuCalCore

func calendarNavigatorTests(_ run: TestRun) {
  let gregorian = Fixtures.calendar(.gregorian, locale: "en_US")

  run.test("December goes to January of the next year and back") { t in
    let december = Fixtures.date(2026, 12, 31, in: gregorian)
    let january = CalendarNavigator.month(byAdding: 1, to: december, calendar: gregorian)
    t.expectEqual(january, Fixtures.date(2027, 1, 1, 0, in: gregorian))
    let back = CalendarNavigator.month(byAdding: -1, to: january, calendar: gregorian)
    t.expectEqual(back, Fixtures.date(2026, 12, 1, 0, in: gregorian))
  }

  run.test("moving by months from the 31st never skips a short month") { t in
    var cursor = Fixtures.date(2026, 1, 31, in: gregorian)
    var months: [Int] = []
    for _ in 0..<12 {
      cursor = CalendarNavigator.month(byAdding: 1, to: cursor, calendar: gregorian)
      months.append(gregorian.component(.month, from: cursor))
    }
    t.expectEqual(months, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1])
  }

  run.test("a year step keeps the month") { t in
    let leapDay = Fixtures.date(2024, 2, 29, in: gregorian)
    let next = CalendarNavigator.month(byAddingYears: 1, to: leapDay, calendar: gregorian)
    t.expectEqual(next, Fixtures.date(2025, 2, 1, 0, in: gregorian))
  }

  run.test("a Hebrew leap year is walked through all thirteen months") { t in
    let hebrew = Fixtures.calendar(.hebrew, locale: "he_IL")
    // Tishri 5784 starts in September 2023, and 5784 is a leap year.
    var cursor = CalendarEngine.startOfMonth(for: Fixtures.date(2023, 9, 20, in: gregorian), calendar: hebrew)
    let year = hebrew.component(.year, from: cursor)
    var starts: Set<Date> = []
    while hebrew.component(.year, from: cursor) == year {
      starts.insert(cursor)
      cursor = CalendarNavigator.month(byAdding: 1, to: cursor, calendar: hebrew)
    }
    t.expectEqual(starts.count, 13)
  }

  run.test("a year step out of a Hebrew leap month lands in a real month") { t in
    let hebrew = Fixtures.calendar(.hebrew, locale: "he_IL")
    // Adar I exists only in leap years; late February 2024 is inside it.
    let adarOne = Fixtures.date(2024, 2, 20, in: gregorian)
    let next = CalendarNavigator.month(byAddingYears: 1, to: adarOne, calendar: hebrew)
    t.expectEqual(hebrew.component(.year, from: next), hebrew.component(.year, from: adarOne) + 1)
    t.expectEqual(hebrew.component(.day, from: next), 1)
  }

  run.test("day steps cross a month edge and a clock change") { t in
    let warsaw = Fixtures.calendar(.gregorian, locale: "pl_PL")
    let saturday = Fixtures.date(2026, 3, 28, in: warsaw)
    let monday = CalendarNavigator.day(byAdding: 2, to: saturday, calendar: warsaw)
    t.expectEqual(monday, Fixtures.date(2026, 3, 30, 0, in: warsaw))
    let week = CalendarNavigator.day(byAdding: 7, to: saturday, calendar: warsaw)
    t.expectEqual(week, Fixtures.date(2026, 4, 4, 0, in: warsaw))
    let back = CalendarNavigator.day(byAdding: -28, to: saturday, calendar: warsaw)
    t.expectEqual(back, Fixtures.date(2026, 2, 28, 0, in: warsaw))
  }

  run.test("the direction between months is chronological") { t in
    let september = Fixtures.date(2026, 9, 18, in: gregorian)
    t.expect(CalendarNavigator.direction(from: september, to: Fixtures.date(2026, 9, 1, in: gregorian), calendar: gregorian) == .none)
    t.expect(CalendarNavigator.direction(from: september, to: Fixtures.date(2026, 10, 1, in: gregorian), calendar: gregorian) == .forward)
    t.expect(CalendarNavigator.direction(from: september, to: Fixtures.date(2025, 12, 1, in: gregorian), calendar: gregorian) == .backward)
    t.expect(CalendarNavigator.isSameMonth(september, Fixtures.date(2026, 9, 30, in: gregorian), calendar: gregorian))
  }
}
