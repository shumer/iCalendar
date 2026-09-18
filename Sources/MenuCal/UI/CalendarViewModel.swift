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

  private(set) var state: CalendarState
  private(set) var grid: MonthGrid
  private(set) var today: Date
  private(set) var footerText = ""
  /// The keyboard focus ring appears with the first key press, as it does in AppKit lists.
  private(set) var showsFocusRing = false
  var hoveredDay: Date?
  var hoveredControl: Control?

  @ObservationIgnored private var calendar: Calendar
  @ObservationIgnored private var locale: Locale
  @ObservationIgnored private var formatters: GridFormatters
  @ObservationIgnored private var footerFormatter = DateFormatter()
  @ObservationIgnored private var scroll = ScrollAccumulator()
  @ObservationIgnored private let now: () -> Date

  init(preferences: Preferences, now: @escaping () -> Date = Date.init) {
    self.preferences = preferences
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
  }

  // MARK: Layout

  var metrics: Metrics { Metrics.metrics(for: preferences.density) }
  var typography: Typography { Typography.typography(for: preferences.density) }

  var panelSize: CGSize {
    metrics.panelSize(
      showsWeekNumbers: preferences.showsWeekNumbers, showsFooter: preferences.showsFullDate)
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
  func select(_ day: DayCellModel) { changeMonth { $0.select(day.date, calendar: calendar) } }

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
      if flags == [.option] {
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
      guard flags.isEmpty else { return false }
      moveFocus(byDays: event.keyCode == 125 ? 7 : -7)
      return true
    case 36, 76, 49:  // Return, Enter, Space.
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
      formatters: formatters)
    footerText = footerFormatter.string(from: state.selectedDate)
  }

  private func rebuildFooterFormatter() {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale
    formatter.timeZone = calendar.timeZone
    formatter.dateStyle = .full
    footerFormatter = formatter
  }

  private static func systemCalendar(_ preferences: Preferences) -> Calendar {
    // A snapshot of the autoupdating calendar: it is rebuilt on every system change, and a
    // value that changes under a half built grid would be worse than one that waits a moment.
    CalendarEngine.effectiveCalendar(
      Calendar.current, firstWeekdayOverride: preferences.firstWeekday.weekday)
  }
}
