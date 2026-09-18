import SwiftUI

struct GeneralPane: View {
  let loginItem: LoginItemModel

  var body: some View {
    Form {
      Section {
        Toggle(
          L("settings.general.launchAtLogin"),
          isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
        if loginItem.needsApproval {
          LabeledContent {
            Button(L("settings.general.openLoginItems")) { loginItem.openSystemSettings() }
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
      }
    }
    .formStyle(.grouped)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
  }
}
