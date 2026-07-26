# Señor Particle

A macOS menu bar application for real-time monitoring of Aranet Bluetooth sensors. Displays CO2, temperature, humidity, pressure, and radiation measurements directly in the menu bar.

## Features

- Real-time sensor data in the macOS menu bar
- Automatic Bluetooth discovery and connection
- Concurrent multi-device monitoring with automatic reconnection
- Per-device status indicator (green/yellow/red) based on native sensor thresholds
- Battery level display for each device
- Signed automatic updates with user-controlled checks and downloads
- No sensor pairing required - reads directly via BLE

## Supported Sensors

All Bluetooth communication is handled by [AranetKit](https://github.com/heikopanjas/aranet-kit).

| Device | Measurements | Status |
| --- | --- | --- |
| [Aranet4](https://aranet.com/en/home/products/aranet4-home) | CO2 (ppm), temperature, humidity, pressure | Fully supported |
| [Aranet Radiation](https://aranet.com/en/home/products/aranet-radiation-sensor) | Dose rate (uSv/h), cumulative dose | Fully supported |
| [Aranet2](https://aranet.com/en/home/products/aranet2-home) | Temperature, humidity | Experimental |
| [Aranet Radon Plus](https://aranet.com/en/home/products/aranet-radon-sensor) | Radon concentration (Bq/m3) | Experimental |

## Requirements

- macOS 15.7 (Sequoia) or later
- Xcode 26+ / Swift 6
- Bluetooth adapter
- One or more Aranet sensors

## Installation

Clone the repository and open in Xcode:

```bash
git clone https://github.com/heikopanjas/senor-particle.git
cd senor-particle
open senor-particle.xcodeproj
```

Build and run with `Cmd + R`, or from the command line:

```bash
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug -destination "generic/platform=macOS" -derivedDataPath Build/DerivedData/CLI -clonedSourcePackagesDirPath Build/SourcePackages build
```

Dependencies are resolved automatically via Swift Package Manager. All generated files stay under `Build/`: app products in `Build/Products`, intermediates and Derived Data in `Build/DerivedData`, package checkouts and tools in `Build/SourcePackages`, local distribution output in `Build/Local`, and GitHub Actions staging in `Build/CI`.

## Usage

1. Launch the app -- a sensor icon appears in the menu bar
2. Grant Bluetooth permission when prompted
3. The app scans for nearby Aranet sensors on launch
4. The menu bar shows the primary metric from the first connected device (CO2 for Aranet4, dose rate for Aranet Radiation, temperature for Aranet2)
5. Click the menu bar icon to see detailed readings for all connected devices
6. Open **Settings > About** to check for updates or configure automatic checks and downloads

Sparkle asks on the second launch whether it may check for updates automatically. Updates are announced before installation unless automatic downloads are enabled in About. Version 1.1.0 is the first Sparkle-enabled release, so existing 1.0 users must install 1.1.0 manually once.

## Architecture

```text
senor-particle/
├── AppDelegate.swift        # Entry point, status bar setup, scan/monitor orchestration
├── AboutViewController.swift # App identity and Sparkle update preferences
├── SensorManager.swift      # Device discovery, monitoring with retry logic
├── MenuManager.swift        # Programmatic NSMenu lifecycle (populate on open, clear on close)
├── SensorDeviceView.swift   # Custom NSView per device (icon, readings, status badge)
├── BatteryView.swift        # Battery icon and percentage display
├── Base.lproj/
│   └── Main.storyboard      # Minimal storyboard (app delegate wiring only)
└── Assets.xcassets/         # App icons and accent color
```

**AppDelegate** creates the `NSStatusItem`, starts a Bluetooth scan via `SensorManager`, and begins monitoring discovered devices. Status bar text updates on each new reading.

**AppDelegate** also owns the app's single `SPUStandardUpdaterController` and passes it to the Settings window. The About tab reads and writes Sparkle's persisted updater preferences directly.

**SensorManager** wraps `AranetClient` from AranetKit. It scans for devices, then spawns a monitoring task per device using AranetKit's `monitor()` AsyncStream. Disconnections are handled with exponential backoff retry (up to 5 attempts).

**MenuManager** acts as `NSMenuDelegate`. On `menuWillOpen`, it builds a menu item per device with a custom `SensorDeviceView`. On `menuDidClose`, it clears dynamic items. Live updates refresh the menu while open.

**SensorDeviceView** renders a device icon (color-coded by status), device name, battery level, and measurement rows. Status colors come from the native sensor status byte parsed by AranetKit.

## Building

```bash
# Debug build
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug -destination "generic/platform=macOS" -derivedDataPath Build/DerivedData/CLI -clonedSourcePackagesDirPath Build/SourcePackages build

# Release build
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Release -destination "generic/platform=macOS" -derivedDataPath Build/DerivedData/CLI -clonedSourcePackagesDirPath Build/SourcePackages build
```

Use `build.sh` for a Developer ID archive and export. It writes archives, exported apps, and optional notarization zips below `Build/Local` while reusing `Build/SourcePackages`.

### GitHub Actions

`.github/workflows/build.yml` creates signed ARM64 Developer ID builds on pushes and pull requests for `develop` and `feature/**`. `.github/workflows/release.yml` validates pull requests targeting `main`, then runs again after a merge is pushed to `main` to notarize the app and publish a versioned GitHub release. Both workflows use `Build/DerivedData/CI`, `Build/SourcePackages`, and `Build/CI`, then upload a zip containing `Senor Particle.app`, `CHANGELOG.md`, and `BILL_OF_MATERIALS.md`.

Release runs also create an app-only Sparkle archive, generate an EdDSA-signed appcast, and retain all update archives in the mutable `sparkle-updates` prerelease. After those archives are available, the workflow deploys the appcast to [GitHub Pages](https://heikopanjas.github.io/senor-particle/appcast.xml). Delta updates are intentionally disabled until multiple Sparkle-enabled production releases are available.

Each release uses `MARKETING_VERSION` as its Git tag, such as `v1.0`. Increment the version before merging another release after that tag exists.

The build workflow requires these signing secrets:

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`

The release workflow requires those three signing secrets plus three App Store Connect API key secrets and one Sparkle key, for seven repository secrets in total:

- `APPSTORE_CONNECT_KEY_ID`
- `APPSTORE_CONNECT_ISSUER_ID`
- `APPSTORE_CONNECT_KEY_P8_BASE64`
- `SPARKLE_ED_PRIVATE_KEY`

### One-Time Sparkle Setup

The Sparkle key uses the Keychain account `com.panjas.senor-particle`. Its public key is stored in `Info.plist`; never replace it without a migration plan because existing installations trust that key.

1. Resolve packages into `Build/SourcePackages` so Sparkle's tools are available at the deterministic package artifact path used by release CI.
2. Export the existing private key with Sparkle's `generate_keys --account com.panjas.senor-particle -x <secure-file>` option.
3. Store the exported value as the repository secret `SPARKLE_ED_PRIVATE_KEY` and keep a separate encrypted offline backup.
4. In GitHub repository settings, configure Pages to use **GitHub Actions** as its source.

For every release, increment `MARKETING_VERSION`, review the generated release notes, and merge to `main`. CI handles signing, notarization, update packaging, appcast signing, asset publication, and Pages deployment. If the `github-pages` environment has required reviewers, approve that deployment, then smoke-test **Settings > About > Check for Updates…** from the previous version.

## Troubleshooting

### Bluetooth Permission Denied

Go to **System Settings > Privacy & Security > Bluetooth** and enable access for the app.

### No Devices Found

- Ensure sensors are powered on and nearby
- Enable "Smart Home integrations" in the Aranet Home mobile app
- Check that sensors are not exclusively connected to another app

### Reconnection

The app automatically reconnects with exponential backoff if a sensor disconnects. After 5 failed attempts, monitoring for that device stops. Relaunch the app to retry.

## Privacy

- Only uses Bluetooth for sensor communication
- No data collection; network access is used only to retrieve signed update metadata and archives from GitHub
- All sensor data stays on your device

## License

MIT License -- see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Aranet](https://aranet.com/) for their environmental sensors
- [AranetKit](https://github.com/heikopanjas/aranet-kit) -- Swift library for Aranet Bluetooth communication
- [aranet4-python](https://github.com/Anrijs/Aranet4-Python) by Anrijs Jargans -- original Python implementation
