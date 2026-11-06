fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run the unit tests on the simulator

### ios device

```sh
[bundle exec] fastlane ios device
```

Build Release and install on the iPhone (DEVICE in .env, or the first paired iPhone)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Screenshots for the required App Store sizes (iPhone 6.3", iPad 13") into fastlane/screenshots

### ios creative_assets

```sh
[bundle exec] fastlane ios creative_assets
```

The App Store creative assets into fastlane/creative: the product page header, and the search results image in every language (bin/creative-assets.swift, from the screenshots and their photos)

### ios upload_creative_assets

```sh
[bundle exec] fastlane ios upload_creative_assets
```

Draw the creative assets (`creative_assets`), upload them to the app's asset library and place them on the editable iOS version: the header for every language, and each language's search results image. Doesn't submit

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload the screenshots that changed to the editable version on App Store Connect (dry_run:true only reports)

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Upload fastlane/metadata and the screenshots, attach the latest build of this version, and submit it for review (uploads:false skips the uploads, review:false stops after them; mac:true does the Mac version, with fastlane/metadata-mac)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight (internal testers only; not submitted for external testing)

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store Connect (does not submit for review)

### ios next_version

```sh
[bundle exec] fastlane ios next_version
```

Start the next version once the current one is live on the App Store: bumps the version (minor if there are ✨ commits since the last 🔖 one, else patch; or bump: patch, minor or major) and the build number, builds and uploads it like `release`, writes the release notes (`release_notes`), and commits them with the bump as 🔖 (upload:false only bumps and writes the notes)

### ios release_notes

```sh
[bundle exec] fastlane ios release_notes
```

Write this version's fastlane/metadata release notes in every language with Claude Code, from the app's commits since the last release (keeping that release's main points when it's under a month old)

### ios release_mac

```sh
[bundle exec] fastlane ios release_mac
```

Build the Mac app and upload it to the Mac version on App Store Connect, with the build number of the last `release` (does not submit for review)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
