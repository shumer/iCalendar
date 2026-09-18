import AppKit
import SwiftUI

struct AboutPane: View {
  let updater: Updater

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

      Divider().padding(.vertical, 4)

      VStack(spacing: 8) {
        if let release = updater.availableRelease {
          Button(L("menu.updateTo", release.version.description)) {
            Task { await updater.install() }
          }
          .buttonStyle(.borderedProminent)
          .disabled(updater.isBusy)
        } else {
          Button(L("menu.checkForUpdates")) {
            Task { await updater.check(userInitiated: true) }
          }
          .disabled(updater.isBusy)
        }
        HStack(spacing: 6) {
          if updater.isBusy {
            ProgressView().controlSize(.small)
          }
          Text(status)
            .font(.callout)
            .foregroundStyle(isFailure ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            .multilineTextAlignment(.center)
        }
        .frame(minHeight: 18)
      }
    }
    .padding(.vertical, 28)
    .padding(.horizontal, 40)
    .frame(width: 520)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var isFailure: Bool {
    if case .failed = updater.phase { return true }
    return false
  }

  private var status: String {
    switch updater.phase {
    case .idle: ""
    case .checking: L("updates.checking")
    case .upToDate: L("updates.upToDate")
    case .available(let release):
      updater.canInstallInPlace && release.asset != nil
        ? L("updates.available", release.version.description) : L("updates.availableManual")
    case .downloading: L("updates.downloading")
    case .failed(let message): message
    }
  }

  private static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
  }

  private static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
  }
}
