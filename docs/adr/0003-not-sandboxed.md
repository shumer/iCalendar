# ADR 0003: The app is not sandboxed

Date: 2026-09-18. Status: accepted.

## Context

B-5 of the brief says to turn the App Sandbox on "if nothing is in the way". Something is: the
app updates itself by replacing its own bundle (ADR 0002), and a sandboxed process cannot write
to `/Applications` or to wherever else the user put it. Sparkle solves this with an XPC installer
outside the sandbox, which is exactly the nested code ADR 0002 decided not to carry.

## Decision

No App Sandbox. The hardened runtime is on. The entitlements file holds exactly one key,
`com.apple.security.personal-information.calendars`, added with ADR 0005: without it the
hardened runtime never shows the calendar permission dialog, and `requestFullAccessToEvents`
answers false in silence. The app asks for no other exception, so it cannot load unsigned
code, use JIT memory or read `DYLD_` variables.

## What limits the app instead

- It reads nothing of the user's: no files, no contacts, no calendars, no location.
- It makes two kinds of network request. One is a GET to the releases API of its own
  repository, and a download from the same repository's releases when the user agrees to update.
  The other, added by ADR 0004, is a GET for a country's public holidays that carries a country
  code and a year. The feed is not trusted;
  the downloaded app must carry the same bundle identifier and the same Developer ID team as the
  running one, and be newer, before it replaces anything.
- The global shortcut uses the Carbon hot key API, which needs no accessibility permission.

## Consequence

The Mac App Store is closed to this build. Distribution is a notarised Developer ID download,
which is what the brief asks for.
