import AppKit
import SwiftUI

struct AboutPane: View {
  static let sourceURL = URL(string: "https://github.com/shumer/iCalendar")!

  var body: some View {
    VStack(spacing: 12) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
      VStack(spacing: 4) {
        Text("MenuCal")
          .font(.title2.weight(.semibold))
        Text(L("settings.about.version", Self.version, Self.build))
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
      Text(L("settings.about.tagline"))
        .font(.callout)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Link(L("settings.about.source"), destination: Self.sourceURL)
        .font(.callout)
    }
    .padding(.vertical, 28)
    .padding(.horizontal, 40)
    .frame(width: 520)
    .fixedSize(horizontal: false, vertical: true)
  }

  private static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
  }

  private static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
  }
}
