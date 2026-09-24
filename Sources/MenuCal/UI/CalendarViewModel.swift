import AppKit
import MenuCalCore
import Observation
import SwiftUI

/// The state behind the calendar panel. SwiftUI's `@State` is unavailable on this toolchain, so
/// everything a view would keep for itself, hover included, lives here.
@MainActor
@Observable
final class CalendarViewModel {
  enum Control: Hashable {
    case previous, today, next
  }

  let preferences: Preferences
  let holidays: HolidayStore
  let vacations: VacationStore
  let events: EventStore
  let eventSettings: EventSettingsStore

  private(set) var state: CalendarState
  private(set) var grid: MonthGrid
  private(set) var today: Date
  private(set) var footerText = ""
  /// The short date and the name of the holiday, when the selected day is one.
  private(set) var selectedHoliday: (date: String, name: String)?
  /// The vacation's name, or the word "Vacation", when the selected day is one.
  private(set) var selectedVacationName: String?
  /// The day's list, open under the grid. It follows the selection while open.
  private(set) var isDayListOpen = false
  private(set) var dayRows: [EventRow] = []
  /// Groups the list is narrowed to, for this run of the app only; empty means all. Closing
  /// the panel keeps it, and the chips show it, so nothing is hidden in silence.
  private(set) var listFilter: Set<UUID> = []
  /// The keyboard focus ring appears with the first key press, as it does in AppKit lists.
  private(set) var showsFocusRing = false
  var hoveredDay: Date?
  var hoveredControl: Control?

  @ObservationIgnored private var calendar: Calendar
  @ObservationIgnored private var locale: Locale
  @ObservationIgnored private var formatters: GridFormatters
  @ObservationIgnored private var footerFormatter = DateFormatter()
  @ObservationIgnored private var shortFooterFormatter = DateFormatter()
  @ObservationIgnored private var rangeFormatter = DateFormatter()
  @ObservationIgnored private var timeFormatter = DateFormatter()
  @ObservationIgnored private var scroll = ScrollAccumulator()
  @ObservationIgnored private let now: () -> Date

  init(
    preferences: Preferences, holidays: HolidayStore, vacations: VacationStore,
    events: EventStore, eventSettings: EventSettingsStore,
    now: @escaping () -> Date = Date.init
  ) {
    self.preferences = preferences
    self.holidays = holidays
    self.vacations = vacations
    self.events = events
    self.eventSettings = eventSettings
    self.now = now
    let calendar = Self.systemCalendar(preferences)
    let locale = Locale.autoupdatingCurrent
    let moment = now()
    self.calendar = calendar
    self.locale = locale
    formatters = GridFormatters(calendar: calendar, locale: locale)
    var initial = CalendarState(now: moment, calendar: calendar)
    if preferences.reopenBehavior == .lastViewedMonth, let month = preferences.lastViewedMonth {
      initial.restoreDisplayedMonth(month, calendar: calendar)
    }
    state = initial
    today = calendar.startOfDay(for: moment)
    grid = CalendarEngine.makeGrid(
      for: moment, today: moment, calendar: calendar, locale: locale, formatters: formatters)
    rebuildFooterFormatter()
    rebuild()
    trackHolidays()
  }

  /// A holiday list that arrived, or a holiday setting that changed, redraws the grid.
  private func trackHolidays() {
    withObservationTracking {
      _ = holidays.revision
      _ = preferences.marksHolidays
      _ = preferences.holidayCountry
      _ = preferences.showsVacation
      _ = vacations.list
      _ = events.revision
      _ = events.access
      _ = eventSettings.settings
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.rebuild()
        self?.trackHolidays()
      }
    }
  }

  // MARK: Layout

  var metrics: Metrics { Metrics.metrics(for: preferences.density) }
  var typography: Typography { Typography.typography(for: preferences.density) }

  var panelSize: CGSize {
    metrics.panelSize(
      showsWeekNumbers: preferences.showsWeekNumbers, showsFooter: preferences.showsFullDate,
      showsDayList: isDayListOpen)
  }

  /// Events are on when the user wants them, the system allows them and a group shows in the
  /// grid; only then do day circles make room for the dots.
  var showsEventDots: Bool {
    eventSettings.settings.isEnabled && eventSettings.settings.showsDots && events.access == .granted
      && eventSettings.settings.groups.contains(where: \.showsInGrid)
  }

  var showsEvents: Bool {
    eventSettings.settings.isEnabled && events.access == .granted
  }

  /// The system accent, or the colour picked in Appearance settings.
  var accent: Color {
    guard preferences.usesCustomAccent else { return .accentColor }
    let custom = preferences.customAccent
    return Color(.sRGB, red: custom.red, green: custom.green, blue: custom.blue)
  }

  var isShowingCurrentMonth: Bool {
    state.isShowingCurrentMonth(now: today, calendar: calendar)
  }

  // MARK: Lifecycle

  /// Called right before the panel appears.
  func prepareToOpen() {
    refreshClock()
    state.reopen(
      now: now(), calendar: calendar,
      remembersMonth: preferences.reopenBehavior == .lastViewedMonth)
    showsFocusRing = false
    hoveredDay = nil
    hoveredControl = nil
    rebuild()
  }

  func didClose() {
    preferences.lastViewedMonth = state.displayedMonth
    isDayListOpen = false
    hoveredDay = nil
    hoveredControl = nil
  }

  /// The locale, the region, the time zone, the clock or the day changed.
  func systemChanged() {
    calendar = Self.systemCalendar(preferences)
    locale = .autoupdatingCurrent
    formatters = GridFormatters(calendar: calendar, locale: locale)
    rebuildFooterFormatter()
    refreshClock()
  }

  /// A setting that changes the grid itself changed: the first weekday.
  func preferencesChanged() {
    systemChanged()
  }

  private func refreshClock() {
    let moment = now()
    today = calendar.startOfDay(for: moment)
    state.clockChanged(now: moment, calendar: calendar)
    rebuild()
  }

  // MARK: Actions

  func showPreviousMonth() { changeMonth { $0.showMonth(byAdding: -1, calendar: calendar) } }
  func showNextMonth() { changeMonth { $0.showMonth(byAdding: 1, calendar: calendar) } }
  func goToToday() { changeMonth { $0.goToToday(now: now(), calendar: calendar) } }
  func select(_ day: DayCellModel) {
    changeMonth { $0.select(day.date, calendar: calendar) }
    // A day with events opens its list; an open list stays open and follows the selection.
    if day.hasEvents, showsEvents, !isDayListOpen { setDayList(open: true) }
  }

  func setDayList(open: Bool) {
    guard isDayListOpen != open else { return }
    withAnimation(Motion.monthChange) {
      isDayListOpen = open
    }
    rebuild()
  }

  func toggleDayList() { setDayList(open: !isDayListOpen) }

  /// The chips: every group that is not hidden, in the settings' order. None with one group.
  var filterChips: [EventGroup] {
    let groups = eventSettings.settings.groups.filter(\.showsInList)
    return groups.count > 1 ? groups : []
  }

  /// A click adds the group to the filter or takes it out, so several groups can be looked at
  /// together; with Command, the click keeps only this group. No group chosen means all.
  func toggleFilter(_ groupID: UUID, only: Bool) {
    if only {
      listFilter = listFilter == [groupID] ? [] : [groupID]
    } else if listFilter.contains(groupID) {
      listFilter.remove(groupID)
    } else {
      listFilter.insert(groupID)
    }
    rebuild()
  }

  /// The chip under the pointer widens to its full name, so a cut name is read without waiting
  /// for the tooltip.
  var hoveredChip: UUID?

  /// "Школа" or "Школа, Работа": the groups the list is narrowed to, for the empty state.
  var filterNames: String {
    filterChips.filter { listFilter.contains($0.id) }.map(\.name).joined(separator: ", ")
  }

  func durationText(_ row: EventRow) -> String {
    Self.durationFormatter.string(from: TimeInterval(row.durationMinutes * 60)) ?? ""
  }

  private static let durationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated
    formatter.zeroFormattingBehavior = .dropAll
    return formatter
  }()

  func openInCalendar(_ row: EventRow) { events.open(eventID: row.id) }
  func extendSelection(to day: DayCellModel) { changeMonth { $0.extendSelection(to: day.date, calendar: calendar) } }
  func clearRange() { changeMonth { $0.clearRange() } }

  // MARK: Vacation

  /// What the footer's action bar offers for the selected days: nothing for a plain day that is
  /// not a vacation, "Vacation" for a range, "Remove" when every selected day is one already.
  enum VacationAction: Equatable {
    case add, remove
  }

  var vacationAction: VacationAction? {
    guard preferences.showsVacation else { return nil }
    let range = state.selectedRange
    if vacations.covers(from: range.lowerBound, to: range.upperBound, calendar: calendar) { return .remove }
    return state.hasRange ? .add : nil
  }

  /// The action bar's text: "23 Sep - 2 Oct  ·  10 days", or for one day its date and, when it
  /// is a vacation, the vacation's name.
  var selectedRangeText: String {
    let range = state.selectedRange
    guard range.lowerBound != range.upperBound else {
      return [shortFooterFormatter.string(from: range.lowerBound), selectedVacationName]
        .compactMap { $0 }.joined(separator: "  ·  ")
    }
    let count = VacationCalendar.dayCount(
      from: VacationCalendar.key(for: range.lowerBound, calendar: calendar),
      to: VacationCalendar.key(for: range.upperBound, calendar: calendar), calendar: calendar)
    return rangeFormatter.string(from: range.lowerBound) + " - " + rangeFormatter.string(from: range.upperBound)
      + "  ·  " + L("vacation.dayCount", count)
  }

  func markVacation() {
    let range = state.selectedRange
    vacations.add(from: range.lowerBound, to: range.upperBound, calendar: calendar)
    changeMonth { $0.clearRange() }
  }

  func unmarkVacation() {
    let range = state.selectedRange
    vacations.remove(from: range.lowerBound, to: range.upperBound, calendar: calendar)
    changeMonth { $0.clearRange() }
  }

  /// The context menu of one day: a plain day can be marked on its own, without a range.
  func markVacation(_ day: DayCellModel) {
    vacations.add(from: day.date, to: day.date, calendar: calendar)
  }

  func unmarkVacation(_ day: DayCellModel) {
    vacations.remove(from: day.date, to: day.date, calendar: calendar)
  }

  func hover(_ day: Date, isInside: Bool) {
    if isInside {
      hoveredDay = day
    } else if hoveredDay == day {
      hoveredDay = nil
    }
  }

  func hover(_ control: Control, isInside: Bool) {
    if isInside {
      hoveredControl = control
    } else if hoveredControl == control {
      hoveredControl = nil
    }
  }

  /// Returns true when the key was ours. `isRightToLeft` mirrors the horizontal arrows.
  func handleKey(_ event: NSEvent, isRightToLeft: Bool) -> Bool {
    let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
    let forward = isRightToLeft ? -1 : 1

    switch Int(event.keyCode) {
    case 123, 124:  // Left and right arrows.
      let step = event.keyCode == 124 ? forward : -forward
      if flags == [.shift] {
        changeMonth { $0.extendSelection(byDays: step, calendar: calendar) }
        showsFocusRing = true
      } else if flags == [.option] {
        changeMonth { $0.showMonth(byAdding: step, calendar: calendar) }
      } else if flags == [.command, .shift] {
        changeMonth { $0.showYear(byAdding: step, calendar: calendar) }
      } else if flags.isEmpty {
        moveFocus(byDays: step)
      } else {
        return false
      }
      return true
    case 125, 126:  // Down and up arrows.
      let step = event.keyCode == 125 ? 7 : -7
      if flags == [.shift] {
        changeMonth { $0.extendSelection(byDays: step, calendar: calendar) }
        showsFocusRing = true
      } else if flags.isEmpty {
        moveFocus(byDays: step)
      } else {
        return false
      }
      return true
    case 36, 76:  // Return and Enter select and open the day's list when there is one.
      guard flags.isEmpty else { return false }
      showsFocusRing = true
      changeMonth { $0.selectFocused(calendar: calendar) }
      if showsEvents { setDayList(open: true) }
      return true
    case 49:  // Space.
      guard flags.isEmpty else { return false }
      showsFocusRing = true
      changeMonth { $0.selectFocused(calendar: calendar) }
      return true
    default:
      break
    }

    if event.charactersIgnoringModifiers?.lowercased() == "t", flags.isEmpty || flags == [.command] {
      goToToday()
      return true
    }
    return false
  }

  func handleScroll(_ event: NSEvent, isRightToLeft: Bool) {
    let phase: ScrollAccumulator.Phase
    if event.phase.contains(.began) || event.phase.contains(.mayBegin) {
      phase = .began
    } else if event.phase.contains(.changed) {
      phase = .changed
    } else if event.phase.contains(.ended) {
      phase = .ended
    } else if event.phase.contains(.cancelled) {
      phase = .cancelled
    } else {
      phase = .none
    }
    let horizontal = isRightToLeft ? -event.scrollingDeltaX : event.scrollingDeltaX
    let step = scroll.feed(
      ScrollAccumulator.Sample(
        deltaX: horizontal, deltaY: event.scrollingDeltaY, phase: phase,
        isMomentum: !event.momentumPhase.isEmpty, timestamp: event.timestamp))
    if step != 0 {
      changeMonth { $0.showMonth(byAdding: step, calendar: calendar) }
    }
  }

  // MARK: Pieces

  private func moveFocus(byDays days: Int) {
    showsFocusRing = true
    changeMonth { $0.moveFocus(byDays: days, calendar: calendar) }
  }

  private func changeMonth(_ mutate: (inout CalendarState) -> Void) {
    var next = state
    mutate(&next)
    guard next != state else { return }
    let monthChanged = next.displayedMonth != state.displayedMonth
    if monthChanged {
      withAnimation(Motion.monthChange) {
        state = next
        rebuild()
      }
    } else {
      state = next
      rebuild()
    }
  }

  private func rebuild() {
    grid = CalendarEngine.makeGrid(
      for: state.displayedMonth, today: today, calendar: calendar, locale: locale,
      formatters: formatters, indicatorProvider: indicatorProvider())
    footerText = footerFormatter.string(from: state.selectedDate)
    selectedHoliday = holidayCalendar()?.name(on: state.selectedDate, calendar: calendar).map {
      (shortFooterFormatter.string(from: state.selectedDate), $0)
    }
    rebuildDayRows()
    if preferences.showsVacation,
      let range = vacations.list.range(containing: VacationCalendar.key(for: state.selectedDate, calendar: calendar))
    {
      selectedVacationName = range.name.isEmpty ? L("vacation.title") : range.name
    } else {
      selectedVacationName = nil
    }
  }

  private func indicatorProvider() -> (any IndicatorProvider)? {
    var providers: [any IndicatorProvider] = []
    if let holidays = holidayCalendar() { providers.append(holidays) }
    if preferences.showsVacation, !vacations.list.isEmpty { providers.append(VacationCalendar(vacations.list)) }
    if showsEventDots {
      events.ensureLoaded(around: state.displayedMonth, calendar: calendar)
      providers.append(EventIndicatorProvider(index: events.eventIndex, settings: eventSettings.settings))
    }
    return providers.isEmpty ? nil : CompositeIndicatorProvider(providers)
  }

  private func rebuildDayRows() {
    guard isDayListOpen, showsEvents else {
      dayRows = []
      return
    }
    events.ensureLoaded(around: state.displayedMonth, calendar: calendar)
    // A group that vanished from the settings leaves the filter, so it cannot narrow the list
    // to nothing with no chip to show why.
    let known = Set(eventSettings.settings.groups.map(\.id))
    listFilter = listFilter.intersection(known)
    dayRows = EventListBuilder.rows(
      for: state.selectedDate, index: events.eventIndex, settings: eventSettings.settings,
      calendars: events.calendarsByID, calendar: calendar, timeFormatter: timeFormatter,
      dayFormatter: rangeFormatter, allDayText: L("events.allDay"), onlyGroups: listFilter)
  }

  private func holidayCalendar() -> HolidayCalendar? {
    guard preferences.marksHolidays,
      let country = HolidayPolicy.country(override: preferences.holidayCountry, locale: locale)
    else { return nil }
    // Names come in the country's language and in English; English speakers get the latter.
    let prefersLocal = Locale.preferredLanguages.first?.hasPrefix("en") != true
    return holidays.holidays(
      country: country,
      years: HolidayPolicy.years(around: state.displayedMonth, calendar: calendar),
      prefersLocalNames: prefersLocal)
  }

  private func rebuildFooterFormatter() {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale
    formatter.timeZone = calendar.timeZone
    formatter.dateStyle = .full
    footerFormatter = formatter

    let short = DateFormatter()
    short.calendar = calendar
    short.locale = locale
    short.timeZone = calendar.timeZone
    short.setLocalizedDateFormatFromTemplate("EdMMM")
    shortFooterFormatter = short

    // No weekday in a range: two of them do not fit the footer.
    let brief = DateFormatter()
    brief.calendar = calendar
    brief.locale = locale
    brief.timeZone = calendar.timeZone
    brief.setLocalizedDateFormatFromTemplate("dMMM")
    rangeFormatter = brief

    let time = DateFormatter()
    time.calendar = calendar
    time.locale = locale
    time.timeZone = calendar.timeZone
    time.setLocalizedDateFormatFromTemplate("jmm")
    timeFormatter = time
  }

  private static func systemCalendar(_ preferences: Preferences) -> Calendar {
    // A snapshot of the autoupdating calendar: it is rebuilt on every system change, and a
    // value that changes under a half built grid would be worse than one that waits a moment.
    CalendarEngine.effectiveCalendar(
      Calendar.current, firstWeekdayOverride: preferences.firstWeekday.weekday)
  }
}
