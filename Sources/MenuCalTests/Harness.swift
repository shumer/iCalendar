import Foundation

/// A small assertion harness. The Command Line Tools ship neither XCTest nor the swift-testing
/// macros, so the suite is a plain executable that exits non-zero when anything fails.
final class TestRun {
  private(set) var passed = 0
  private(set) var failed = 0
  private(set) var failures: [String] = []
  private var currentTest = ""

  func test(_ name: String, _ body: (TestRun) throws -> Void) {
    currentTest = name
    let before = failures.count
    do {
      try body(self)
    } catch {
      failures.append("\(name): threw \(error)")
    }
    if failures.count == before { passed += 1 } else { failed += 1 }
  }

  func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    if !condition() {
      failures.append("\(currentTest) (\(file):\(line)) \(message())")
    }
  }

  func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: @autoclosure () -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    let a = actual()
    let e = expected()
    if a != e {
      failures.append("\(currentTest) (\(file):\(line)) got \(a), expected \(e). \(message())")
    }
  }

  /// Prints the summary and returns the process exit code.
  func finish() -> Int32 {
    for failure in failures {
      FileHandle.standardError.write(Data("FAIL \(failure)\n".utf8))
    }
    print("\(passed) passed, \(failed) failed")
    return failures.isEmpty ? 0 : 1
  }
}

enum Fixtures {
  /// A Gregorian calendar pinned to a time zone, so no test depends on the machine it runs on.
  static func gregorian(_ timeZone: String = "Europe/Warsaw", locale: String = "en_US") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    calendar.locale = Locale(identifier: locale)
    return calendar
  }

  static func date(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0,
    in calendar: Calendar
  ) -> Date {
    let components = DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    return calendar.date(from: components)!
  }
}
