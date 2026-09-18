import Foundation
import MenuCalCore

func updatesTests(_ run: TestRun) {
  func feed(tag: String = "v1.4", draft: Bool = false, prerelease: Bool = false, assets: String) -> Data {
    Data("""
      {"tag_name": "\(tag)", "draft": \(draft), "prerelease": \(prerelease),
       "html_url": "https://github.com/shumer/iCalendar/releases/tag/\(tag)",
       "assets": [\(assets)]}
      """.utf8)
  }
  let goodAsset = """
    {"name": "MenuCal-1.4-57.zip", "size": 1234567,
     "browser_download_url": "https://github.com/shumer/iCalendar/releases/download/v1.4/MenuCal-1.4-57.zip"}
    """

  run.test("versions parse with or without a v and ignore trailing zeros") { t in
    t.expectEqual(AppVersion("v1.4"), AppVersion("1.4.0"))
    t.expectEqual(AppVersion(" 2 ")?.description, "2")
    t.expectEqual(AppVersion("0.1")?.components, [0, 1])
    for bad in ["", "v", "1..2", "1.x", "1.4-beta", "1.2.3.4.5", "١.٢", "-1"] {
      t.expect(AppVersion(bad) == nil, bad)
    }
  }

  run.test("versions compare numerically, not as text") { t in
    t.expect(AppVersion("1.10")! > AppVersion("1.9")!)
    t.expect(AppVersion("1.4.1")! > AppVersion("1.4")!)
    t.expect(AppVersion("2")! > AppVersion("1.99.99")!)
    t.expect(!(AppVersion("1.4")! < AppVersion("1.4.0")!))
  }

  run.test("a release with its build attached is read") { t in
    let release = try ReleaseFeed.parse(feed(assets: goodAsset))
    t.expectEqual(release.version, AppVersion("1.4"))
    t.expectEqual(release.asset?.name, "MenuCal-1.4-57.zip")
    t.expectEqual(release.asset?.size, 1_234_567)
    t.expect(UpdatePolicy.isNewer(release, than: AppVersion("1.3")!))
    t.expect(!UpdatePolicy.isNewer(release, than: AppVersion("1.4")!))
    t.expect(!UpdatePolicy.isNewer(release, than: AppVersion("2.0")!))
  }

  run.test("a release without a build yet is a release with no asset") { t in
    let release = try ReleaseFeed.parse(feed(assets: ""))
    t.expectEqual(release.asset, nil)
  }

  run.test("an asset outside this repository's releases is not an update") { t in
    let elsewhere = [
      "https://evil.example/shumer/iCalendar/releases/download/v1.4/MenuCal-1.4-57.zip",
      "http://github.com/shumer/iCalendar/releases/download/v1.4/MenuCal-1.4-57.zip",
      "https://github.com/someone/else/releases/download/v1.4/MenuCal-1.4-57.zip",
      "https://github.com/shumer/iCalendar/releases/download/../../../evil/MenuCal-1.4-57.zip",
      "https://github.com.evil.example/shumer/iCalendar/releases/download/v1.4/MenuCal-1.4-57.zip",
    ]
    for url in elsewhere {
      let asset = "{\"name\": \"MenuCal-1.4-57.zip\", \"size\": 1, \"browser_download_url\": \"\(url)\"}"
      let release = try ReleaseFeed.parse(feed(assets: asset))
      t.expectEqual(release.asset, nil, url)
    }
  }

  run.test("only the app's own zip is picked among the assets") { t in
    let others = """
      {"name": "MenuCal-1.4.dmg", "size": 1, "browser_download_url": "https://github.com/shumer/iCalendar/releases/download/v1.4/MenuCal-1.4.dmg"},
      {"name": "Source.zip", "size": 1, "browser_download_url": "https://github.com/shumer/iCalendar/releases/download/v1.4/Source.zip"},
      """
    let release = try ReleaseFeed.parse(feed(assets: others + goodAsset))
    t.expectEqual(release.asset?.name, "MenuCal-1.4-57.zip")
  }

  run.test("drafts, prereleases and nonsense are refused") { t in
    func error(_ data: Data) -> ReleaseFeedError? {
      do { _ = try ReleaseFeed.parse(data); return nil } catch { return error as? ReleaseFeedError }
    }
    t.expectEqual(error(feed(draft: true, assets: goodAsset)), .notARelease)
    t.expectEqual(error(feed(prerelease: true, assets: goodAsset)), .notARelease)
    t.expectEqual(error(feed(tag: "nightly", assets: goodAsset)), .malformed)
    t.expectEqual(error(Data("not json".utf8)), .malformed)
    t.expectEqual(error(Data("{\"message\": \"Not Found\"}".utf8)), .malformed)
  }

  run.test("an automatic check is due once a day") { t in
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    t.expect(UpdatePolicy.isCheckDue(lastCheck: nil, now: now))
    t.expect(!UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-3600), now: now))
    t.expect(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-90_000), now: now))
    t.expect(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(500), now: now), "a check from the future is no check")
  }
}
