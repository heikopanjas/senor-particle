# Project Instructions for AI Coding Agents

**Last updated:** 2026-10-22

<!-- {mission} -->

## Mission Statement

**senor-particle** is a macOS menu bar application that reads sensor data from Aranet4 and Aranet Radiation sensors via Bluetooth and displays the measurements in a custom menu bar view. The app provides real-time monitoring of environmental sensor data directly from the macOS menu bar.

### Key Features

- Bluetooth connectivity to Aranet4 sensors (CO2, temperature, humidity, pressure)
- Bluetooth connectivity to Aranet Radiation sensors
- Real-time sensor data display in menu bar
- Custom status item view with sensor readings
- Background monitoring and updates
- Signed automatic application updates hosted on GitHub

## Technology Stack

- **Language:** Swift 6 with complete strict concurrency checking
- **Framework:** Cocoa (AppKit) - macOS menu bar app
- **Build System:** Xcode
- **Platform:** macOS on Apple silicon (`arm64` only)
- **Dependencies:** [AranetKit](https://github.com/heikopanjas/aranet-kit) `3.5.2` or later compatible release for Bluetooth sensor communication, and [Sparkle](https://github.com/sparkle-project/Sparkle) `2.9.4` or later compatible 2.x release for automatic updates
- **Version Control:** Git
- **Package Manager:** Swift Package Manager
- **Version Manifest:** `MARKETING_VERSION` in `senor-particle.xcodeproj/project.pbxproj`
- **License:** MIT

<!-- {principles} -->

## Primary Instructions

- Avoid making assumptions. If you need additional context to accurately answer the user, ask the user for the missing information. Be specific about which context you need.
- Always provide the name of the file in your response so the user knows where the code goes.
- Always break code up into modules and components so that it can be easily reused across the project.
- All code you write MUST be fully optimized. ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt). If the code is not fully optimized, you will be fined $100.

### Working Together

This file (`AGENTS.md`) is the primary instructions file for AI coding assistants working on this project. Agent-specific instruction files (such as `.github/copilot-instructions.md`, `CLAUDE.md`) reference this document, maintaining a single source of truth.

When initializing a session or analyzing the workspace, refer to instruction files in this order:

1. `AGENTS.md` (this file - primary instructions and single source of truth)
2. Agent-specific reference file (if present - points back to AGENTS.md)

### Update Protocol (CRITICAL)

**PROACTIVELY update this file (`AGENTS.md`) as we work together.** Whenever you make a decision, choose a technology, establish a convention, or define a standard, you MUST update AGENTS.md immediately in the same response.

**Update ONLY this file (`AGENTS.md`)** when coding standards, conventions, or project decisions evolve. Do not modify agent-specific reference files unless the reference mechanism itself needs changes.

**When to update** (do this automatically, without being asked):

- Technology choices (build tools, languages, frameworks)
- Directory structure decisions
- Coding conventions and style guidelines
- Architecture decisions
- Naming conventions
- Build/test/deployment procedures

**How to update AGENTS.md:**

- Maintain the "Last updated" timestamp at the top
- Add content to the relevant section (Project Overview, Coding Standards, etc.)
- Add entries to the "Recent Updates & Decisions" log in `UPDATES.md`, directly below the `<!-- {changelog} -->` marker, newest first, with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- Never edit or delete existing `UPDATES.md` entries; the `recent-updates` skill defines the full entry format
- Preserve this structure: title header → timestamp → main instructions

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: Findings and the phased fix plan live in `CODE_REVIEW.md`; load the `swift-coding-conventions`, `swift-concurrency-pro`, and `swift-testing-pro` skills for every review
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to the "Recent Updates & Decisions" log in `UPDATES.md`

### Development Guidelines

- **Menu Bar Architecture**: Use `NSStatusItem` and `NSStatusBarButton` for menu bar integration
- **Sensor Communication**: Use `AranetKit` library for all Bluetooth operations (scanning, reading sensor data)
- **AranetKit Integration**:
  - Use `AranetClient` for device discovery and data retrieval
  - Leverage async/await API provided by AranetKit
  - No manual CoreBluetooth management needed - handled by AranetKit
  - UI updates react to `Notification.Name.aranetReadingDidUpdate` from AranetKit (not app-local sensor notifications)
- **UI Updates**: Use Swift concurrency (async/await) for sensor data updates to keep UI responsive
- **Background Operation**: Design for efficient background monitoring with minimal resource usage
- **Periodic Updates**: Schedule readings based on device update intervals (AranetKit provides timing info)
- **Error Handling**: Provide clear user feedback for Bluetooth connectivity and sensor communication issues
- **Status Notifications**: Use `StatusNotificationCopy` for Carrot Weather-inspired notification text on status color transitions. Four configurable personality levels (`NotificationPersonality`: Professional, Friendly, Snarky, Overkill) in Settings. Copy is data-first (metric + plain-language severity), device-type aware (CO₂, radiation, radon), and direction-aware (worsening vs improving). Stored in Swift static tables in `StatusNotificationCopy.swift`
- **Status Item Display Selection**: The macOS menu bar status item can be pinned to one or two device metrics from Settings > Devices. Store one selected device UUID and up to two ordered `StatusBarDisplayMetric` values in `StatusBarDisplayPreferences`, post `Notification.Name.statusBarDisplayPreferenceDidChange` on changes, and refresh the status item through `MenuTrackingRefresh`. If no explicit selection exists, show the first two available values from the first device with a reading. Displayed values always render in one custom status item view with one vertical label column (`AIR` for non-radiation sensors, `RAD` for radiation sensors) and one or two value rows. Single-value displays use the larger menu bar value font; two-value displays use the compact stacked value font. Keep sensor icons out of the value display. Before readings are available, show `StatusItemPlaceholderView` with a radio-wave pulse around the scanning symbol; its timer runs in `.common` mode and stops when real values appear
- **Display Unit System**: Users can choose Metric or Imperial units in Settings > General. Store the explicit choice in `DisplayUnitSystemPreferences`; when unset, default from `Locale.current.measurementSystem`. Post `Notification.Name.displayUnitSystemPreferenceDidChange` on changes and refresh display surfaces through `MenuTrackingRefresh`. Keep all user-facing sensor value formatting centralized in `StatusBarDisplayMetric.valueString(for:)` so the status item, menu dropdown, Devices preview, and notification metric clauses stay consistent
- **Settings Help Text**: General settings controls include concise secondary explanatory text beneath each control. Keep this copy action-oriented and focused on user-visible behavior rather than implementation details
- **Devices Settings Hierarchy**: Keep the Devices settings surface table-based, but use `NSOutlineView` when showing hierarchical device content. Device rows stay top-level with editable name and notification controls; metric rows are children used for menu bar display selection
- **Settings View Controllers**: Keep each Settings tab controller in its own source file (`GeneralViewController.swift`, `DevicesViewController.swift`, `AdvancedSettingsViewController.swift`) and keep `SettingsWindowController.swift` focused on window, toolbar, and shared preference helper types
- **App Branding**: Every user-visible app name reads `Señor Particle`. Swift code uses `Bundle.main.displayName` (`Bundle+DisplayName.swift`), backed by `CFBundleDisplayName` in `Info.plist`, so system surfaces (notifications, Login Items, permission prompts, Sparkle dialogs) match the app UI. The ASCII `Senor Particle` is reserved for `PRODUCT_NAME`, bundle and archive file names, scripts, and CI, so paths stay stable for builds and existing installations
- **About Entry Point**: The status menu has an `About Señor Particle` item directly below `Settings…` that opens the shared Settings window directly on the About tab through `SettingsWindowController.showAboutAndBringToFront()`. Do not add a separate About window. The About tab's update checkboxes are centered as one group under the centered header while staying left-aligned with each other
- **Automatic Updates**: Use one long-lived `SPUStandardUpdaterController` owned by `AppDelegate` and pass it explicitly through `MenuManager` to `SettingsWindowController` and `AboutViewController`. Keep all update UI in Settings > About; bind the manual check button to `canCheckForUpdates` and use Sparkle's `automaticallyChecksForUpdates` and `automaticallyDownloadsUpdates` properties directly instead of duplicating preferences. Preserve Sparkle's second-launch consent prompt and notification-before-install defaults
- **Sparkle Security**: Require EdDSA-signed archives and signed feeds with `SUVerifyUpdateBeforeExtraction` and `SURequireSignedFeed`. Keep the public key in `Info.plist`, the private key only in the `SPARKLE_ED_PRIVATE_KEY` repository secret plus an offline backup, and pass it to `generate_appcast` through standard input. Sandboxed builds use direct outgoing network access, the Installer Launcher service, and the `-spks`/`-spki` Mach lookup exceptions; do not enable Sparkle's Downloader service
- **Update Cycle Progress**: Each sensor in the menu shows an `UpdateCycleProgressView` below the timestamp. Cycle position = `reading.ago at receive + time since lastUpdated`, repeating every interval via modulo while the menu stays open. Fill color fades from light green opaque to light green at 37% opacity. New readings re-anchor via `MonitoredDevice.updateSequence`. After a configurable number of missed intervals without a reading (**Degraded situation**, default 3, Settings > Advanced), the bar shows full opaque dark red. UI refresh during menu tracking uses `MenuTrackingRefresh` (`.common` run loop); reading delivery relies on AranetKit monitor timers and `Notification.Name.aranetReadingDidUpdate`

### Security & Safety

- Never include API keys, tokens, or credentials in code
- Always require explicit human confirmation before commits
- Maintain conventional commit message standards
- Never include agent co-authorship trailers in commit messages
- Keep change history transparent through commit messages
- [Add project-specific security guidelines]

### Testing

- **Unit tests**: Test sensor data parsing and transformation logic
- **Integration tests**: Test Bluetooth connectivity and sensor communication (may require physical sensors)
- **UI tests**: Test menu bar interface and user interactions
- **Testing framework**: XCTest
- **Location**: Tests are organized alongside source files in the Xcode project

### Documentation

- **Code comments**: Use DocC-style documentation (`///`) for all public APIs and complex logic
- **Inline comments**: Explain "why" not "what" for non-obvious implementation decisions
- **README**: Maintain up-to-date setup instructions, supported sensors, and usage guide
- **Bluetooth Specs**: Document Aranet sensor UUID specifications and data packet formats
- **Architecture docs**: Document key architectural decisions and system design

<!-- {languages} -->

## Coding Conventions

Load the `swift-coding-conventions` skill before writing, reviewing, or refactoring Swift code. It is the single source for naming, formatting, control flow, optionals, access control, and documentation style; `.swift-format` enforces its formatting rules.

Project-specific notes for this AppKit app target:

- Rules aimed at reusable Swift packages do not apply: app types keep default `internal` access instead of explicit `public`, and AppKit is the UI framework rather than a forbidden dependency
- Load `swift-concurrency-pro` when touching async, actor, or `@MainActor` code; the target uses Swift 6 complete strict concurrency with MainActor default isolation
- Load `swift-testing-pro` when writing or reviewing tests

## Build Commands

This is an Xcode project: use the `xcodebuild` and `build.sh` commands below. The SwiftPM commands in the `swift-build-commands` skill (`swift build`, `swift test`, `swift package reset`) do not apply.

### Setup

```bash
# Check Swift and Xcode version
swift --version
xcodebuild -version

# Install Xcode Command Line Tools (if not already installed)
xcode-select --install

# Open project in Xcode
open senor-particle.xcodeproj
```

### Development (Xcode IDE)

- **Build**: `Cmd + B`
- **Run**: `Cmd + R`
- **Test**: `Cmd + U`
- **Clean**: `Cmd + Shift + K`
- **Clean Build Folder**: `Cmd + Option + Shift + K`

### Development (Command Line)

Always pass `-destination "generic/platform=macOS"` to avoid ambiguous destination warnings.
`.build/` is the only supported generated root. Xcode products, intermediates, caches, indexes, logs, SDK stat caches, Swift package checkouts, local distribution output, and CI staging all remain below it. Project build settings route module, compilation, index, log, SDK stat, and package caches to `$(PROJECT_DIR)/.build/...`. The shared workspace settings give the Xcode IDE a custom workspace-relative build location (`.build/Products`, `.build/Intermediates`) and Derived Data in `.build/DerivedData`, so IDE Debug builds write `.build/Products/Debug/Senor Particle.app`. `xcodebuild` ignores shared workspace settings, so scripted builds must pass `-derivedDataPath` and `-clonedSourcePackagesDirPath` explicitly; with default Xcode Locations preferences their products land in `.build/DerivedData/CLI/Build/Products`. Do not add project-level `SYMROOT` or `OBJROOT` overrides because Xcode treats those as legacy build locations and rejects Swift package dependencies.

```bash
# Build the project (debug)
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -configuration Debug -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages build

# Run tests
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages

# Clean build artifacts
xcodebuild clean -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages
```

### Build & Deploy

Use `build.sh` for archive, export, and optional notarization:

```bash
# Archive and export with Developer ID signing
./build.sh

# Clean first, then archive and export
./build.sh --clean

# Archive, export, notarize, and staple
./build.sh --notarize

# Show help
./build.sh --help
```

### Continuous Integration

`.github/workflows/build.yml` runs signed ARM64 Developer ID builds on pushes and pull requests for `develop` and `feature/**`. `.github/workflows/release.yml` validates pull requests targeting `main`, then runs on pushes to `main` after merge. Both import the signing certificate into temporary runner storage, use `.build/DerivedData/CI` plus `.build/SourcePackages`, stage distribution files under `.build/CI`, archive and export the app, verify its signature and architecture, generate `CHANGELOG.md` and `BILL_OF_MATERIALS.md`, and upload the packaged zip. The release workflow alone uses versioned release artifact names and performs Apple notarization, stapling, and Gatekeeper verification. It uses the Sparkle publishing tool from the deterministic package artifact directory. It also creates a notarized app-only Sparkle archive, generates an EdDSA-signed appcast with deltas disabled, and validates the feed during pull requests. Post-merge, it publishes the normal `v<MARKETING_VERSION>` release, uploads versioned archives and notes to the mutable `sparkle-updates` prerelease, then deploys only `appcast.xml` to GitHub Pages. Update assets must be published before the feed. Release publication is retry-safe only when an existing version tag targets the same commit; otherwise increment `MARKETING_VERSION`. Use `GITHUB_RUN_NUMBER` as the monotonically increasing `CFBundleVersion`. Both workflows use `macos-26`, `actions/checkout@v6`, and `actions/upload-artifact@v6`; publication uses `actions/download-artifact@v8`, and Pages uses the official configure, upload, and deploy actions.

The build workflow requires repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, and `APPLE_SIGNING_IDENTITY`. The release workflow additionally requires `APPSTORE_CONNECT_KEY_ID`, `APPSTORE_CONNECT_ISSUER_ID`, and `APPSTORE_CONNECT_KEY_P8_BASE64` for App Store Connect API key notarization plus `SPARKLE_ED_PRIVATE_KEY` for appcast/update signing, for seven secrets in total. The Sparkle key uses Keychain account `com.panjas.senor-particle`; retain an encrypted offline backup of its exported private key. The non-sensitive team ID is read from `exportOptions.plist`. Configure repository Pages with GitHub Actions as its source. Version 1.1.0 is the Sparkle bootstrap release, so 1.0 installations require one final manual upgrade.

### Package Management

```bash
# Add Swift Package dependency (via Xcode)
# File > Add Packages... in Xcode

# Update package dependencies
xcodebuild -resolvePackageDependencies -project senor-particle.xcodeproj -scheme senor-particle -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages

# Show resolved package versions
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages -showBuildSettings | grep PACKAGE
```

### Code Quality

```bash
# Enable build warnings and static analyzer
# Xcode: Build Settings > Warnings > All Issues

# Run static analyzer
xcodebuild analyze -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages

# Format code (requires swift-format)
swift-format format --in-place --recursive senor-particle/
```

**Important**: Always use debug builds during development. Debug builds include debugging symbols and are optimized for debugging. Use release builds only for final testing and distribution.

<!-- {integration} -->

## Commit Protocol (CRITICAL)

- **NEVER commit automatically** - always wait for explicit confirmation
- Load the `git-workflow` skill before every commit; it defines the conventional commit format, the 50-character subject and 500-character total limits, bullet-only bodies, and shell-safe characters
- Never add agent co-authorship trailers or generated-by footers

## Semantic Versioning

Load the `semantic-versioning` skill to choose between PATCH, MINOR, and MAJOR. Project specifics:

- The version lives in `MARKETING_VERSION` in `senor-particle.xcodeproj/project.pbxproj`; update the Debug and Release configurations together
- CI sets `CURRENT_PROJECT_VERSION` (`CFBundleVersion`) from `GITHUB_RUN_NUMBER`; never bump the build number by hand
- Published `v<MARKETING_VERSION>` tags are immutable, so changes after a release need a new version
- Include the version bump in the same commit as the change it versions
