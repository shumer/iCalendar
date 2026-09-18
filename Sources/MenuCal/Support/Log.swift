import os

/// One logger per area, so Console can be filtered by category.
enum Log {
  private static let subsystem = "com.shumenko.menucal"

  static let app = Logger(subsystem: subsystem, category: "app")
  static let statusItem = Logger(subsystem: subsystem, category: "status-item")
  static let panel = Logger(subsystem: subsystem, category: "panel")
  static let settings = Logger(subsystem: subsystem, category: "settings")
  static let updates = Logger(subsystem: subsystem, category: "updates")
  static let holidays = Logger(subsystem: subsystem, category: "holidays")
}
