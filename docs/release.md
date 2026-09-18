# Releasing MenuCal

A tag published on GitHub produces a signed, notarised and stapled `MenuCal.app`, as a zip for
the app's own updater and as a disk image for people, attached to the release with install notes
the workflow writes itself. The pipeline is the one described in the DevDeck handover, adapted.

## One time: five repository secrets

GitHub, repository, Settings, Secrets and variables, Actions.

| Secret | What it is |
|---|---|
| `DEVELOPER_ID_P12` | the Developer ID Application certificate with its private key, exported as `.p12`, base64 |
| `DEVELOPER_ID_P12_PASSWORD` | the password set while exporting it |
| `NOTARY_KEY_P8` | an App Store Connect API key (`AuthKey_XXXXXXXXXX.p8`), base64 |
| `NOTARY_KEY_ID` | that key's Key ID |
| `NOTARY_ISSUER_ID` | the team's Issuer ID |

```bash
base64 -i DeveloperID.p12 | tr -d '\n' | pbcopy
```

They are the same five DevDeck uses, so they can be copied over as they are. Without them the
workflow still runs and attaches an ad-hoc signed build, and the notes explain the quarantine
steps. Ad-hoc is a fallback for forks, not a way to ship.

## Every release

```bash
echo "0.2" > VERSION && git commit -am "chore: version 0.2" && git push
```

```bash
gh release create v0.2 --title "0.2" --notes "What changed."
```

```bash
gh run watch "$(gh run list --workflow=release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

The workflow refuses a tag that does not match `VERSION`: an app that reports 0.1 from a release
called 0.2 would offer itself as an update forever.

What it does, in order: checks out the tag's commit with full history (the build number is the
commit count), runs the suite, imports the certificate into a throwaway keychain, runs
`./build.sh`, notarises and staples the app, zips it with `ditto`, builds and signs the disk
image, notarises and staples the image, uploads both, rewrites the Installing section of the
release notes.

## What users get

- `MenuCal-<version>.dmg`: open, drag to Applications.
- `MenuCal-<version>-<build>.zip`: what the running app downloads when it updates itself. The
  updater only accepts an asset named `MenuCal-*.zip` from this repository's releases, verifies
  its signature against its own, and refuses anything that is not newer.

## Checking a build by hand

```bash
codesign -dv --verbose=4 MenuCal.app
```

```bash
xcrun stapler validate MenuCal.app
```

```bash
spctl --assess --type execute --verbose=2 MenuCal.app
```

`source=Notarized Developer ID` is what a good answer looks like.

## Not done

- The disk image has no background picture. Laying one out needs Finder scripting, which is
  unreliable on a CI runner; the image has the app and the Applications link, which is what
  matters.
- `packaging/homebrew/menucal.rb` is a ready cask. Publishing it means a tap repository and a
  version and checksum bump per release; the workflow prints the checksum in the notes.
- The app icon is drawn by `Scripts/make-icon.swift` into `Resources/AppIcon/MenuCal.iconset`.
  Run the script again after changing it and commit the images.
