import Foundation

/// The string tables are resources, not code, so nothing but a test notices a key that exists in
/// one language only, or a key the code asks for that no table has.
func localizationTests(_ run: TestRun) {
  let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let tablesFolder = root.appendingPathComponent("Resources/Localizations")
  let languages = ["en", "ru", "uk", "pl"]

  func table(_ language: String) -> [String: String] {
    let url = tablesFolder.appendingPathComponent("\(language).lproj/Localizable.strings")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
    return (try? PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil)) as? [String: String] ?? [:]
  }

  /// The `%@` and `%d` of a format string, in order.
  func specifiers(_ value: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: "%(\\d+\\$)?[@dfs]")
    let range = NSRange(value.startIndex..., in: value)
    return pattern.matches(in: value, range: range).map { String(value[Range($0.range, in: value)!]) }
  }

  func keysUsedInSources() -> Set<String> {
    let sources = root.appendingPathComponent("Sources/MenuCal")
    let pattern = try! NSRegularExpression(pattern: "\\bL\\(\\s*\"([^\"]+)\"")
    var keys: Set<String> = []
    let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
    while let file = files?.nextObject() as? URL {
      guard file.pathExtension == "swift", let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
      let range = NSRange(text.startIndex..., in: text)
      for match in pattern.matches(in: text, range: range) {
        keys.insert(String(text[Range(match.range(at: 1), in: text)!]))
      }
    }
    return keys
  }

  let english = table("en")

  run.test("every language has a table that parses") { t in
    for language in languages {
      t.expect(!table(language).isEmpty, language)
    }
  }

  run.test("every table has exactly the English keys") { t in
    for language in languages.dropFirst() {
      let other = Set(table(language).keys)
      let missing = Set(english.keys).subtracting(other).sorted()
      let extra = other.subtracting(english.keys).sorted()
      t.expect(missing.isEmpty, "\(language) lacks \(missing)")
      t.expect(extra.isEmpty, "\(language) has keys English does not: \(extra)")
    }
  }

  run.test("format specifiers agree across languages") { t in
    for language in languages.dropFirst() {
      let other = table(language)
      for (key, value) in english {
        t.expectEqual(specifiers(other[key] ?? ""), specifiers(value), "\(language) \(key)")
      }
    }
  }

  run.test("no translation is empty") { t in
    for language in languages {
      let empty = table(language).filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()
      t.expect(empty.isEmpty, "\(language): \(empty)")
    }
  }

  run.test("the sources and the tables name the same keys") { t in
    let used = keysUsedInSources()
    t.expect(!used.isEmpty, "the sweep found no L(\"...\") call at all")
    let unknown = used.subtracting(english.keys).sorted()
    let unused = Set(english.keys).subtracting(used).sorted()
    t.expect(unknown.isEmpty, "the code asks for keys no table has: \(unknown)")
    t.expect(unused.isEmpty, "the tables carry keys the code never asks for: \(unused)")
  }

  run.test("no table uses a typographic dash") { t in
    for language in languages {
      let offenders = table(language).filter { $0.value.contains("\u{2014}") || $0.value.contains("\u{2013}") }.keys.sorted()
      t.expect(offenders.isEmpty, "\(language): \(offenders)")
    }
  }
}
