# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-10-22 (v1.2.0, build output in .build 10:50)

- moved every generated root from build to .build: project cache settings, shared workspace settings, build.sh, both ci workflows, readme, and agents
- shared workspace settings now pin a custom workspace-relative location (.build/Products, .build/Intermediates) instead of deferring to xcode app preferences
- also repointed the sdk stat cache and derived data dir settings that still wrote to build
- rationale: one hidden generated root, and ide output no longer depends on each developer's xcode locations preference
- xcodebuild ignores shared workspace settings, so scripted builds keep passing explicit derived data and package paths
- github upload-artifact skips hidden files by item name only, so artifact paths below .build/CI still upload
- supersedes the 2026-07-26 decision to consolidate under build

### 2026-10-22 (v1.2.0, log moved to updates.md 10:40)

- moved all recent updates and decisions entries from agents.md into updates.md, unchanged, sorted newest first
- same-day 2026-06-27 entries were appended in agents.md, so their order is reversed to newest first
- pointed the agents.md update protocol at updates.md
- rationale: one append-only log as defined by the recent-updates skill instead of two diverging logs

### 2026-10-22 (v1.2.0, señor particle branding 10:30)

- added cfbundledisplayname set to señor particle and a bundle displayname accessor used by the about tab, menu items, and general settings text
- updated the bluetooth usage description to the branded name
- rationale: the about tab and menu showed the ascii product name; one display name keeps app and system surfaces consistent
- kept the ascii senor particle for product name, bundle file name, scripts, and ci so build paths and existing installations are unaffected
- version: stays 1.2.0 because that release is unpublished; this joins it rather than taking a patch number of its own

### 2026-10-22 (v1.2.0, about menu item placement 10:15)

- moved the about menu item below settings and renamed it to about senor particle
- rationale: follows the macOS convention of naming the app in the about item, keeps settings as the first entry in the app section

### 2026-10-22 (v1.2.0, about menu item)

- added an about menu item above settings that opens the shared settings window on the about tab
- centered the two update checkboxes as one group so they line up with the icon, name, and update button
- rationale: reuse the existing about tab instead of adding a second window, and keep the checkboxes left-aligned with each other as macOS expects
- version bump: 1.1.1 to 1.2.0 (MINOR - new user-facing menu entry)

### 2026-07-26

- **Consolidated generated artifacts under `Build/`**: Removed the tracked user-specific workspace build-location override that routed products and intermediates into `.build/`, moved shared workspace Derived Data to `Build/DerivedData`, and standardized local scripts plus both GitHub workflows on explicit Derived Data and `Build/SourcePackages` paths. Local distribution output uses `Build/Local`, CI staging uses `Build/CI`, and Sparkle continues to invoke `generate_appcast` from the deterministic package artifact directory. Project-level `SYMROOT`/`OBJROOT` overrides are intentionally avoided because Xcode 26 rejects Swift package dependencies when legacy build locations are active
- **Release 1.1.1 patch version**: Incremented `MARKETING_VERSION` from 1.1.0 to 1.1.1 for the post-bootstrap CI and About-layout fixes. Release tags are immutable: once `v1.1.0` identifies its published source commit, later changes must use a new semantic version rather than replacing that release
- **Centered About settings content**: Group the About tab's app identity and Sparkle controls in one fixed-size container with flexible horizontal and vertical margins so the complete block remains centered when the shared Settings window is resized or switched from another tab
- **Deterministic Sparkle publishing tools in CI**: The release workflow now passes `-clonedSourcePackagesDirPath Build/SourcePackages` to package resolution, build-settings inspection, and archive creation, then invokes `generate_appcast` from that exact artifact directory. GitHub-hosted runners otherwise place package artifacts in an opaque Derived Data path outside the repository, causing the earlier `find Build` lookup to fail even though Sparkle was linked successfully
- **Sparkle automatic updates**: Added Sparkle 2.9.4 through Swift Package Manager with one updater controller owned by `AppDelegate` and an About settings tab for manual checks, automatic-check consent, and automatic downloads. Signed app-only updates are hosted in a dedicated `sparkle-updates` GitHub prerelease, while a signed appcast is deployed to GitHub Pages only after its archive exists. The sandbox permits direct HTTPS update access and Sparkle Installer Launcher communication; archives and the feed use a repository-specific EdDSA key. Release 1.1.0 bootstraps updates, full archives ship first, and deltas remain deferred
- **Stable AranetKit package release**: Changed the remote Swift package requirement from the temporary `develop` branch pin to `upToNextMajorVersion` starting at `3.5.2`. Release `v3.5.2` includes the notification API required by the app, so the project can use stable semantic-version updates while `Package.resolved` continues to pin reproducible builds
- **Apple-silicon-only builds**: Set the project-level `ARCHS` build setting to `arm64` for Debug and Release configurations. The app no longer builds or distributes an `x86_64` slice because supported deployments target Apple silicon exclusively; the shared setting also applies to command-line archives and Swift package dependencies
- **GitHub Actions build and release pipelines**: Added Token Torch-inspired `.github/workflows/build.yml` and `.github/workflows/release.yml`. Build runs for pushes and pull requests on `develop` and `feature/**`; release runs for pull requests targeting `main`. Both produce signed ARM64 Developer ID artifacts with changelog and dependency BOM metadata, while release alone applies versioned naming and performs Apple notarization, stapling, and Gatekeeper verification
- **App Store Connect API key notarization**: Configured the release workflow to authenticate `notarytool` with the same issuer ID, key ID, and base64-encoded `.p8` secret pattern as AranetKit. API key authentication avoids storing an Apple ID app-specific password and supports submission-log retrieval when notarization fails
- **Profile-free Developer ID signing**: Removed the `Senor Particle macOS` provisioning profile from CI and `exportOptions.plist` after verifying a signed archive retains App Sandbox, Bluetooth, and user-selected-file entitlements without an embedded profile. The six-secret contract now matches AranetKit: certificate, certificate password, signing identity, and three App Store Connect API key values; the non-sensitive team ID remains in `exportOptions.plist`
- **Post-merge GitHub releases**: Extended `release.yml` to run on pushes to `main` as well as pull requests targeting it. Pull requests validate the complete signed and notarized artifact without publishing; the post-merge run downloads that run's packaged artifact into a write-scoped job and creates the `v<MARKETING_VERSION>` GitHub release. Existing version tags fail before signing to prevent accidental replacement

### 2026-07-25

- **Radiation measurement duration metric**: Added a `radiationDuration` case to `StatusBarDisplayMetric`, sourced from the Aranet Radiation `AranetReading.radiationDuration` value (measurement period in seconds). It renders in the menu as `Duration` in days (`%.1f d`) and is ordered immediately after `Total dose`. The value is unit-system independent (days for both metric and imperial). This surfaces how long the cumulative total dose was integrated over so users can interpret the total dose in context
- **Remote AranetKit package dependency**: Replaced the sibling `../aranet-kit` package reference with the GitHub repository at <https://github.com/heikopanjas/aranet-kit> on the `develop` branch. The app requires `Notification.Name.aranetReadingDidUpdate`, which is available on `develop` but not in the latest stable `v3.2.0` tag, so the branch requirement preserves current notification-driven updates while making package resolution independent of a local checkout. Track the shared `Package.resolved` file to pin the exact branch revision for reproducible application builds

### 2026-06-27 (initial status placeholder)

- **Animated scanning placeholder**: Replaced the static menu bar scanning placeholder with `StatusItemPlaceholderView`, a compact radio-wave pulse around the `antenna.radiowaves.left.and.right` SF Symbol. The placeholder uses a `.common` run-loop timer so it keeps animating while menus are tracked, and `AppDelegate` removes/stops it as soon as real status values are available

### 2026-06-27 (commit authorship)

- **No agent co-authorship trailers**: Updated commit workflow guidance so commits and amended commits never include agent co-authorship trailers. This keeps project history attributed only to the human author

### 2026-06-27 (strict concurrency + settings split)

- **Swift 6 strict concurrency**: Updated the app target to Swift 6 with `SWIFT_STRICT_CONCURRENCY = complete` while retaining approachable concurrency and MainActor default isolation. This makes concurrency diagnostics enforceable during normal Xcode builds
- **Settings controller file structure**: Split Settings tab controllers into `GeneralViewController.swift`, `DevicesViewController.swift`, and `AdvancedSettingsViewController.swift`, leaving `SettingsWindowController.swift` focused on window and toolbar coordination. This keeps one primary UI controller per file and avoids implicitly unwrapped AppKit view properties

### 2026-06-27 (general settings cleanup)

- **Removed General rescan control**: Removed Rescan from Settings > General to keep the tab focused on persistent preferences; rescan remains available from device-focused surfaces

### 2026-06-27 (settings help text)

- **General tab explanations**: Added concise secondary text below Start at Login, Notification Personality, Units, and Scan timeout controls so Settings communicates user-visible effects directly in the UI

### 2026-06-27 (advanced settings)

- **Advanced tab**: Moved the Degraded situation missed-cycle slider from Settings > General to Settings > Advanced and added compact explanatory copy below the slider describing stale readings and the dark red progress state

### 2026-06-27 (display unit setting)

- **General display unit preference**: Added Metric and Imperial display units in Settings > General. The effective default follows macOS `Locale.current.measurementSystem` until the user chooses a value, and changes post `displayUnitSystemPreferenceDidChange` for live status/menu refresh
- **Centralized unit conversion**: `StatusBarDisplayMetric.valueString(for:)` now owns metric/imperial conversion for temperature, pressure, radiation, and radon so all display and notification surfaces stay aligned

### 2026-06-27 (code review + DRY cleanup)

- **BatteryView symbol fix**: Removed the redundant `level < 7` branch in `batterySymbolName(for:)` that returned the same `battery.0percent` glyph as `level < 13` (SF Symbols has no 10% glyph). Promoted the critical red-tint threshold to a named `criticalBatteryThreshold` constant
- **Metric formatting deduplicated**: `StatusNotificationCopy.metricClause(for:)` now reuses `StatusBarDisplayMetric.valueString(for:)` instead of re-implementing CO2/radiation/radon number formatting. Removed the unused `StatusBarDisplayMetric.statusItemTitle(for:)` dead code
- **Shared label styling**: Added `NSTextField.applyPlainLabelStyle()` (`NSTextField+PlainLabel.swift`) and adopted it in `SensorDeviceView` and `BatteryView` to remove duplicated transparent-label setup. Did not introduce speculative `AppColors`/`AppTypography`/`AppSpacing` token enums since each color/font/spacing value is used in exactly one place (the differing greens are intentionally distinct status-badge vs progress-bar visuals)
- **Centralized scan-timeout preference**: Added `ScanPreferences` (key, default, resolved value) so `SensorManager` and `SettingsWindowController` no longer duplicate the `scanTimeout` UserDefaults key, the `15` default, or the fallback logic. Replaced `print` in `AppDelegate` scan failure with `NSLog`
- **Settings outline checkbox helper**: Extracted `checkboxCell(identifier:action:in:)` mirroring the existing `textCell()` to remove duplicated make-or-create button boilerplate in the notifications and menu-bar columns
- **Concurrency verified, no change**: Confirmed AranetKit posts `aranetReadingDidUpdate` only from `@MainActor`-isolated functions (synchronous `NotificationCenter.post`), so `SensorManager` and `NotificationManager` reading handlers already run on the main thread. The earlier-flagged dictionary race cannot occur; no dispatch hops were added

### 2026-06-27

- **Status item metric selector**: Added a Settings > Devices outline hierarchy where each sensor expands to selectable metric rows. The selected device UUID and metric choices are persisted through `StatusBarDisplayPreferences`, and `AppDelegate` refreshes the status item on preference changes so users can pin the menu bar display to specific sensor values
- **Shared metric formatting**: Centralized displayable Aranet metrics in `StatusBarDisplayMetric` so status item titles, Settings metric rows, and menu dropdown readings share labels and formatting, including radon concentration
- **Debug build output path (superseded 2026-07-26)**: Initially used a target Debug `CONFIGURATION_BUILD_DIR` plus manual Swift/library/framework search paths. The artifact-consolidation change removed these asymmetric workarounds; modern Xcode workspace locations and explicit scripted Derived Data/package paths now produce both Debug and Release outputs below `Build/`
- **Xcode generated directory locations**: Project build settings plus workspace Derived Data settings route `CompilationCache.noindex`, `Index.noindex`, `ModuleCache.noindex`, `SDKStatCaches.noindex`, `SourcePackages`, and `Logs` under `Build/` so repository-root Xcode artifacts stay contained
- **Project-relative Derived Data**: Added workspace settings for project-relative Derived Data, now located at `Build/DerivedData`, while explicit build settings keep compilation, module, index, log, and SDK stat caches under the repository `Build/` hierarchy
- **Text-only status item values**: Removed sensor icons from the menu bar value display so selected metrics render as text only, while placeholder states can continue to use the scanning symbol
- **Dual status item display**: Expanded status item selection to up to two ordered metrics from the same device. The Devices outline uses constrained checkboxes, and `StatusItemDisplayView` renders selected or automatic values inside the single `NSStatusItem` as one vertical label (`AIR` or `RAD`) with one or two value rows

### 2026-05-20

- **Carrot-inspired notification copy**: Replaced generic GREEN/YELLOW/RED transition messages with data-first, personality-configurable copy in `StatusNotificationCopy.swift`. Added `NotificationPersonality` enum (Professional, Friendly, Snarky, Overkill) with Settings picker in General tab. Notifications use custom device display names and include live metric values from `AranetReading`
- **Removed Homicidal personality**: Dropped homicidal notification tone level; four personalities remain
- **Update cycle progress bar**: Added `UpdateCycleProgressView` below each sensor in the menu dropdown. Shows elapsed fraction of the device update interval with live color shift from green to red; uses `reading.ago`, `reading.interval`, and `lastUpdated`
- **Live menu updates**: Progress bar timer uses `RunLoop.main` `.common` mode for updates while menu is tracked; `MenuManager` refreshes sensor views in place instead of rebuilding menu items on each reading
- **Progress bar states**: Green fade cycles every interval while menu is open; dark red full after three missed intervals
- **Menu tracking UI refresh**: Added `MenuTrackingRefresh` to schedule status bar and menu view updates on `RunLoop.main` `.common` mode. `MenuManager` observes `Notification.Name.aranetReadingDidUpdate` and forces view redraw after in-place configure so sensor values update while the menu is open
- **In-place menu row updates**: `SensorDeviceView` reuses persistent metric row fields instead of removing and recreating subviews on each reading; AppKit does not repaint rebuilt subviews during menu tracking. `MenuManager` reassigns `NSMenuItem.view` after updates to force menu item redraw
- **Menu-open sensor polling**: Root cause of stale menu/status values while menu open is AranetKit monitor timers using default run loop mode (paused during menu tracking). Fixed upstream in AranetKit; app listens to `Notification.Name.aranetReadingDidUpdate` only

### 2026-03-22

- **Switched aranet-kit to published version**: Changed SPM dependency from branch-based (develop) to version-based (upToNextMajorVersion from 3.2.0) now that the package is published on GitHub with tagged releases

### 2026-03-14

- **Updated AranetKit to e0bffa8**: Picked up multi-device support (e170d85), DRY refactoring (56d409e), and native radiation status parsing (e0bffa8). Updated Package.resolved pin from 97dcfe7 to e0bffa8
- **Simplified SensorDeviceView.effectiveStatus()**: Removed manual radiation dose-rate threshold logic (0.3/1.0 uSv/h boundaries). AranetKit now parses the native status byte (byte 27) for Aranet Radiation, so reading.status is populated for all device types except Aranet2
- **Adopted AranetKit default scan timeout**: Removed explicit 10s timeout from SensorManager.scan(), using AranetKit new 15s default for better device discovery

### 2026-03-12

- **Replaced Pomodoro scaffolding with Aranet sensor functionality**: Removed Task, TaskStatus, TaskTimes models and TaskView from Sarah Reichelt tutorial starter code
- **Added aranet-kit SPM dependency**: Configured in pbxproj using develop branch from <https://github.com/heikopanjas/aranet-kit.git>
- **Bluetooth permissions**: Created entitlements file with com.apple.security.device.bluetooth for App Sandbox, added NSBluetoothAlwaysUsageDescription to build settings
- **Architecture: SensorManager pattern**: Single AranetClient instance for all devices. AranetKit isolates per-peripheral state via ReadOperation so concurrent monitoring is safe. Uses AranetKit monitor() AsyncStream for smart scheduling
- **Architecture: Programmatic menu**: Menu is now built entirely in code (removed storyboard menu dependency). MenuManager populates device items on menuWillOpen and clears on menuDidClose
- **File structure**: AppDelegate.swift (entry point, scan/monitor orchestration), SensorManager.swift (device scanning and monitoring), MenuManager.swift (menu lifecycle), SensorDeviceView.swift (custom NSView per device)
- **Status bar display**: Shows first available reading's key metric (CO2 ppm for Aranet4, radiation rate for Aranet Radiation, temperature for Aranet2)

### 2025-12-23

- **Project initialization**: Set up senor-particle as macOS menu bar application
- **Mission defined**: Read and display Aranet4 and Aranet Radiation sensor data via Bluetooth
- **Technology stack**: Swift with Cocoa (AppKit) framework, using aranet-kit library for sensor communication
- **Architecture decision**: Use [aranet-kit](https://github.com/heikopanjas/aranet-kit.git) package for all Bluetooth operations instead of implementing CoreBluetooth from scratch. This provides a clean async/await API and handles all sensor protocols (Aranet4, Aranet2, Aranet Radiation, Aranet Radon Plus)
- **Architecture guidelines**: Established patterns for menu bar integration, AranetKit integration, and periodic monitoring
- **Build system**: Configured for Xcode-based development with Swift Package Manager dependencies
- **Coding standards**: Adopted comprehensive Swift conventions from DoomKit guidelines (4-space indentation, explicit access control, async/await for concurrency)

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles
