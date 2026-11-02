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

### ios release_mac

```sh
[bundle exec] fastlane ios release_mac
```

Build the Mac app and upload it to the Mac version on App Store Connect, with the build number of the last `release` (does not submit for review)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
