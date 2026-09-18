import MenuCalCore
import SwiftUI

struct GeneralPane: View {
  let preferences: Preferences
  let format: FormatEditorModel
  let hotkey: HotkeyRecorderModel
  let loginItem: LoginItemModel

  var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section(L("settings.format.section")) {
        LabeledContent(L("settings.format.presets")) {
          FlowLayout {
            ForEach(FormatPreset.allCases, id: \.self) { preset in
              Toggle(
                presetTitle(preset),
                isOn: Binding(get: { format.selectedPreset == preset }, set: { _ in format.choose(preset) }))
              .toggleStyle(.button)
              .controlSize(.small)
            }
          }
          .frame(maxWidth: 300, alignment: .trailing)
        }

        TextField(
          L("settings.format.pattern"),
          text: Binding(get: { format.text }, set: { format.edit($0) }))
        .font(.system(.body, design: .monospaced))
        .autocorrectionDisabled()
        .overlay(alignment: .trailing) {
          if format.error != nil {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundStyle(.red)
              .padding(.trailing, -18)
              .accessibilityHidden(true)
          }
        }

        LabeledContent(L("settings.format.preview")) {
          MenuBarPreview(text: format.preview, icon: preferences.menuBarIcon)
        }

        if let message = format.errorMessage {
          Text(message + " " + L("settings.format.error.keeps"))
            .font(.callout)
            .foregroundStyle(.red)
        }

        LabeledContent {
          Button(L("settings.format.openClock")) { format.openClockSettings() }
            .controlSize(.small)
        } label: {
          Text(L("settings.format.clockHint"))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        Picker(L("settings.icon"), selection: $preferences.menuBarIcon) {
          Text(L("settings.icon.none")).tag(MenuBarIcon.none)
          Text(L("settings.icon.calendar")).tag(MenuBarIcon.calendar)
          Text(L("settings.icon.dayNumber")).tag(MenuBarIcon.dayNumber)
        }
        .pickerStyle(.segmented)

        Toggle(
          L("settings.general.launchAtLogin"),
          isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
        if loginItem.needsApproval {
          LabeledContent {
            Button(L("settings.general.openLoginItems")) { loginItem.openSystemSettings() }
              .controlSize(.small)
          } label: {
            Text(L("settings.general.needsApproval"))
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        if let error = loginItem.lastError {
          Text(error)
            .font(.callout)
            .foregroundStyle(.red)
        }

        LabeledContent(L("settings.hotkey")) {
          HStack(spacing: 6) {
            Button(hotkey.title) { hotkey.toggleRecording() }
              .frame(minWidth: 130)
            if hotkey.hotkey != nil, !hotkey.isRecording {
              Button {
                hotkey.clear()
              } label: {
                Image(systemName: "xmark.circle.fill")
              }
              .buttonStyle(.borderless)
              .accessibilityLabel(L("settings.hotkey.clear"))
              .help(L("settings.hotkey.clear"))
            }
          }
        }
        if hotkey.wasRefused {
          Text(L("settings.hotkey.refused"))
            .font(.callout)
            .foregroundStyle(.red)
        }
      }

      Section {
        Toggle(L("settings.updates.automatic"), isOn: $preferences.checksForUpdatesAutomatically)
      }
    }
    .formStyle(.grouped)
    .frame(width: 520)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func presetTitle(_ preset: FormatPreset) -> String {
    switch preset {
    case .dateOnly: L("settings.format.preset.dateOnly")
    case .dateAndWeekday: L("settings.format.preset.dateAndWeekday")
    case .dateAndTime: L("settings.format.preset.dateAndTime")
    case .compact: L("settings.format.preset.compact")
    case .full: L("settings.format.preset.full")
    }
  }
}

/// The status item as it will look, in the menu bar's own font.
private struct MenuBarPreview: View {
  let text: String
  let icon: MenuBarIcon

  var body: some View {
    HStack(spacing: Tokens.MenuBar.iconTextGap) {
      if let image = MenuBarIconRenderer.image(for: icon, dayNumber: Self.dayNumber) {
        Image(nsImage: image)
      }
      Text(text)
        .font(Font(Tokens.MenuBar.font))
        .lineLimit(1)
        .contentTransition(.opacity)
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, 8)
    .frame(height: 24)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private static var dayNumber: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter.string(from: Date())
  }
}
