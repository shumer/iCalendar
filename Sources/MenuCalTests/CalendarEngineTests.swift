import Foundation
import MenuCalCore

private let locales = ["en_US", "ru_RU", "pl_PL", "ar_SA", "he_IL"]
private let calendars: [Calendar.Identifier] = [.gregorian, .islamicUmmAlQura, .hebrew]

/// Reference instants, as Gregorian dates, that land in awkward months of every calendar: a leap
/// February, a four week February, a six week August, a year boundary, the reference month.
private let referenceDays: [(Int, Int, Int)] = [
  (2024, 2, 15), (2021, 2, 10), (2026, 8, 20), (2026, 9, 18), (2026, 12, 31), (2027, 1, 1),
]

private func grid(
  _ year: Int, _ month: Int, _ day: Int,
  calendar: Calendar, locale: String = "en_US",
  today: Date? = nil, override: Int? = nil
) -> MonthGrid {
  let gregorian = Fixtures.gregorian(calendar.timeZone.identifier)
  let reference = Fixtures.date(year, month, day, in: gregorian)
  return CalendarEngine.makeGrid(
    for: reference, today: today ?? reference, calendar: calendar,
    locale: Locale(identifier: locale), firstWeekdayOverride: override)
}

func calendarEngineTests(_ run: TestRun) {
  // MARK: The matrix

  for localeID in locales {
    for identifier in calendars {
      for (year, month, day) in referenceDays {
        let name = "\(localeID) \(identifier) \(year)-\(month)-\(day)"
        let calendar = Fixtures.calendar(identifier, locale: localeID)
        run.test("grid invariants: \(name)") { t in
          let result = grid(year, month, day, calendar: calendar, locale: localeID)
          let days = result.days

          t.expectEqual(result.weeks.count, 6)
          t.expect(result.weeks.allSatisfy { $0.days.count == 7 }, "7 days per row")
          t.expectEqual(Set(days.map(\.id)).count, 42, "unique ids")

          for (previous, next) in zip(days, days.dropFirst()) {
            let step = calendar.dateComponents([.day], from: previous.date, to: next.date).day
            t.expectEqual(step, 1, "consecutive days")
          }
          t.expect(days.allSatisfy { $0.id == calendar.startOfDay(for: $0.date) }, "ids are day starts")

          let firstWeekday = calendar.component(.weekday, from: days[0].date)
          t.expectEqual(firstWeekday, calendar.firstWeekday, "the first column is the first weekday")

          let inMonth = days.filter(\.isInCurrentMonth)
          let expected = calendar.range(of: .day, in: .month, for: result.referenceDate)?.count
          t.expectEqual(inMonth.count, expected, "every day of the month, once")
          t.expect(days[0..<7].contains { $0.isInCurrentMonth }, "the month starts in the first row")

          let flags = days.map(\.isInCurrentMonth)
          let firstIn = flags.firstIndex(of: true) ?? 0
          let lastIn = flags.lastIndex(of: true) ?? 0
          t.expect(flags[firstIn...lastIn].allSatisfy { $0 }, "the month is one contiguous run")

          t.expectEqual(days.filter(\.isToday).count, 1, "today is marked once")
          t.expectEqual(result.weekdaySymbols.count, 7)
          t.expect(days.allSatisfy { !$0.dayNumber.isEmpty && !$0.accessibilityLabel.isEmpty })
          t.expect(!result.monthName.isEmpty && !result.yearText.isEmpty && !result.monthTitle.isEmpty)
          t.expect(days.allSatisfy { $0.indicators.isEmpty }, "no provider, no indicators")
        }
      }
    }
  }

  // MARK: Gregorian edge months

  run.test("leap February has 29 days") { t in
    let result = grid(2024, 2, 1, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"))
    t.expectEqual(result.days.filter(\.isInCurrentMonth).count, 29)
  }

  run.test("a four week February leaves two whole rows to the next month") { t in
    // February 2021 starts on a Monday and has 28 days.
    let result = grid(2021, 2, 1, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"))
    t.expect(result.weeks[0].days[0].isInCurrentMonth, "the first cell is the 1st")
    t.expect(result.weeks[3].days.allSatisfy(\.isInCurrentMonth))
    t.expect(result.weeks[4].days.allSatisfy { !$0.isInCurrentMonth })
    t.expect(result.weeks[5].days.allSatisfy { !$0.isInCurrentMonth })
  }

  run.test("September 2026 with Monday first has an empty sixth row") { t in
    let result = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"))
    t.expectEqual(result.weeks[0].days.map(\.dayNumber), ["31", "1", "2", "3", "4", "5", "6"])
    t.expect(result.weeks[5].days.allSatisfy { !$0.isInCurrentMonth })
    t.expectEqual(result.weeks[5].days.first?.dayNumber, "5")
  }

  run.test("a month starting on Sunday with Monday first needs six rows") { t in
    // August 2026 starts on a Saturday, so with Monday first the 31st lands in row six.
    let result = grid(2026, 8, 1, calendar: Fixtures.calendar(.gregorian, locale: "pl_PL"))
    t.expect(result.weeks[5].days[0].isInCurrentMonth)
    t.expectEqual(result.weeks[5].days[0].dayNumber, "31")
    // November 2026 starts on a Sunday.
    let november = grid(2026, 11, 1, calendar: Fixtures.calendar(.gregorian, locale: "pl_PL"))
    t.expectEqual(november.weeks[0].days.filter(\.isInCurrentMonth).count, 1)
    t.expect(november.weeks[5].days[0].isInCurrentMonth)
  }

  // MARK: First weekday

  run.test("the first weekday follows the locale") { t in
    let us = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "en_US"))
    let ru = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"), locale: "ru_RU")
    t.expectEqual(us.weekdaySymbols.first?.short, "Sun")
    t.expectEqual(ru.weekdaySymbols.first?.short.lowercased(), "пн")
    t.expectEqual(us.weeks[0].days[0].dayNumber, "30")
    t.expectEqual(ru.weeks[0].days[0].dayNumber, "31")
  }

  run.test("the override replaces the locale's first weekday") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    for (override, symbol) in [(1, "Sun"), (2, "Mon"), (7, "Sat")] {
      let result = grid(2026, 9, 18, calendar: calendar, override: override)
      t.expectEqual(result.weekdaySymbols.first?.short, symbol)
      t.expectEqual(calendar.component(.weekday, from: result.weeks[0].days[0].date), override)
    }
  }

  run.test("a display locale that differs from the calendar's keeps the calendar's week rules") { t in
    // Assigning a locale to a Calendar resets its first weekday. A Mac set to English with
    // Monday as the first day would otherwise get Sunday back.
    var calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
    calendar.minimumDaysInFirstWeek = 4
    let result = grid(2026, 9, 18, calendar: calendar, locale: "en_US")
    t.expectEqual(result.weekdaySymbols.first?.short, "Mon")
    t.expectEqual(result.weeks[0].days[0].dayNumber, "31")
    t.expectEqual(grid(2027, 1, 1, calendar: calendar, locale: "en_US").weeks[0].weekOfYear, 53)
  }

  run.test("an override out of range is ignored") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    t.expectEqual(grid(2026, 9, 18, calendar: calendar, override: 9).weekdaySymbols.first?.short, "Sun")
    t.expectEqual(grid(2026, 9, 18, calendar: calendar, override: 0).weekdaySymbols.first?.short, "Sun")
  }

  run.test("weekend columns come from the calendar, not from Saturday and Sunday") { t in
    let ru = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"), locale: "ru_RU")
    t.expectEqual(ru.weekdaySymbols.map(\.isWeekend), [false, false, false, false, false, true, true])
    let saudi = Fixtures.calendar(.gregorian, locale: "ar_SA")
    let sa = grid(2026, 9, 18, calendar: saudi, locale: "ar_SA")
    let weekendDays = sa.weeks[1].days.filter(\.isWeekend).map { saudi.component(.weekday, from: $0.date) }
    t.expectEqual(weekendDays.sorted(), [6, 7], "Friday and Saturday in Saudi Arabia")
  }

  // MARK: Today

  run.test("today is marked in an adjacent month too") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
    let today = Fixtures.date(2026, 10, 2, in: calendar)
    let result = grid(2026, 9, 1, calendar: calendar, today: today)
    let marked = result.days.filter(\.isToday)
    t.expectEqual(marked.count, 1)
    t.expectEqual(marked.first?.isInCurrentMonth, false)
  }

  run.test("today outside the grid marks nothing") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
    let result = grid(2026, 9, 1, calendar: calendar, today: Fixtures.date(2027, 3, 3, in: calendar))
    t.expect(result.days.allSatisfy { !$0.isToday })
  }

  run.test("today is decided in the calendar's time zone, late in the evening too") { t in
    let warsaw = Fixtures.calendar(.gregorian, locale: "pl_PL", timeZone: "Europe/Warsaw")
    let tokyo = Fixtures.calendar(.gregorian, locale: "pl_PL", timeZone: "Asia/Tokyo")
    // 23:30 on the 18th in Warsaw is already the 19th in Tokyo.
    let instant = Fixtures.date(2026, 9, 18, 23, 30, in: warsaw)
    let here = CalendarEngine.makeGrid(for: instant, today: instant, calendar: warsaw, locale: warsaw.locale!)
    let there = CalendarEngine.makeGrid(for: instant, today: instant, calendar: tokyo, locale: tokyo.locale!)
    t.expectEqual(here.days.first(where: \.isToday)?.dayNumber, "18")
    t.expectEqual(there.days.first(where: \.isToday)?.dayNumber, "19")
  }

  // MARK: Daylight saving

  run.test("months with a clock change still have 42 distinct consecutive days") { t in
    let warsaw = Fixtures.calendar(.gregorian, locale: "pl_PL", timeZone: "Europe/Warsaw")
    for month in [3, 10] {
      let result = grid(2026, month, 15, calendar: warsaw)
      t.expectEqual(Set(result.days.map(\.id)).count, 42)
      t.expectEqual(result.days.filter(\.isInCurrentMonth).count, 31)
    }
  }

  run.test("a day without a midnight is still a day") { t in
    // Brazil moved its clocks at 00:00, so 2018-11-04 starts at 01:00 in Sao Paulo.
    let saoPaulo = Fixtures.calendar(.gregorian, locale: "en_US", timeZone: "America/Sao_Paulo")
    let result = grid(2018, 11, 10, calendar: saoPaulo)
    t.expectEqual(result.days.filter(\.isInCurrentMonth).count, 30)
    t.expectEqual(Set(result.days.map(\.dayNumber).prefix(7)).count, 7)
    let fourth = result.days.first { $0.isInCurrentMonth && $0.dayNumber == "4" }
    t.expectEqual(fourth.map { saoPaulo.component(.hour, from: $0.date) }, 1)
  }

  // MARK: Week numbers

  run.test("week numbers follow the calendar's own rules") { t in
    // ISO 8601: Monday first, four days minimum. 2027-01-01 is a Friday, so it is in week 53.
    var iso = Fixtures.calendar(.gregorian, locale: "pl_PL")
    iso.firstWeekday = 2
    iso.minimumDaysInFirstWeek = 4
    let january = grid(2027, 1, 1, calendar: iso)
    t.expectEqual(january.weeks[0].weekOfYear, 53)
    t.expectEqual(january.weeks[1].weekOfYear, 1)

    // The US rule: Sunday first, one day is enough, so the same day is in week 1.
    let us = grid(2027, 1, 1, calendar: Fixtures.calendar(.gregorian, locale: "en_US"))
    t.expectEqual(us.weeks[0].weekOfYear, 1)
  }

  // MARK: Localisation

  run.test("day numbers use the locale's digits") { t in
    let arabic = Fixtures.calendar(.gregorian, locale: "ar_SA@numbers=arab")
    let result = grid(2026, 9, 18, calendar: arabic, locale: "ar_SA@numbers=arab")
    let first = result.days.first { $0.isInCurrentMonth }
    t.expectEqual(first?.dayNumber, "١")
    t.expectEqual(result.weeks[0].weekNumber.unicodeScalars.allSatisfy { $0.value > 127 }, true)
  }

  run.test("the month name is capitalised and the title keeps the locale's form") { t in
    let ru = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "ru_RU"), locale: "ru_RU")
    t.expectEqual(ru.monthName, "Сентябрь")
    t.expectEqual(ru.yearText, "2026")
    t.expect(ru.monthTitle.contains("2026"))
    let en = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "en_US"))
    t.expectEqual(en.monthName, "September")
    t.expectEqual(en.monthTitle, "September 2026")
  }

  run.test("the accessibility label is the full date") { t in
    let en = grid(2026, 9, 18, calendar: Fixtures.calendar(.gregorian, locale: "en_US"))
    let day = en.days.first { $0.isInCurrentMonth && $0.dayNumber == "18" }
    t.expectEqual(day?.accessibilityLabel, "Friday, September 18, 2026")
  }

  // MARK: Non-Gregorian calendars

  run.test("an Islamic month has 29 or 30 days and starts at day one") { t in
    let islamic = Fixtures.calendar(.islamicUmmAlQura, locale: "ar_SA")
    let result = grid(2026, 9, 18, calendar: islamic, locale: "en_US")
    let inMonth = result.days.filter(\.isInCurrentMonth)
    t.expect([29, 30].contains(inMonth.count))
    t.expectEqual(islamic.component(.day, from: inMonth[0].date), 1)
  }

  run.test("a Japanese calendar grid carries the era in its year") { t in
    let japanese = Fixtures.calendar(.japanese, locale: "ja_JP")
    let result = grid(2026, 9, 18, calendar: japanese, locale: "ja_JP")
    t.expect(result.yearText.contains("令和"), result.yearText)
    t.expectEqual(result.days.filter(\.isInCurrentMonth).count, 30)
  }

  run.test("a Buddhist calendar grid shifts the year and nothing else") { t in
    let buddhist = Fixtures.calendar(.buddhist, locale: "th_TH")
    let result = grid(2026, 9, 18, calendar: buddhist, locale: "en_US")
    t.expect(result.yearText.contains("2569"), result.yearText)
    t.expectEqual(result.days.filter(\.isInCurrentMonth).count, 30)
  }

  // MARK: Extension point

  run.test("an indicator provider is asked once per cell") { t in
    final class Counting: IndicatorProvider {
      var calls = 0
      func indicators(for day: Date, calendar: Calendar) -> [DayIndicator] {
        calls += 1
        return [DayIndicator(kind: .publicHoliday, title: "Holiday")]
      }
    }
    let provider = Counting()
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    let date = Fixtures.date(2026, 9, 18, in: calendar)
    let result = CalendarEngine.makeGrid(
      for: date, today: date, calendar: calendar, locale: calendar.locale!,
      indicatorProvider: provider)
    t.expectEqual(provider.calls, 42)
    t.expect(result.days.allSatisfy { $0.holidayName == "Holiday" })
    t.expect(result.days.allSatisfy { $0.accessibilityLabel.hasSuffix(", Holiday") })
  }

  run.test("shared formatters give the same grid as fresh ones") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
    let locale = Locale(identifier: "ru_RU")
    let shared = GridFormatters(calendar: calendar, locale: locale)
    let date = Fixtures.date(2026, 9, 18, in: calendar)
    let a = CalendarEngine.makeGrid(for: date, today: date, calendar: calendar, locale: locale, formatters: shared)
    let b = CalendarEngine.makeGrid(for: date, today: date, calendar: calendar, locale: locale)
    t.expect(a == b)
  }
}
