# Project Instructions for AI Coding Agents

**Last updated:** 2026-07-26

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
- Add entries to the "Recent Updates & Decisions" log at the bottom with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- Preserve this structure: title header → timestamp → main instructions → "Recent Updates & Decisions" section

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: [Describe your code review process]
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to "Recent Updates & Decisions" section below

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

# Swift Coding Conventions for DoomKit

*Last updated: November 16, 2025*

This document establishes comprehensive coding standards and style guidelines for the DoomKit Swift Package. These conventions ensure consistency, maintainability, and adherence to Swift best practices across the entire codebase.

---

## Table of Contents

1. [File Organization](#file-organization)
2. [Naming Conventions](#naming-conventions)
3. [Code Structure](#code-structure)
4. [Access Control](#access-control)
5. [Type Declarations](#type-declarations)
6. [Property Declarations](#property-declarations)
7. [Function Declarations](#function-declarations)
8. [Control Flow](#control-flow)
9. [Error Handling](#error-handling)
10. [Concurrency & Async/Await](#concurrency--asyncawait)
11. [Protocols & Extensions](#protocols--extensions)
12. [Generics](#generics)
13. [Comments & Documentation](#comments--documentation)
14. [Formatting & Whitespace](#formatting--whitespace)
15. [Swift-Specific Patterns](#swift-specific-patterns)
16. [Package-Specific Conventions](#package-specific-conventions)

---

## File Organization

### Import Statements

```swift
// CORRECT: Organize imports alphabetically, Foundation first if needed
import Foundation
import CoreLocation
import MapKit
import WeatherKit

// INCORRECT: Random order
import WeatherKit
import Foundation
import CoreLocation
```

### File Structure Order

1. Import statements
2. Type declarations (class, struct, enum, protocol)
3. Properties (in order: static, instance)
4. Initializers
5. Lifecycle methods
6. Public methods
7. Internal methods
8. Private methods
9. Nested types (if applicable)

### Single Responsibility

- **One primary type per file** (exceptions for small, tightly-coupled helper types)
- File name must match the primary type name: `ProcessManager.swift` contains `ProcessManager` class
- Place closely related types in the same file only when they form a cohesive unit

---

## Naming Conventions

### General Rules

- Use clear, descriptive names that convey intent
- Prefer full words over abbreviations
- Use American English spelling

### Types (Classes, Structs, Enums, Protocols)

```swift
// CORRECT: PascalCase for types
public class ProcessManager { }
public struct Location { }
public enum ProcessQuality { }
public protocol ProcessController { }

// INCORRECT
public class processManager { }  // Wrong case
public struct location { }       // Wrong case
```

### Properties & Variables

```swift
// CORRECT: camelCase for properties and variables
let locationManager = LocationManager()
var subscriptions: [ProcessSubscription] = []
private let updateInterval: TimeInterval = 60

// INCORRECT
let LocationManager = LocationManager()  // Wrong case
var Subscriptions: [ProcessSubscription] = []  // Wrong case
```

### Functions & Methods

```swift
// CORRECT: camelCase, descriptive action verbs
func refreshData(for location: Location) async throws -> ProcessSensor?
func updateLocation(location: Location) -> Void
private func significantLocationChange(previous: Location?, current: Location) -> Bool

// INCORRECT
func RefreshData() { }  // Wrong case
func upd() { }  // Too abbreviated
func location_update() { }  // Snake case
```

### Constants

```swift
// CORRECT: Use static let for type-level constants
public class LocationManager {
    public static let houseOfWorldCultures = Location(latitude: 52.51889, longitude: 13.36528)
}

// CORRECT: camelCase for constant properties
private let updateInterval: TimeInterval = 60
```

### Enums

```swift
// CORRECT: PascalCase for enum name, camelCase for cases
public enum ProcessQuality {
    case good
    case uncertain
    case bad
    case unknown
}

// CORRECT: Associated value enums
public enum ProcessSelector: Hashable {
    case weather(Weather)
    case forecast(Forecast)
    case covid(Covid)
}
```

### Protocols

```swift
// CORRECT: Use descriptive protocol names
public protocol ProcessController { }
public protocol LocationManagerDelegate: Identifiable where ID == UUID { }

// CORRECT: Protocol names ending in -able, -ible indicate capability
protocol Sendable { }  // Standard library example
```

---

## Code Structure

### Braces

```swift
// CORRECT: Opening brace on same line, closing brace on new line
public class ProcessManager {
    func updateSubscriptions() {
        for subscription in subscriptions {
            subscription.update(timeout: updateInterval)
        }
    }
}

// INCORRECT
public class ProcessManager
{  // Opening brace on new line
    func updateSubscriptions()
    {
        for subscription in subscriptions {
            subscription.update(timeout: updateInterval) }  // Closing brace on same line
    }
}
```

### Indentation

- Use **4 spaces** for indentation (no tabs)
- Align continuation lines with the opening delimiter

```swift
// CORRECT: 4-space indentation
public init(
    name: String, location: Location, placemark: String?, customData: [String: Any]?,
    measurements: [ProcessSelector: [ProcessValue<Dimension>]], timestamp: Date?
) {
    self.name = name
    self.location = location
    self.placemark = placemark
    self.customData = customData
    self.measurements = measurements
    self.timestamp = timestamp
}
```

### Line Length

- Target maximum: **120 characters** per line
- Break long lines at logical points (parameters, operators, closures)

```swift
// CORRECT: Break long function signatures
public func dataWithRetry(
    from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0,
    delegate: (any URLSessionTaskDelegate)? = nil
) async throws -> (Data, URLResponse) {
    // Implementation
}
```

---

## Access Control

### Access Levels (Most to Least Restrictive)

1. `private` - Only visible within the current declaration
2. `fileprivate` - Visible within the same source file
3. `internal` - Visible within the module (default)
4. `public` - Visible to consumers of the module
5. `open` - Visible and subclassable outside the module

### Package Guidelines

```swift
// CORRECT: Explicit public for exported API
public class ProcessManager: Identifiable, LocationManagerDelegate {
    public let id = UUID()
    public static let shared = ProcessManager()

    private let locationManager = LocationManager()  // Internal implementation
    private var location: Location?  // Private state

    public func refreshSubscriptions() {  // Public API
        // Implementation
    }

    private func updateSubscriptions() {  // Private helper
        // Implementation
    }
}
```

### Rules

- **Always explicit**: Mark APIs as `public` explicitly; avoid relying on default `internal`
- **Minimize exposure**: Only expose what consumers need
- **Private by default**: Start with `private`, increase visibility as needed
- **No `open` classes**: Package doesn't require subclassing from consumers

---

## Type Declarations

### Classes

```swift
// CORRECT: Class with protocol conformance
public class ProcessManager: Identifiable, LocationManagerDelegate {
    public let id = UUID()
    public static let shared = ProcessManager()

    private init() {
        // Singleton pattern
    }
}

// CORRECT: Subclass with inheritance
public class WeatherController: ProcessController {
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Implementation
    }
}
```

### Structs

```swift
// CORRECT: Simple value type
public struct Location: Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// CORRECT: Generic struct with computed properties
public struct ProcessValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let quality: ProcessQuality
    public let timestamp: Date
}
```

### Enums

```swift
// CORRECT: Simple enum
public enum ProcessQuality {
    case good
    case uncertain
    case bad
    case unknown
}

// CORRECT: Enum with raw values
public enum Weather: Int, CaseIterable {
    case temperature = 0
    case apparentTemperature = 1
    case dewPoint = 2
}

// CORRECT: Enum with associated values
public enum ProcessSelector: Hashable {
    case weather(Weather)
    case forecast(Forecast)
    case covid(Covid)
}
```

### Protocols

```swift
// CORRECT: Protocol with associated type constraints
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}

// CORRECT: Simple protocol
public protocol ProcessController {
    func refreshData(for location: Location) async throws -> ProcessSensor?
}
```

---

## Property Declarations

### Stored Properties

```swift
// CORRECT: Property declarations with explicit types
public class ProcessManager {
    public let id = UUID()  // Type inferred from initializer
    private let locationManager = LocationManager()
    private var location: Location?  // Optional type explicit
    private let updateInterval: TimeInterval = 60  // Explicit type
    private var subscriptions: [ProcessSubscription] = []  // Explicit initialization
}
```

### Computed Properties

```swift
// CORRECT: Computed property
public struct Location {
    public let latitude: Double
    public let longitude: Double

    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

// CORRECT: Read-only computed property (implicit get)
var isReady: Bool {
    return location != nil && subscriptions.isEmpty == false
}
```

### Property Observers

```swift
// CORRECT: willSet and didSet
var location: Location? {
    willSet {
        print("About to set location to \(newValue)")
    }
    didSet {
        if location != oldValue {
            refreshSubscriptions()
        }
    }
}
```

### Lazy Properties

```swift
// CORRECT: Lazy initialization for expensive resources
lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()
```

---

## Function Declarations

### Basic Structure

```swift
// CORRECT: Function signature formatting
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
    // Implementation
    return ProcessSensor(name: "", location: location, measurements: measurements, timestamp: Date.now)
}
```

### Parameter Labels

```swift
// CORRECT: Descriptive external labels
func updateLocation(location: Location) -> Void { }
func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) { }

// CORRECT: Omit external label with underscore when appropriate
func process(_ data: Data) -> Result { }

// INCORRECT: Redundant labels
func updateLocation(location location: Location) -> Void { }  // Redundant
```

### Default Parameters

```swift
// CORRECT: Default parameters at end
public func dataWithRetry(
    from url: URL,
    retryCount: Int = 3,
    retryInterval: TimeInterval = 1.0,
    delegate: (any URLSessionTaskDelegate)? = nil
) async throws -> (Data, URLResponse) {
    // Implementation
}
```

### Multiple Initializers

```swift
// CORRECT: Convenience initializers calling designated initializers
public struct ProcessValue<T: Dimension> {
    // Designated initializer (most comprehensive)
    public init(value: Measurement<T>, customData: [String: Any]?, quality: ProcessQuality, timestamp: Date) {
        self.value = value
        self.customData = customData
        self.quality = quality
        self.timestamp = timestamp
    }

    // Convenience initializers
    public init(value: Measurement<T>, quality: ProcessQuality, timestamp: Date) {
        self.init(value: value, customData: nil, quality: quality, timestamp: timestamp)
    }

    public init(value: Measurement<T>, quality: ProcessQuality) {
        self.init(value: value, quality: quality, timestamp: Date.now)
    }

    public init(value: Measurement<T>) {
        self.init(value: value, quality: .unknown)
    }
}
```

### Return Type Void

```swift
// CORRECT: Explicit Void return type
public func updateLocation(location: Location) -> Void {
    // Implementation
}

// ALSO CORRECT: Omit return type for Void
public func updateLocation(location: Location) {
    // Implementation
}
```

---

## Control Flow

### If Statements

```swift
// CORRECT: Standard if statement
if location != nil {
    refreshSubscriptions()
}

// CORRECT: If-let for optional binding
if let location = self.location {
    delegate.locationManager(didUpdateLocation: location)
}

// CORRECT: Guard for early return
guard let location = self.location else {
    return
}

// CORRECT: Multiple conditions
if needsUpdate == true {
    self.location = location
    if let delegate = self.delegate {
        delegate.locationManager(didUpdateLocation: location)
    }
}
```

### Guard Statements

```swift
// CORRECT: Guard for preconditions and early exits
guard ReachabilityManager.shared.isConnected else {
    throw URLError(.notConnectedToInternet)
}

guard let url = URL(string: "https://api.example.com/data") else {
    return nil
}

// CORRECT: Multiple guard conditions
guard let data = data,
      let response = response as? HTTPURLResponse,
      (200...299).contains(response.statusCode) else {
    throw NetworkError.invalidResponse
}
```

### For Loops

```swift
// CORRECT: For-in loops
for subscription in subscriptions {
    subscription.update(timeout: updateInterval)
}

// CORRECT: Enumeration with index
for (index, item) in items.enumerated() {
    print("\(index): \(item)")
}

// CORRECT: Filtering in loop
for subscription in subscriptions where subscription.isPending() {
    subscription.reset()
}
```

### Switch Statements

```swift
// CORRECT: Exhaustive switch on enum
switch quality {
    case .good:
        return "✓"
    case .uncertain:
        return "~"
    case .bad:
        return "✗"
    case .unknown:
        return "?"
}

// CORRECT: Switch with multiple cases
switch connectionType {
    case .wifi, .ethernet:
        return true
    case .cellular:
        return false
    case .unknown:
        return false
}
```

### Ternary Operator

```swift
// CORRECT: Simple conditions
let result = condition ? trueValue : falseValue

// AVOID: Nested ternary (use if-else instead)
let result = condition1 ? value1 : (condition2 ? value2 : value3)  // Hard to read
```

---

## Error Handling

### Error Definitions

```swift
// CORRECT: Custom error enum
enum NetworkError: Error {
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
}
```

### Throwing Functions

```swift
// CORRECT: Function that can throw
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    let weather = try await WeatherService.shared.weather(for: clLocation)
    // Process weather data
    return sensor
}
```

### Try-Catch Blocks

```swift
// CORRECT: Standard try-catch
do {
    let (data, response) = try await self.data(from: url, delegate: delegate)
    return (data, response)
} catch {
    lastError = error
    if attempt < retryCount - 1 {
        try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
        continue
    }
}

// CORRECT: Specific error catching
do {
    let result = try riskyOperation()
    return result
} catch NetworkError.invalidResponse {
    print("Invalid response")
    return nil
} catch {
    print("Unknown error: \(error)")
    return nil
}
```

### Optional Try

```swift
// CORRECT: try? for optional result
if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
    // Use placemark
}

// CORRECT: try! only when failure is impossible
let config = try! Configuration.load()  // Only if guaranteed to succeed
```

---

## Concurrency & Async/Await

### Async Functions

```swift
// CORRECT: Async function declaration
public func refreshData(for location: Location) async throws -> ProcessSensor? {
    let weather = try await WeatherService.shared.weather(for: clLocation)
    let placemark = await LocationManager.reverseGeocodeLocation(location: location)
    return ProcessSensor(/* ... */)
}
```

### Task Creation

```swift
// CORRECT: Create task for async work
Task {
    await delegate.refreshData(location: location)
}

// CORRECT: Task with error handling
Task {
    do {
        let result = try await fetchData()
        process(result)
    } catch {
        print("Error: \(error)")
    }
}
```

### Actor Usage

```swift
// CORRECT: Actor for thread-safe state management
actor NetworkManager {
    private var isConnected = true

    func updateConnectionStatus(_ status: Bool) {
        self.isConnected = status
    }

    func checkConnection() -> Bool {
        return isConnected
    }
}
```

### Sendable Conformance

```swift
// CORRECT: @unchecked Sendable for custom Dimension types
public class UnitRadiation: Dimension, @unchecked Sendable {
    public static let sieverts = UnitRadiation(
        symbol: "Sv/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )
}
```

### Async Sequences

```swift
// CORRECT: Iterating async sequence
for await value in asyncSequence {
    process(value)
}
```

---

## Protocols & Extensions

### Protocol Declarations

```swift
// CORRECT: Protocol with requirements
public protocol ProcessController {
    func refreshData(for location: Location) async throws -> ProcessSensor?
}

// CORRECT: Protocol with associated type constraints
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}
```

### Protocol Conformance

```swift
// CORRECT: Conformance in type definition
public class ProcessManager: Identifiable, LocationManagerDelegate {
    // Implementation
}

// CORRECT: Conformance in extension (when appropriate)
extension ProcessManager: CustomStringConvertible {
    public var description: String {
        return "ProcessManager with \(subscriptions.count) subscriptions"
    }
}
```

### Extensions

```swift
// CORRECT: Extension to add functionality
extension URLSession {
    public func dataWithRetry(
        from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0
    ) async throws -> (Data, URLResponse) {
        // Implementation
    }
}

// CORRECT: Extension for protocol conformance
extension Location: Equatable, Hashable {
    // Compiler synthesizes conformance for structs with Equatable/Hashable properties
}
```

### Extension Organization

```swift
// CORRECT: Organize extensions by purpose
// File: ProcessManager.swift

public class ProcessManager {
    // Core implementation
}

// MARK: - LocationManagerDelegate
extension ProcessManager: LocationManagerDelegate {
    public func locationManager(didUpdateLocation location: Location) {
        // Implementation
    }
}

// MARK: - Subscription Management
extension ProcessManager {
    public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
        // Implementation
    }
}
```

---

## Generics

### Generic Types

```swift
// CORRECT: Generic struct with type constraints
public struct ProcessValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let quality: ProcessQuality
}
```

### Generic Functions

```swift
// CORRECT: Generic function with constraints
func measure<T: Dimension>(_ value: Double, unit: T) -> Measurement<T> {
    return Measurement(value: value, unit: unit)
}
```

### Associated Types

```swift
// CORRECT: Protocol with associated type
protocol Container {
    associatedtype Item
    var items: [Item] { get set }
    mutating func add(_ item: Item)
}
```

### Type Erasure

```swift
// CORRECT: Using 'any' for existential types
private var subscribers: [UUID: any ProcessSubscriber] = [:]

public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
    subscribers[subscriber.id] = subscriber
}
```

---

## Comments & Documentation

### Single-Line Comments

```swift
// CORRECT: Comment explains why, not what
// Check if device is connected before attempting network request
guard ReachabilityManager.shared.isConnected else {
    throw URLError(.notConnectedToInternet)
}

// INCORRECT: States the obvious
// Set location to new location
self.location = location
```

### Multi-Line Comments

```swift
// CORRECT: Use single-line style for multi-line comments
// This function performs exponential backoff retry logic
// for network requests. It checks connectivity before each
// attempt and throws immediately if connection is lost.
```

### Documentation Comments

```swift
// CORRECT: DocC-style documentation
/// A simple and fast logging facility with support for different log levels and detailed timestamps.
public class Trace {
    /// Represents different log levels
    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
    }

    /// Creates a new Logger instance
    /// - Parameters:
    ///   - minimumLevel: Minimum level of logs to display
    ///   - showColors: Whether to use ANSI colors in console output
    ///   - dateFormat: Format string for timestamps (default: "yyyy-MM-dd HH:mm:ss.SSS")
    ///   - logFile: Path to file for writing logs (optional)
    public init(
        minimumLevel: Level = .debug,
        showColors: Bool = true,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS",
        logFile: String? = nil
    ) {
        // Implementation
    }
}
```

### MARK Comments

```swift
// CORRECT: Use MARK to organize code sections
public class WeatherController {
    // MARK: - Properties
    private let service = WeatherService.shared

    // MARK: - Initialization
    public init() { }

    // MARK: - Public Methods
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Implementation
    }

    // MARK: - Private Helpers
    private func processWeatherData(_ data: WeatherData) -> ProcessSensor {
        // Implementation
    }
}
```

### TODO/FIXME Comments

```swift
// TODO: Implement caching mechanism for weather data
// FIXME: Handle edge case when location is exactly on boundary
// NOTE: This assumes the API always returns valid data
```

---

## Formatting & Whitespace

### Blank Lines

```swift
// CORRECT: Blank line between logical sections
public class ProcessManager {
    public let id = UUID()
    public static let shared = ProcessManager()

    private let locationManager = LocationManager()
    private var location: Location?

    private init() {
        self.locationManager.delegate = self
    }

    public func refreshSubscriptions() {
        // Implementation
    }
}
```

### Spacing

```swift
// CORRECT: Space after comma, around operators
let values = [1, 2, 3, 4]
let sum = a + b
let range = 0.0 ... 100.0

// CORRECT: No space around range operators
for i in 0..<count { }
let range = 0...10

// CORRECT: No space before colon, space after
var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) { }

// INCORRECT
let values=[1,2,3,4]  // Missing spaces
let sum=a+b  // Missing spaces
var dict : [String : Int]  // Spaces before colons
```

### Trailing Whitespace

```swift
// AVOID: Trailing whitespace at end of lines
func process() {
    let value = 10___
}  // Remove trailing spaces

// CORRECT: No trailing whitespace
func process() {
    let value = 10
}
```

### Empty Lines at File End

```swift
// CORRECT: Single empty line at end of file
public class ProcessManager {
    // Implementation
}

// ← One blank line here, then EOF
```

---

## Swift-Specific Patterns

### Optionals

```swift
// CORRECT: Optional binding with if-let
if let location = self.location {
    process(location)
}

// CORRECT: Optional binding with guard
guard let location = self.location else {
    return
}

// CORRECT: Optional chaining
let count = subscribers[id]?.subscriptions.count

// CORRECT: Nil coalescing
let value = optionalValue ?? defaultValue

// AVOID: Force unwrapping (use only when absolutely certain)
let value = optionalValue!  // Only if guaranteed non-nil
```

### Type Inference

```swift
// CORRECT: Let Swift infer obvious types
let manager = ProcessManager.shared
let id = UUID()
let values = [1, 2, 3]

// CORRECT: Explicit types for clarity
let timeout: TimeInterval = 60
let measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]

// AVOID: Redundant type annotations
let manager: ProcessManager = ProcessManager.shared  // Type obvious
```

### Closures

```swift
// CORRECT: Trailing closure syntax
Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
    self.updateSubscriptions()
}

// CORRECT: Explicit closure parameters
items.map { item in
    return item.value * 2
}

// CORRECT: Shorthand when simple
items.map { $0.value * 2 }

// CORRECT: Multiple trailing closures (Swift 5.3+)
UIView.animate(withDuration: 0.3) {
    view.alpha = 0
} completion: { _ in
    view.removeFromSuperview()
}
```

### Collections

```swift
// CORRECT: Array initialization
var subscriptions: [ProcessSubscription] = []
let values = [1, 2, 3, 4, 5]

// CORRECT: Dictionary initialization
var measurements: [ProcessSelector: [ProcessValue<Dimension>]] = [:]
let dict = ["key": "value"]

// CORRECT: Set initialization
let uniqueIds: Set<UUID> = []
```

### Lazy Evaluation

```swift
// CORRECT: Lazy sequences for performance
let largeArray = (0..<1_000_000)
let evenNumbers = largeArray.lazy.filter { $0 % 2 == 0 }
```

### Property Wrappers

```swift
// CORRECT: Custom property wrapper usage
@Published var measurements: [ProcessValue<Dimension>] = []

// CORRECT: UserDefaults property wrapper
@AppStorage("refreshInterval") var refreshInterval: TimeInterval = 60
```

---

## Package-Specific Conventions

### Public API Patterns

```swift
// CORRECT: Controller pattern
public class WeatherController: ProcessController {
    public func refreshData(for location: Location) async throws -> ProcessSensor? {
        // Fetch data from service
        // Process into ProcessSensor
        // Return structured data
    }
}

// CORRECT: Service pattern (stateless)
public class CovidService {
    static func fetchDistricts(for location: Location, radius: Double) async throws -> Data? {
        // Perform HTTP request
        // Return raw data
    }
}

// CORRECT: Transformer pattern
public class WeatherTransformer: ProcessTransformer {
    override public func renderCurrent(measurements: [ProcessSelector: [ProcessValue<Dimension>]])
        -> [ProcessSelector: ProcessValue<Dimension>] {
        // Transform raw measurements into current values
    }
}
```

### Data Flow Pattern

```swift
// Service (HTTP) → Controller (Parse) → Transformer (Process) → Consumer (Display)

// 1. Service: Fetch raw data
let data = try await CovidService.fetchIncidence(id: districtId)

// 2. Controller: Parse and structure
let sensor = try await controller.refreshData(for: location)

// 3. Transformer: Process for display
let transformer = WeatherTransformer()
try transformer.renderData(sensor: sensor)

// 4. Consumer uses: transformer.current, transformer.faceplate, etc.
```

### Process Architecture

```swift
// CORRECT: ProcessValue with quality assessment
let temperature = Measurement<Dimension>(value: 20.5, unit: UnitTemperature.celsius)
let processValue = ProcessValue(value: temperature, quality: .good, timestamp: Date.now)

// CORRECT: ProcessSensor with measurements
let sensor = ProcessSensor(
    name: "Weather Station",
    location: location,
    placemark: "Berlin, Germany",
    customData: ["icon": "cloud.sun"],
    measurements: measurements,
    timestamp: Date.now
)

// CORRECT: ProcessSelector for data organization
measurements[.weather(.temperature)] = [processValue]
measurements[.weather(.humidity)] = [humidityValue]
```

### Custom Units Pattern

```swift
// CORRECT: Custom Dimension subclass with @unchecked Sendable
public class UnitRadiation: Dimension, @unchecked Sendable {
    public static let sieverts = UnitRadiation(
        symbol: "Sv/h",
        converter: UnitConverterLinear(coefficient: 1.0)
    )

    public static let microsieverts = UnitRadiation(
        symbol: "µSv/h",
        converter: UnitConverterLinear(coefficient: 0.000001)
    )

    override public class func baseUnit() -> Self {
        return sieverts as! Self
    }
}
```

### Subscription Pattern

```swift
// CORRECT: ProcessManager subscription system
public func add(subscriber: any ProcessSubscriber, timeout: TimeInterval) {
    subscriptions.append(ProcessSubscription(id: subscriber.id, timeout: timeout * 60))
    subscribers[subscriber.id] = subscriber
}

// CORRECT: ProcessSubscriber protocol implementation
public protocol ProcessSubscriber: Identifiable {
    func refreshData(location: Location) async
    func resetData() async
}
```

### Location-Based Updates

```swift
// CORRECT: LocationManagerDelegate pattern
public protocol LocationManagerDelegate: Identifiable where ID == UUID {
    func locationManager(didUpdateLocation location: Location) -> Void
}

// CORRECT: Significant location change detection
private func significantLocationChange(previous: Location?, current: Location) -> Bool {
    guard let previous = previous else { return true }
    let deadband = Measurement(value: 100.0, unit: UnitLength.meters)
    let distance = haversineDistance(location_0: previous, location_1: current)
    return distance > deadband
}
```

### Network Resilience Pattern

```swift
// CORRECT: URLSession extension with retry logic
extension URLSession {
    public func dataWithRetry(
        from url: URL, retryCount: Int = 3, retryInterval: TimeInterval = 1.0
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        guard ReachabilityManager.shared.isConnected else {
            throw URLError(.notConnectedToInternet)
        }

        for attempt in 0..<retryCount {
            do {
                let (data, response) = try await self.data(from: url)
                return (data, response)
            } catch {
                lastError = error
                if attempt < retryCount - 1 {
                    try await Task.sleep(nanoseconds: UInt64(retryInterval * 1_000_000_000))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
```

### Logging Pattern

```swift
// CORRECT: Use Trace utility for structured logging
trace.debug("Fetching covid measurement districts...")
let data = try await service.fetch()
trace.debug("Fetched covid measurement districts.")

trace.error("Failed to parse response: \(error)")
```

### Platform Independence

```swift
// CORRECT: Platform conditionals for OS-specific code
#if os(iOS)
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = false
#else
locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
#endif

// AVOID: UI framework dependencies (SwiftUI, UIKit, AppKit) in package
// Keep package focused on business logic and data processing
```

---

## Summary Checklist

### Before Committing Code

- [ ] All public APIs have explicit `public` access control
- [ ] All types, functions, and properties follow naming conventions
- [ ] Code is formatted with 4-space indentation
- [ ] No trailing whitespace
- [ ] Documentation comments for public APIs
- [ ] Error handling is comprehensive
- [ ] Async/await used consistently throughout
- [ ] No platform-specific UI dependencies (SwiftUI, UIKit, AppKit)
- [ ] Custom `Dimension` types conform to `@unchecked Sendable`
- [ ] Protocol conformance is clear and explicit
- [ ] MARK comments organize code sections
- [ ] No force unwrapping (!) unless absolutely safe
- [ ] Follows established package patterns (Controller/Service/Transformer)

### Code Review Focus Areas

1. **Access Control**: Correct use of public/private/internal
2. **Naming**: Clear, descriptive, follows conventions
3. **Error Handling**: Comprehensive try-catch, meaningful errors
4. **Concurrency**: Proper async/await, actor usage, Sendable conformance
5. **Architecture**: Follows Controller/Service/Transformer pattern
6. **Documentation**: Public APIs documented, complex logic explained
7. **Platform Independence**: No UI framework dependencies
8. **Performance**: Efficient algorithms, lazy evaluation where appropriate
9. **Safety**: No force unwrapping, proper optional handling
10. **Consistency**: Matches existing codebase patterns

---

*This document is maintained alongside AGENTS.md and should be updated when new patterns emerge or conventions change.*

## Build Commands

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
Debug builds write the app bundle to `Build/Products/Debug/Senor Particle.app` inside the repository.
Xcode-generated caches, indexes, logs, SDK stat caches, and Swift package checkouts are routed under `Build/`.
Derived Data is configured as a project-relative `Build` location via workspace settings.

```bash
# Build the project (debug)
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -configuration Debug build

# Run tests
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS"

# Clean build artifacts
xcodebuild clean -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS"
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

`.github/workflows/build.yml` runs signed ARM64 Developer ID builds on pushes and pull requests for `develop` and `feature/**`. `.github/workflows/release.yml` validates pull requests targeting `main`, then runs on pushes to `main` after merge. Both import the signing certificate into temporary runner storage, archive and export the app, verify its signature and architecture, generate `CHANGELOG.md` and `BILL_OF_MATERIALS.md`, and upload the packaged zip. The release workflow alone uses versioned release artifact names and performs Apple notarization, stapling, and Gatekeeper verification. It also creates a notarized app-only Sparkle archive, generates an EdDSA-signed appcast with deltas disabled, and validates the feed during pull requests. Post-merge, it publishes the normal `v<MARKETING_VERSION>` release, uploads versioned archives and notes to the mutable `sparkle-updates` prerelease, then deploys only `appcast.xml` to GitHub Pages. Update assets must be published before the feed. Release publication is retry-safe only when an existing version tag targets the same commit; otherwise increment `MARKETING_VERSION`. Use `GITHUB_RUN_NUMBER` as the monotonically increasing `CFBundleVersion`. Both workflows use `macos-26`, `actions/checkout@v6`, and `actions/upload-artifact@v6`; publication uses `actions/download-artifact@v8`, and Pages uses the official configure, upload, and deploy actions.

The build workflow requires repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, and `APPLE_SIGNING_IDENTITY`. The release workflow additionally requires `APPSTORE_CONNECT_KEY_ID`, `APPSTORE_CONNECT_ISSUER_ID`, and `APPSTORE_CONNECT_KEY_P8_BASE64` for App Store Connect API key notarization plus `SPARKLE_ED_PRIVATE_KEY` for appcast/update signing, for seven secrets in total. The Sparkle key uses Keychain account `com.panjas.senor-particle`; retain an encrypted offline backup of its exported private key. The non-sensitive team ID is read from `exportOptions.plist`. Configure repository Pages with GitHub Actions as its source. Version 1.1.0 is the Sparkle bootstrap release, so 1.0 installations require one final manual upgrade.

### Package Management

```bash
# Add Swift Package dependency (via Xcode)
# File > Add Packages... in Xcode

# Update package dependencies
xcodebuild -resolvePackageDependencies -project senor-particle.xcodeproj

# Show resolved package versions
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -showBuildSettings | grep PACKAGE
```

### Code Quality

```bash
# Enable build warnings and static analyzer
# Xcode: Build Settings > Warnings > All Issues

# Run static analyzer
xcodebuild analyze -project senor-particle.xcodeproj -scheme senor-particle

# Format code (requires swift-format)
swift-format format --in-place --recursive senor-particle/
```

**Important**: Always use debug builds during development. Debug builds include debugging symbols and are optimized for debugging. Use release builds only for final testing and distribution.

<!-- {integration} -->

## Commit Protocol (CRITICAL)

- **NEVER commit automatically** - always wait for explicit confirmation

Whenever asked to commit changes:

- Stage the changes
- Write a detailed but concise commit message using conventional commits format
- Commit the changes

This is **CRITICAL**!

## **Commit Message Guidelines - CRITICAL**

Follow these rules to prevent VSCode terminal crashes and ensure clean git history:

**Message Format (Conventional Commits):**

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Character Limits:**

- **Subject line**: Maximum 50 characters (strict limit)
- **Body lines**: Wrap at 72 characters per line
- **Total message**: Keep under 500 characters total
- **Blank line**: Always add blank line between subject and body

**Subject Line Rules:**

- Use conventional commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`
- Scope is optional but recommended: `feat(api):`, `fix(build):`, `docs(readme):`
- Use imperative mood: "add feature" not "added feature"
- No period at end of subject line
- Keep concise and descriptive

**Body Rules (if needed):**

- Add blank line after subject before body
- Wrap each line at 72 characters maximum
- Explain what and why, not how
- Use bullet points (`-`) for multiple items with lowercase text after bullet
- Keep it concise

**Special Character Safety:**

- Avoid nested quotes or complex quoting
- Avoid special shell characters: `$`, `` ` ``, `!`, `\`, `|`, `&`, `;`
- Use simple punctuation only
- No emoji or unicode characters

**Best Practices:**

- **Break up large commits**: Split into smaller, focused commits with shorter messages
- **One concern per commit**: Each commit should address one specific change
- **Test before committing**: Ensure code builds and works
- **Reference issues**: Use `#123` format in footer if applicable

**Examples:**

Good:

```text
feat(api): add KStringTrim function

- add trimming function to remove whitespace from
  both ends of string
- supports all encodings
```

Good (short):

```text
fix(build): correct static library output name
```

Bad (too long):

```text
feat(api): add a new comprehensive string trimming function that handles all edge cases including UTF-8, UTF-16LE, UTF-16BE, and ANSI encodings with proper boundary checking and memory management
```

Bad (special characters):

```text
fix: update `KString` with "nested 'quotes'" & $special chars!
```

## Semantic Versioning Protocol

**AUTOMATICALLY track version changes using semantic versioning (SemVer) in Cargo.toml.**

The current version is defined in `Cargo.toml` under `[package]` section as `version = "X.Y.Z"`.

### Version Format: MAJOR.MINOR.PATCH

**When to increment:**

1. **PATCH version** (X.Y.Z → X.Y.Z+1)
   - Bug fixes and minor corrections
   - Performance improvements without API changes
   - Documentation updates
   - Internal refactoring that doesn't affect public API
   - Example: `1.0.0` → `1.0.1`

2. **MINOR version** (X.Y.Z → X.Y+1.0)
   - New features added
   - New CLI commands or options
   - New functionality that maintains backward compatibility
   - Example: `1.0.1` → `1.1.0`

3. **MAJOR version** (X.Y.Z → X+1.0.0)
   - Breaking changes to public API
   - Removal of features or commands
   - Changes that require user action or code updates
   - Incompatible CLI changes
   - Example: `1.1.0` → `2.0.0`

### Process

After making ANY code changes:

1. Determine the type of change (fix, feature, or breaking change)
2. Update the version in `Cargo.toml` accordingly
3. Include the version change in the same commit as the code change
4. Mention version bump in commit message footer if significant

**Note:** Version changes should be included in the commit with the actual code changes, not as a separate commit.

---

## Recent Updates & Decisions

### 2026-07-26

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

### 2025-12-23

- **Project initialization**: Set up senor-particle as macOS menu bar application
- **Mission defined**: Read and display Aranet4 and Aranet Radiation sensor data via Bluetooth
- **Technology stack**: Swift with Cocoa (AppKit) framework, using aranet-kit library for sensor communication
- **Architecture decision**: Use [aranet-kit](https://github.com/heikopanjas/aranet-kit.git) package for all Bluetooth operations instead of implementing CoreBluetooth from scratch. This provides a clean async/await API and handles all sensor protocols (Aranet4, Aranet2, Aranet Radiation, Aranet Radon Plus)
- **Architecture guidelines**: Established patterns for menu bar integration, AranetKit integration, and periodic monitoring
- **Build system**: Configured for Xcode-based development with Swift Package Manager dependencies
- **Coding standards**: Adopted comprehensive Swift conventions from DoomKit guidelines (4-space indentation, explicit access control, async/await for concurrency)

### 2026-03-12

- **Replaced Pomodoro scaffolding with Aranet sensor functionality**: Removed Task, TaskStatus, TaskTimes models and TaskView from Sarah Reichelt tutorial starter code
- **Added aranet-kit SPM dependency**: Configured in pbxproj using develop branch from <https://github.com/heikopanjas/aranet-kit.git>
- **Bluetooth permissions**: Created entitlements file with com.apple.security.device.bluetooth for App Sandbox, added NSBluetoothAlwaysUsageDescription to build settings
- **Architecture: SensorManager pattern**: Single AranetClient instance for all devices. AranetKit isolates per-peripheral state via ReadOperation so concurrent monitoring is safe. Uses AranetKit monitor() AsyncStream for smart scheduling
- **Architecture: Programmatic menu**: Menu is now built entirely in code (removed storyboard menu dependency). MenuManager populates device items on menuWillOpen and clears on menuDidClose
- **File structure**: AppDelegate.swift (entry point, scan/monitor orchestration), SensorManager.swift (device scanning and monitoring), MenuManager.swift (menu lifecycle), SensorDeviceView.swift (custom NSView per device)
- **Status bar display**: Shows first available reading's key metric (CO2 ppm for Aranet4, radiation rate for Aranet Radiation, temperature for Aranet2)

### 2026-03-14

- **Updated AranetKit to e0bffa8**: Picked up multi-device support (e170d85), DRY refactoring (56d409e), and native radiation status parsing (e0bffa8). Updated Package.resolved pin from 97dcfe7 to e0bffa8
- **Simplified SensorDeviceView.effectiveStatus()**: Removed manual radiation dose-rate threshold logic (0.3/1.0 uSv/h boundaries). AranetKit now parses the native status byte (byte 27) for Aranet Radiation, so reading.status is populated for all device types except Aranet2
- **Adopted AranetKit default scan timeout**: Removed explicit 10s timeout from SensorManager.scan(), using AranetKit new 15s default for better device discovery

### 2026-03-22

- **Switched aranet-kit to published version**: Changed SPM dependency from branch-based (develop) to version-based (upToNextMajorVersion from 3.2.0) now that the package is published on GitHub with tagged releases

### 2026-05-20

- **Carrot-inspired notification copy**: Replaced generic GREEN/YELLOW/RED transition messages with data-first, personality-configurable copy in `StatusNotificationCopy.swift`. Added `NotificationPersonality` enum (Professional, Friendly, Snarky, Overkill) with Settings picker in General tab. Notifications use custom device display names and include live metric values from `AranetReading`
- **Removed Homicidal personality**: Dropped homicidal notification tone level; four personalities remain
- **Update cycle progress bar**: Added `UpdateCycleProgressView` below each sensor in the menu dropdown. Shows elapsed fraction of the device update interval with live color shift from green to red; uses `reading.ago`, `reading.interval`, and `lastUpdated`
- **Live menu updates**: Progress bar timer uses `RunLoop.main` `.common` mode for updates while menu is tracked; `MenuManager` refreshes sensor views in place instead of rebuilding menu items on each reading
- **Progress bar states**: Green fade cycles every interval while menu is open; dark red full after three missed intervals
- **Menu tracking UI refresh**: Added `MenuTrackingRefresh` to schedule status bar and menu view updates on `RunLoop.main` `.common` mode. `MenuManager` observes `Notification.Name.aranetReadingDidUpdate` and forces view redraw after in-place configure so sensor values update while the menu is open
- **In-place menu row updates**: `SensorDeviceView` reuses persistent metric row fields instead of removing and recreating subviews on each reading; AppKit does not repaint rebuilt subviews during menu tracking. `MenuManager` reassigns `NSMenuItem.view` after updates to force menu item redraw
- **Menu-open sensor polling**: Root cause of stale menu/status values while menu open is AranetKit monitor timers using default run loop mode (paused during menu tracking). Fixed upstream in AranetKit; app listens to `Notification.Name.aranetReadingDidUpdate` only

### 2026-06-27

- **Status item metric selector**: Added a Settings > Devices outline hierarchy where each sensor expands to selectable metric rows. The selected device UUID and metric choices are persisted through `StatusBarDisplayPreferences`, and `AppDelegate` refreshes the status item on preference changes so users can pin the menu bar display to specific sensor values
- **Shared metric formatting**: Centralized displayable Aranet metrics in `StatusBarDisplayMetric` so status item titles, Settings metric rows, and menu dropdown readings share labels and formatting, including radon concentration
- **Debug build output path**: Set the target Debug `CONFIGURATION_BUILD_DIR` to `$(PROJECT_DIR)/Build/Products/Debug` so command-line and Xcode debug builds produce `Build/Products/Debug/Senor Particle.app` in the repository. Keep Swift, library, and framework search paths pointed at `$(BUILD_DIR)/$(CONFIGURATION)` so local Swift package products remain discoverable
- **Xcode generated directory locations**: Project build settings plus workspace Derived Data settings route `CompilationCache.noindex`, `Index.noindex`, `ModuleCache.noindex`, `SDKStatCaches.noindex`, `SourcePackages`, and `Logs` under `Build/` so repository-root Xcode artifacts stay contained
- **Project-relative Derived Data**: Added workspace settings for project-relative Derived Data at `Build`, which keeps `SourcePackages`, `Logs`, and `Index.noindex` under the repository `Build/` hierarchy while explicit build settings keep compilation, module, and SDK stat caches there too
- **Text-only status item values**: Removed sensor icons from the menu bar value display so selected metrics render as text only, while placeholder states can continue to use the scanning symbol
- **Dual status item display**: Expanded status item selection to up to two ordered metrics from the same device. The Devices outline uses constrained checkboxes, and `StatusItemDisplayView` renders selected or automatic values inside the single `NSStatusItem` as one vertical label (`AIR` or `RAD`) with one or two value rows

### 2026-06-27 (code review + DRY cleanup)

- **BatteryView symbol fix**: Removed the redundant `level < 7` branch in `batterySymbolName(for:)` that returned the same `battery.0percent` glyph as `level < 13` (SF Symbols has no 10% glyph). Promoted the critical red-tint threshold to a named `criticalBatteryThreshold` constant
- **Metric formatting deduplicated**: `StatusNotificationCopy.metricClause(for:)` now reuses `StatusBarDisplayMetric.valueString(for:)` instead of re-implementing CO2/radiation/radon number formatting. Removed the unused `StatusBarDisplayMetric.statusItemTitle(for:)` dead code
- **Shared label styling**: Added `NSTextField.applyPlainLabelStyle()` (`NSTextField+PlainLabel.swift`) and adopted it in `SensorDeviceView` and `BatteryView` to remove duplicated transparent-label setup. Did not introduce speculative `AppColors`/`AppTypography`/`AppSpacing` token enums since each color/font/spacing value is used in exactly one place (the differing greens are intentionally distinct status-badge vs progress-bar visuals)
- **Centralized scan-timeout preference**: Added `ScanPreferences` (key, default, resolved value) so `SensorManager` and `SettingsWindowController` no longer duplicate the `scanTimeout` UserDefaults key, the `15` default, or the fallback logic. Replaced `print` in `AppDelegate` scan failure with `NSLog`
- **Settings outline checkbox helper**: Extracted `checkboxCell(identifier:action:in:)` mirroring the existing `textCell()` to remove duplicated make-or-create button boilerplate in the notifications and menu-bar columns
- **Concurrency verified, no change**: Confirmed AranetKit posts `aranetReadingDidUpdate` only from `@MainActor`-isolated functions (synchronous `NotificationCenter.post`), so `SensorManager` and `NotificationManager` reading handlers already run on the main thread. The earlier-flagged dictionary race cannot occur; no dispatch hops were added

### 2026-06-27 (display unit setting)

- **General display unit preference**: Added Metric and Imperial display units in Settings > General. The effective default follows macOS `Locale.current.measurementSystem` until the user chooses a value, and changes post `displayUnitSystemPreferenceDidChange` for live status/menu refresh
- **Centralized unit conversion**: `StatusBarDisplayMetric.valueString(for:)` now owns metric/imperial conversion for temperature, pressure, radiation, and radon so all display and notification surfaces stay aligned

### 2026-06-27 (advanced settings)

- **Advanced tab**: Moved the Degraded situation missed-cycle slider from Settings > General to Settings > Advanced and added compact explanatory copy below the slider describing stale readings and the dark red progress state

### 2026-06-27 (settings help text)

- **General tab explanations**: Added concise secondary text below Start at Login, Notification Personality, Units, and Scan timeout controls so Settings communicates user-visible effects directly in the UI

### 2026-06-27 (general settings cleanup)

- **Removed General rescan control**: Removed Rescan from Settings > General to keep the tab focused on persistent preferences; rescan remains available from device-focused surfaces

### 2026-06-27 (strict concurrency + settings split)

- **Swift 6 strict concurrency**: Updated the app target to Swift 6 with `SWIFT_STRICT_CONCURRENCY = complete` while retaining approachable concurrency and MainActor default isolation. This makes concurrency diagnostics enforceable during normal Xcode builds
- **Settings controller file structure**: Split Settings tab controllers into `GeneralViewController.swift`, `DevicesViewController.swift`, and `AdvancedSettingsViewController.swift`, leaving `SettingsWindowController.swift` focused on window and toolbar coordination. This keeps one primary UI controller per file and avoids implicitly unwrapped AppKit view properties

### 2026-06-27 (commit authorship)

- **No agent co-authorship trailers**: Updated commit workflow guidance so commits and amended commits never include agent co-authorship trailers. This keeps project history attributed only to the human author

### 2026-06-27 (initial status placeholder)

- **Animated scanning placeholder**: Replaced the static menu bar scanning placeholder with `StatusItemPlaceholderView`, a compact radio-wave pulse around the `antenna.radiowaves.left.and.right` SF Symbol. The placeholder uses a `.common` run-loop timer so it keeps animating while menus are tracked, and `AppDelegate` removes/stops it as soon as real status values are available
