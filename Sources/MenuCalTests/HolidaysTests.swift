import Foundation
import MenuCalCore

func holidaysTests(_ run: TestRun) {
  let feed = Data("""
    [
      {"date": "2026-01-01", "localName": "Nowy Rok", "name": "New Year's Day", "global": true, "counties": null, "types": ["Public"]},
      {"date": "2026-11-11", "localName": "Narodowe Święto Niepodległości", "name": "Independence Day", "global": true, "counties": null, "types": ["Public", "Bank"]},
      {"date": "2026-02-14", "localName": "Walentynki", "name": "Valentine's Day", "global": true, "counties": null, "types": ["Observance"]},
      {"date": "2026-06-04", "localName": "Regionalne", "name": "Regional Day", "global": false, "counties": ["PL-SL"], "types": ["Public"]},
      {"date": "2026-09-01", "localName": "Szkoła", "name": "School Day", "global": true, "counties": null, "types": ["School"]},
      {"date": "2027-01-01", "localName": "Zły rok", "name": "Wrong Year", "global": true, "counties": null, "types": ["Public"]},
      {"date": "2026-13-40", "localName": "Bzdura", "name": "Nonsense", "global": true, "counties": null, "types": ["Public"]},
      {"date": "2026-05-03", "localName": "", "name": "Constitution Day", "global": true, "counties": null, "types": ["Public"]}
    ]
    """.utf8)

  run.test("only official, country wide days off survive the feed") { t in
    let holidays = try HolidayFeed.parse(feed, year: 2026)
    t.expectEqual(holidays.map(\.name), ["New Year's Day", "Independence Day", "Constitution Day"])
    t.expectEqual(holidays[0].localName, "Nowy Rok")
    t.expectEqual(holidays[2].localName, "Constitution Day", "an empty local name falls back to English")
  }

  run.test("a feed that is not a list is refused") { t in
    for text in ["not json", "{\"status\": 404}"] {
      do {
        _ = try HolidayFeed.parse(Data(text.utf8), year: 2026)
        t.expect(false, "parsed \(text)")
      } catch {
        t.expectEqual(error as? HolidayFeedError, .malformed)
      }
    }
  }

  run.test("a request is built only for a country the service knows") { t in
    t.expectEqual(HolidayFeed.url(country: "PL", year: 2026)?.absoluteString, "https://date.nager.at/api/v3/PublicHolidays/2026/PL")
    for bad in ["pl", "XX", "", "PL/../x", "POL"] {
      t.expect(HolidayFeed.url(country: bad, year: 2026) == nil, bad)
    }
    t.expect(HolidayFeed.url(country: "PL", year: 12) == nil)
    t.expect(HolidayFeed.supportedCountries.count > 100)
    t.expect(HolidayFeed.supportedCountries.isSuperset(of: ["PL", "UA", "US", "DE"]))
  }

  run.test("the country is the system region unless one is picked") { t in
    t.expectEqual(HolidayPolicy.country(override: nil, locale: Locale(identifier: "ru_PL")), "PL")
    t.expectEqual(HolidayPolicy.country(override: nil, locale: Locale(identifier: "ru_UA")), "UA")
    t.expectEqual(HolidayPolicy.country(override: "DE", locale: Locale(identifier: "ru_PL")), "DE")
    t.expectEqual(HolidayPolicy.country(override: nil, locale: Locale(identifier: "en_001")), nil, "no country, no holidays")
    t.expectEqual(HolidayPolicy.country(override: nil, locale: Locale(identifier: "ru")), nil)
  }

  run.test("a list is fetched when missing, refreshed monthly, and left alone once its year is over") { t in
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func entry(year: Int, age: TimeInterval) -> HolidayCacheEntry {
      HolidayCacheEntry(country: "PL", year: year, fetchedAt: now.addingTimeInterval(-age), holidays: [])
    }
    t.expect(HolidayPolicy.needsFetch(nil, now: now, currentYear: 2026))
    t.expect(!HolidayPolicy.needsFetch(entry(year: 2026, age: 86_400), now: now, currentYear: 2026))
    t.expect(HolidayPolicy.needsFetch(entry(year: 2026, age: 40 * 86_400), now: now, currentYear: 2026))
    t.expect(!HolidayPolicy.needsFetch(entry(year: 2025, age: 400 * 86_400), now: now, currentYear: 2026))
    t.expect(HolidayPolicy.needsFetch(entry(year: 2026, age: -500), now: now, currentYear: 2026), "fetched in the future")
  }

  run.test("a cache entry survives a round trip through JSON") { t in
    let entry = HolidayCacheEntry(
      country: "PL", year: 2026, fetchedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
      holidays: try HolidayFeed.parse(feed, year: 2026))
    let decoded = try JSONDecoder().decode(HolidayCacheEntry.self, from: JSONEncoder().encode(entry))
    t.expectEqual(decoded, entry)
  }

  run.test("the grid marks holidays and VoiceOver hears their names") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "pl_PL")
    let holidays = HolidayCalendar(try HolidayFeed.parse(feed, year: 2026))
    let november = Fixtures.date(2026, 11, 5, in: calendar)
    let grid = CalendarEngine.makeGrid(
      for: november, today: november, calendar: calendar, locale: Locale(identifier: "pl_PL"),
      indicatorProvider: holidays)
    let marked = grid.days.filter { $0.holidayName != nil }
    t.expectEqual(marked.map(\.dayNumber), ["11"])
    t.expectEqual(marked.first?.holidayName, "Narodowe Święto Niepodległości")
    t.expect(marked.first?.accessibilityLabel.hasSuffix(", Narodowe Święto Niepodległości") == true)
    t.expectEqual(HolidayCalendar([], prefersLocalNames: true).isEmpty, true)
  }

  run.test("English names are used when local ones are not wanted") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    let holidays = HolidayCalendar(try HolidayFeed.parse(feed, year: 2026), prefersLocalNames: false)
    t.expectEqual(holidays.name(on: Fixtures.date(2026, 1, 1, in: calendar), calendar: calendar), "New Year's Day")
    t.expectEqual(holidays.name(on: Fixtures.date(2026, 1, 2, in: calendar), calendar: calendar), nil)
  }

  run.test("a holiday is found from a grid drawn in another calendar") { t in
    // The 1st of January 2026 seen through the Hebrew calendar is still New Year's Day.
    let hebrew = Fixtures.calendar(.hebrew, locale: "he_IL")
    let gregorian = Fixtures.calendar(.gregorian, locale: "he_IL")
    let holidays = HolidayCalendar(try HolidayFeed.parse(feed, year: 2026))
    let newYear = Fixtures.date(2026, 1, 1, in: gregorian)
    t.expectEqual(holidays.name(on: hebrew.startOfDay(for: newYear), calendar: hebrew), "Nowy Rok")
  }

  run.test("a holiday belongs to its day in the calendar's time zone") { t in
    let warsaw = Fixtures.calendar(.gregorian, locale: "pl_PL")
    let tokyo = Fixtures.calendar(.gregorian, locale: "pl_PL", timeZone: "Asia/Tokyo")
    let holidays = HolidayCalendar(try HolidayFeed.parse(feed, year: 2026))
    // 20:00 on the 31st of December in Warsaw is already the 1st of January in Tokyo.
    let evening = Fixtures.date(2025, 12, 31, 20, in: warsaw)
    t.expectEqual(holidays.name(on: evening, calendar: warsaw), nil)
    t.expectEqual(holidays.name(on: evening, calendar: tokyo), "Nowy Rok")
  }

  run.test("a grid around the new year needs two years of holidays") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "pl_PL")
    func years(_ month: Int, _ year: Int) -> Set<Int> {
      let date = Fixtures.date(year, month, 10, in: calendar)
      let grid = CalendarEngine.makeGrid(for: date, today: date, calendar: calendar, locale: Locale(identifier: "pl_PL"))
      return HolidayPolicy.years(of: grid, calendar: calendar)
    }
    for (month, year) in [(12, 2026), (1, 2026), (6, 2026), (2, 2021)] {
      let start = CalendarEngine.startOfMonth(for: Fixtures.date(year, month, 10, in: calendar), calendar: calendar)
      t.expect(HolidayPolicy.years(around: start, calendar: calendar).isSuperset(of: years(month, year)), "\(month).\(year)")
    }
    t.expectEqual(years(12, 2026), [2026, 2027])
    t.expectEqual(years(1, 2026), [2025, 2026])
    t.expectEqual(years(6, 2026), [2026])
  }
}
