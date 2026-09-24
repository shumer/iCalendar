import MenuCalCore
import SwiftUI

/// The fifth pane, laid out as in the designer's section 5: access, then the groups as a list
/// of name and source lines with "Edit…" opening a sheet, marks in the grid, and the vacations
/// as a table. The pane has a fixed height and the form scrolls inside it.
struct EventsPane: View {
  let events: EventStore
  let store: EventSettingsStore
  let vacations: VacationStore
  let preferences: Preferences
  let sheets: EventsPaneModel

  static let height: CGFloat = 600

  var body: some View {
    let settings = store.settings
    @Bindable var preferences = preferences
    Form {
      Section {
        Toggle(L("settings.events.toggle"), isOn: Binding(get: { settings.isEnabled }, set: { value in store.update { $0.isEnabled = value } }))
        accessRow
      } footer: {
        Text(L("settings.events.note"))
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if events.access == .granted {
        Section {
          ForEach(settings.groups) { group in
            groupRow(group)
          }
          HStack(spacing: 12) {
            Button {
              store.update { _ = $0.addGroup(named: L("settings.events.newGroup")) }
              if let last = store.settings.groups.last { sheets.editingGroupID = last.id }
            } label: {
              Image(systemName: "plus")
            }
            .disabled(settings.groups.count >= EventGroup.maximumCount)
            .accessibilityLabel(L("settings.events.addGroup"))
            Spacer()
          }
          .buttonStyle(.borderless)
          .controlSize(.small)
        } header: {
          Text(L("settings.events.groups"))
        } footer: {
          Text(L("settings.events.groups.note"))
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(!settings.isEnabled)

        Section(L("settings.events.marks")) {
          Picker(L("settings.events.marks.style"), selection: Binding(get: { settings.showsDots }, set: { value in store.update { $0.showsDots = value } })) {
            Text(L("settings.events.marks.dots")).tag(true)
            Text(L("settings.events.marks.none")).tag(false)
          }
          .pickerStyle(.segmented)
          Toggle(isOn: Binding(get: { settings.showsDotsInAdjacentMonths }, set: { value in store.update { $0.showsDotsInAdjacentMonths = value } })) {
            Text(L("settings.events.marks.adjacent"))
            Text(L("settings.events.marks.adjacent.sub"))
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .disabled(!settings.showsDots)
        }
        .disabled(!settings.isEnabled)
      }

      Section {
        Toggle(L("settings.vacation.toggle"), isOn: $preferences.showsVacation)
        VacationTable(vacations: vacations, sheets: sheets)
          .disabled(!preferences.showsVacation)
      } header: {
        Text(L("vacation.title"))
      } footer: {
        Text(L("settings.vacation.note"))
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: Self.height)
    .sheet(item: Binding(get: { sheets.editingGroupID.map(GroupSheetItem.init) }, set: { sheets.editingGroupID = $0?.id })) { item in
      GroupEditorSheet(groupID: item.id, events: events, store: store)
    }
    .sheet(isPresented: Binding(get: { sheets.isAddingVacation }, set: { sheets.isAddingVacation = $0 })) {
      VacationAddSheet(vacations: vacations, sheets: sheets)
    }
  }

  @ViewBuilder
  private var accessRow: some View {
    switch events.access {
    case .granted:
      LabeledContent {
        Button(L("settings.events.access.openPrivacy")) { events.openPrivacySettings() }
          .controlSize(.small)
      } label: {
        Text(L("settings.events.access"))
        Text(L("settings.events.access.granted.sub"))
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    case .undetermined:
      LabeledContent {
        Button(L("settings.events.access.request")) { events.requestAccess() }
          .controlSize(.small)
      } label: {
        Text(L("settings.events.access"))
        Text(L("settings.events.access.undetermined"))
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    case .denied, .restricted:
      LabeledContent {
        Button(L("settings.events.access.openPrivacy")) { events.openPrivacySettings() }
          .controlSize(.small)
      } label: {
        Text(L("settings.events.access"))
        Text(L("settings.events.access.denied"))
          .font(.callout)
          .foregroundStyle(.red)
      }
    }
  }

  /// A colour well, the name over its sources, where it shows, Edit; and under it the group's
  /// calendars with a tick each, so that keeping one calendar out of an account is one click and
  /// not a trip into the sheet.
  private func groupRow(_ group: EventGroup) -> some View {
    let settings = store.settings
    let members = group.calendarIDs.compactMap { events.calendarsByID[$0] }
    return DisclosureGroup(
      isExpanded: Binding(get: { !sheets.collapsedGroupIDs.contains(group.id) }, set: { expanded in
        if expanded { sheets.collapsedGroupIDs.remove(group.id) } else { sheets.collapsedGroupIDs.insert(group.id) }
      })
    ) {
      ForEach(members) { calendar in
        Toggle(isOn: Binding(get: { !settings.hiddenCalendarIDs.contains(calendar.id) }, set: { on in
          store.update { $0.setVisible(calendar.id, on) }
        })) {
          HStack(spacing: 6) {
            Circle()
              .fill(Color(.sRGB, red: calendar.color.red, green: calendar.color.green, blue: calendar.color.blue))
              .frame(width: 8, height: 8)
            Text(calendar.title)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
        .toggleStyle(.checkbox)
        .padding(.leading, 26)
        // A form centres a lone control in its row; these are a list and read from the left.
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      if members.isEmpty {
        Text(L("settings.events.noCalendars"))
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.leading, 26)
      }
    } label: {
      HStack(spacing: 10) {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Palette.group(group.paletteIndex))
          .frame(width: 16, height: 16)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 1) {
          Text(group.name.isEmpty ? L("settings.events.newGroup") : group.name)
          Text(sourcesLine(group, members: members, settings: settings))
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        // The line is cut in the middle when the account is an address; the tooltip has it whole.
        .help(group.name + "\n" + sourcesLine(group, members: members, settings: settings))
        Spacer(minLength: 12)
        VisibilityPicker(group: group, store: store)
          .fixedSize()
        Button(L("settings.events.edit")) { sheets.editingGroupID = group.id }
          .controlSize(.small)
      }
    }
  }

  /// "Google · 2 of 5 calendars", or the one calendar's name.
  private func sourcesLine(_ group: EventGroup, members: [CalendarInfo], settings: EventSettings) -> String {
    guard !members.isEmpty else { return L("settings.events.noCalendars") }
    let accountTitles = Set(members.map(\.accountID)).compactMap { id in events.accounts.first { $0.id == id }?.title }.sorted()
    let account = accountTitles.count == 1 ? accountTitles[0] : accountTitles.joined(separator: ", ")
    if members.count == 1 { return account + "  ·  " + members[0].title }
    let shown = members.filter { !settings.hiddenCalendarIDs.contains($0.id) }.count
    if shown == members.count { return account + "  ·  " + L("settings.events.calendarCount", members.count) }
    return account + "  ·  " + L("settings.events.calendarCountShown", shown, members.count)
  }
}

/// Where a group's events show: the grid and the list, the list only, or nowhere for now.
private struct VisibilityPicker: View {
  let group: EventGroup
  let store: EventSettingsStore

  var body: some View {
    Picker(L("settings.events.visibility"), selection: Binding(get: { group.visibility }, set: { value in store.update { $0.update(id: group.id) { $0.visibility = value } } })) {
      Text(L("settings.events.visibility.gridAndList")).tag(EventGroup.Visibility.gridAndList)
      Text(L("settings.events.visibility.listOnly")).tag(EventGroup.Visibility.listOnly)
      Text(L("settings.events.visibility.hidden")).tag(EventGroup.Visibility.hidden)
    }
    .labelsHidden()
  }
}

/// What the pane keeps between redraws: which sheet is open. SwiftUI's own view state is not
/// available on this toolchain.
@MainActor
@Observable
final class EventsPaneModel {
  var editingGroupID: UUID?
  var collapsedGroupIDs: Set<UUID> = []
  var isAddingVacation = false
  var selectedVacationID: UUID?
  var newVacationStart = Date()
  var newVacationEnd = Date()
  var newVacationName = ""
}

private struct GroupSheetItem: Identifiable {
  let id: UUID
}

/// Name, colour and the calendars of one group. Ticking a calendar that is in another group
/// moves it here, since a calendar belongs to one group.
private struct GroupEditorSheet: View {
  let groupID: UUID
  let events: EventStore
  let store: EventSettingsStore

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let settings = store.settings
    let group = settings.groups.first { $0.id == groupID }
    VStack(alignment: .leading, spacing: 14) {
      Text(L("settings.events.editGroup"))
        .font(.headline)
      if let group {
        HStack(spacing: 12) {
          TextField(L("settings.events.groupName"), text: Binding(get: { group.name }, set: { value in store.update { $0.update(id: groupID) { $0.name = value } } }))
            .textFieldStyle(.roundedBorder)
          HStack(spacing: 6) {
            ForEach(0..<EventGroup.paletteSize, id: \.self) { index in
              Button {
                store.update { $0.update(id: groupID) { $0.paletteIndex = index } }
              } label: {
                Circle()
                  .fill(Palette.group(index))
                  .frame(width: 18, height: 18)
                  .overlay {
                    if index == group.paletteIndex {
                      Circle().strokeBorder(Palette.primary, lineWidth: 2).padding(-3)
                    }
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel(colorName(index))
              .accessibilityAddTraits(index == group.paletteIndex ? [.isSelected] : [])
              .help(colorName(index))
            }
          }
        }
        LabeledContent(L("settings.events.visibility")) {
          VisibilityPicker(group: group, store: store)
        }

        Text(L("settings.events.calendarsInGroup"))
          .font(.callout)
          .foregroundStyle(.secondary)
        Text(L("settings.events.calendarsInGroup.sub"))
          .font(.callout)
          .foregroundStyle(.tertiary)
        ScrollView {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(events.accounts) { account in
              Text(account.title)
                .font(.callout.weight(.semibold))
                .padding(.top, 6)
              ForEach(events.calendars.filter { $0.accountID == account.id }) { calendar in
                let owner = settings.group(of: calendar.id)
                Toggle(isOn: Binding(get: { owner?.id == groupID }, set: { on in
                  store.update { $0.setShown(calendar.id, in: groupID, shown: on) }
                })) {
                  HStack(spacing: 6) {
                    Circle()
                      .fill(Color(.sRGB, red: calendar.color.red, green: calendar.color.green, blue: calendar.color.blue))
                      .frame(width: 8, height: 8)
                    Text(calendar.title).lineLimit(1)
                    if let owner, owner.id != groupID {
                      Text(L("settings.events.inOtherGroup", owner.name))
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    }
                  }
                }
                .toggleStyle(.checkbox)
              }
            }
          }
          .padding(.horizontal, 2)
        }
        .frame(height: 220)
      }
      HStack {
        Button(L("settings.events.removeGroup"), role: .destructive) {
          store.update { $0.removeGroup(id: groupID) }
          dismiss()
        }
        Spacer()
        Button(L("settings.events.done")) { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 440)
  }

  private func colorName(_ index: Int) -> String {
    switch index {
    case 0: L("settings.events.color.indigo")
    case 1: L("settings.events.color.orange")
    case 2: L("settings.events.color.teal")
    case 3: L("settings.events.color.purple")
    case 4: L("settings.events.color.brown")
    case 5: L("settings.events.color.yellow")
    default: ""
    }
  }
}

/// The vacations as a table: from, to, name; a name edits in place, minus removes the selected
/// row, plus opens the sheet with two dates.
private struct VacationTable: View {
  let vacations: VacationStore
  let sheets: EventsPaneModel

  var body: some View {
    VStack(spacing: 6) {
      Table(vacations.list.ranges, selection: Binding(get: { sheets.selectedVacationID }, set: { sheets.selectedVacationID = $0 })) {
        TableColumn(L("settings.vacation.from")) { range in
          Text(Self.dayText(range.startKey)).monospacedDigit()
        }
        .width(96)
        TableColumn(L("settings.vacation.to")) { range in
          Text(Self.dayText(range.endKey)).monospacedDigit()
        }
        .width(96)
        TableColumn(L("settings.vacation.namePlaceholder")) { range in
          TextField(L("settings.vacation.unnamed"), text: Binding(get: { range.name }, set: { vacations.rename(id: range.id, to: $0) }))
            .textFieldStyle(.plain)
        }
      }
      .frame(height: max(72, min(160, CGFloat(vacations.list.ranges.count) * 24 + 30)))
      HStack(spacing: 12) {
        Button { sheets.isAddingVacation = true } label: { Image(systemName: "plus") }
          .accessibilityLabel(L("settings.vacation.add"))
        Button {
          if let id = sheets.selectedVacationID { vacations.delete(id: id) }
          sheets.selectedVacationID = nil
        } label: { Image(systemName: "minus") }
          .disabled(sheets.selectedVacationID == nil)
          .accessibilityLabel(L("settings.vacation.delete"))
        Spacer()
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
    }
  }

  private static func dayText(_ key: Int) -> String {
    let calendar = Calendar.autoupdatingCurrent
    guard let date = VacationCalendar.date(for: key, calendar: calendar) else { return "" }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = .autoupdatingCurrent
    formatter.dateStyle = .short
    return formatter.string(from: date)
  }
}

private struct VacationAddSheet: View {
  let vacations: VacationStore
  let sheets: EventsPaneModel

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L("settings.vacation.add"))
        .font(.headline)
      DatePicker(L("settings.vacation.from"), selection: Binding(get: { sheets.newVacationStart }, set: { sheets.newVacationStart = $0 }), displayedComponents: .date)
      DatePicker(L("settings.vacation.to"), selection: Binding(get: { sheets.newVacationEnd }, set: { sheets.newVacationEnd = $0 }), in: sheets.newVacationStart..., displayedComponents: .date)
      TextField(L("settings.vacation.namePlaceholder"), text: Binding(get: { sheets.newVacationName }, set: { sheets.newVacationName = $0 }))
        .textFieldStyle(.roundedBorder)
      HStack {
        Button(L("vacation.cancel")) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(L("settings.vacation.addConfirm")) {
          vacations.add(from: sheets.newVacationStart, to: sheets.newVacationEnd, name: sheets.newVacationName, calendar: .autoupdatingCurrent)
          sheets.newVacationName = ""
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 360)
  }
}
