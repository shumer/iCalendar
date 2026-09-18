import Foundation

/// A dotted numeric version. "v1.4", "1.4" and "1.4.0" are the same version.
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
  public let components: [Int]

  public init?(_ text: String) {
    var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.first == "v" || trimmed.first == "V" { trimmed.removeFirst() }
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty, parts.count <= 4 else { return nil }
    var numbers: [Int] = []
    for part in parts {
      guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber), let number = Int(part)
      else { return nil }
      numbers.append(number)
    }
    while numbers.count > 1, numbers.last == 0 { numbers.removeLast() }
    components = numbers
  }

  public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    for index in 0..<max(lhs.components.count, rhs.components.count) {
      let left = index < lhs.components.count ? lhs.components[index] : 0
      let right = index < rhs.components.count ? rhs.components[index] : 0
      if left != right { return left < right }
    }
    return false
  }

  public var description: String { components.map(String.init).joined(separator: ".") }
}

public struct ReleaseAsset: Equatable, Sendable {
  public let name: String
  public let downloadURL: URL
  public let size: Int
}

public struct ReleaseInfo: Equatable, Sendable {
  public let version: AppVersion
  public let tag: String
  public let pageURL: URL
  /// The zip the updater installs. Nil when the release has none yet, which is the case for the
  /// minutes between publishing a release and the workflow attaching its build.
  public let asset: ReleaseAsset?
}

public enum ReleaseFeedError: Error, Equatable, Sendable {
  case malformed
  case notARelease
}

/// Reads the answer of GitHub's "latest release" endpoint and trusts as little of it as it can.
public enum ReleaseFeed {
  /// Where updates come from. An asset anywhere else is not an update, whatever the feed says.
  public static let repositoryPath = "/shumer/iCalendar"
  public static let latestReleaseURL = URL(string: "https://api.github.com/repos/shumer/iCalendar/releases/latest")!

  public static func parse(_ data: Data) throws -> ReleaseInfo {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let tag = object["tag_name"] as? String
    else { throw ReleaseFeedError.malformed }
    if object["draft"] as? Bool == true || object["prerelease"] as? Bool == true {
      throw ReleaseFeedError.notARelease
    }
    guard let version = AppVersion(tag),
      let page = (object["html_url"] as? String).flatMap(URL.init(string:)),
      isTrusted(page, under: repositoryPath + "/releases/")
    else { throw ReleaseFeedError.malformed }

    let assets = (object["assets"] as? [[String: Any]] ?? []).compactMap { entry -> ReleaseAsset? in
      guard let name = entry["name"] as? String, name.hasPrefix("MenuCal-"), name.hasSuffix(".zip"),
        let url = (entry["browser_download_url"] as? String).flatMap(URL.init(string:)),
        isTrusted(url, under: repositoryPath + "/releases/download/")
      else { return nil }
      return ReleaseAsset(name: name, downloadURL: url, size: entry["size"] as? Int ?? 0)
    }
    return ReleaseInfo(version: version, tag: tag, pageURL: page, asset: assets.first)
  }

  /// HTTPS, github.com itself, and inside this repository's releases.
  static func isTrusted(_ url: URL, under pathPrefix: String) -> Bool {
    url.scheme == "https" && url.host == "github.com" && url.path.hasPrefix(pathPrefix)
      && !url.path.contains("..")
  }
}

public enum UpdatePolicy {
  public static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

  public static func isNewer(_ release: ReleaseInfo, than current: AppVersion) -> Bool {
    release.version > current
  }

  /// An automatic check is due once a day. A last check in the future, from a clock that was
  /// wrong, counts as none at all.
  public static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
    guard let lastCheck, lastCheck <= now else { return true }
    return now.timeIntervalSince(lastCheck) >= automaticCheckInterval
  }
}
