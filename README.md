# Señor Particle

A macOS menu bar application for real-time monitoring of Aranet Bluetooth sensors. Displays CO2, temperature, humidity, pressure, and radiation measurements directly in the menu bar.

## Features

- Real-time sensor data in the macOS menu bar
- Automatic Bluetooth discovery and connection
- Concurrent multi-device monitoring with automatic reconnection
- Per-device status indicator (green/yellow/red) based on native sensor thresholds
- Battery level display for each device
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
- Xcode 16+ / Swift 5
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
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug build
```

Dependencies are resolved automatically via Swift Package Manager.

## Usage

1. Launch the app -- a sensor icon appears in the menu bar
2. Grant Bluetooth permission when prompted
3. The app scans for nearby Aranet sensors on launch
4. The menu bar shows the primary metric from the first connected device (CO2 for Aranet4, dose rate for Aranet Radiation, temperature for Aranet2)
5. Click the menu bar icon to see detailed readings for all connected devices

## Architecture

```text
senor-particle/
├── AppDelegate.swift        # Entry point, status bar setup, scan/monitor orchestration
├── SensorManager.swift      # Device discovery, monitoring with retry logic
├── MenuManager.swift        # Programmatic NSMenu lifecycle (populate on open, clear on close)
├── SensorDeviceView.swift   # Custom NSView per device (icon, readings, status badge)
├── BatteryView.swift        # Battery icon and percentage display
├── Base.lproj/
│   └── Main.storyboard      # Minimal storyboard (app delegate wiring only)
└── Assets.xcassets/         # App icons and accent color
```

**AppDelegate** creates the `NSStatusItem`, starts a Bluetooth scan via `SensorManager`, and begins monitoring discovered devices. Status bar text updates on each new reading.

**SensorManager** wraps `AranetClient` from AranetKit. It scans for devices, then spawns a monitoring task per device using AranetKit's `monitor()` AsyncStream. Disconnections are handled with exponential backoff retry (up to 5 attempts).

**MenuManager** acts as `NSMenuDelegate`. On `menuWillOpen`, it builds a menu item per device with a custom `SensorDeviceView`. On `menuDidClose`, it clears dynamic items. Live updates refresh the menu while open.

**SensorDeviceView** renders a device icon (color-coded by status), device name, battery level, and measurement rows. Status colors come from the native sensor status byte parsed by AranetKit.

## Building

```bash
# Debug build
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug build

# Release build
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Release build
```

### GitHub Actions

`.github/workflows/build.yml` creates signed ARM64 Developer ID builds on pushes and pull requests for `develop` and `feature/**`. `.github/workflows/release.yml` runs on pull requests targeting `main` and adds Apple notarization, stapling, Gatekeeper verification, and versioned release artifact naming. Both workflows upload a zip containing `Senor Particle.app`, `CHANGELOG.md`, and `BILL_OF_MATERIALS.md`.

The build workflow requires these signing secrets:

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`

The release workflow requires those three signing secrets plus these three App Store Connect API key secrets, for six repository secrets in total:

- `APPSTORE_CONNECT_KEY_ID`
- `APPSTORE_CONNECT_ISSUER_ID`
- `APPSTORE_CONNECT_KEY_P8_BASE64`

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
- No data collection or network activity
- All sensor data stays on your device

## License

MIT License -- see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Aranet](https://aranet.com/) for their environmental sensors
- [AranetKit](https://github.com/heikopanjas/aranet-kit) -- Swift library for Aranet Bluetooth communication
- [aranet4-python](https://github.com/Anrijs/Aranet4-Python) by Anrijs Jargans -- original Python implementation
