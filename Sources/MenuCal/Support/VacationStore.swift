import Foundation
import MenuCalCore
import Observation

/// The user's vacations, kept in one JSON file under Application Support and written on every
/// change. Nothing leaves the Mac.
@MainActor
@Observable
final class VacationStore {
  private(set) var list = VacationList()
  @ObservationIgnored private let file: URL?

  init() {
    file = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("MenuCal/vacation.json")
    if let file, let data = try? Data(contentsOf: file),
      let stored = try? JSONDecoder().decode(VacationList.self, from: data)
    {
      list = stored
    }
  }

  func add(from start: Date, to end: Date, calendar: Calendar) {
    update { $0.add(VacationRange(startKey: key(start, calendar), endKey: key(end, calendar)), calendar: calendar) }
  }

  func remove(from start: Date, to end: Date, calendar: Calendar) {
    update { $0.remove(VacationRange(startKey: key(start, calendar), endKey: key(end, calendar)), calendar: calendar) }
  }

  func delete(id: UUID) { update { $0.delete(id: id) } }
  func rename(id: UUID, to name: String) { update { $0.rename(id: id, to: name) } }

  /// True when every day from `start` to `end` is a vacation already.
  func covers(from start: Date, to end: Date, calendar: Calendar) -> Bool {
    var cursor = calendar.startOfDay(for: start)
    let last = calendar.startOfDay(for: end)
    while cursor <= last {
      guard list.range(containing: key(cursor, calendar)) != nil else { return false }
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }
    return true
  }

  private func key(_ date: Date, _ calendar: Calendar) -> Int {
    VacationCalendar.key(for: date, calendar: calendar)
  }

  private func update(_ change: (inout VacationList) -> Void) {
    var next = list
    change(&next)
    guard next != list else { return }
    list = next
    guard let file else { return }
    do {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(next).write(to: file, options: .atomic)
    } catch {
      Log.app.error("Vacation list was not written: \(error.localizedDescription, privacy: .public)")
    }
  }
}
