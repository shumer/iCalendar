import MenuCalCore
import SwiftUI

struct CalendarPane: View {
  let preferences: Preferences

  var body: some View {
    @Bindable var preferences = preferences
    Form {
      Section {
        Picker(L("settings.calendar.firstWeekday"), selection: $preferences.firstWeekday) {
          Text(L("settings.calendar.firstWeekday.system")).tag(FirstWeekdayPreference.system)
          Divider()
          Text(weekdayName(2)).tag(FirstWeekdayPreference.monday)
          Text(weekdayName(1)).tag(FirstWeekdayPreference.sunday)
          Text(weekdayName(7)).tag(FirstWeekdayPreference.saturday)
        }
        Toggle(L("settings.calendar.weekNumbers"), isOn: $preferences.showsWeekNumbers)
        Toggle(L("settings.calendar.fullDate"), isOn: $preferences.showsFullDate)
        Toggle(L("settings.calendar.weekends"), isOn: $preferences.highlightsWeekends)
      }
      Section {
        Picker(L("settings.calendar.reopen"), selection: $preferences.reopenBehavior) {
          Text(L("settings.calendar.reopen.current")).tag(ReopenBehavior.currentMonth)
          Text(L("settings.calendar.reopen.last")).tag(ReopenBehavior.lastViewedMonth)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520)
    .fixedSize(horizontal: false, vertical: true)
  }

  /// Weekday names come from the calendar, like every other calendar fact.
  private func weekdayName(_ weekday: Int) -> String {
    let name = Calendar.current.standaloneWeekdaySymbols[weekday - 1]
    return name.prefix(1).uppercased(with: .autoupdatingCurrent) + name.dropFirst()
  }
}
