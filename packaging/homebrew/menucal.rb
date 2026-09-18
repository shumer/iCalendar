# Homebrew cask for MenuCal. Publishing it is a separate decision: copy this file into a tap
# (a repository named homebrew-<something>, under Casks/) and set `version` and `sha256` from the
# release notes, where the workflow prints the image's checksum.
cask "menucal" do
  version "0.1"
  sha256 "replace-with-the-sha256-from-the-release-notes"

  url "https://github.com/shumer/iCalendar/releases/download/v#{version}/MenuCal-#{version}.dmg"
  name "MenuCal"
  desc "Calendar in the menu bar"
  homepage "https://github.com/shumer/iCalendar"

  # The app replaces itself from GitHub releases, so brew must not fight it over versions.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "MenuCal.app"

  uninstall quit: "com.shumenko.menucal"

  zap trash: "~/Library/Preferences/com.shumenko.menucal.plist"
end
