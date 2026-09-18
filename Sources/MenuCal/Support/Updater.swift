import AppKit
import MenuCalCore
import Observation
import Security

/// Updates the app from its GitHub releases, the way its sibling DevDeck does; the reasons are
/// in docs/adr/0002-no-third-party-dependencies.md. What is trusted is not the feed and not the
/// download but the signature: a downloaded app replaces this one only when it is signed by the
/// same team, carries the same bundle identifier and is a newer version.
@MainActor
@Observable
final class Updater {
  enum Phase: Equatable {
    case idle
    case checking
    case upToDate
    case available(ReleaseInfo)
    case downloading(ReleaseInfo)
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  let currentVersion: AppVersion

  @ObservationIgnored private let preferences: Preferences
  @ObservationIgnored private var timer: Timer?
  @ObservationIgnored private let session: URLSession

  init(preferences: Preferences) {
    self.preferences = preferences
    let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    currentVersion = short.flatMap(AppVersion.init) ?? AppVersion("0")!
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 20
    configuration.httpAdditionalHeaders = [
      "Accept": "application/vnd.github+json",
      "User-Agent": "MenuCal/\(currentVersion)",
    ]
    session = URLSession(configuration: configuration)
  }

  var availableRelease: ReleaseInfo? {
    switch phase {
    case .available(let release), .downloading(let release): release
    default: nil
    }
  }

  var isBusy: Bool {
    switch phase {
    case .checking, .downloading: true
    default: false
    }
  }

  /// A bundle that macOS runs from a randomised read only path, or one in a folder this user
  /// cannot write to, cannot replace itself. The release page is opened instead.
  var canInstallInPlace: Bool {
    let bundle = Bundle.main.bundleURL
    guard bundle.pathExtension == "app", !bundle.path.contains("/AppTranslocation/") else { return false }
    return FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
  }

  // MARK: Checking

  /// Starts the automatic checks. The timer only asks whether a check is due, a few times a day
  /// with a generous tolerance, so it costs nothing measurable.
  func start() {
    checkIfDue()
    let timer = Timer(timeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.checkIfDue() }
    }
    timer.tolerance = 30 * 60
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func checkIfDue() {
    guard preferences.checksForUpdatesAutomatically, !isBusy,
      UpdatePolicy.isCheckDue(lastCheck: preferences.lastUpdateCheck, now: Date())
    else { return }
    Task { await check(userInitiated: false) }
  }

  func check(userInitiated: Bool) async {
    guard !isBusy else { return }
    let previous = phase
    phase = .checking
    do {
      let (data, response) = try await session.data(from: ReleaseFeed.latestReleaseURL)
      let status = (response as? HTTPURLResponse)?.statusCode
      preferences.lastUpdateCheck = Date()
      // GitHub answers 404 while a repository has no release at all, which is not a failure.
      if status == 404 {
        phase = .upToDate
        return
      }
      guard status == 200 else { throw URLError(.badServerResponse) }
      let release = try ReleaseFeed.parse(data)
      if UpdatePolicy.isNewer(release, than: currentVersion) {
        phase = .available(release)
        Log.updates.info("Update available: \(release.version.description, privacy: .public)")
      } else {
        phase = .upToDate
      }
    } catch {
      Log.updates.error("Update check failed: \(error.localizedDescription, privacy: .public)")
      // A failed background check keeps whatever was known before and says nothing.
      if userInitiated {
        phase = .failed(L("updates.error.check"))
      } else if case .available = previous {
        phase = previous
      } else {
        phase = .idle
      }
    }
  }

  // MARK: Installing

  func install() async {
    guard case .available(let release) = phase else { return }
    guard canInstallInPlace, let asset = release.asset else {
      NSWorkspace.shared.open(release.pageURL)
      return
    }
    phase = .downloading(release)
    do {
      let (downloaded, _) = try await session.download(from: asset.downloadURL)
      let installed = try await Self.verifyAndInstall(
        archive: downloaded, expectedSize: asset.size, over: Bundle.main.bundleURL,
        newerThan: currentVersion)
      Log.updates.info("Installed \(release.version.description, privacy: .public), relaunching")
      Self.relaunch(installed)
    } catch let error as InstallError {
      Log.updates.error("Update refused: \(String(describing: error), privacy: .public)")
      phase = .failed(error == .untrusted ? L("updates.error.untrusted") : L("updates.error.install"))
    } catch {
      Log.updates.error("Update failed: \(error.localizedDescription, privacy: .public)")
      phase = .failed(L("updates.error.install"))
    }
  }

  enum InstallError: Error, Equatable {
    case badArchive
    case untrusted
    case notNewer
  }

  /// Everything that touches the disk, off the main actor. Returns the bundle to relaunch.
  private nonisolated static func verifyAndInstall(
    archive: URL, expectedSize: Int, over bundle: URL, newerThan current: AppVersion
  ) async throws -> URL {
    let files = FileManager.default
    let size = (try files.attributesOfItem(atPath: archive.path)[.size] as? Int) ?? 0
    guard size > 0, size < 200 * 1024 * 1024, expectedSize == 0 || size == expectedSize else {
      throw InstallError.badArchive
    }

    // A scratch folder on the bundle's own volume, so the final swap is a rename and not a copy.
    let scratch = try files.url(
      for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: bundle, create: true)
    defer { try? files.removeItem(at: scratch) }

    let unzip = Process()
    unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    unzip.arguments = ["-x", "-k", archive.path, scratch.path]
    try unzip.run()
    unzip.waitUntilExit()
    let candidate = scratch.appendingPathComponent(bundle.lastPathComponent)
    guard unzip.terminationStatus == 0, files.fileExists(atPath: candidate.path) else {
      throw InstallError.badArchive
    }

    try verifySignature(of: candidate)
    let plist = NSDictionary(contentsOf: candidate.appendingPathComponent("Contents/Info.plist"))
    guard let text = plist?["CFBundleShortVersionString"] as? String, let version = AppVersion(text),
      version > current
    else { throw InstallError.notNewer }

    _ = try files.replaceItemAt(bundle, withItemAt: candidate)
    return bundle
  }

  /// The downloaded app must satisfy a requirement built from this app's own signature: the same
  /// bundle identifier, and when this build has a Developer ID, the same team under Apple's
  /// anchor. An ad-hoc build has no team to compare, so only the identifier and the integrity of
  /// the bundle are checked; such builds are for development.
  private nonisolated static func verifySignature(of candidate: URL) throws {
    let identifier = Bundle.main.bundleIdentifier ?? "com.shumenko.menucal"
    var text = "identifier \"\(identifier)\""
    if let team = ownTeamIdentifier() {
      text += " and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
    }
    var requirement: SecRequirement?
    var code: SecStaticCode?
    guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
      SecStaticCodeCreateWithPath(candidate as CFURL, [], &code) == errSecSuccess,
      let requirement, let code
    else { throw InstallError.untrusted }
    let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
    guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else {
      throw InstallError.untrusted
    }
  }

  private nonisolated static func ownTeamIdentifier() -> String? {
    var selfCode: SecCode?
    var staticCode: SecStaticCode?
    var information: CFDictionary?
    guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
      SecCodeCopyStaticCode(selfCode, [], &staticCode) == errSecSuccess, let staticCode,
      SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
        == errSecSuccess
    else { return nil }
    return (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
  }

  /// The new copy is opened by a detached shell a moment after this process is gone, because
  /// LaunchServices will not start a second instance of an agent that is still running.
  private static func relaunch(_ bundle: URL) {
    let launcher = Process()
    launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
    launcher.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", bundle.path]
    try? launcher.run()
    NSApp.terminate(nil)
  }
}
