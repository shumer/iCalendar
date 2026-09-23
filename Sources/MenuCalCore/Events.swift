import Foundation

// MARK: - What the system has

/// An account in System Settings that offers calendars: iCloud, a Google or Exchange account,
/// the local store. The app never holds an account of its own (ADR 0005).
public struct CalendarAccount: Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

/// One calendar of an account, with the colour the user gave it in Calendar.
public struct CalendarInfo: Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let accountID: String
  public let color: AccentComponents

  public init(id: String, title: String, accountID: String, color: AccentComponents) {
    self.id = id
    self.title = title
    self.accountID = accountID
    self.color = color
  }
}

/// One occurrence of an event on one day. Recurrences are expanded by the system before they
/// get here.
public struct EventItem: Equatable, Identifiable, Sendable {
  public let id: String
  public let calendarID: String
  public let title: String
  public let start: Date
  public let end: Date
  public let isAllDay: Bool

  public init(id: String, calendarID: String, title: String, start: Date, end: Date, isAllDay: Bool) {
    self.id = id
    self.calendarID = calendarID
    self.title = title
    self.start = start
    self.end = end
    self.isAllDay = isAllDay
  }
}

// MARK: - What the user decided

/// A group of calendars that share one colour and one slot in the grid. A person does not have
/// twelve calendars, they have three meanings: personal, work one, work two. The colour is an
/// index into the group palette, which is fixed by design (indigo, orange, teal, purple, brown,
/// yellow) and holds no red, pink or green: those mean day off, today and vacation.
public struct EventGroup: Codable, Equatable, Identifiable, Sendable {
  public static let paletteSize = 6
  public static let maximumCount = 4
  /// How many groups the grid can show; the rest live in the day's list.
  public static let gridSlots = 3

  /// Where a group's events appear. A timetable that runs every weekday is better kept out of
  /// the grid and in the list; a group nobody wants to see for a while is hidden without losing
  /// which calendars it holds.
  public enum Visibility: String, Codable, CaseIterable, Sendable {
    case gridAndList
    case listOnly
    case hidden
  }

  public let id: UUID
  public var name: String
  public var paletteIndex: Int
  public var visibility: Visibility
  public var calendarIDs: [String]

  public init(id: UUID = UUID(), name: String, paletteIndex: Int, visibility: Visibility = .gridAndList, calendarIDs: [String] = []) {
    self.id = id
    self.name = name
    self.paletteIndex = ((paletteIndex % Self.paletteSize) + Self.paletteSize) % Self.paletteSize
    self.visibility = visibility
    self.calendarIDs = calendarIDs
  }

  public var showsInGrid: Bool { visibility == .gridAndList }
  public var showsInList: Bool { visibility != .hidden }

  private enum CodingKeys: String, CodingKey {
    case id, name, paletteIndex, visibility, calendarIDs, showsInGrid
  }

  /// Files from 0.5 hold `showsInGrid` instead of `visibility`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    let palette = try container.decode(Int.self, forKey: .paletteIndex)
    paletteIndex = ((palette % Self.paletteSize) + Self.paletteSize) % Self.paletteSize
    calendarIDs = try container.decodeIfPresent([String].self, forKey: .calendarIDs) ?? []
    if let stored = try container.decodeIfPresent(Visibility.self, forKey: .visibility) {
      visibility = stored
    } else {
      visibility = (try container.decodeIfPresent(Bool.self, forKey: .showsInGrid) ?? true) ? .gridAndList : .listOnly
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(paletteIndex, forKey: .paletteIndex)
    try container.encode(visibility, forKey: .visibility)
    try container.encode(calendarIDs, forKey: .calendarIDs)
  }
}

/// The user's event settings: the groups in their order, which decides the grid slots.
/// A calendar in no group is not shown at all, so unchecking a calendar means removing it from
/// its group.
public struct EventSettings: Codable, Equatable, Sendable {
  public var isEnabled: Bool
  public var groups: [EventGroup]
  /// Dots under the days, or no marks at all; the day's list works either way.
  public var showsDots: Bool
  /// Dots on the days of adjacent months, paler like the dates themselves.
  public var showsDotsInAdjacentMonths: Bool

  public init(isEnabled: Bool = true, groups: [EventGroup] = [], showsDots: Bool = true, showsDotsInAdjacentMonths: Bool = true) {
    self.isEnabled = isEnabled
    self.groups = Array(groups.prefix(EventGroup.maximumCount))
    self.showsDots = showsDots
    self.showsDotsInAdjacentMonths = showsDotsInAdjacentMonths
  }

  private enum CodingKeys: String, CodingKey {
    case isEnabled, groups, showsDots, showsDotsInAdjacentMonths
  }

  /// A file written before a key existed still reads; the missing key takes its default.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    groups = Array((try container.decodeIfPresent([EventGroup].self, forKey: .groups) ?? []).prefix(EventGroup.maximumCount))
    showsDots = try container.decodeIfPresent(Bool.self, forKey: .showsDots) ?? true
    showsDotsInAdjacentMonths = try container.decodeIfPresent(Bool.self, forKey: .showsDotsInAdjacentMonths) ?? true
  }

  public func group(of calendarID: String) -> EventGroup? {
    groups.first { $0.calendarIDs.contains(calendarID) }
  }

  public func isShown(_ calendarID: String) -> Bool {
    group(of: calendarID) != nil
  }

  /// The grid slot of a group: its position among the groups that show in the grid, or nil
  /// beyond the third or when the group does not show in the grid.
  public func gridSlot(of groupID: UUID) -> Int? {
    let inGrid = groups.filter(\.showsInGrid)
    guard let index = inGrid.firstIndex(where: { $0.id == groupID }), index < EventGroup.gridSlots else { return nil }
    return index
  }

  // MARK: Editing

  /// The first time an account appears, its calendars become one group named after it, with the
  /// next free palette colour, so the person sees their accounts told apart without touching
  /// a setting. Accounts seen before are left as the user arranged them.
  public mutating func adopt(accounts: [CalendarAccount], calendars: [CalendarInfo], knownAccountIDs: inout Set<String>) {
    for account in accounts where !knownAccountIDs.contains(account.id) {
      knownAccountIDs.insert(account.id)
      guard groups.count < EventGroup.maximumCount else { continue }
      let ids = calendars.filter { $0.accountID == account.id }.map(\.id).filter { !isShown($0) }
      let used = Set(groups.map(\.paletteIndex))
      let palette = (0..<EventGroup.paletteSize).first { !used.contains($0) } ?? groups.count % EventGroup.paletteSize
      groups.append(EventGroup(name: account.title, paletteIndex: palette, calendarIDs: ids))
    }
  }

  public mutating func setShown(_ calendarID: String, in groupID: UUID?, shown: Bool) {
    for index in groups.indices {
      groups[index].calendarIDs.removeAll { $0 == calendarID }
    }
    guard shown, let groupID, let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
    groups[index].calendarIDs.append(calendarID)
  }

  public mutating func move(_ calendarID: String, to groupID: UUID) {
    setShown(calendarID, in: groupID, shown: true)
  }

  @discardableResult
  public mutating func addGroup(named name: String) -> EventGroup? {
    guard groups.count < EventGroup.maximumCount else { return nil }
    let used = Set(groups.map(\.paletteIndex))
    let palette = (0..<EventGroup.paletteSize).first { !used.contains($0) } ?? 0
    let group = EventGroup(name: name, paletteIndex: palette)
    groups.append(group)
    return group
  }

  public mutating func removeGroup(id: UUID) {
    groups.removeAll { $0.id == id }
  }

  public mutating func update(id: UUID, _ change: (inout EventGroup) -> Void) {
    guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
    change(&groups[index])
  }

  public mutating func moveGroup(id: UUID, up: Bool) {
    guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
    let target = up ? index - 1 : index + 1
    guard groups.indices.contains(target) else { return }
    groups.swapAt(index, target)
  }
}

// MARK: - Into the grid

/// Events by the day they fall on, in the calendar's time zone. A multi-day event is on every
/// day it touches.
public struct EventIndex: Sendable {
  private var byDay: [Int: [EventItem]] = [:]

  public init(events: [EventItem], calendar: Calendar) {
    for event in events {
      var day = calendar.startOfDay(for: event.start)
      // An end at exactly midnight belongs to the day before, not to the next one.
      let lastInstant = event.isAllDay ? event.end.addingTimeInterval(-1) : max(event.start, event.end.addingTimeInterval(-1))
      let last = calendar.startOfDay(for: lastInstant)
      var guardCount = 0
      while day <= last, guardCount < 400 {
        byDay[VacationCalendar.key(for: day, calendar: calendar), default: []].append(event)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
        guardCount += 1
      }
    }
  }

  public func events(on day: Date, calendar: Calendar) -> [EventItem] {
    byDay[VacationCalendar.key(for: day, calendar: calendar)] ?? []
  }

  public var isEmpty: Bool { byDay.isEmpty }
}

/// Marks days with the groups that have events on them. Only calendars in a group count.
public struct EventIndicatorProvider: IndicatorProvider {
  private let index: EventIndex
  private let settings: EventSettings

  public init(index: EventIndex, settings: EventSettings) {
    self.index = index
    self.settings = settings
  }

  public func indicators(for day: Date, calendar: Calendar) -> [DayIndicator] {
    guard settings.isEnabled, settings.showsDots else { return [] }
    var seen: Set<Int> = []
    var result: [DayIndicator] = []
    for event in index.events(on: day, calendar: calendar) {
      guard let group = settings.group(of: event.calendarID), let slot = settings.gridSlot(of: group.id),
        !seen.contains(slot)
      else { continue }
      seen.insert(slot)
      result.append(DayIndicator(kind: .events(slot: slot, paletteIndex: group.paletteIndex), title: group.name))
    }
    return result.sorted { $0.kind.slot ?? 0 < $1.kind.slot ?? 0 }
  }
}

// MARK: - The day's list

/// One row of the day's list, ready to draw: the time text is made once, here, and never in
/// the view.
public struct EventRow: Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let timeText: String
  public let isAllDay: Bool
  public let calendarColor: AccentComponents
  public let groupPaletteIndex: Int
  public let groupName: String
  public let calendarTitle: String

  public var accessibilityLabel: String {
    "\(timeText), \(title), \(calendarTitle)"
  }
}

public enum EventListBuilder {
  /// The events of a day that the settings show, all-day ones first, then by start, with the
  /// group of each. `allDayText` is the localised word for the time column of an all-day row.
  public static func rows(
    for day: Date, index: EventIndex, settings: EventSettings, calendars: [String: CalendarInfo],
    calendar: Calendar, timeFormatter: DateFormatter, allDayText: String
  ) -> [EventRow] {
    let events = index.events(on: day, calendar: calendar)
    let shown = events.compactMap { event -> (EventItem, EventGroup)? in
      guard let group = settings.group(of: event.calendarID), group.showsInList else { return nil }
      return (event, group)
    }
    let sorted = shown.sorted { a, b in
      if a.0.isAllDay != b.0.isAllDay { return a.0.isAllDay }
      if a.0.start != b.0.start { return a.0.start < b.0.start }
      return a.0.title < b.0.title
    }
    return sorted.map { event, group in
      let info = calendars[event.calendarID]
      return EventRow(
        id: event.id, title: event.title,
        timeText: event.isAllDay ? allDayText : timeFormatter.string(from: event.start),
        isAllDay: event.isAllDay,
        calendarColor: info?.color ?? AccentComponents(red: 0.5, green: 0.5, blue: 0.5),
        groupPaletteIndex: group.paletteIndex, groupName: group.name,
        calendarTitle: info?.title ?? "")
    }
  }
}
