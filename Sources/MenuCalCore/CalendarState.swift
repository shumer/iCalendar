import Foundation

/// What the calendar panel shows: three separate things, the displayed month, the selected date
/// and the date the keyboard is on. A value type with no clock in it, so every rule of
/// DesignSpec section 10 can be tested.
public struct CalendarState: Equatable, Sendable {
  /// The first day of the month on screen.
  public private(set) var displayedMonth: Date
  public private(set) var selectedDate: Date
  public private(set) var focusedDate: Date
  /// True until the user picks a date. A selection that only follows today moves with it at
  /// midnight; a date the user picked stays where it is.
  public private(set) var selectionFollowsToday: Bool
  /// The direction of the last month change, for the slide.
  public private(set) var lastDirection: NavigationDirection
  /// Counts month changes, so two moves in the same direction still animate twice.
  public private(set) var monthChangeCount: Int
  /// Counts returns to today, which pulse the today cell.
  public private(set) var todayPulseCount: Int
  /// The other end of a range selection, set by Shift-click or Shift-arrows. Nil while a single
  /// day is selected. It lives across month changes, so a range can span the month's edge.
  public private(set) var rangeAnchor: Date?

  public init(now: Date, calendar: Calendar) {
    let today = calendar.startOfDay(for: now)
    displayedMonth = CalendarEngine.startOfMonth(for: today, calendar: calendar)
    selectedDate = today
    focusedDate = today
    selectionFollowsToday = true
    lastDirection = .none
    monthChangeCount = 0
    todayPulseCount = 0
    rangeAnchor = nil
  }

  // MARK: Opening

  /// The panel opens on the current month with today selected. With `remembersMonth` the month
  /// that was on screen stays, and the selection is today all the same.
  public mutating func reopen(now: Date, calendar: Calendar, remembersMonth: Bool) {
    let today = calendar.startOfDay(for: now)
    selectedDate = today
    selectionFollowsToday = true
    lastDirection = .none
    rangeAnchor = nil
    if !remembersMonth {
      displayedMonth = CalendarEngine.startOfMonth(for: today, calendar: calendar)
    }
    focusedDate = focusAnchor(calendar: calendar)
  }

  /// Puts back the month that was on screen when the app last quit. Not a navigation, so it
  /// does not slide.
  public mutating func restoreDisplayedMonth(_ date: Date, calendar: Calendar) {
    displayedMonth = CalendarEngine.startOfMonth(for: date, calendar: calendar)
    lastDirection = .none
    focusedDate = focusAnchor(calendar: calendar)
  }

  // MARK: Months

  public mutating func showMonth(byAdding months: Int, calendar: Calendar) {
    show(CalendarNavigator.month(byAdding: months, to: displayedMonth, calendar: calendar), calendar: calendar)
    focusedDate = focusAnchor(calendar: calendar)
  }

  public mutating func showYear(byAdding years: Int, calendar: Calendar) {
    show(CalendarNavigator.month(byAddingYears: years, to: displayedMonth, calendar: calendar), calendar: calendar)
    focusedDate = focusAnchor(calendar: calendar)
  }

  public func isShowingCurrentMonth(now: Date, calendar: Calendar) -> Bool {
    CalendarNavigator.isSameMonth(displayedMonth, now, calendar: calendar)
  }

  // MARK: Days

  /// Moves the keyboard focus, carrying the displayed month across its edge.
  public mutating func moveFocus(byDays days: Int, calendar: Calendar) {
    focusedDate = CalendarNavigator.day(byAdding: days, to: focusedDate, calendar: calendar)
    show(focusedDate, calendar: calendar)
  }

  public mutating func selectFocused(calendar: Calendar) {
    select(focusedDate, calendar: calendar)
  }

  /// A click or Space on a day. A day of an adjacent month also moves to that month.
  public mutating func select(_ date: Date, calendar: Calendar) {
    let day = calendar.startOfDay(for: date)
    selectedDate = day
    focusedDate = day
    selectionFollowsToday = false
    rangeAnchor = nil
    show(day, calendar: calendar)
  }

  /// Shift-click: the days from the selection to `date` become the range. The anchor is the
  /// end that stays put, so a second Shift-click moves the other end.
  public mutating func extendSelection(to date: Date, calendar: Calendar) {
    let day = calendar.startOfDay(for: date)
    if rangeAnchor == nil { rangeAnchor = selectedDate }
    selectedDate = day
    focusedDate = day
    selectionFollowsToday = false
    show(day, calendar: calendar)
  }

  /// Shift-arrows: the same, one step at a time from the focused day.
  public mutating func extendSelection(byDays days: Int, calendar: Calendar) {
    extendSelection(to: CalendarNavigator.day(byAdding: days, to: focusedDate, calendar: calendar), calendar: calendar)
  }

  /// Esc or Cancel on the action bar: back to the single selected day.
  public mutating func clearRange() {
    rangeAnchor = nil
  }

  /// The selected days in order: one day, or the range between the anchor and the selection.
  public var selectedRange: ClosedRange<Date> {
    guard let rangeAnchor else { return selectedDate...selectedDate }
    return min(rangeAnchor, selectedDate)...max(rangeAnchor, selectedDate)
  }

  public var hasRange: Bool { rangeAnchor != nil && rangeAnchor != selectedDate }

  /// `T`, `Cmd+T` and the Today button. Always selects today, even on the current month.
  public mutating func goToToday(now: Date, calendar: Calendar) {
    let today = calendar.startOfDay(for: now)
    selectedDate = today
    focusedDate = today
    selectionFollowsToday = true
    rangeAnchor = nil
    todayPulseCount += 1
    show(today, calendar: calendar)
  }

  // MARK: The world changed

  /// Midnight, a time zone change, a new system calendar. Dates are day starts in the calendar
  /// that made them, so they are normalised again, and a selection that was following today
  /// follows it to the new day.
  public mutating func clockChanged(now: Date, calendar: Calendar) {
    let today = calendar.startOfDay(for: now)
    let wasOnSelection = focusedDate == selectedDate
    if selectionFollowsToday {
      let wasShowingSelection = CalendarNavigator.isSameMonth(displayedMonth, selectedDate, calendar: calendar)
      selectedDate = today
      if wasShowingSelection {
        displayedMonth = CalendarEngine.startOfMonth(for: today, calendar: calendar)
      }
    } else {
      selectedDate = calendar.startOfDay(for: selectedDate)
    }
    displayedMonth = CalendarEngine.startOfMonth(for: displayedMonth, calendar: calendar)
    focusedDate = wasOnSelection ? selectedDate : calendar.startOfDay(for: focusedDate)
    rangeAnchor = rangeAnchor.map { calendar.startOfDay(for: $0) }
    lastDirection = .none
  }

  // MARK: Pieces

  private mutating func show(_ date: Date, calendar: Calendar) {
    let target = CalendarEngine.startOfMonth(for: date, calendar: calendar)
    let direction = CalendarNavigator.direction(from: displayedMonth, to: target, calendar: calendar)
    guard direction != .none else { return }
    lastDirection = direction
    displayedMonth = target
    monthChangeCount += 1
  }

  /// Where the keyboard starts in a month it did not walk into: the selection when it is on
  /// screen, the first of the month otherwise.
  private func focusAnchor(calendar: Calendar) -> Date {
    CalendarNavigator.isSameMonth(selectedDate, displayedMonth, calendar: calendar)
      ? selectedDate : displayedMonth
  }
}
