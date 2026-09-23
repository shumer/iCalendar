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
        Toggle(L("settings.holidays.toggle"), isOn: $preferences.marksHolidays)
        Picker(L("settings.holidays.country"), selection: $preferences.holidayCountry) {
          Text(systemRegionTitle).tag(String?.none)
          Divider()
          ForEach(Self.countries, id: \.code) { country in
            Text(country.name).tag(Optional(country.code))
          }
        }
        .disabled(!preferences.marksHolidays)
      } footer: {
        Text(L("settings.holidays.note"))
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
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

  private var systemRegionTitle: String {
    let locale = Locale.autoupdatingCurrent
    guard let code = HolidayPolicy.country(override: nil, locale: locale),
      let name = locale.localizedString(forRegionCode: code)
    else { return L("settings.holidays.country.systemUnknown") }
    return L("settings.holidays.country.system", name)
  }

  /// The countries the holiday service knows, named and sorted in the user's language.
  private static var countries: [(code: String, name: String)] {
    let locale = Locale.autoupdatingCurrent
    return HolidayFeed.supportedCountries
      .map { (code: $0, name: locale.localizedString(forRegionCode: $0) ?? $0) }
      .sorted { $0.name.compare($1.name, locale: locale) == .orderedAscending }
  }

  /// Weekday names come from the calendar, like every other calendar fact.
  private func weekdayName(_ weekday: Int) -> String {
    let name = Calendar.current.standaloneWeekdaySymbols[weekday - 1]
    return name.prefix(1).uppercased(with: .autoupdatingCurrent) + name.dropFirst()
  }
}
