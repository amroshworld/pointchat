fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### doctor

```sh
[bundle exec] fastlane doctor
```

Run pre-flight health check on all mobile credentials & toolchains

### deploy_all

```sh
[bundle exec] fastlane deploy_all
```

Deploy both iOS (TestFlight) and Android (Internal Track)

### bump_version

```sh
[bundle exec] fastlane bump_version
```

Bump version in pubspec.yaml (e.g. fastlane bump_version type:patch|minor|major|build)

----


## iOS

### ios doctor

```sh
[bundle exec] fastlane ios doctor
```

Verify iOS signing, tools, and credentials

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build Flutter iOS and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build Flutter iOS and submit to App Store

----


## Android

### android doctor

```sh
[bundle exec] fastlane android doctor
```

Verify Android signing, tools, and credentials

### android internal

```sh
[bundle exec] fastlane android internal
```

Build Flutter Android App Bundle and upload to Google Play Internal Track

### android beta

```sh
[bundle exec] fastlane android beta
```

Build Flutter Android App Bundle and upload to Google Play Beta Track

### android production

```sh
[bundle exec] fastlane android production
```

Build Flutter Android App Bundle and upload to Google Play Production Track

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
