# ADR 0004: Public holidays from Nager.Date, by the system region

Date: 2026-09-18. Status: accepted.

## Context

The customer asked for official days off to be marked in red, for the country the user is in.
The brief ruled out events, EventKit and any network use except updates, so this is a change of
scope that he made knowingly. Two questions had to be answered: which country, and where the
days come from.

## Decision

**The country is the region of the system**, `Locale.region`, with a picker in settings to
override it. It is a setting the user already controls, it needs no permission, and it is right
for somebody who lives in Poland with a Russian interface. Geolocation would need a permission
prompt for a calendar, and would be wrong on every trip abroad.

**The days come from Nager.Date** (`date.nager.at`), a free service with no key that covers
about two hundred countries. Each entry says what kind of day it is and whether it holds for the
whole country, so "official days off" can be asked for precisely: type `Public` and `global`.
Observances, bank and school holidays and regional days are dropped.

The list for a country and a year is fetched when it is missing, refreshed about once a month
while the year is current, and kept in `Application Support/MenuCal/Holidays`. The panel never
waits for it: it opens with what is known and redraws when more arrives. A failed download is
retried no sooner than an hour later and costs nothing but the red.

Holidays enter the grid through `IndicatorProvider`, the extension point the brief reserved for
events. This is its first use, and `CalendarEngine` did not have to change shape for it.

## Alternatives rejected

- **EventKit holiday calendars.** A permission prompt for the user's whole calendar, to read a
  list of public holidays, and nothing at all if the user has no such calendar subscribed.
- **Apple's iCloud holiday feeds.** They mix official days off with observances such as
  Valentine's Day and do not tell them apart, which is exactly what the customer ruled out.
- **A list shipped inside the app.** Governments move and add holidays, and an app that is wrong
  about the next long weekend is worse than one that says nothing.

## Consequences

- The app now makes a second kind of network request. It carries the country code and the year
  and nothing else, and it can be turned off in settings. ADR 0003 is amended to say so.
- The service is a third party and may disappear. Then the cache ages out and days stop being
  red; nothing else depends on it.
- The list has days off, not working days moved to a weekend, which some countries decree.
  Those are not marked.
- Red is a colour, and colour alone is not enough: the holiday's name is in the day's tooltip,
  in its VoiceOver label and in the footer when the day is selected.
- Names come in the country's language and in English. English interfaces get English; every
  other interface gets the country's own names.
