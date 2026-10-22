# Code Review and Fix Plan

**Reviewed revision:** `5c5310c` (`develop`, 2026-10-22)
**Scope:** every Swift source under `senor-particle/`, the Xcode project settings, the shared scheme, `Info.plist`, entitlements, CI workflows, and the agent instruction files
**Method:** line-by-line static review against the `swift-coding-conventions`, `swift-concurrency-pro`, and `swift-testing-pro` skills, cross-checked against the pinned AranetKit 3.5.2 sources (`75eedd0`) for isolation and API contracts
**Not done:** no build, lint, or test run. The review environment has no Xcode or Swift toolchain. Every phase below ends with the macOS commands that verify it.
**Re-checked:** 2026-10-22 against AranetKit 4.0.0 (`v4.0.0`, released the same day). The section "AranetKit 4.0.0 impact" lists what the new release changes; findings C3, C4, C5, K5, A3, A9, T2, T3, and D3 carry an "AranetKit 4.0.0" note, and C20 and D7 are new.

Line numbers refer to the reviewed revision. Finding IDs are stable and are referenced from the phases in Part 2.

## Fix status (v1.3.0, branch `feature/code-review`)

Phases 0 to 5 and the C4/A11 slice of Phase 6 are implemented. CI builds, lints, and runs the unit tests with and without Thread Sanitizer. A hardware run with real sensors is still required before release.

**Decisions taken** (Part 3): C10 shows the available pinned values and falls back to the default values; C11 requests permission lazily; D2 keeps 147 columns; K8 adopts `os.Logger` now; C14 keeps the tables with a coverage test; D7 bumps AranetKit to 4.0.0 first.

| Area | Fixed | Not fixed |
| --- | --- | --- |
| Correctness | C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13, C14, C16, C17, C18, C19, C20 | C15 (Settings layout, see A10) |
| Concurrency | K1, K2, K3, K4, K5, K7, K8 | K6 (informational, no action) |
| Architecture | A1, A2, A3, A4, A5, A6, A7, A8, A9, A11, A13, A14 | A10 (stack view layout), A12 (localization, informational) |
| Conventions | S1 to S10, S12 to S14, S16 | S11 and S15 (no action) |
| Testing | T1, T2, T3 | T4 (UI tests) |
| Tooling and docs | D1, D2, D3, D4, D5, D6, D7 | none |

**Deviations from the plan:**

- C8 and K5: `SensorManager` iterates AranetKit's `monitor(from:)` streams instead of observing `aranetReadingDidUpdate`. The compiler then checks reading isolation, and nothing depends on notification delivery. Every other consumer observes `sensorDevicesDidChange`.
- C5: a failed scan shows its reason in the status menu and retries every 30 seconds. There is no separate Bluetooth-off banner.
- T2: tests use `ReadingFixtures` instead of an `AranetReading` extension, record notifications synchronously instead of with `confirmation()`, and use no tags. Battery tests target the extracted `BatteryLevel`.
- D6: the version is 1.3.0, because the connection state and scan error UI are new behavior and v1.2.0 is already tagged.

**Deferred:** A10 and C15 change the Settings layout and T4 adds UI tests. Both need visual verification on a Mac, so they stay in Phase 6.

---

## Executive summary

The app is small (23 files, about 2,900 lines), already builds under Swift 6 with complete strict concurrency and main-actor default isolation, and is free of force unwraps, `try!`, `DispatchQueue`, `@unchecked Sendable`, and `Task.detached`. Brace style, `else`/`catch` placement, explicit `-> Void`, and `== true`/`== false` comparisons are applied consistently. That is a solid base.

The review found four groups of problems that need work, in priority order:

1. **Monitoring resilience (C1, C2, C3).** The reconnect loop in `SensorManager` abandons a device permanently after five lifetime disconnects, finished monitoring tasks block any restart via Rescan, and `rescan()` can run two scans concurrently. Against AranetKit 3.5.2 the double scan hung the first caller inside AranetKit; 4.0.0 joins concurrent scans, so C3 drops to Medium, but the app-side guard is still needed. These are user-visible bugs for a background monitor that is meant to run for weeks.
2. **No tests, and code shaped so it cannot be tested (T1, A2, A3, A4).** There is no test target, CI never runs tests, and `AGENTS.md` names XCTest while the project's own testing skill mandates Swift Testing. Preferences are static enums bound to `UserDefaults.standard`, `SensorManager` owns a concrete `AranetClient`, and views call `Date()` directly, so none of the interesting logic can be exercised in isolation.
3. **Notification fan-out (C7, C8, K5).** Five objects observe AranetKit's `aranetReadingDidUpdate` and each re-derives state from `SensorManager`. Correct behavior depends on undocumented observer ordering and on AranetKit posting from the main actor. Each reading also triggers two full menu refreshes.
4. **Convention drift (S1–S14, A1).** Around 60 unqualified `Self.` accesses, 7 implicit returns, 7 files with more than one top-level type, 6 dead `StatusBarDisplayPreferences` helpers, and a line-length mismatch between `.swift-format` (147) and the conventions skill (187).

Severity counts: **High 5**, **Medium 23**, **Low 27**, Informational 6 (after the AranetKit 4.0.0 re-check: C3 High to Medium, C20 and D7 added).

### AranetKit 4.0.0 impact

AranetKit 4.0.0 shipped on 2026-10-22 with its own code review and a test suite behind it. The app still pins `3.5.2` with an `upToNextMajorVersion` requirement, so nothing changes until the dependency is bumped (D7). Once it is:

| 4.0.0 change | Effect on this review |
| --- | --- |
| Concurrent `scan()` calls join the in-flight scan; no continuation is lost | C3 loses its hang; the re-entrancy guard remains for app state |
| Ending the iteration of `monitor(from:)` (cancelling the consuming task or releasing the stream) stops the Bluetooth polling | New C20: `stopMonitoring()` now really stops the radio; 3.5.2 leaked a polling loop per device |
| `AranetClient` is `@MainActor`; readings are posted from the main actor by documented contract | K5 becomes a documented contract instead of an accident; the app compiles unchanged because its default isolation is already `MainActor` |
| `public protocol SensorClient` and `AranetClient.makeLive` | A3 uses AranetKit's protocol instead of defining one |
| `AranetError` conforms to `LocalizedError` | C4, C5, and the catch in `rescan()` get real messages from `error.localizedDescription` |
| `AranetError.operationInProgress` | Not reachable from the app (it never calls `readCurrentReadings`); listed for completeness |
| Deployment target macOS 13, `AranetUUID` is an enum, `AranetClient` no longer subclasses `NSObject` | No effect: the app targets 15.7 and uses none of these |

---

# Part 1: Findings

Severity key: **High** = user-visible defect or hang; **Medium** = latent defect, testability blocker, or structural debt that will cause defects; **Low** = convention, duplication, naming; **Info** = note, no action required.

## C. Correctness and behavior

### C1. Retry counter never resets after a successful reading — High

`SensorManager.swift:92-121`. `retryCount` is declared once outside the `while` loop and only ever increments. Every time the AranetKit stream ends (device out of range, Bluetooth toggled, sleep/wake) the counter grows. After the fifth stream end in the lifetime of the process the loop logs "Giving up" and returns, even if the device delivered readings for days in between. For a menu bar app that runs indefinitely this is a guaranteed eventual failure.

```swift
// Before
for await result in stream {
    if Task.isCancelled == true { return }
    switch result {
        case .success: break
        case .failure: break
    }
}

// After
for await result in stream {
    if Task.isCancelled == true { return }
    switch result {
        case .success:
            retryCount = 0
        case .failure(let error):
            Self.logger.error("Monitoring \(device.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
    }
}
```

### C2. Finished monitoring tasks are never removed, so Rescan cannot restart them — High

`SensorManager.swift:59-65` keys tasks by device id and skips any id already present. `monitorWithRetry` returns after giving up (line 112) or after an unexpected stream end, but the completed `Task` handle stays in `monitoringTasks`. `rescan()` calls `startMonitoring()`, which sees the stale handle and does nothing. The only way to resume monitoring that device is to relaunch the app.

Fix: clear the entry when the task body finishes, guarding against replacing a newer task.

```swift
// After
self.monitoringTasks[id] = Task { [weak self] in
    await self?.monitorWithRetry(id: id, device: monitored.device)
    self?.monitoringTaskDidFinish(id: id)
}

private func monitoringTaskDidFinish(id: UUID) -> Void {
    guard self.monitoringTasks[id]?.isCancelled == false else { return }
    self.monitoringTasks[id] = nil
}
```

(Compare the handle identity if cancellation semantics need to be exact; see Phase 1.)

AranetKit 4.0.0: unchanged. The stream still finishes after the first failed read, so every stream end costs one retry, and the `.failure` payload is an `AranetError` whose `localizedDescription` is now the real message, which makes the log line in C1 useful.

### C3. `rescan()` has no re-entrancy guard — Medium (High against AranetKit 3.5.2)

`SensorManager.swift:48-57`. The Rescan menu item is only disabled while the menu is open (`MenuManager.swift:106`), and the Devices tab has its own Rescan button (`DevicesViewController.swift:115-117`). Two quick triggers start two `AranetClient.scan()` calls.

Against AranetKit 3.5.2 this was a hang: `scan()` stored one `scanContinuation` (`AranetClient.swift:296`), the second call overwrote it, the first continuation was never resumed, and the first `Task` kept `self` alive forever. AranetKit 4.0.0 keeps every waiter in a `WaiterRegistry` and lets a second `scan()` join the scan in progress, so both callers receive the same device list and nothing hangs.

What remains is app state: both tasks run `startMonitoring()`, `isScanning` is set and cleared twice (two `aranetScanStateDidChange` posts, the second `defer` clears the flag while the other task may still be merging devices), and a scan started just before `applicationWillTerminate` is never cancelled (C19). Keep the guard and the stored handle.

```swift
// After
func rescan() -> Void {
    guard self.isScanning == false else { return }
    self.scanTask = Task { [weak self] in
        guard let self else { return }
        do {
            try await self.scan()
            self.startMonitoring()
        }
        catch {
            Self.logger.error("Rescan failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

Store `scanTask` and cancel it in `stopMonitoring()` so termination does not leave a scan running (see C19).

### C4. Stream failures are swallowed with no log and no UI state — Medium

`SensorManager.swift:101-104` discards `.failure` entirely. The only user-visible symptom of a dead connection is the progress bar turning dark red after `degradedCycles × interval` (15 minutes by default). `AGENTS.md` asks for "clear user feedback for Bluetooth connectivity and sensor communication issues". Add a `connectionState` (or `lastError`) to `MonitoredDevice`, set it from the stream, and show it in `SensorDeviceView` and the Devices tab status column instead of "Searching…". AranetKit 4.0.0: `AranetError` is a `LocalizedError`, so the state can show `error.localizedDescription` verbatim ("Failed to connect to device", "Operation timed out") instead of a generic Foundation message.

### C5. Initial scan failure is silent and never retried — Medium

`AppDelegate.swift:53-63`. If Bluetooth is off or unauthorized at launch, `scan()` throws, the error goes to `NSLog`, the status item shows the placeholder forever, and the menu says "No devices found". Nothing retries when Bluetooth comes back. Surface the error text in the menu ("Bluetooth is off. Turn it on and choose Rescan.") and retry automatically on the next `aranetScanStateDidChange` or a timer-backed backoff. AranetKit 4.0.0: the thrown `AranetError` describes itself ("Bluetooth access is not authorized. Please grant Bluetooth permissions in System Settings."), so the menu can show the library text and add only the retry hint.

### C6. Renaming a device does not refresh the menu or notification title — Medium

`DevicesViewController.swift:417-424` writes `DeviceNamePreferences.setName`, but nothing observes it. `SensorDeviceView.configure` (`SensorDeviceView.swift:46-49`) and `StatusNotificationCopy.content` (`StatusNotificationCopy.swift:14`) read the name lazily, so the new name appears only after the next reading (up to the device interval, 5 minutes by default). Post a change notification and route it through `MenuTrackingRefresh`, matching `statusBarDisplayPreferenceDidChange`.

### C7. Every reading triggers two full menu refreshes — Medium

`MenuManager.swift:47-52, 64-68` observes `aranetReadingDidUpdate` and schedules `refreshIfNeededOnMainThread()`. `AppDelegate.swift:72-77` observes the same notification and additionally calls `menuManager?.refreshIfNeeded()`. Both go through `MenuTrackingRefresh.perform`, so each reading reconfigures every device view twice, which also recreates each `UpdateCycleProgressView` timer twice (see C9). Keep one owner (resolved by C8).

### C8. Five observers of one third-party notification, with ordering-dependent correctness — High

`AppDelegate.swift:28-33`, `SensorManager.swift:28-33`, `MenuManager.swift:47-52`, `NotificationManager.swift:16-21`, `DevicesViewController.swift:72-77` all observe `Notification.Name.aranetReadingDidUpdate`. Only `SensorManager.handleReadingDidUpdate` updates `devices`; the other four read `sensorManager.devices` / `sortedDevices`. `NotificationManager` (line 30-51) and `DevicesViewController` (line 102-104) read synchronously inside their handlers, so they only see the new reading if `SensorManager`'s observer ran first. That holds today because `SensorManager` registers first, but `NotificationCenter` does not document delivery order. The AppKit-side handlers defer through the run loop and are safe by accident.

Fix: `SensorManager` becomes the single observer of the AranetKit notification. After mutating `devices` it posts an app-level `Notification.Name.sensorDevicesDidChange` carrying the device id. Everything else observes that. This also gives one place to assert main-actor delivery (K5) and makes C7 and C12 trivial.

### C9. `UpdateCycleProgressView.configure` recreates its timer on every call — Low

`UpdateCycleProgressView.swift:34-47, 81-90`. `startTimer()` invalidates and reallocates a `Timer` on every `configure`, which runs on every reading for every visible device (twice, per C7). Only start when `self.timer == nil`; `clear()` already stops it.

### C10. A two-metric selection with one missing value shows the scanning placeholder — Medium (confirm intent)

`StatusBarDisplayMetric.swift:93-96` returns `nil` unless every selected metric has a value, and `AppDelegate.swift:108-115` then shows the placeholder, even though a reading exists. Example: a user pins CO₂ and Pressure on an Aranet4 whose firmware omits pressure in a reading. Decide whether to show the available subset (recommended: fall back to `defaultValueStrings`) or keep the placeholder; either way, return `[String]` and let the caller decide (see S8).

### C11. Notification authorization is requested at every launch, before it is needed — Medium

`NotificationManager.swift:12-14` prompts the user for notification permission in `init`, regardless of whether any device has notifications enabled. Request authorization when the first per-device toggle is turned on (`DevicesViewController.swift:398-404`), with the async API (K2), and reflect a denied state in the Devices tab.

### C12. Status transitions are recomputed for every device on every reading — Low

`NotificationManager.swift:30-51` ignores which device the notification is about and iterates `sortedDevices`. After C8 the device id arrives with the notification; evaluate only that device.

### C13. `sortedDevices` sorts on every access — Low

`SensorManager.swift:72`. Called three times per menu refresh (`MenuManager.swift:73, 78, 115/149`), once per notification, once per outline reload. N is tiny, but `AGENTS.md` requires optimized code; cache the sorted array and invalidate on mutation (`didSet` on `devices`).

### C14. Copy table gaps silently drop notifications — Medium

`StatusNotificationCopy.swift:83-89`. `copy(for:transition:personality:)` returns `String?` from three nested dictionary lookups; a missing entry returns `nil` and `content` returns `nil`, so the notification is never delivered and nothing logs it. There are 4 × 4 × 4 = 64 required entries and nothing checks them. Add a parameterized test that asserts every combination is non-empty (T2), and consider a `switch`-based table so the compiler enforces exhaustiveness.

### C15. Settings tabs lay out against a fixed 420-point design inside a half-screen window — Low (confirm intent)

`SettingsWindowController.swift:105-117` sizes the window to half the visible screen on first show; `GeneralViewController.swift:28-29`, `AdvancedSettingsViewController.swift:26-27`, `AboutViewController.swift:23-24`, `DevicesViewController.swift:28-29` each hard-code 420 × N and rely on autoresizing masks to stretch. The screenshots in `docs/images` show this works, so it is intentional, but the duplicated arithmetic is the main reason A10 exists. No behavior change required; fold into A10 if layout is ever touched.

### C16. `fixedItemCount = 7` is hand-synchronized with `init` — Low

`MenuManager.swift:188-193`. Adding or removing a fixed menu item without updating the constant silently deletes or leaks items. Record `self.fixedItemCount = self.menu.items.count` at the end of `init`.

### C17. Outline data source indexes without bounds checks — Low

`DevicesViewController.swift:232-246`. `child:ofItem:` returns `self.deviceItems[index]` unguarded and returns `scanningItem` as a fallback for a missing `sensorManager`, while `numberOfChildrenOfItem` returns 0 in that case. Both run on the main actor so the counts agree in practice; guard with `indices.contains(index)` to keep the data source total.

### C18. KVO binding uses a string key path — Low

`AboutViewController.swift:60`. `"canCheckForUpdates"` is not checked by the compiler. Use `#keyPath(SPUUpdater.canCheckForUpdates)`.

### C19. Startup scan task is not stored or cancelled on termination — Low

`AppDelegate.swift:53-63`. `applicationWillTerminate` stops monitoring but an in-flight scan continues. Store the task (or move the startup sequence into `SensorManager.start()` with C3's `scanTask`) and cancel it in `stopMonitoring()`.

### C20. Cancelled monitoring kept AranetKit polling the device — Medium against 3.5.2, resolved by D7

`SensorManager.swift:67-70, 95-107`. `stopMonitoring()` cancels the app's task and `monitorWithRetry` returns from inside `for await`, which releases the stream. In AranetKit 3.5.2 that did nothing to the producer: the library's monitoring loop kept connecting and reading the device until the process exited, so a Rescan after a give-up, or a device removed from the list, left a Bluetooth polling loop behind. AranetKit 4.0.0 cancels the producer when the iteration ends (consumer cancelled or stream released), which makes the app's existing code correct without changes. Phase 1's `SensorManagerTests` assert it through the fake stream's `onTermination`.

## K. Concurrency (swift-concurrency-pro)

### K1. Timer callbacks allocate a `Task` per tick to hop to an actor they are already on — Medium

`StatusItemPlaceholderView.swift:40-46` and `UpdateCycleProgressView.swift:83-89`. Both timers are added to `RunLoop.main`, so the block already runs on the main thread, yet each tick spawns `Task { @MainActor in … }`. For the placeholder that is 30 task allocations per second and one extra run-loop turn of latency per frame. `MenuTrackingRefresh.swift:5-11` already shows the right pattern (`MainActor.assumeIsolated`). Factor one helper and use it in both views:

```swift
// MainRunLoopTimer.swift
enum MainRunLoopTimer {
    /// Schedules a repeating timer on the main run loop in `.common` mode so it keeps firing during menu tracking.
    static func scheduleRepeating(every interval: TimeInterval, _ block: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { block() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
```

### K2. Closure-based `UNUserNotificationCenter` APIs where async variants exist — Medium

`NotificationManager.swift:12` (`requestAuthorization(options:completionHandler:)`) and `:79` (`add(_:withCompletionHandler:)`). The skill rule is to prefer the `async` overloads. Both completion handlers run on an arbitrary queue and only `NSLog`. Replace with `try await center.requestAuthorization(options:)` and `try await center.add(request)` inside a stored task, and handle `CancellationError` separately from real errors.

### K3. Redundant isolation annotations under main-actor default isolation — Low

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set for the target, so `Task { @MainActor in }` at `SensorManager.swift:49, 61`, `StatusItemPlaceholderView.swift:41`, `UpdateCycleProgressView.swift:84`, and `@MainActor` on `MenuTrackingRefresh.perform` (`:5`), `StatusItemDisplayView.requiredWidth` (`:38`), `StatusItemPlaceholderView.requiredWidth` (`:65`) change nothing. Remove them so the remaining annotations signal real isolation changes. Keep `MainActor.assumeIsolated` where a nonisolated callback is bridged.

### K4. Legacy `Task.sleep(nanoseconds:)` with manual conversion — Low

`SensorManager.swift:119`. Use `Task.sleep(for: .seconds(delay))`. `try?` currently hides `CancellationError`; the loop re-checks `Task.isCancelled` so the result is correct, but make the intent explicit:

```swift
do { try await Task.sleep(for: .seconds(delay)) }
catch { return }
```

### K5. `@objc` observers depend on AranetKit posting from the main actor — Medium

All five handlers in C8 are selector-based, which bypasses isolation checking. Against AranetKit 3.5.2 they were safe only because `postReadingDidUpdate` happened to be called from `@MainActor` methods (`AranetClient.swift:420, 480`), with nothing documenting it. AranetKit 4.0.0 makes it a contract: `AranetClient` is `@MainActor`, `ReadingMonitor.publish` runs on the main actor, and the library's `AGENTS.md` states "Readings are posted to `NotificationCenter` from the main actor; consumers may rely on main-thread delivery." The risk shrinks from "accident" to "documented contract that the compiler still does not check". Mitigation stays the same and gets cheaper: add `MainActor.assertIsolated()` at the top of the single remaining handler after C8, and cite the AranetKit contract in `AGENTS.md`. Consuming `NotificationCenter.default.notifications(named:)` from a main-actor task owned by `SensorManager` remains the option that makes isolation checked.

### K6. Per-device unstructured tasks — Info

`SensorManager.swift:60-64` creates one `Task` per device in a loop. `structured.md` flags this pattern, but here the tasks are long-lived, keyed, individually cancellable, and have independent lifetimes, which is the legitimate case. Keep, add a doc comment stating why, and fix C2 so the registry stays accurate.

### K7. Plain `deinit` on a main-actor view controller — Low

`AboutViewController.swift:83-85` compiles because `unbind(_:)` is a nonisolated `NSObject` API, but `StatusItemPlaceholderView` and `UpdateCycleProgressView` use `isolated deinit`. Use `isolated deinit` here too so AppKit teardown is provably on the main actor. (Deployment target 15.7 satisfies the `isolated deinit` runtime requirement.)

### K8. Error logging sink is `NSLog` — Low

Seven sites (`AppDelegate.swift:62`, `GeneralViewController.swift:167`, `NotificationManager.swift:13, 80`, `SensorManager.swift:55, 111, 116`). Use `os.Logger` with subsystem `com.panjas.senor-particle` and one category per type; it is structured, filterable in Console, and `privacy:` annotations keep device names out of persisted logs by default.

## A. Architecture and structure

### A1. One primary type per file — Medium

| File | Top-level types | Action |
| --- | --- | --- |
| `SensorManager.swift` | `MonitoredDevice`, `SensorManager` | move `MonitoredDevice` to `MonitoredDevice.swift` |
| `StatusBarDisplayMetric.swift` | `StatusBarDisplaySelection`, `StatusBarDisplayPreferences`, `StatusBarDisplayMetric` | three files |
| `StatusItemDisplayView.swift` | `StatusItemDisplayValue`, `StatusItemDisplayView` | move the value struct |
| `DisplayUnitSystem.swift` | `DisplayUnitSystem`, `DisplayUnitSystemPreferences` | two files |
| `NotificationPersonality.swift` | `NotificationPersonality`, `NotificationPersonalityPreferences` | two files |
| `SettingsWindowController.swift` | `DegradedSituationPreferences`, `NotificationPreferences`, `DeviceNamePreferences`, `SettingsWindowController` | preferences move out (A2) |
| `DevicesViewController.swift` | `DevicesViewController`, `DeviceNameTextField`, `ScanningOutlineItem`, `DeviceOutlineItem`, `MetricOutlineItem` | `DeviceNameTextField` to its own file; the three outline items become `private` nested types of the controller (allowed exception) |

`AGENTS.md` ("Settings View Controllers") currently instructs agents to keep the shared preference helper types in `SettingsWindowController.swift`, which contradicts the conventions skill. Update that bullet when A2 lands.

### A2. Preferences are static enums bound to `UserDefaults.standard` — High (testability)

Five files, 22 call sites, string keys built inline (`"notifications.\(deviceId.uuidString)"`, `"deviceName.…"`). Nothing can be tested without polluting the real defaults domain, and change notifications are posted ad hoc (some setters post, some do not; `DisplayUnitSystemPreferences` posts even when unchanged). Introduce one injectable store:

```swift
// PreferencesStore.swift
final class PreferencesStore {
    static let shared = PreferencesStore(defaults: .standard)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var scanTimeout: TimeInterval { … }
    var degradedCycles: Int { … }
    var displayUnitSystem: DisplayUnitSystem { … }
    var notificationPersonality: NotificationPersonality { … }
    func deviceName(for deviceId: UUID) -> String? { … }
    func setDeviceName(_ name: String, for deviceId: UUID) -> Void { … }
    func notificationsEnabled(for deviceId: UUID) -> Bool { … }
    var statusBarSelection: StatusBarDisplaySelection? { … }
}
```

Keys live in one `private enum PreferenceKey`. Every setter compares before writing and posts one `Notification.Name.preferencesDidChange` with the changed key in `userInfo`. Consumers receive the store through their initializers (default `.shared`) so tests pass `UserDefaults(suiteName:)`. The existing enums can remain as thin forwarding shims during migration and be deleted at the end of Phase 2.

### A3. `SensorManager` owns a concrete `AranetClient` — High (testability)

`SensorManager.swift:16`. The retry/backoff, task registry, and device merge logic (C1–C3) are exactly what needs tests, and none of it is reachable without Bluetooth. AranetKit 4.0.0 ships the seam, so the app does not define its own protocol:

```swift
// AranetKit 4.0.0
@MainActor
public protocol SensorClient: AnyObject, Sendable {
    var verbose: Bool { get set }
    func scan(timeout: TimeInterval) async throws -> [AranetDevice]
    func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading
    func monitor(from device: AranetDevice) -> AsyncStream<Result<AranetReading, any Error>>
}
extension AranetClient: SensorClient {}
```

`SensorManager.init(client: any SensorClient = AranetClient())`; `AppDelegate` keeps calling `SensorManager()`. Tests supply a `FakeSensorClient` that records calls and returns `AsyncStream.makeStream(of:)` continuations they control; the fake has to implement all four members (`verbose` and `readCurrentReadings` as stubs). AranetKit's own fakes live in its test targets and are not exported, but `Tests/AranetCliTests/Fakes/FakeSensorClient.swift` in the aranet-kit repository is a working template. `AranetClient.makeLive` exists for callers that need a factory instead of an instance; the app does not.

### A4. Time is read directly from `Date()` — Medium (testability)

`UpdateCycleProgressView.swift:95, 120`, `StatusItemPlaceholderView.swift:35, 59`, `DevicesViewController.swift:127`, `SensorManager.swift:81`. Extract the cycle arithmetic into a pure value type and give it a clock:

```swift
// UpdateCycleCalculator.swift
struct UpdateCycleCalculator {
    let anchor: Date
    let startAgo: TimeInterval
    let interval: TimeInterval
    let degradedCycles: Int

    enum State: Equatable {
        case progressing(Double)
        case degraded
    }

    func state(at now: Date) -> State { … }
}
```

`UpdateCycleProgressView` keeps a calculator and calls `state(at: self.now())` where `now` is an injected `() -> Date` defaulting to `Date.init`. This also removes the duplicated elapsed/degraded computation in `refresh()` and `currentProgress()`.

### A5. Tuples where a named type is clearer — Low

`MenuManager.swift:12` `[UUID: (NSMenuItem, SensorDeviceView)]` → `private struct DeviceMenuEntry`. `StatusNotificationCopy.swift:11` `(title: String, body: String)?` → `struct StatusNotificationContent`.

### A6. Column and cell identifiers as raw strings — Low

`DevicesViewController.swift:41-48, 277, 292, 298, 302, 325-340, 345-371`. Seven column ids and eight cell ids are string literals compared in `switch`. Use `enum DeviceColumn: String { case device, uuid, name, type, status, menuBar, notifications }` with a computed `NSUserInterfaceItemIdentifier`, and derive cell ids from it.

### A7. Dead code — Medium

`StatusBarDisplayPreferences.title(for:reading:)` (`:98-101`), `defaultTitle(for:)` (`:103-108`), `postChangeNotification()` (`:132-134`), `maximumMetricCountReached(for:)` (`:118-121`), `hasSelection(on:)` (`:123-125`), `hasSelectionOnAnotherDevice(_:)` (`:127-130`) have no callers. `StatusBarDisplayMetric.defaultMetric(for:)` (`:241-244`) is used only by the dead `defaultTitle`. `AppDelegate.applyStatusBarValues` (`:128-135`) is an indirection with one live branch. `MenuManager.refreshIfNeeded` (`:59-62`) repeats the guard in `refreshIfNeededOnMainThread`. `MenuManager.menu` (`:6`) is never read outside the class and can be `private`. `AGENTS.md` ("no extra code") makes removal mandatory.

### A8. Duplication — Low

- `AppDelegate.applyCompactStatusBarValues` (`:137-160`) and `setStatusBarPlaceholder` (`:166-188`) share 14 lines (width/height, remove other view, `length`, clear title/image, attach, frame, autoresizing, display) → `installStatusItemView(_:width:)`.
- `AppDelegate` handlers (`:72-102`) are four copies of the same `MenuTrackingRefresh.perform` block → one `scheduleStatusRefresh(includingMenu:)`.
- `SettingsWindowController.swift:170-179` repeats the identifier array three times → one `private static let tabIdentifiers`.
- `DevicesViewController.swift:95, 107` repeat `(self.sensorManager?.isScanning ?? false) == false` → `private var canRescan: Bool`.
- `UpdateCycleProgressView.refresh` and `currentProgress` (`:92-123`) duplicate the elapsed/degraded computation → A4.
- `UpdateCycleProgressView.normalColor` (`:140-149`) rebuilds an `NSColor` from components; `Self.lightGreen.withAlphaComponent(alpha)` is equivalent.

### A9. Hand-rolled unit conversion that AranetKit already provides — Low

`StatusBarDisplayMetric.swift:156, 229-231` defines `picocuriesPerLiterPerBecquerelPerCubicMeter = 1/37`. AranetKit ships `UnitRadioactivity.picocuriesPerLiter` (`Units.swift`, unchanged in 4.0.0); use `radonConcentration.converted(to: .picocuriesPerLiter)`. AranetKit has no millirem unit, so `milliremsPerMicrosievert` stays (document it, or contribute `UnitRadiationDose.millirems` upstream and switch when the dependency is bumped).

### A10. Manual frame arithmetic across all Settings tabs — Low (optional)

`GeneralViewController.swift:27-121`, `AdvancedSettingsViewController.swift:25-55`, `AboutViewController.swift:22-76` compute every frame with inline offsets (`y -= 4 + 26`, `y: 160`, `y: 132`). An `NSStackView` per tab with `NSGridView` for label/control pairs removes roughly 100 lines and makes C15 irrelevant. Larger change, UI-only, schedule last.

### A11. No user-facing error surface — Medium

Related to C4, C5, K8. Decide one place to show operational state (recommended: a disabled info item at the top of the menu plus the Devices tab status column) and route scan errors, Bluetooth state, login-item failures (`GeneralViewController.swift:166-169`), and notification-posting failures there.

### A12. No localization — Info

All user-facing strings are inline literals and `String(format:)` is used without a locale, so the decimal separator is always ".". Acceptable for an English-only app; if that changes, route strings through `String(localized:)` and use `Locale.current` in the formats as files are touched. No action in this plan.

### A13. `NotificationPersonality` raw values skip 3 — Low

`NotificationPersonality.swift:4-8` (`overkill = 4`). A stored value of 3 silently maps to `.professional`. Either document the gap (removed case) in a doc comment or add an explicit migration. Do not renumber, that would change existing users' stored preference.

### A14. Non-final classes with no subclasses — Low

`AdvancedSettingsViewController`, `BatteryView`, `DevicesViewController`, `GeneralViewController`, `MenuManager`, `NotificationManager`, `SensorDeviceView`, `SensorManager`, `SettingsWindowController`, `UpdateCycleProgressView`. Mark `final` (the conventions skill forbids subclassable API; `AboutViewController`, `StatusItemDisplayView`, `StatusItemPlaceholderView` already are).

## S. Conventions (swift-coding-conventions)

### S1. Type-level members accessed without `Self.` — Low (many sites)

| File | Lines |
| --- | --- |
| `StatusBarDisplayMetric.swift` | 20, 25, 26, 35, 50, 51, 58, 59, 60, 65, 74, 82, 84, 88, 99, 114, 119, 120, 124, 128, 137, 138, 139, 238 |
| `ScanPreferences.swift` | 10, 11, 16, 17 |
| `DisplayUnitSystem.swift` | 24, 26, 31 |
| `NotificationPersonality.swift` | 25, 29 |
| `SensorSymbol.swift` | 36, 43 |
| `StatusNotificationCopy.swift` | 15, 17, 18, 88, 92, 93, 94, 95 |
| `UpdateCycleProgressView.swift` | 133 |

Most of these disappear with A2 (the preference enums are rewritten). The rest are mechanical.

### S2. Instance member accessed without `self.` — Low

`SensorDeviceView.swift:172` (`configureLabel(label, …)`).

### S3. Shorthand binding that shadows a type-level property — Low

`StatusBarDisplayMetric.swift:65, 82, 88, 119, 128` use `guard let selection` to bind the static `selection` property. The convention requires `guard let selection = Self.selection` so the scope of the identifier is visible. (Shorthand of parameters and locals, e.g. `SensorDeviceView.swift:61, 97, 219`, `SensorSymbol.swift:24`, `NotificationManager.swift:13, 80`, `SensorManager.swift:50`, is permitted.)

### S4. Implicit returns — Low

`ScanPreferences.swift:10`, `DisplayUnitSystem.swift:37`, `StatusBarDisplayMetric.swift:111-116, 124`, `StatusNotificationCopy.swift:88`, `UpdateCycleProgressView.swift:133`, `SensorDeviceView.swift:237`. `.swift-format` has `OmitExplicitReturns: false`, so `swift-format lint` will flag these once it runs in CI (D1).

### S5. Boolean expressions without explicit comparison — Low

`NotificationManager.swift:36` (`guard NotificationPreferences.isEnabled(for: id),`). Ternaries on a bare `Bool`: `AboutViewController.swift:11`, `AdvancedSettingsViewController.swift:15`, `DevicesViewController.swift:15, 294, 366`, `GeneralViewController.swift:17` → `self.isViewLoaded == true ? … : …`. Compound conditions the convention asks to nest: `StatusBarDisplayMetric.swift:84`, `SensorSymbol.swift:26`, `MenuManager.swift:73`.

### S6. Multi-condition `guard` statements — Low

The convention asks for one condition per `guard`: `AppDelegate.swift:108-112`; `DevicesViewController.swift:288-290, 400-402, 408-410, 419-421`; `DisplayUnitSystem.swift:24-26`; `NotificationManager.swift:36-43`; `SensorManager.swift:77-79`; `StatusBarDisplayMetric.swift:20-23, 31-33, 65-68, 88, 104-107, 119`. Apply where the split does not hurt readability; the formatter does not enforce this rule.

### S7. Switch patterns — Low

`AppDelegate.swift:130` (`case 1, 2:`), `StatusNotificationCopy.swift:45, 47` (multi-pattern cases). `default:` on otherwise exhaustive enums or optionals: `SensorSymbol.swift:14, 51`, `SensorDeviceView.swift:247`, `StatusNotificationCopy.swift:60`. Replace `case 1, 2:` with a range check; for the transition table, prefer explicit per-pair cases so a new `AranetStatusColor` case fails to compile.

### S8. Optional array return — Low

`StatusBarDisplayMetric.swift:93` `valueStrings(for:reading:) -> [String]?`. Return `[String]` and move the "all metrics present" decision to the caller (ties into C10).

### S9. Lines over the configured 147-character limit — Low

`AdvancedSettingsViewController.swift:53` (181), `StatusItemPlaceholderView.swift:99` (161), `BatteryView.swift:32` (150), `SensorDeviceView.swift:100` (149), `DevicesViewController.swift:293` (148). The conventions skill text says 187 while `.swift-format` enforces 147; align the two (recommendation: keep 147, it is what the formatter enforces, and note it in `AGENTS.md`).

### S10. Delegate conformance declared on the type line — Low

`MenuManager.swift:5` declares `NSMenuDelegate` inline while `SettingsWindowController` and `DevicesViewController` use extensions. Move `menuWillOpen`/`menuDidClose` into `extension MenuManager: NSMenuDelegate`.

### S11. Already compliant (no action)

Explicit `-> Void` on every function, `else`/`catch` on their own lines, same-line braces, `== true`/`== false` in conditions almost everywhere, no force unwraps, no `try!`, no implicitly unwrapped optionals, four-space indentation, ordered imports, `fileprivate` only where file-scoped. Keep it that way: D1 adds the lint gate.

### S12. Missing doc comments on non-obvious logic — Low

`SensorManager.monitorWithRetry` (backoff policy, give-up rule), `MenuTrackingRefresh` (why `.common` mode), `StatusBarDisplayPreferences.selection` (legacy `statusBarDisplay.metric` migration), `UpdateCycleProgressView` (cycle math, documented only in `AGENTS.md`), `MenuManager.reattachMenuItemView` (has one), `SettingsWindowController.switchToTab` (why `_ = newViewController.view`). `AGENTS.md` asks for `///` on complex logic.

### S13. Magic numbers — Low

`BatteryView.swift:10, 70-73` (7, 13, 38, 63, 88), `SensorDeviceView.swift:51, 56, 98, 100, 102` (56, 4, 2, 14), `StatusItemDisplayView.swift:76` (`- 0.5`), `AboutViewController.swift:40-73` (72, 160, 132, 109, 70, 160, 30), `StatusItemPlaceholderView.swift:86-87` (9, 5, 0.55). Name them as `private static let` constants next to the existing ones.

### S14. Instance constants that are really type constants — Low

`BatteryView.swift:7-10`, `SensorDeviceView.swift:20-34`: `private let` layout constants on every instance. Make them `private static let` and access via `Self.`, matching `StatusItemDisplayView`.

### S15. `fatalError` in `init?(coder:)` — Info

Nine identical `@available(*, unavailable) required init?(coder:)` stubs. Standard AppKit practice for code-built views; no action.

### S16. Setters that post change notifications even when unchanged — Low

`DisplayUnitSystem.swift:30-33`, `StatusBarDisplayMetric.swift:58-62`. Compare before writing; folded into A2.

## T. Testing (swift-testing-pro)

### T1. No tests, no test target, no test step in CI — High

`project.pbxproj` has one native target; the shared scheme's `TestAction` has no testables; `build.yml` and `release.yml` never run `xcodebuild test`. `AGENTS.md` says "Testing framework: XCTest" and "Tests are organized alongside source files in the Xcode project", neither of which matches the installed `swift-testing-pro` skill or reality.

Target state: a `SenorParticleTests` unit-test bundle (Swift Testing, `@testable import senor_particle`, `ENABLE_TESTABILITY` is already `YES` for Debug), with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` matching the app target so suites can touch main-actor types without ceremony; `xcodebuild test` in both workflows; `AGENTS.md` updated to "Swift Testing for unit and integration tests; XCTest only for UI tests".

### T2. Test inventory

Written against the shapes introduced by A2–A4. Suites are `struct`s, no `@Suite` unless a trait is needed, `#expect(x == false)` never `!x`, `#require` for unwraps, parameterized where cases repeat, `confirmation()` for notifications, no sleeps.

| Suite | What it proves | Depends on |
| --- | --- | --- |
| `StatusBarDisplayMetricTests` | `valueString` for every metric × unit system (parameterized, `zip` for pairwise), `nil` on missing values, exact formats (`%.1f °C`, 2-decimal inHg, 3-decimal µSv/h), `availableMetrics` keeps `allCases` order | A2 (unit system injected) |
| `StatusBarDisplayPreferencesTests` | legacy single-metric key migrates, duplicates dropped, cap at 2, toggle add/remove/switch device, empty selection clears, change notification posted once | A2 |
| `StatusNotificationCopyTests` | all 64 category × transition × personality entries non-empty (C14); same-color and `nil` transitions produce no content; title uses custom name then reading name; metric clause picks CO₂ → radiation → radon → generic | A2, A5 |
| `StatusTransitionTrackerTests` | first reading sets baseline without firing; disabling clears baseline; one event per transition; re-enabling does not replay | Phase 3 extraction |
| `UpdateCycleCalculatorTests` | progress 0 at anchor, wraps at `interval`, `ago` offsets the anchor, degraded exactly at `interval × cycles` (`>=`), interval fallback 300, `max(interval, 1)` | A4 |
| `SensorManagerTests` | backoff 5/10/20/40/80 s (clock injected), gives up after 5 consecutive failures, counter resets after success (C1), finished task removed and restartable (C2), second `rescan` while scanning is a no-op (C3), `stopMonitoring` cancels and the fake stream's `onTermination` fires (C20), devices merged not duplicated, `.failure` updates connection state (C4) | A3 (AranetKit `SensorClient`), A4, D7 |
| `PreferencesStoreTests` | degraded cycles clamp to 1…10 and default 3 on 0/negative; scan timeout defaults to 15 when unset; unit system falls back to injected `Locale`; invalid raw values fall back; setters do not post when unchanged | A2 |
| `BatterySymbolTests` | boundaries 12/13, 37/38, 62/63, 87/88, 100; critical at 6 vs 7 | extract `BatteryLevel` helper from `BatteryView` |
| `SensorSymbolTests` | `systemName` per type/status; `effectiveStatus` returns `.green` when only temperature/humidity present | none |
| `NotificationPersonalityTests` | raw value 3 falls back to `.professional`; `displayName` per case | none |

Tags: `.preferences`, `.formatting`, `.monitoring`, `.notifications`. Fixtures: one `AranetReading.fixture(…)` factory per device type in `Fixtures/AranetReading+Fixtures.swift`.

### T3. Concurrency testing

Per `swift-concurrency-pro/references/testing.md`: `SensorManagerTests` drive a fake `AsyncStream` continuation (`makeStream(of:)`) and cancel the monitoring task while it is suspended on the stream to prove the loop exits; no timing-based waits. The fake conforms to AranetKit 4.0.0's `SensorClient` (A3). Two lessons from the aranet-kit suite apply here: releasing an `AsyncStream` cancels its producer, so a test that wants the stream alive must keep the iterator in scope; and work the subject starts in its own `Task` may run after the call that started it returns, so tests wait for an observable effect (a recorded call, a continuation registered) before acting on it, never on ordering assumptions. Add a CI job variant with Thread Sanitizer (`-enableThreadSanitizer YES`) once the suite exists.

### T4. UI tests — Info

Swift Testing does not cover UI tests. A later XCTest UI target (menu opens, Settings tabs switch) is optional and not scheduled here.

## D. Tooling and documentation

### D1. CI has no lint or test gate — Medium

Add to `build.yml` (and the pull-request leg of `release.yml`), before the archive step:

```bash
xcrun swift-format lint --strict --recursive senor-particle SenorParticleTests
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle -destination "platform=macOS,arch=arm64" -derivedDataPath .build/DerivedData/CI -clonedSourcePackagesDirPath .build/SourcePackages
```

(`generic/platform=macOS` cannot run tests; the test step needs a concrete destination.)

### D2. Line-length disagreement — Low

See S9. Pick 147.

### D3. `AGENTS.md` statements that the plan changes — Medium

- "Testing framework: XCTest" → Swift Testing (T1).
- "Settings View Controllers … keep `SettingsWindowController.swift` focused on window, toolbar, and shared preference helper types" → preference types live in `PreferencesStore.swift` (A1, A2).
- "UI updates react to `Notification.Name.aranetReadingDidUpdate` from AranetKit (not app-local sensor notifications)" → inverted by C8: only `SensorManager` observes AranetKit; UI observes `sensorDevicesDidChange`.
- "Code Review: [Describe your code review process]" → point to this file.
- "[Add project-specific security guidelines]" → at least: no logging of device identifiers at `.public` privacy, Sparkle key handling already documented above it.
- Add the main-actor delivery contract for AranetKit notifications (K5) and the `os.Logger` subsystem/category convention (K8).
- AranetKit Integration bullet: record the 4.0.0 contracts the app relies on (readings posted from the main actor; a monitor stream stops its Bluetooth activity when the iteration ends; `SensorClient` is the injection point) and the dependency rule (`upToNextMajorVersion` from 4.0.0).

### D4. `UPDATES.md` entries — Low

Each phase that lands a decision (A2, C8, T1, D2, K8) adds an entry per the `recent-updates` skill, newest first, with the version it ships in.

### D5. Warnings as errors — Low

Once Phase 5 is clean, set `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` so convention regressions that the compiler can see (unused results, unreachable code) fail CI.

### D6. Versioning — Info

`UPDATES.md` records 1.2.0 as unpublished. Behavior fixes from Phases 1 and 3 join 1.2.0 if it is still unpublished when they land; otherwise they are a PATCH (`1.2.1`). Refactor-only phases do not bump. Follow the `semantic-versioning` skill at merge time.

### D7. AranetKit is pinned below 4.0.0 — Medium

`project.pbxproj:381-388` requires `upToNextMajorVersion` from `3.5.2`, and `Package.resolved` holds `75eedd0` (3.5.2). AranetKit 4.0.0 is a major release, so Xcode will not pick it up until the requirement is raised to `4.0.0`. The bump is low risk for this app:

- `AranetClient` is `@MainActor` and no longer an `NSObject`: the target already compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SensorManager` is main-actor isolated, and nothing relies on `NSObject` conformance.
- Deployment target macOS 13: the app targets 15.7.
- `AranetUUID` enum: unused by the app.
- Monitor termination semantics: an improvement the app gets for free (C20).

What the bump buys: C3 loses its hang, C20 is fixed, `error.localizedDescription` becomes meaningful (C4, C5), K5 rests on a documented contract, and A3 can use AranetKit's `SensorClient`. Do it first (Phase 0, step 0): change the requirement, let Xcode resolve `Package.resolved` to the `v4.0.0` tag, build, and run the app once against a real sensor (the AranetKit release itself has not been exercised on hardware since its rewrite; its own `TEST_PLAN.md` says so).

---

# Part 2: Fix plan

Six phases, each with a milestone that is observable from CI or from the running app. Phases 1–3 are ordered by dependency; 4–6 can be reordered. Size: S = under half a day, M = one to two days, L = several days. Every phase ends with the commits suggested in conventional-commit form and an `AGENTS.md`/`UPDATES.md` note where the phase changes a convention. Commits need explicit confirmation per the project's commit protocol.

## Phase 0: Safety net (size S)

**Milestone M0: CI builds, lints, and runs an empty test target on every push.**

Findings: D7, C20, T1 (target only), D1, D2, S9.

0. Raise the AranetKit requirement to `upToNextMajorVersion` from `4.0.0` in `project.pbxproj`, resolve packages so `Package.resolved` points at the `v4.0.0` tag, build, and run the app against a real sensor once (D7). This alone fixes C20 and the AranetKit half of C3.
1. Add a `SenorParticleTests` unit-test bundle target to the project, hosted by the app, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. One placeholder suite with a single trivial `@Test` so the step is green.
2. Add the test target to the shared scheme's `TestAction`.
3. Add the lint and test steps from D1 to `build.yml` and to the pull-request path of `release.yml`.
4. Wrap the five lines in S9. Decide D2 (147) and record it in `AGENTS.md`.
5. `AGENTS.md`: Testing section → Swift Testing for unit/integration, XCTest for UI tests, test commands with a concrete destination. `UPDATES.md` entry.

Acceptance: `Package.resolved` lists aranet-kit at version `4.0.0`; `xcrun swift-format lint --strict --recursive senor-particle` exits 0; `xcodebuild test … -destination "platform=macOS,arch=arm64"` runs one passing test; both workflows green; readings arrive from a real sensor.

Commits: `build(deps): adopt aranet-kit 4.0.0`, `build(tests): add swift testing unit test target`, `ci: lint and run unit tests before archiving`, `docs(agents): adopt swift testing and 147 columns`.

## Phase 1: Monitoring resilience (size M)

**Milestone M1: a device that drops off and comes back is monitored again, and Rescan always restarts monitoring. Proven by tests, not by waiting.**

Findings: C1, C2, C3, C4 (logging and state), C19, K4, K6, K8, A3, A1 (`MonitoredDevice.swift`).

1. Inject AranetKit's `SensorClient` (A3): `SensorManager.init(client: any SensorClient = AranetClient())`. No app-local protocol.
2. Move `MonitoredDevice` to its own file; add `connectionState` (`.connected`, `.reconnecting(attempt: Int)`, `.failed(String)`).
3. Rewrite `monitorWithRetry`: reset the counter on success (C1), log failures with `os.Logger` (K8), set `connectionState`, `Task.sleep(for:)` with explicit cancellation handling (K4), doc comment on the backoff policy (K6, S12).
4. Clear finished task handles (C2); add the `scanTask` handle and re-entrancy guard (C3); cancel both in `stopMonitoring()` (C19). Move the startup sequence from `AppDelegate` into `SensorManager.start()` so there is one place that scans then monitors.
5. Tests: `SensorManagerTests` from T2 with a `FakeSensorClient` conforming to AranetKit's protocol and an injected clock for the backoff schedule (so the 80-second wait is asserted, not waited for); one test cancels the monitoring task and expects the fake stream's `onTermination` (C20).
6. `UPDATES.md` entry (bug fixes worth remembering).

Acceptance: `SensorManagerTests` pass; manual check on hardware: power-cycle a sensor six times, confirm readings resume each time; trigger Rescan from the menu and from Settings in quick succession, confirm one scan.

Commits: `refactor(sensors): inject aranetkit sensor client`, `fix(sensors): reset retry count after reading`, `fix(sensors): restart monitoring after give up`, `fix(sensors): guard concurrent rescans`, `test(sensors): cover retry and rescan behavior`.

## Phase 2: Preferences and testability (size M)

**Milestone M2: every preference read or write goes through one injectable store, and every preference rule has a test.**

Findings: A2, A1 (preference files), C6, C10, S1 (preference files), S3, S4, S8, S16, A7, A9, D3.

1. Add `PreferencesStore.swift` (A2) with `PreferenceKey`; implement all current getters/setters with compare-before-write and a single `preferencesDidChange` notification carrying the key.
2. Migrate call sites file by file; keep the old enums as forwarding shims until the last caller moves, then delete them. Inject the store into `SensorManager`, `NotificationManager`, `MenuManager`, the four view controllers, `SensorDeviceView` (via `configure`), and `StatusBarDisplayMetric.valueString(for:unitSystem:)` (pass the unit system in rather than reading a global).
3. Split `StatusBarDisplayMetric.swift` into three files; delete the dead helpers (A7); return `[String]` from `valueStrings` (S8) and implement the C10 decision in `AppDelegate.updateStatusBar`; replace the radon constant with AranetKit's unit (A9); `Self.` and explicit returns throughout (S1, S3, S4).
4. Post the rename change through the store so the menu refreshes (C6).
5. Tests: `PreferencesStoreTests`, `StatusBarDisplayPreferencesTests`, `StatusBarDisplayMetricTests` with `UserDefaults(suiteName:)` and `removePersistentDomain` in a `deinit`/scope.
6. `AGENTS.md`: Settings View Controllers bullet, Display Unit System bullet (formatting now takes the unit system as a parameter), Status Item Display Selection bullet (store name). `UPDATES.md` entry.

Acceptance: `grep -rn "UserDefaults.standard" senor-particle` returns only `PreferencesStore.swift`; the three suites pass; renaming a device in Settings updates the open menu immediately.

Commits: `refactor(prefs): add injectable preferences store`, `refactor(prefs): migrate callers to preferences store`, `refactor(status): split status bar display files`, `fix(menu): refresh after device rename`, `test(prefs): cover preference rules and migration`.

## Phase 3: Notification pipeline (size M)

**Milestone M3: one observer of AranetKit, one app-level change notification, one menu refresh per reading, and notification copy proven complete.**

Findings: C7, C8, C11, C12, C14, K2, K5, A5, A11 (first slice).

1. `SensorManager` becomes the sole observer of `aranetReadingDidUpdate`; it posts `sensorDevicesDidChange` with `userInfo[deviceId]` after mutating state, and `MainActor.assertIsolated()` guards the handler (K5). Cite the AranetKit 4.0.0 main-actor delivery contract in `AGENTS.md`.
2. `AppDelegate`, `MenuManager`, `NotificationManager`, `DevicesViewController` observe `sensorDevicesDidChange` instead; remove `AppDelegate`'s `menuManager?.refreshIfNeeded()` duplication (C7).
3. Extract `StatusTransitionTracker` (pure: `previousStatuses`, `evaluate(deviceId:status:enabled:) -> Transition?`) from `NotificationManager`; `NotificationManager` evaluates only the changed device (C12) and delivers through the async `UNUserNotificationCenter` APIs (K2), requesting authorization lazily on first enable (C11).
4. `StatusNotificationContent` struct (A5); consider `switch`-based tables (C14).
5. Surface Bluetooth/scan errors in the menu (A11, C5 minimal: disabled info item with the error text and a retry on the next scan-state change).
6. Tests: `StatusTransitionTrackerTests`, `StatusNotificationCopyTests` (64-entry coverage), and a `confirmation()`-based test that one `sensorDevicesDidChange` is posted per AranetKit notification.
7. `AGENTS.md`: AranetKit Integration bullet (UI reacts to `sensorDevicesDidChange`), Status Notifications bullet. `UPDATES.md` entry.

Acceptance: `grep -rn "aranetReadingDidUpdate" senor-particle` returns only `SensorManager.swift`; each reading causes exactly one `refreshIfNeededOnMainThread` (assert via a counter in a debug build or log); notification permission is requested only after the first toggle.

Commits: `refactor(sensors): publish app-level device change notification`, `refactor(notifications): extract status transition tracker`, `fix(notifications): request authorization on first enable`, `feat(menu): show scan errors in status menu`, `test(notifications): cover transitions and copy tables`.

## Phase 4: Views and timers (size M)

**Milestone M4: no per-tick task allocation, cycle math is a tested value type, and view classes are thin.**

Findings: K1, K3, K7, A4, A8, C9, C16, C17, C18, A5 (`DeviceMenuEntry`), A6, S13, S14, A14.

1. `MainRunLoopTimer.swift` (K1); adopt in `StatusItemPlaceholderView` and `UpdateCycleProgressView`; start the timer only when nil (C9).
2. `UpdateCycleCalculator.swift` (A4) with injected `now`; `UpdateCycleProgressView` delegates to it; delete the duplicated computation (A8).
3. `AppDelegate`: `installStatusItemView(_:width:)`, `scheduleStatusRefresh(includingMenu:)`, remove `applyStatusBarValues` (A7, A8).
4. `MenuManager`: `DeviceMenuEntry`, `fixedItemCount` recorded in `init` (C16), `NSMenuDelegate` extension (S10), `private let menu`.
5. `DevicesViewController`: `DeviceColumn` enum (A6), bounds checks (C17), nested private outline items, `DeviceNameTextField.swift`, `canRescan` helper (A8).
6. `AboutViewController`: `#keyPath` (C18), `isolated deinit` (K7), named layout constants (S13).
7. `BatteryView`/`SensorDeviceView`/`StatusItemPlaceholderView`: static constants (S14), named magic numbers (S13), extract `BatteryLevel.symbolName(for:)` for testing.
8. Remove redundant isolation annotations (K3); mark classes `final` (A14).
9. Tests: `UpdateCycleCalculatorTests`, `BatterySymbolTests`, `SensorSymbolTests`.

Acceptance: `grep -rn "Task {" senor-particle` shows no timer-driven tasks; Instruments Allocations shows no `Task` churn while the placeholder animates; suites pass; menu and status item look identical to `docs/images`.

Commits: `refactor(views): share main run loop timer`, `refactor(views): extract update cycle calculator`, `refactor(app): consolidate status item installation`, `refactor(settings): type devices outline identifiers`, `test(views): cover cycle progress and battery levels`.

## Phase 5: Convention sweep (size S–M)

**Milestone M5: `swift-format lint --strict` is clean and the convention greps below return nothing.**

Findings: S1, S2, S5, S6, S7, S12, S16, remaining A1 splits (`DisplayUnitSystem`, `NotificationPersonality`, `StatusItemDisplayValue`), D5.

1. File-by-file pass in this order (smallest blast radius first): `ScanPreferences` (likely deleted by A2), `DisplayUnitSystem`, `NotificationPersonality`, `SensorSymbol`, `StatusNotificationCopy`, `SensorDeviceView`, `UpdateCycleProgressView`, `NotificationManager`, `AppDelegate`, `DevicesViewController`, `SettingsWindowController`, `GeneralViewController`, `AdvancedSettingsViewController`, `AboutViewController`, `MenuManager`, `SensorManager`.
2. Add doc comments listed in S12.
3. Enable `SWIFT_TREAT_WARNINGS_AS_ERRORS` (D5) once the build is warning-free.
4. Fill the `AGENTS.md` placeholders (code review process → this file; security guidelines). `UPDATES.md` entry.

Verification greps (all must return no lines; run from the repository root):

```bash
# implicit returns in single-line getters
grep -rnE '^\s*get \{ [^r}]*\}$' senor-particle | grep -v return
# ternary on a bare Bool
grep -rnE '\? \.on : \.off|isViewLoaded \?' senor-particle
# shorthand binding of a static property
grep -rnE 'guard let selection( |,)' senor-particle
# more than one top-level type per file
for f in senor-particle/*.swift; do n=$(grep -cE '^(final |private |fileprivate )*(class|struct|enum|actor|protocol) ' "$f"); [ "$n" -gt 1 ] && echo "$f: $n"; done
# non-final classes
grep -rnE '^class ' senor-particle
# NSLog
grep -rn 'NSLog' senor-particle
```

Commits: one `style(<scope>): apply coding conventions` per file group, `build: treat warnings as errors`, `docs(agents): fill review and security sections`.

## Phase 6: UX and layout follow-ups (size L, optional)

**Milestone M6: operational state is visible in the UI and Settings layout is declarative.**

Findings: C5 (full), A10, A11 (full), A12, A13, C15, T4.

1. Connection state per device in `SensorDeviceView` and the Devices tab (C4/A11 full slice), Bluetooth-off banner with automatic retry (C5).
2. Rebuild the Settings tabs with `NSStackView`/`NSGridView` (A10), which retires the 420-point constants (C15).
3. Document the personality raw-value gap (A13).
4. Optional XCTest UI target (T4).

Acceptance: product decision per item; screenshots in `docs/images` regenerated.

---

# Part 3: Decisions needed from the maintainer

1. **C10:** placeholder or partial values when one of two pinned metrics is missing? (Recommended: partial values.)
2. **C11:** request notification permission lazily on first enable, or keep the launch prompt? (Recommended: lazily.)
3. **D2:** 147 or 187 columns? (Recommended: 147, matches `.swift-format`.)
4. **K8:** adopt `os.Logger` now (Phase 1) or defer? (Recommended: now; it is a one-file change plus call sites touched anyway.)
5. **C14:** keep dictionary tables with a coverage test, or convert to `switch`? (Recommended: test first, convert only if the tables grow.)
6. **Phase 6:** schedule, or leave as backlog?
7. **D7:** bump AranetKit to 4.0.0 as the first step of Phase 0 (recommended; it needs one hardware run), or only when Phase 1 starts?

# Part 4: Verification commands (macOS, Xcode 26)

```bash
# Format and lint
xcrun swift-format format --in-place --recursive senor-particle SenorParticleTests
xcrun swift-format lint --strict --recursive senor-particle SenorParticleTests

# Build
xcodebuild -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -configuration Debug -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages build

# Unit tests (concrete destination required)
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle -destination "platform=macOS,arch=arm64" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages

# Unit tests under Thread Sanitizer
xcodebuild test -project senor-particle.xcodeproj -scheme senor-particle -destination "platform=macOS,arch=arm64" -enableThreadSanitizer YES -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages

# Static analyzer
xcodebuild analyze -project senor-particle.xcodeproj -scheme senor-particle -destination "generic/platform=macOS" -derivedDataPath .build/DerivedData/CLI -clonedSourcePackagesDirPath .build/SourcePackages
```
