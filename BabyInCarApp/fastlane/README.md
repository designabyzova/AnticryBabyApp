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

### ios age_rating

```sh
[bundle exec] fastlane ios age_rating
```

Set age rating

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata to App Store Connect

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Upload screenshots to App Store Connect

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Submit for App Store Review

### ios set_pricing

```sh
[bundle exec] fastlane ios set_pricing
```

Set pricing to FREE

### ios set_privacy

```sh
[bundle exec] fastlane ios set_privacy
```

Set app privacy - no data collected

### ios register_app_ids

```sh
[bundle exec] fastlane ios register_app_ids
```

Register all App IDs with proper capabilities

### ios configure_xcode_cloud

```sh
[bundle exec] fastlane ios configure_xcode_cloud
```

Configure Xcode Cloud workflow for TestFlight

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Upload IPA to TestFlight

### ios build_and_upload

```sh
[bundle exec] fastlane ios build_and_upload
```

Build and upload to TestFlight locally

### ios release

```sh
[bundle exec] fastlane ios release
```

Archive Release + upload to TestFlight (uses version/build already set in project)

### ios check_ready

```sh
[bundle exec] fastlane ios check_ready
```

Check app submission readiness

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
