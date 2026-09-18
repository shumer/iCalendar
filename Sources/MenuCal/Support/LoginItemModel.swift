import Observation
import ServiceManagement

/// Launch at login through `SMAppService`. The system owns the truth, the user can flip it in
/// System Settings at any time, so the state is read back rather than remembered.
@MainActor
@Observable
final class LoginItemModel {
  private(set) var isEnabled = false
  private(set) var needsApproval = false
  private(set) var lastError: String?

  init() {
    refresh()
  }

  func refresh() {
    let status = SMAppService.mainApp.status
    isEnabled = status == .enabled
    needsApproval = status == .requiresApproval
  }

  func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      lastError = nil
    } catch {
      Log.settings.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
      lastError = error.localizedDescription
    }
    refresh()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
