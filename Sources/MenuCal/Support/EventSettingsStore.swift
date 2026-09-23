import Foundation
import MenuCalCore
import Observation

/// The user's event groups and which calendars are in them, in one JSON file beside the
/// vacations. The accounts it has seen are kept too, so a new account gets a group of its own
/// once and an old one stays as arranged.
@MainActor
@Observable
final class EventSettingsStore {
  private struct Stored: Codable {
    var settings: EventSettings
    var knownAccountIDs: Set<String>
  }

  private(set) var settings = EventSettings()
  @ObservationIgnored private var knownAccountIDs: Set<String> = []
  @ObservationIgnored private let file: URL?

  init() {
    file = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("MenuCal/events.json")
    if let file, let data = try? Data(contentsOf: file),
      let stored = try? JSONDecoder().decode(Stored.self, from: data)
    {
      settings = stored.settings
      knownAccountIDs = stored.knownAccountIDs
    }
  }

  func adopt(accounts: [CalendarAccount], calendars: [CalendarInfo]) {
    update { $0.adopt(accounts: accounts, calendars: calendars, knownAccountIDs: &knownAccountIDs) }
  }

  func update(_ change: (inout EventSettings) -> Void) {
    var next = settings
    change(&next)
    guard next != settings else {
      save()
      return
    }
    settings = next
    save()
  }

  private func save() {
    guard let file else { return }
    do {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(Stored(settings: settings, knownAccountIDs: knownAccountIDs)).write(to: file, options: .atomic)
    } catch {
      Log.events.error("Event settings were not written: \(error.localizedDescription, privacy: .public)")
    }
  }
}
