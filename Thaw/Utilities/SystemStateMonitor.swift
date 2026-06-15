//
//  SystemStateMonitor.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import Combine
import CoreAudio
import CoreWLAN
import Foundation
import IOBluetooth
import Network

// MARK: - SystemState

/// A snapshot of the system signals that menu bar item triggers evaluate
/// against. Every field is cheap to compare so the monitor can publish only
/// on real changes.
struct SystemState: Equatable {
    /// Battery / power source state.
    var power: PowerState

    /// Bundle identifier of the frontmost application, if any.
    var frontmostAppBundleID: String?

    /// Bundle identifiers of all running (regular) applications.
    var runningAppBundleIDs: Set<String>

    /// Whether the machine has general network connectivity.
    var isNetworkConnected: Bool

    /// Whether a VPN tunnel appears to be active.
    var isVPNActive: Bool

    /// The current Wi-Fi network name, if available (best-effort).
    var wifiSSID: String?

    /// Names of currently connected Bluetooth devices.
    var connectedBluetoothDeviceNames: Set<String>

    /// The name of the current default audio output device.
    var audioOutputDeviceName: String?

    /// The number of active displays.
    var screenCount: Int

    /// Whether at least one external (non-built-in) display is connected.
    var externalDisplayConnected: Bool

    /// Whether a macOS Focus / Do Not Disturb appears to be active
    /// (best-effort).
    var isFocusActive: Bool

    init(
        power: PowerState = PowerState(batteryPercentage: nil, isOnACPower: true, isCharging: false),
        frontmostAppBundleID: String? = nil,
        runningAppBundleIDs: Set<String> = [],
        isNetworkConnected: Bool = true,
        isVPNActive: Bool = false,
        wifiSSID: String? = nil,
        connectedBluetoothDeviceNames: Set<String> = [],
        audioOutputDeviceName: String? = nil,
        screenCount: Int = 1,
        externalDisplayConnected: Bool = false,
        isFocusActive: Bool = false
    ) {
        self.power = power
        self.frontmostAppBundleID = frontmostAppBundleID
        self.runningAppBundleIDs = runningAppBundleIDs
        self.isNetworkConnected = isNetworkConnected
        self.isVPNActive = isVPNActive
        self.wifiSSID = wifiSSID
        self.connectedBluetoothDeviceNames = connectedBluetoothDeviceNames
        self.audioOutputDeviceName = audioOutputDeviceName
        self.screenCount = screenCount
        self.externalDisplayConnected = externalDisplayConnected
        self.isFocusActive = isFocusActive
    }
}

// MARK: - SystemStateMonitor

/// Aggregates several system signals into a single published
/// ``SystemState``, starting only the monitors whose feature flag is
/// enabled so disabled sources cost nothing.
///
/// Event-driven sources (power, frontmost/running app, display, network)
/// update the state immediately. Heavier sources (audio output, Bluetooth,
/// VPN, Wi-Fi SSID, Focus) are sampled on a single low-frequency poll while
/// their flag is enabled. Trigger evaluation already debounces, so the poll
/// latency is not user-visible.
@MainActor
final class SystemStateMonitor: ObservableObject {
    @Published private(set) var state = SystemState()

    private weak var flags: TriggerFeatureFlagsManager?

    private let powerMonitor = PowerSourceMonitor()

    private var cancellables = Set<AnyCancellable>()

    // Event-driven source handles.
    private var workspaceObservers = [NSObjectProtocol]()
    private var screenObserver: NSObjectProtocol?
    private var pathMonitor: NWPathMonitor?

    // Poll timer for the sampled sources.
    private var pollTimer: Timer?

    private let diagLog = DiagLog(category: "SystemStateMonitor")

    // MARK: Lifecycle

    /// Starts monitoring, observing the given feature flags so monitors can
    /// be (de)activated as flags change.
    func start(flags: TriggerFeatureFlagsManager) {
        self.flags = flags

        powerMonitor.start()
        powerMonitor.$state
            .removeDuplicates()
            .sink { [weak self] power in
                self?.update { $0.power = power }
            }
            .store(in: &cancellables)

        flags.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // Reconfigure after the flag set has actually mutated.
                DispatchQueue.main.async { self?.reconfigure() }
            }
            .store(in: &cancellables)

        // Seed the static portions of the state up front.
        update {
            $0.power = self.powerMonitor.state
            $0.screenCount = NSScreen.screens.count
            $0.externalDisplayConnected = Self.hasExternalDisplay()
        }

        reconfigure()
    }

    /// Starts or stops individual monitors to match the current flags.
    private func reconfigure() {
        guard let flags else { return }

        setFrontmostAppMonitoring(flags.isEnabled(.frontmostApp) || flags.isEnabled(.appRunning))
        setDisplayMonitoring(flags.isEnabled(.display))
        setNetworkMonitoring(flags.isEnabled(.network) || flags.isEnabled(.vpn))

        let needsPoll = flags.isEnabled(.audioOutput)
            || flags.isEnabled(.bluetooth)
            || flags.isEnabled(.vpn)
            || flags.isEnabled(.wifiSSID)
            || flags.isEnabled(.focusMode)
        setPolling(needsPoll)

        // Run one immediate sample so newly enabled sources populate now.
        samplePolledSources()
    }

    // MARK: State update

    /// Applies a mutation and republishes only when the state changed.
    private func update(_ mutate: (inout SystemState) -> Void) {
        var copy = state
        mutate(&copy)
        if copy != state {
            state = copy
        }
    }

    // MARK: Frontmost / running apps

    private func setFrontmostAppMonitoring(_ enabled: Bool) {
        let isRunning = !workspaceObservers.isEmpty
        guard enabled != isRunning else {
            if enabled { refreshApps() }
            return
        }

        if enabled {
            let center = NSWorkspace.shared.notificationCenter
            let names: [NSNotification.Name] = [
                NSWorkspace.didActivateApplicationNotification,
                NSWorkspace.didLaunchApplicationNotification,
                NSWorkspace.didTerminateApplicationNotification,
            ]
            for name in names {
                let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshApps() }
                }
                workspaceObservers.append(token)
            }
            refreshApps()
        } else {
            for token in workspaceObservers {
                NSWorkspace.shared.notificationCenter.removeObserver(token)
            }
            workspaceObservers.removeAll()
        }
    }

    private func refreshApps() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let running = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleIdentifier)
        )
        update {
            $0.frontmostAppBundleID = frontmost
            $0.runningAppBundleIDs = running
        }
    }

    // MARK: Display

    private func setDisplayMonitoring(_ enabled: Bool) {
        if enabled, screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDisplays() }
            }
            refreshDisplays()
        } else if !enabled, let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    private func refreshDisplays() {
        let count = NSScreen.screens.count
        let external = Self.hasExternalDisplay()
        update {
            $0.screenCount = count
            $0.externalDisplayConnected = external
        }
    }

    private static func hasExternalDisplay() -> Bool {
        // The built-in display reports a builtin flag via its device
        // description; any screen without it is treated as external.
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(number.uint32Value)
            if CGDisplayIsBuiltin(displayID) == 0 {
                return true
            }
        }
        return false
    }

    // MARK: Network

    private func setNetworkMonitoring(_ enabled: Bool) {
        if enabled, pathMonitor == nil {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                let connected = path.status == .satisfied
                Task { @MainActor in
                    self?.update { $0.isNetworkConnected = connected }
                }
            }
            monitor.start(queue: DispatchQueue(label: "com.stonerl.Thaw.networkMonitor"))
            pathMonitor = monitor
        } else if !enabled, let monitor = pathMonitor {
            monitor.cancel()
            pathMonitor = nil
        }
    }

    // MARK: Polled sources

    private func setPolling(_ enabled: Bool) {
        if enabled, pollTimer == nil {
            let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.samplePolledSources() }
            }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
        } else if !enabled {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    private func samplePolledSources() {
        guard let flags else { return }

        let audio = flags.isEnabled(.audioOutput) ? Self.defaultAudioOutputDeviceName() : nil
        let bluetooth = flags.isEnabled(.bluetooth) ? Self.connectedBluetoothDeviceNames() : []
        let vpn = flags.isEnabled(.vpn) ? Self.isVPNActive() : false
        let ssid = flags.isEnabled(.wifiSSID) ? Self.currentWiFiSSID() : nil
        let focus = flags.isEnabled(.focusMode) ? Self.isFocusActive() : false

        update {
            if flags.isEnabled(.audioOutput) { $0.audioOutputDeviceName = audio }
            if flags.isEnabled(.bluetooth) { $0.connectedBluetoothDeviceNames = bluetooth }
            if flags.isEnabled(.vpn) { $0.isVPNActive = vpn }
            if flags.isEnabled(.wifiSSID) { $0.wifiSSID = ssid }
            if flags.isEnabled(.focusMode) { $0.isFocusActive = focus }
        }
    }

    // MARK: Sampling helpers

    /// Returns the name of the current default audio output device.
    static func defaultAudioOutputDeviceName() -> String? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let nameStatus = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
        guard nameStatus == noErr, let cfName = name?.takeRetainedValue() else { return nil }
        return cfName as String
    }

    /// Returns the names of all currently connected Bluetooth devices.
    static func connectedBluetoothDeviceNames() -> Set<String> {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        var names = Set<String>()
        for device in devices where device.isConnected() {
            if let name = device.name, !name.isEmpty {
                names.insert(name)
            }
        }
        return names
    }

    /// Heuristically detects an active VPN by inspecting the scoped system
    /// proxy settings for tunnel interface names.
    static func isVPNActive() -> Bool {
        guard
            let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
            let scoped = settings["__SCOPED__"] as? [String: Any]
        else {
            return false
        }
        let tunnelPrefixes = ["tap", "tun", "ppp", "ipsec", "utun"]
        for key in scoped.keys {
            if tunnelPrefixes.contains(where: { key.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Returns the current Wi-Fi SSID, if available. Requires Location
    /// permission on recent macOS; returns `nil` otherwise (best-effort).
    static func currentWiFiSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    /// Best-effort detection of an active Focus / Do Not Disturb by reading
    /// the Do Not Disturb assertions store. Returns `false` on any failure.
    static func isFocusActive() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        guard
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let records = json["data"] as? [[String: Any]],
            let first = records.first,
            let assertions = first["storeAssertionRecords"] as? [[String: Any]]
        else {
            return false
        }
        return !assertions.isEmpty
    }
}
