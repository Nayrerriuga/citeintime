# citeintime

A new Flutter project.

## Android builds and Shorebird updates

The `Android updates` GitHub Actions workflow is configured to run on pushes
to `main`:

- Changes limited to Dart files under `lib/` are published as a Shorebird patch.
  Phones receive the patch in the background and apply it the next time the app
  starts.
- Changes that may require a full app build produce a release APK as a
  downloadable GitHub Actions artifact. For sideloaded apps, that APK still
  needs to be installed on each phone manually.

Before the workflow can publish updates:

1. Install the Shorebird CLI and run `shorebird init` in the project. Commit the
   generated `shorebird.yaml`.
2. Create and distribute a Shorebird Android release once. Phones must install
   this Shorebird-enabled build before they can receive OTA patches.
3. Add a Shorebird API key as the GitHub Actions repository secret
   `SHOREBIRD_TOKEN`.
4. Push this project to the `main` branch of the configured GitHub repository.

Shorebird patches only update Dart code. Native Android/iOS, plugin, asset, or
Flutter engine changes require a full release. This project's Android release
build currently uses the debug signing configuration; replace it with a
production keystore before distributing a production release. The keystore and
password must be kept out of source control.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
