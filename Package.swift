// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MenuCal",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MenuCal", targets: ["MenuCal"]),
    .library(name: "MenuCalCore", targets: ["MenuCalCore"]),
  ],
  targets: [
    // Everything that can be tested without a window server: calendar maths, formatting,
    // preferences. No AppKit views in here.
    .target(name: "MenuCalCore"),
    .executableTarget(name: "MenuCal", dependencies: ["MenuCalCore"]),
    // The suite is an executable because the Command Line Tools ship neither XCTest nor the
    // swift-testing macros. See docs/adr/0001-spm-only-toolchain.md.
    .executableTarget(name: "MenuCalTests", dependencies: ["MenuCalCore"]),
  ],
  swiftLanguageModes: [.v6]
)
