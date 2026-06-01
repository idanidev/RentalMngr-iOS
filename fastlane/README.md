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

### ios tests

```sh
[bundle exec] fastlane ios tests
```

Ejecuta los tests unitarios y de UI

### ios build

```sh
[bundle exec] fastlane ios build
```

Compila la app y exporta el .ipa

### ios setup_app

```sh
[bundle exec] fastlane ios setup_app
```

Crea la app en App Store Connect (idempotente)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Sube una nueva versión beta a TestFlight

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Sube SOLO screenshots (sin metadata ni binario)

### ios release

```sh
[bundle exec] fastlane ios release
```

Sube la app al App Store para revisión de Apple

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Genera capturas de pantalla con Snapshot

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
