import Foundation
import MenuCalCore

func eventsTests(_ run: TestRun) {
  let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
  func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date { Fixtures.date(y, m, d, h, min, in: calendar) }
  let google = CalendarAccount(id: "acc-google", title: "Google")
  let exchange = CalendarAccount(id: "acc-ex", title: "Exchange")
  let personal = CalendarInfo(id: "cal-personal", title: "Личное", accountID: google.id, color: AccentComponents(red: 0, green: 0.5, blue: 1))
  let school = CalendarInfo(id: "cal-school", title: "Расписание", accountID: google.id, color: AccentComponents(red: 1, green: 0.5, blue: 0))
  let work = CalendarInfo(id: "cal-work", title: "Календарь", accountID: exchange.id, color: AccentComponents(red: 0, green: 0, blue: 1))
  let calendars = [personal, school, work]
  let byID = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })

  func adopted() -> EventSettings {
    var settings = EventSettings()
    var known: Set<String> = []
    settings.adopt(accounts: [google, exchange], calendars: calendars, knownAccountIDs: &known)
    return settings
  }

  run.test("a new account becomes a group named after it, with its own colour") { t in
    let settings = adopted()
    t.expectEqual(settings.groups.map(\.name), ["Google", "Exchange"])
    t.expectEqual(settings.groups.map(\.paletteIndex), [0, 1])
    t.expectEqual(settings.groups[0].calendarIDs, [personal.id, school.id])
    t.expectEqual(settings.groups[1].calendarIDs, [work.id])
    t.expect(settings.isShown(school.id))
  }

  run.test("an account seen before is left as the user arranged it") { t in
    var settings = adopted()
    var known: Set<String> = [google.id, exchange.id]
    settings.setShown(school.id, in: nil, shown: false)
    settings.adopt(accounts: [google, exchange], calendars: calendars, knownAccountIDs: &known)
    t.expect(!settings.isShown(school.id), "unchecking survives a relaunch")
    t.expectEqual(settings.groups.count, 2)
  }

  run.test("a calendar moves between groups and can be hidden") { t in
    var settings = adopted()
    let mine = settings.addGroup(named: "Школа")!
    settings.move(school.id, to: mine.id)
    t.expectEqual(settings.group(of: school.id)?.name, "Школа")
    t.expect(!settings.groups[0].calendarIDs.contains(school.id), "it is in one group only")
    t.expectEqual(mine.paletteIndex, 2, "the next free colour")
    settings.setShown(school.id, in: mine.id, shown: false)
    t.expect(!settings.isShown(school.id))
  }

  run.test("groups are at most four and colours wrap without red") { t in
    var settings = EventSettings()
    for name in ["a", "b", "c", "d", "e"] { settings.addGroup(named: name) }
    t.expectEqual(settings.groups.count, 4)
    t.expectEqual(settings.groups.map(\.paletteIndex), [0, 1, 2, 3])
    t.expectEqual(EventGroup(name: "x", paletteIndex: 7).paletteIndex, 1)
    t.expectEqual(EventGroup(name: "x", paletteIndex: -1).paletteIndex, 5)
  }

  run.test("grid slots follow the order of the groups that show in the grid") { t in
    var settings = adopted()
    let third = settings.addGroup(named: "Третья")!
    let fourth = settings.addGroup(named: "Четвёртая")!
    t.expectEqual(settings.gridSlot(of: settings.groups[0].id), 0)
    t.expectEqual(settings.gridSlot(of: third.id), 2)
    t.expectEqual(settings.gridSlot(of: fourth.id), nil, "the fourth lives in the list only")
    settings.update(id: settings.groups[0].id) { $0.showsInGrid = false }
    t.expectEqual(settings.gridSlot(of: settings.groups[0].id), nil)
    t.expectEqual(settings.gridSlot(of: third.id), 1, "the slots close up")
    t.expectEqual(settings.gridSlot(of: fourth.id), 2)
    settings.moveGroup(id: fourth.id, up: true)
    t.expectEqual(settings.groups.map(\.name), ["Google", "Exchange", "Четвёртая", "Третья"])
    settings.removeGroup(id: third.id)
    t.expectEqual(settings.groups.count, 3)
  }

  run.test("settings survive a round trip through JSON, and an old file takes the new defaults") { t in
    var settings = adopted()
    settings.showsDots = false
    let decoded = try JSONDecoder().decode(EventSettings.self, from: JSONEncoder().encode(settings))
    t.expectEqual(decoded, settings)
    let old = try JSONDecoder().decode(EventSettings.self, from: Data("{\"isEnabled\":true,\"groups\":[]}".utf8))
    t.expect(old.showsDots && old.showsDotsInAdjacentMonths)
  }

  run.test("no dots when marks are off, though the list still works") { t in
    var settings = adopted()
    settings.showsDots = false
    let day = at(2026, 9, 24)
    let events = [EventItem(id: "1", calendarID: personal.id, title: "x", start: day, end: day.addingTimeInterval(3600), isAllDay: false)]
    let index = EventIndex(events: events, calendar: calendar)
    t.expectEqual(EventIndicatorProvider(index: index, settings: settings).indicators(for: day, calendar: calendar).count, 0)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "HH:mm"
    t.expectEqual(EventListBuilder.rows(for: day, index: index, settings: settings, calendars: byID, calendar: calendar, timeFormatter: formatter, allDayText: "").count, 1)
  }

  run.test("events land on every day they touch, and a midnight end stays on its day") { t in
    let events = [
      EventItem(id: "1", calendarID: personal.id, title: "Урок", start: at(2026, 9, 24, 15), end: at(2026, 9, 24, 16), isAllDay: false),
      EventItem(id: "2", calendarID: personal.id, title: "Поездка", start: at(2026, 9, 25, 0), end: at(2026, 9, 28, 0), isAllDay: true),
      EventItem(id: "3", calendarID: work.id, title: "Ночная", start: at(2026, 9, 24, 22), end: at(2026, 9, 25, 0), isAllDay: false),
    ]
    let index = EventIndex(events: events, calendar: calendar)
    t.expectEqual(index.events(on: at(2026, 9, 24), calendar: calendar).map(\.id), ["1", "3"])
    t.expectEqual(index.events(on: at(2026, 9, 25), calendar: calendar).map(\.id), ["2"], "the 24th's night event does not spill over")
    t.expectEqual(index.events(on: at(2026, 9, 27), calendar: calendar).map(\.id), ["2"])
    t.expectEqual(index.events(on: at(2026, 9, 28), calendar: calendar).map(\.id), [], "an all-day event ending at midnight of the 28th ends on the 27th")
  }

  run.test("six events from three calendars give at most three dots, one per group") { t in
    var settings = adopted()
    let mine = settings.addGroup(named: "Школа")!
    settings.move(school.id, to: mine.id)
    let day = at(2026, 9, 24)
    var events: [EventItem] = []
    for (i, cal) in [personal, personal, school, school, work, work].enumerated() {
      events.append(EventItem(id: "\(i)", calendarID: cal.id, title: "e\(i)", start: day.addingTimeInterval(Double(i) * 3600), end: day.addingTimeInterval(Double(i + 1) * 3600), isAllDay: false))
    }
    let provider = EventIndicatorProvider(index: EventIndex(events: events, calendar: calendar), settings: settings)
    let dots = provider.indicators(for: day, calendar: calendar)
    t.expectEqual(dots.count, 3)
    t.expectEqual(dots.map(\.kind.slot), [0, 1, 2])
    t.expectEqual(dots.map(\.title), ["Google", "Exchange", "Школа"])
    let grid = CalendarEngine.makeGrid(for: day, today: day, calendar: calendar, locale: Locale(identifier: "ru_RU"), indicatorProvider: provider)
    let cell = grid.days.first { $0.isInCurrentMonth && $0.dayNumber == "24" }!
    t.expect(cell.hasEvents)
    t.expectEqual(cell.eventDots.map(\.paletteIndex), [0, 1, 2])
    t.expect(cell.accessibilityLabel.contains("Google") && cell.accessibilityLabel.contains("Школа"))
  }

  run.test("a group hidden from the grid gives no dot, and disabled events give none at all") { t in
    var settings = adopted()
    settings.update(id: settings.groups[0].id) { $0.showsInGrid = false }
    let day = at(2026, 9, 24)
    let events = [EventItem(id: "1", calendarID: school.id, title: "Урок", start: day, end: day.addingTimeInterval(3600), isAllDay: false)]
    let index = EventIndex(events: events, calendar: calendar)
    t.expectEqual(EventIndicatorProvider(index: index, settings: settings).indicators(for: day, calendar: calendar).count, 0)
    settings.update(id: settings.groups[0].id) { $0.showsInGrid = true }
    t.expectEqual(EventIndicatorProvider(index: index, settings: settings).indicators(for: day, calendar: calendar).count, 1)
    settings.isEnabled = false
    t.expectEqual(EventIndicatorProvider(index: index, settings: settings).indicators(for: day, calendar: calendar).count, 0)
  }

  run.test("the day's list has all-day rows first, then by time, and skips hidden calendars") { t in
    var settings = adopted()
    settings.setShown(work.id, in: nil, shown: false)
    let day = at(2026, 9, 24)
    let events = [
      EventItem(id: "late", calendarID: personal.id, title: "Ужин", start: at(2026, 9, 24, 19), end: at(2026, 9, 24, 20), isAllDay: false),
      EventItem(id: "all", calendarID: school.id, title: "Экскурсия", start: at(2026, 9, 24, 0), end: at(2026, 9, 25, 0), isAllDay: true),
      EventItem(id: "early", calendarID: personal.id, title: "Врач", start: at(2026, 9, 24, 8, 30), end: at(2026, 9, 24, 9), isAllDay: false),
      EventItem(id: "hidden", calendarID: work.id, title: "Стендап", start: at(2026, 9, 24, 10), end: at(2026, 9, 24, 10, 15), isAllDay: false),
    ]
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("jmm")
    let rows = EventListBuilder.rows(
      for: day, index: EventIndex(events: events, calendar: calendar), settings: settings,
      calendars: byID, calendar: calendar, timeFormatter: formatter, allDayText: "весь день")
    t.expectEqual(rows.map(\.id), ["all", "early", "late"])
    t.expectEqual(rows[0].timeText, "весь день")
    t.expectEqual(rows[1].timeText, "08:30")
    t.expectEqual(rows[1].calendarTitle, "Личное")
    t.expectEqual(rows[1].groupName, "Google")
    t.expectEqual(rows[0].calendarColor, school.color)
    t.expectEqual(rows[1].accessibilityLabel, "08:30, Врач, Личное")
  }
}
