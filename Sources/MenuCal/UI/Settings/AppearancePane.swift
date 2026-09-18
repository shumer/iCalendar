import AppKit
import MenuCalCore
import SwiftUI

struct AppearancePane: View {
  let preferences: Preferences

  var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section {
        Picker(L("settings.appearance.theme"), selection: $preferences.appearance) {
          Text(L("settings.appearance.theme.system")).tag(AppearancePreference.system)
          Text(L("settings.appearance.theme.light")).tag(AppearancePreference.light)
          Text(L("settings.appearance.theme.dark")).tag(AppearancePreference.dark)
        }
        .pickerStyle(.segmented)

        Picker(L("settings.appearance.accent"), selection: $preferences.usesCustomAccent) {
          Text(L("settings.appearance.accent.system")).tag(false)
          Text(L("settings.appearance.accent.custom")).tag(true)
        }
        if preferences.usesCustomAccent {
          ColorPicker(
            L("settings.appearance.accent.color"),
            selection: Binding(get: { color }, set: { store($0) }),
            supportsOpacity: false)
        }
      }
      Section {
        Picker(L("settings.appearance.density"), selection: $preferences.density) {
          Text(L("settings.appearance.density.regular")).tag(Density.regular)
          Text(L("settings.appearance.density.compact")).tag(Density.compact)
        }
        .pickerStyle(.segmented)
      }
    }
    .formStyle(.grouped)
    .frame(width: 520)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var color: Color {
    let custom = preferences.customAccent
    return Color(.sRGB, red: custom.red, green: custom.green, blue: custom.blue)
  }

  private func store(_ color: Color) {
    guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
    preferences.customAccent = AccentComponents(
      red: Double(converted.redComponent), green: Double(converted.greenComponent),
      blue: Double(converted.blueComponent))
  }
}
