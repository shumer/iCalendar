import Foundation
import MenuCalCore
import Observation

/// Public holidays by country and year: read from a small cache on disk at once, fetched in the
/// background when a list is missing or a month old, never waited for. The panel opens with
/// whatever is known and redraws when more arrives. See docs/adr/0004-public-holidays.md.
@MainActor
@Observable
final class HolidayStore {
  /// Bumped whenever a list arrives, so observers know to rebuild the grid.
  private(set) var revision = 0

  @ObservationIgnored private var entries: [String: HolidayCacheEntry] = [:]
  @ObservationIgnored private var lastAttempt: [String: Date] = [:]
  @ObservationIgnored private var inFlight: Set<String> = []
  @ObservationIgnored private let folder: URL?
  @ObservationIgnored private let session: URLSession

  /// A failed download is not tried again sooner than this.
  private static let retryInterval: TimeInterval = 60 * 60

  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 20
    configuration.httpAdditionalHeaders = ["User-Agent": "MenuCal"]
    session = URLSession(configuration: configuration)

    folder = try? FileManager.default
      .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("MenuCal/Holidays", isDirectory: true)
    loadFromDisk()
  }

  /// The holidays known right now for these years, and a request for the ones that are not.
  func holidays(country: String, years: Set<Int>, prefersLocalNames: Bool) -> HolidayCalendar {
    let now = Date()
    let currentYear = Calendar(identifier: .gregorian).component(.year, from: now)
    var known: [Holiday] = []
    for year in years {
      let key = Self.key(country, year)
      known += entries[key]?.holidays ?? []
      if HolidayPolicy.needsFetch(entries[key], now: now, currentYear: currentYear) {
        fetch(country: country, year: year, now: now)
      }
    }
    return HolidayCalendar(known, prefersLocalNames: prefersLocalNames)
  }

  private func fetch(country: String, year: Int, now: Date) {
    let key = Self.key(country, year)
    if let last = lastAttempt[key], now.timeIntervalSince(last) < Self.retryInterval { return }
    guard !inFlight.contains(key), let url = HolidayFeed.url(country: country, year: year) else { return }
    inFlight.insert(key)
    lastAttempt[key] = now
    Task {
      defer { inFlight.remove(key) }
      do {
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let entry = HolidayCacheEntry(
          country: country, year: year, fetchedAt: Date(),
          holidays: try HolidayFeed.parse(data, year: year))
        let changed = entries[key]?.holidays != entry.holidays
        entries[key] = entry
        save(entry)
        if changed { revision += 1 }
      } catch {
        // A stale list is better than none, and no list only means no red days.
        Log.holidays.error("Holiday list \(key, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  // MARK: Disk

  private static func key(_ country: String, _ year: Int) -> String { "\(country)-\(year)" }

  private func loadFromDisk() {
    guard let folder,
      let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    else { return }
    let decoder = JSONDecoder()
    for file in files where file.pathExtension == "json" {
      guard let data = try? Data(contentsOf: file),
        let entry = try? decoder.decode(HolidayCacheEntry.self, from: data),
        HolidayFeed.supportedCountries.contains(entry.country)
      else { continue }
      entries[Self.key(entry.country, entry.year)] = entry
    }
  }

  private func save(_ entry: HolidayCacheEntry) {
    guard let folder else { return }
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("\(Self.key(entry.country, entry.year)).json")
      try JSONEncoder().encode(entry).write(to: file, options: .atomic)
    } catch {
      Log.holidays.error("Holiday cache was not written: \(error.localizedDescription, privacy: .public)")
    }
  }
}
