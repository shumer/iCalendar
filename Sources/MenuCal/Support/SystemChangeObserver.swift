import AppKit

/// Everything outside the app that can change what a date looks like or which day it is: the
/// locale, the region, the time zone, the clock, midnight, and waking from a sleep that may have
/// lasted days. One observer fans out to whoever shows dates, so nothing needs a restart.
@MainActor
final class SystemChangeObserver {
  private let onChange: () -> Void

  init(onChange: @escaping () -> Void) {
    self.onChange = onChange
    let handler: @Sendable (Notification) -> Void = { [weak self] _ in
      MainActor.assumeIsolated { self?.onChange() }
    }
    let center = NotificationCenter.default
    for name in [
      NSLocale.currentLocaleDidChangeNotification,
      .NSSystemTimeZoneDidChange,
      .NSSystemClockDidChange,
      .NSCalendarDayChanged,
    ] {
      center.addObserver(forName: name, object: nil, queue: .main, using: handler)
    }
    // A timer set before a long sleep fires late or not at all, so waking refreshes by hand.
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: handler)
  }
}
