import AppKit
import EventKit
import MenuCalCore
import Observation

/// Reads the system's calendars through EventKit, read only. The app holds no account and no
/// token: the accounts are macOS's, added in System Settings, and this asks once for permission
/// to read what they brought. Events for the months the grid shows are kept in memory and
/// fetched again when the system says the store changed.
@MainActor
@Observable
final class EventStore {
  enum Access: Equatable {
    case undetermined, granted, denied, restricted
  }

  private(set) var access: Access = .undetermined
  private(set) var accounts: [CalendarAccount] = []
  private(set) var calendars: [CalendarInfo] = []
  /// Bumped whenever events changed, so the grid rebuilds.
  private(set) var revision = 0

  @ObservationIgnored private let store = EKEventStore()
  @ObservationIgnored private var index = EventIndex(events: [], calendar: .current)
  @ObservationIgnored private var loadedWindow: DateInterval?
  @ObservationIgnored private var observer: NSObjectProtocol?
  @ObservationIgnored private var reloadTask: Task<Void, Never>?

  init() {
    refreshAccess()
    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: store, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.storeChanged() }
    }
  }

  var calendarsByID: [String: CalendarInfo] {
    Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
  }

  var eventIndex: EventIndex { index }

  // MARK: Access

  private func refreshAccess() {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .fullAccess: access = .granted
    case .denied, .writeOnly: access = .denied
    case .restricted: access = .restricted
    case .notDetermined: access = .undetermined
    @unknown default: access = .undetermined
    }
    if access == .granted { loadCalendars() }
  }

  /// Asks the system for permission. macOS shows its own dialog with the text from Info.plist.
  func requestAccess() {
    Log.events.info("Requesting calendar access, status before: \(EKEventStore.authorizationStatus(for: .event).rawValue)")
    Task {
      do {
        let granted = try await store.requestFullAccessToEvents()
        Log.events.info("Calendar access request answered: \(granted), status now: \(EKEventStore.authorizationStatus(for: .event).rawValue)")
      } catch {
        Log.events.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
      }
      refreshAccess()
      if access == .granted, let window = loadedWindow {
        loadedWindow = nil
        load(window: window)
      }
    }
  }

  func openPrivacySettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    if let url, NSWorkspace.shared.open(url) { return }
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
  }

  // MARK: Calendars

  private func loadCalendars() {
    var seenAccounts: [String: CalendarAccount] = [:]
    var list: [CalendarInfo] = []
    for calendar in store.calendars(for: .event) {
      let source = calendar.source
      let accountID = source?.sourceIdentifier ?? "local"
      if seenAccounts[accountID] == nil {
        seenAccounts[accountID] = CalendarAccount(id: accountID, title: source?.title ?? L("events.localAccount"))
      }
      list.append(
        CalendarInfo(
          id: calendar.calendarIdentifier, title: calendar.title, accountID: accountID,
          color: Self.components(of: calendar.color ?? .systemGray)))
    }
    accounts = seenAccounts.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    calendars = list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
  }

  private static func components(of color: NSColor) -> AccentComponents {
    let rgb = color.usingColorSpace(.sRGB) ?? color
    return AccentComponents(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
  }

  // MARK: Events

  /// Makes sure the events of this window are loaded. The window is the grid's 42 days with a
  /// month on either side, so paging through months rarely waits for a fetch.
  func ensureLoaded(around monthStart: Date, calendar: Calendar) {
    guard access == .granted else { return }
    let start = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
    let end = calendar.date(byAdding: .month, value: 3, to: monthStart) ?? monthStart
    let wanted = DateInterval(start: start, end: end)
    if let loaded = loadedWindow, loaded.start <= wanted.start, loaded.end >= wanted.end { return }
    let wider = DateInterval(
      start: calendar.date(byAdding: .month, value: -2, to: monthStart) ?? start,
      end: calendar.date(byAdding: .month, value: 4, to: monthStart) ?? end)
    load(window: wider)
  }

  private func load(window: DateInterval) {
    loadedWindow = window
    let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: nil)
    // EventKit expands recurrences here, which can take a moment with years of history.
    let events = store.events(matching: predicate)
    let items = events.map { event in
      EventItem(
        id: event.eventIdentifier ?? "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSinceReferenceDate)",
        calendarID: event.calendar.calendarIdentifier, title: event.title ?? "",
        start: event.startDate, end: event.endDate, isAllDay: event.isAllDay)
    }
    index = EventIndex(events: items, calendar: .current)
    revision += 1
    Log.events.info("Loaded \(items.count) events")
  }

  private func storeChanged() {
    // Several notifications arrive for one change; one reload a moment later is enough.
    reloadTask?.cancel()
    reloadTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled, let self else { return }
      self.loadCalendars()
      if let window = self.loadedWindow { self.load(window: window) }
    }
  }

  /// Opens the event in Calendar. The app reads only; editing is Calendar's job.
  func open(eventID: String) {
    if let url = URL(string: "ical://ekevent/\(eventID)") {
      NSWorkspace.shared.open(url)
    }
  }
}
