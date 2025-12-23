# senor-particle

A macOS menu bar application for monitoring environmental sensor data from Aranet4 and Aranet Radiation sensors in real-time.

## Features

- 📊 Real-time sensor data display in macOS menu bar
- 🔵 Bluetooth connectivity to Aranet4 sensors (CO2, temperature, humidity, pressure)
- ☢️ Support for Aranet Radiation sensors
- 🏠 Support for Aranet2 and Aranet Radon Plus sensors
- 🔄 Background monitoring with automatic updates
- 🎨 Custom menu bar view with clear data visualization
- ⚡ Efficient resource usage for always-on monitoring
- 🔓 No sensor pairing required - reads directly via BLE

## Requirements

- **macOS**: 11.0 (Big Sur) or later
- **Xcode**: 14.0 or later
- **Swift**: 5.7 or later
- **Bluetooth**: Built-in or external Bluetooth adapter
- **Sensors**: Aranet4 and/or Aranet Radiation sensors

## Installation

### From Source

1. Clone the repository:

```bash
git clone https://github.com/yourusername/senor-particle.git
cd senor-particle
```

2. Open the project in Xcode:

```bash
open senor-particle.xcodeproj
```

3. Build and run:
   - Press `Cmd + R` in Xcode
   - Or use the command line:

```bash
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug
```

## Usage

1. **Launch the app**: The sensor icon will appear in your macOS menu bar
2. **Grant Bluetooth permissions**: Allow the app to access Bluetooth when prompted
3. **Connect sensors**: The app will automatically discover nearby Aranet sensors
4. **View data**: Click the menu bar icon to see detailed sensor readings

## Supported Sensors

All sensor support is provided by [AranetKit](https://github.com/heikopanjas/aranet-kit.git).

### Aranet4

- CO₂ concentration (ppm)
- Temperature (°C/°F)
- Relative humidity (%)
- Atmospheric pressure (hPa/inHg)
- Battery level
- Status display indicator
- Measurement intervals and age

### Aranet2

- Temperature (°C/°F)
- Relative humidity (%)
- Battery level

### Aranet Radiation

- Radiation levels (μSv/h)
- Battery level

### Aranet Radon Plus

- Radon concentration (Bq/m³)
- Battery level

## Development

### Project Structure

```
senor-particle/
├── senor-particle/          # Main application source
│   ├── AppDelegate.swift    # Application lifecycle
│   ├── ViewController.swift # Main view controller
│   └── Assets.xcassets/     # App icons and assets
├── AGENTS.md               # AI coding agent instructions
└── README.md              # This file
```

### Architecture

The application follows a clean architecture pattern:

- **Menu Bar Integration**: `NSStatusItem` for menu bar presence
- **Sensor Communication**: [AranetKit](https://github.com/heikopanjas/aranet-kit.git) library for Bluetooth operations
- **AranetClient**: Async/await API for device scanning and sensor readings
- **Data Models**: Structured sensor reading models from AranetKit
- **UI Updates**: Swift concurrency for responsive interface
- **Periodic Monitoring**: Schedule updates based on device intervals

### Building

```bash
# Debug build (development)
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Debug build

# Release build (distribution)
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -configuration Release build
```

### Testing

```bash
# Run all tests
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle

# Or in Xcode: Cmd + U
```

### Code Style

This project follows comprehensive Swift coding conventions:

- 4-space indentation
- PascalCase for types, camelCase for properties and functions
- Explicit access control modifiers
- DocC-style documentation for public APIs

See `AGENTS.md` for complete coding standards.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please follow the commit message guidelines in `AGENTS.md`.

## Troubleshooting

### Bluetooth Connection Issues

- Ensure Bluetooth is enabled in System Preferences
- Check that sensors are powered on and in range
- Try restarting the app
- Reset Bluetooth module: Hold Shift + Option and click Bluetooth icon in menu bar

### Sensor Not Detected

- Verify sensor is compatible (Aranet4 or Aranet Radiation)
- Ensure sensor is not connected to another device
- Check sensor battery level
- Move sensor closer to Mac

### Performance Issues

- Check Activity Monitor for resource usage
- Ensure latest macOS version is installed
- Try clean build: `Cmd + Shift + K` then `Cmd + B`

## Privacy

This app:

- Only accesses Bluetooth for sensor communication
- Does not collect or transmit any data
- Does not require internet connectivity
- All sensor data stays on your device

## License

TBD

## Acknowledgments

- [Aranet](https://aranet.com/) for their excellent environmental sensors
- [AranetKit](https://github.com/heikopanjas/aranet-kit.git) - Swift library for Aranet sensor communication
- [aranet4-python](https://github.com/Anrijs/Aranet4-Python) by Anrijs Jargans - Original Python implementation
- Swift and macOS developer community

## Contact

For questions, issues, or suggestions, please open an issue on GitHub.

---

**Note**: This project is under active development. Features and documentation may change.

