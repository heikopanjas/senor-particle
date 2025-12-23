# Implementation Plan: Sensor Manager & Periodic Monitoring

**Project:** senor-particle  
**Date:** 2025-12-23  
**Steps:** 4 (Sensor Manager) & 5 (Periodic Monitoring)

---

## Overview

This plan covers the implementation of the sensor management layer and periodic monitoring system for senor-particle, using [AranetKit](https://github.com/heikopanjas/aranet-kit.git) as the underlying Bluetooth communication library.

---

## Step 4: Implement Sensor Manager

### 4.1 Architecture Overview

The Sensor Manager acts as an application-level wrapper around AranetKit's `AranetClient`, providing:
- Device discovery and selection
- Sensor data caching
- Error handling and recovery
- State management for UI updates
- Integration with the app's lifecycle

### 4.2 File Structure

```
senor-particle/
├── Models/
│   ├── SensorDevice.swift          # App-specific device model
│   ├── SensorReading.swift         # Formatted sensor reading data
│   └── SensorError.swift           # Custom error types
├── Managers/
│   ├── SensorManager.swift         # Main sensor management class
│   └── MonitoringScheduler.swift   # Periodic update scheduling (Step 5)
├── Extensions/
│   └── AranetKit+Extensions.swift  # Convenience extensions for AranetKit
└── AppDelegate.swift               # Modified to initialize manager
```

### 4.3 Core Components

#### 4.3.1 `SensorDevice.swift`

**Purpose:** App-specific device model that wraps AranetKit's device with additional metadata.

**Properties:**
- `id: UUID` - Unique identifier
- `name: String` - Device name (e.g., "Aranet4 228EB")
- `peripheralUUID: UUID` - Bluetooth peripheral UUID
- `deviceType: DeviceType` - Enum: aranet4, aranet2, radiation, radonPlus
- `lastSeen: Date` - Last time device was discovered
- `isSelected: Bool` - User's preferred device

**Methods:**
- `init(from aranetDevice:)` - Create from AranetKit device
- `isStale() -> Bool` - Check if device hasn't been seen recently

**Example:**
```swift
public struct SensorDevice: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let peripheralUUID: UUID
    public let deviceType: DeviceType
    public var lastSeen: Date
    public var isSelected: Bool
    
    public enum DeviceType: String, Codable {
        case aranet4
        case aranet2
        case radiation
        case radonPlus
        case unknown
    }
}
```

---

#### 4.3.2 `SensorReading.swift`

**Purpose:** Formatted sensor data ready for display in the UI.

**Properties:**
- `id: UUID` - Unique reading identifier
- `deviceName: String` - Device that produced the reading
- `timestamp: Date` - When reading was taken
- `measurements: [Measurement]` - Array of individual measurements
- `batteryLevel: Int?` - Battery percentage
- `quality: ReadingQuality` - Overall reading quality indicator
- `updateInterval: TimeInterval?` - Device's configured update interval
- `age: TimeInterval?` - Time since device's last sensor update

**Measurement Structure:**
```swift
public struct Measurement: Identifiable {
    public let id = UUID()
    public let type: MeasurementType
    public let value: Double
    public let unit: String
    public let displayValue: String
    
    public enum MeasurementType {
        case co2
        case temperature
        case humidity
        case pressure
        case radiation
        case radon
    }
}
```

**Methods:**
- `init(from aranetReading:, deviceName:)` - Convert from AranetKit reading
- `formattedAge() -> String` - Human-readable age (e.g., "2m 37s ago")
- `statusColor() -> NSColor` - Color indicator based on values

---

#### 4.3.3 `SensorError.swift`

**Purpose:** Custom error types for better error handling and user feedback.

**Error Cases:**
```swift
public enum SensorError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case bluetoothPoweredOff
    case noDevicesFound
    case deviceNotFound(name: String)
    case deviceDisconnected
    case readingFailed(reason: String)
    case timeout
    case aranetKitError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device"
        case .bluetoothUnauthorized:
            return "Bluetooth access denied. Grant permission in System Settings"
        case .bluetoothPoweredOff:
            return "Bluetooth is turned off. Enable it in System Settings"
        case .noDevicesFound:
            return "No Aranet devices found nearby"
        case .deviceNotFound(let name):
            return "Device '\(name)' not found"
        case .deviceDisconnected:
            return "Device disconnected unexpectedly"
        case .readingFailed(let reason):
            return "Failed to read sensor data: \(reason)"
        case .timeout:
            return "Operation timed out"
        case .aranetKitError(let error):
            return "Sensor communication error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .bluetoothUnauthorized:
            return "Open System Settings → Privacy & Security → Bluetooth"
        case .bluetoothPoweredOff:
            return "Turn on Bluetooth in System Settings"
        case .noDevicesFound:
            return "Ensure device is powered on and nearby"
        case .deviceNotFound:
            return "Try scanning for devices again"
        case .deviceDisconnected:
            return "Device may be out of range or powered off"
        default:
            return nil
        }
    }
}
```

---

#### 4.3.4 `SensorManager.swift`

**Purpose:** Main coordinator for all sensor operations.

**Properties:**
```swift
public class SensorManager: ObservableObject {
    // Singleton instance
    public static let shared = SensorManager()
    
    // AranetKit client
    private let aranetClient: AranetClient
    
    // State
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isReading: Bool = false
    @Published public private(set) var discoveredDevices: [SensorDevice] = []
    @Published public private(set) var selectedDevice: SensorDevice?
    @Published public private(set) var latestReading: SensorReading?
    @Published public private(set) var lastError: SensorError?
    
    // Configuration
    public var scanTimeout: TimeInterval = 5.0
    public var readTimeout: TimeInterval = 10.0
    
    private init() {
        self.aranetClient = AranetClient()
    }
}
```

**Methods:**

1. **Device Discovery**
```swift
/// Scan for nearby Aranet devices
/// - Parameter timeout: Scan duration in seconds
/// - Returns: Array of discovered devices
/// - Throws: SensorError if Bluetooth is unavailable or scan fails
public func scanForDevices(timeout: TimeInterval = 5.0) async throws -> [SensorDevice]
```

2. **Device Selection**
```swift
/// Select a device for monitoring
/// - Parameter device: Device to select
public func selectDevice(_ device: SensorDevice)

/// Get currently selected device from persistent storage
/// - Returns: Selected device or nil
public func loadSelectedDevice() -> SensorDevice?

/// Save selected device to persistent storage
/// - Parameter device: Device to save
private func saveSelectedDevice(_ device: SensorDevice)
```

3. **Sensor Reading**
```swift
/// Read current sensor values from selected device
/// - Returns: SensorReading with current measurements
/// - Throws: SensorError if no device selected or reading fails
public func readCurrentValues() async throws -> SensorReading

/// Read values from a specific device
/// - Parameter device: Device to read from
/// - Returns: SensorReading with current measurements
/// - Throws: SensorError if reading fails
public func readValues(from device: SensorDevice) async throws -> SensorReading
```

4. **State Management**
```swift
/// Check Bluetooth status
/// - Returns: True if Bluetooth is available and authorized
public func checkBluetoothStatus() -> Bool

/// Reset manager state (clear devices, readings, errors)
public func reset()

/// Handle errors and update lastError property
/// - Parameter error: Error to handle
private func handleError(_ error: Error)
```

**Implementation Details:**

```swift
public func scanForDevices(timeout: TimeInterval = 5.0) async throws -> [SensorDevice] {
    // Update state
    await MainActor.run {
        self.isScanning = true
        self.lastError = nil
    }
    
    defer {
        Task { @MainActor in
            self.isScanning = false
        }
    }
    
    do {
        // Use AranetKit to scan
        let aranetDevices = try await aranetClient.scan(timeout: timeout)
        
        // Convert to app-specific model
        let devices = aranetDevices.map { SensorDevice(from: $0) }
        
        // Update discovered devices
        await MainActor.run {
            self.discoveredDevices = devices
        }
        
        return devices
        
    } catch {
        let sensorError = mapToSensorError(error)
        await MainActor.run {
            self.lastError = sensorError
        }
        throw sensorError
    }
}

public func readCurrentValues() async throws -> SensorReading {
    guard let device = selectedDevice else {
        throw SensorError.deviceNotFound(name: "No device selected")
    }
    
    return try await readValues(from: device)
}

public func readValues(from device: SensorDevice) async throws -> SensorReading {
    await MainActor.run {
        self.isReading = true
        self.lastError = nil
    }
    
    defer {
        Task { @MainActor in
            self.isReading = false
        }
    }
    
    do {
        // Find device in AranetKit format
        let aranetDevices = try await aranetClient.scan(timeout: 3.0)
        guard let aranetDevice = aranetDevices.first(where: {
            $0.identifier == device.peripheralUUID
        }) else {
            throw SensorError.deviceNotFound(name: device.name)
        }
        
        // Read sensor data
        let aranetReading = try await aranetClient.readCurrentReadings(from: aranetDevice)
        
        // Convert to app-specific model
        let reading = SensorReading(from: aranetReading, deviceName: device.name)
        
        // Update latest reading
        await MainActor.run {
            self.latestReading = reading
        }
        
        return reading
        
    } catch {
        let sensorError = mapToSensorError(error)
        await MainActor.run {
            self.lastError = sensorError
        }
        throw sensorError
    }
}

private func mapToSensorError(_ error: Error) -> SensorError {
    // Map AranetKit errors to SensorError
    // This depends on AranetKit's error types
    if let sensorError = error as? SensorError {
        return sensorError
    }
    return .aranetKitError(error)
}
```

---

## Step 5: Add Periodic Monitoring

### 5.1 Architecture Overview

The Monitoring Scheduler intelligently schedules sensor readings based on:
- Device's configured update interval (e.g., 300 seconds)
- Time since last sensor update (device age)
- Network availability and Bluetooth state
- App lifecycle (foreground/background)

### 5.2 Smart Scheduling Algorithm

**Goal:** Read sensor data shortly after the device updates its sensors, avoiding stale data.

**Strategy:**
1. Perform initial reading to get device interval and age
2. Calculate when next sensor update will occur: `nextUpdate = interval - age + buffer`
3. Schedule reading 3 seconds after predicted update
4. Repeat indefinitely until stopped

**Example:**
- Device interval: 300 seconds (5 minutes)
- Current age: 237 seconds
- Next update in: 300 - 237 = 63 seconds
- Schedule reading at: 63 + 3 = 66 seconds

### 5.3 Core Component

#### 5.3.1 `MonitoringScheduler.swift`

**Purpose:** Manage periodic sensor readings with intelligent scheduling.

**Properties:**
```swift
public class MonitoringScheduler: ObservableObject {
    // Dependencies
    private let sensorManager: SensorManager
    
    // State
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var nextReadingTime: Date?
    @Published public private(set) var readingCount: Int = 0
    
    // Configuration
    public var bufferTime: TimeInterval = 3.0  // Read 3s after device update
    public var minimumInterval: TimeInterval = 30.0  // Don't poll faster than 30s
    public var maximumInterval: TimeInterval = 3600.0  // Max 1 hour between reads
    
    // Internal
    private var monitoringTask: Task<Void, Never>?
    private var timer: Timer?
    
    public init(sensorManager: SensorManager = .shared) {
        self.sensorManager = sensorManager
    }
}
```

**Methods:**

1. **Start Monitoring**
```swift
/// Start monitoring the selected device
/// - Throws: SensorError if no device selected
public func startMonitoring() async throws

/// Stop monitoring and cancel scheduled readings
public func stopMonitoring()
```

2. **Scheduling Logic**
```swift
/// Calculate next reading time based on device interval and age
/// - Parameter reading: Current sensor reading with timing info
/// - Returns: Time interval until next reading should occur
private func calculateNextReadingInterval(from reading: SensorReading) -> TimeInterval

/// Schedule next reading
/// - Parameter interval: Time interval until next reading
private func scheduleNextReading(after interval: TimeInterval)

/// Perform a single reading cycle
private func performReading() async
```

3. **Lifecycle Management**
```swift
/// Pause monitoring (e.g., when app goes to background)
public func pause()

/// Resume monitoring (e.g., when app comes to foreground)
public func resume()

/// Handle app lifecycle events
private func setupLifecycleObservers()
```

**Implementation:**

```swift
public func startMonitoring() async throws {
    guard let device = sensorManager.selectedDevice else {
        throw SensorError.deviceNotFound(name: "No device selected")
    }
    
    // Cancel existing monitoring
    stopMonitoring()
    
    // Update state
    await MainActor.run {
        self.isMonitoring = true
        self.readingCount = 0
    }
    
    // Start monitoring task
    monitoringTask = Task {
        await monitoringLoop()
    }
}

public func stopMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = nil
    
    timer?.invalidate()
    timer = nil
    
    Task { @MainActor in
        self.isMonitoring = false
        self.nextReadingTime = nil
    }
}

private func monitoringLoop() async {
    while !Task.isCancelled {
        // Perform reading
        await performReading()
        
        // Calculate next reading interval
        guard let reading = sensorManager.latestReading else {
            // No reading available, use default interval
            await scheduleAndWait(interval: 60.0)
            continue
        }
        
        let nextInterval = calculateNextReadingInterval(from: reading)
        await scheduleAndWait(interval: nextInterval)
    }
}

private func performReading() async {
    do {
        let reading = try await sensorManager.readCurrentValues()
        
        await MainActor.run {
            self.readingCount += 1
        }
        
        // Notify observers (UI will update via @Published properties)
        
    } catch {
        // Log error but continue monitoring
        print("Reading failed: \(error.localizedDescription)")
        
        // If device disconnected, try to recover
        if case .deviceDisconnected = error as? SensorError {
            // Wait a bit before retrying
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        }
    }
}

private func calculateNextReadingInterval(from reading: SensorReading) -> TimeInterval {
    guard let interval = reading.updateInterval,
          let age = reading.age else {
        // No timing info, use default
        return 60.0
    }
    
    // Calculate time until next device update
    let timeUntilUpdate = max(0, interval - age)
    
    // Add buffer time to read after update
    var nextInterval = timeUntilUpdate + bufferTime
    
    // Clamp to reasonable range
    nextInterval = max(minimumInterval, min(maximumInterval, nextInterval))
    
    return nextInterval
}

private func scheduleAndWait(interval: TimeInterval) async {
    // Update next reading time for UI
    await MainActor.run {
        self.nextReadingTime = Date().addingTimeInterval(interval)
    }
    
    // Wait for interval
    do {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    } catch {
        // Task was cancelled
        return
    }
}
```

---

### 5.4 Integration with AppDelegate

**Modifications to `AppDelegate.swift`:**

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // Managers
    private let sensorManager = SensorManager.shared
    private let monitoringScheduler = MonitoringScheduler()
    
    // UI
    private var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize managers
        setupManagers()
        
        // Load persisted device selection
        if let device = sensorManager.loadSelectedDevice() {
            sensorManager.selectDevice(device)
            
            // Start monitoring automatically if device was previously selected
            Task {
                try? await monitoringScheduler.startMonitoring()
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Stop monitoring
        monitoringScheduler.stopMonitoring()
    }
    
    private func setupManagers() {
        // Configure managers
        sensorManager.scanTimeout = 5.0
        monitoringScheduler.bufferTime = 3.0
    }
}
```

---

## 5.5 Error Handling & Recovery

### Recovery Strategies

1. **Bluetooth Unavailable**
   - Display clear error message in menu bar
   - Provide link to System Settings
   - Retry when Bluetooth becomes available

2. **Device Not Found**
   - Attempt re-scan (device may have been out of range)
   - After 3 failed attempts, notify user
   - Suggest checking device power and proximity

3. **Reading Failed**
   - Retry with exponential backoff (3s, 9s, 27s)
   - After 3 failures, pause monitoring
   - Resume when user manually triggers scan

4. **Device Disconnected Mid-Monitoring**
   - Wait 10 seconds
   - Attempt to reconnect
   - If reconnection fails after 3 attempts, stop monitoring

### Implementation

```swift
// In SensorManager
private var retryCount: Int = 0
private let maxRetries: Int = 3

private func readWithRetry(device: SensorDevice) async throws -> SensorReading {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
        do {
            let reading = try await readValues(from: device)
            retryCount = 0  // Reset on success
            return reading
            
        } catch {
            lastError = error
            
            if attempt < maxRetries - 1 {
                // Exponential backoff
                let delay = pow(3.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    throw lastError ?? SensorError.readingFailed(reason: "Max retries exceeded")
}
```

---

## 5.6 User Preferences

Store monitoring preferences using `UserDefaults`:

```swift
extension UserDefaults {
    private enum Keys {
        static let selectedDeviceID = "selectedDeviceID"
        static let selectedDeviceData = "selectedDeviceData"
        static let monitoringEnabled = "monitoringEnabled"
        static let scanTimeout = "scanTimeout"
        static let bufferTime = "bufferTime"
    }
    
    var selectedDevice: SensorDevice? {
        get {
            guard let data = data(forKey: Keys.selectedDeviceData) else {
                return nil
            }
            return try? JSONDecoder().decode(SensorDevice.self, from: data)
        }
        set {
            if let device = newValue,
               let data = try? JSONEncoder().encode(device) {
                set(data, forKey: Keys.selectedDeviceData)
            } else {
                removeObject(forKey: Keys.selectedDeviceData)
            }
        }
    }
    
    var monitoringEnabled: Bool {
        get { bool(forKey: Keys.monitoringEnabled) }
        set { set(newValue, forKey: Keys.monitoringEnabled) }
    }
}
```

---

## Testing Strategy

### Unit Tests

1. **SensorManager Tests**
   - Test device scanning with mock AranetClient
   - Test error mapping
   - Test device selection and persistence

2. **MonitoringScheduler Tests**
   - Test interval calculation algorithm
   - Test scheduling with various device intervals
   - Test lifecycle (start/stop/pause/resume)

3. **Error Handling Tests**
   - Test each error case
   - Test retry logic
   - Test recovery strategies

### Integration Tests

1. **End-to-End Monitoring**
   - Requires physical Aranet device
   - Test full monitoring cycle
   - Test reconnection after device goes out of range

2. **Bluetooth State Changes**
   - Test behavior when Bluetooth is disabled
   - Test behavior when permissions are revoked

---

## Implementation Timeline

### Phase 1: Core Models (2-3 hours)
- Implement `SensorDevice.swift`
- Implement `SensorReading.swift`
- Implement `SensorError.swift`
- Add `AranetKit+Extensions.swift` for convenience methods

### Phase 2: Sensor Manager (4-5 hours)
- Implement `SensorManager.swift` basic structure
- Add device scanning functionality
- Add device selection and persistence
- Add sensor reading functionality
- Implement error handling

### Phase 3: Monitoring Scheduler (3-4 hours)
- Implement `MonitoringScheduler.swift` basic structure
- Add interval calculation algorithm
- Add monitoring loop
- Add lifecycle management
- Integrate with AppDelegate

### Phase 4: Error Recovery (2-3 hours)
- Implement retry logic
- Add reconnection handling
- Add user notifications for persistent errors

### Phase 5: Testing & Refinement (3-4 hours)
- Write unit tests
- Perform integration testing with physical devices
- Optimize battery usage and performance
- Add logging for debugging

**Total Estimated Time:** 14-19 hours

---

## Success Criteria

✅ **Step 4 Complete When:**
- SensorManager can scan for devices
- SensorManager can read sensor values
- All AranetKit device types are supported
- Errors are handled gracefully
- Device selection persists across app launches

✅ **Step 5 Complete When:**
- Monitoring automatically schedules readings based on device interval
- Readings occur shortly after device sensor updates
- Monitoring survives temporary connection issues
- App responds appropriately to Bluetooth state changes
- Resource usage is minimal (low CPU, battery impact)

---

## Dependencies

### Required Before Implementation:
- [x] AranetKit added as Swift Package dependency
- [x] Menu bar UI structure in place
- [x] Basic NSStatusItem configured

### External Dependencies:
- AranetKit 1.0.0+
- macOS 12.0+
- Bluetooth hardware

---

## Notes & Considerations

### Performance
- Cache discovered devices to avoid repeated scans
- Use background QoS for monitoring task
- Minimize main thread work for UI responsiveness

### Battery Efficiency
- Don't scan continuously - only scan when needed
- Use device's update interval to schedule readings efficiently
- Consider reducing frequency when running on battery

### User Experience
- Show clear feedback during operations (scanning, reading)
- Display next reading countdown in menu bar
- Provide manual refresh option
- Show connection status indicator

### Security & Privacy
- No data is transmitted outside the app
- Bluetooth permissions required
- Device selection stored locally only

---

**End of Implementation Plan**

