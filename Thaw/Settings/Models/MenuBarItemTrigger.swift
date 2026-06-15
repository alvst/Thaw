//
//  MenuBarItemTrigger.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

// MARK: - TriggerCondition

/// A condition that decides whether a ``MenuBarItemTrigger`` is currently
/// satisfied, evaluated against a ``SystemState`` snapshot.
///
/// New condition kinds can be added as cases without changing the
/// surrounding trigger plumbing; each is independently gated by a
/// ``TriggerFeature`` flag (battery/power conditions are always available).
enum TriggerCondition: Codable, Hashable {
    // Power
    case batteryBelow(percentage: Double)
    case batteryAtOrAbove(percentage: Double)
    case onACPower
    case onBatteryPower
    case charging

    // Applications
    case frontmostApp(bundleID: String)
    case appRunning(bundleID: String)

    // Network
    case networkConnected
    case vpnActive
    case wifiSSID(name: String)

    // Devices
    case bluetoothConnected(name: String)
    case audioOutput(contains: String)
    case externalDisplayConnected

    // Time / Focus
    case schedule(startMinutes: Int, endMinutes: Int)
    case focusActive

    /// Returns whether the condition is satisfied by the given state at the
    /// given time.
    func isSatisfied(state: SystemState, now: Date = Date()) -> Bool {
        switch self {
        case let .batteryBelow(percentage):
            guard let level = state.power.batteryPercentage else { return false }
            return level < percentage
        case let .batteryAtOrAbove(percentage):
            guard let level = state.power.batteryPercentage else { return false }
            return level >= percentage
        case .onACPower:
            return state.power.isOnACPower
        case .onBatteryPower:
            return !state.power.isOnACPower
        case .charging:
            return state.power.isCharging
        case let .frontmostApp(bundleID):
            return !bundleID.isEmpty && state.frontmostAppBundleID == bundleID
        case let .appRunning(bundleID):
            return !bundleID.isEmpty && state.runningAppBundleIDs.contains(bundleID)
        case .networkConnected:
            return state.isNetworkConnected
        case .vpnActive:
            return state.isVPNActive
        case let .wifiSSID(name):
            return !name.isEmpty && state.wifiSSID?.caseInsensitiveCompare(name) == .orderedSame
        case let .bluetoothConnected(name):
            return !name.isEmpty && state.connectedBluetoothDeviceNames.contains {
                $0.localizedCaseInsensitiveContains(name)
            }
        case let .audioOutput(substring):
            return !substring.isEmpty && (state.audioOutputDeviceName?.localizedCaseInsensitiveContains(substring) ?? false)
        case .externalDisplayConnected:
            return state.externalDisplayConnected
        case let .schedule(start, end):
            return Self.isWithinSchedule(now: now, startMinutes: start, endMinutes: end)
        case .focusActive:
            return state.isFocusActive
        }
    }

    /// Whether `now` falls within the daily window `[start, end)`, handling
    /// windows that wrap past midnight.
    static func isWithinSchedule(now: Date, startMinutes: Int, endMinutes: Int) -> Bool {
        guard startMinutes != endMinutes else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let current = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if startMinutes < endMinutes {
            return current >= startMinutes && current < endMinutes
        }
        // Window wraps midnight (e.g. 22:00–06:00).
        return current >= startMinutes || current < endMinutes
    }
}

// MARK: - TriggerConditionKind

/// The user-selectable kind of a ``TriggerCondition``, used to drive the
/// settings UI independently of any value the condition carries.
enum TriggerConditionKind: String, CaseIterable, Identifiable {
    case batteryBelow
    case batteryAtOrAbove
    case onACPower
    case onBatteryPower
    case charging
    case frontmostApp
    case appRunning
    case networkConnected
    case vpnActive
    case wifiSSID
    case bluetoothConnected
    case audioOutput
    case externalDisplay
    case schedule
    case focusActive

    var id: String { rawValue }

    /// A human-readable description for the settings interface.
    var displayString: String {
        switch self {
        case .batteryBelow: "Battery is below"
        case .batteryAtOrAbove: "Battery is at or above"
        case .onACPower: "Connected to power"
        case .onBatteryPower: "Running on battery"
        case .charging: "Battery is charging"
        case .frontmostApp: "App is frontmost"
        case .appRunning: "App is running"
        case .networkConnected: "Network is connected"
        case .vpnActive: "VPN is active"
        case .wifiSSID: "Connected to Wi-Fi network"
        case .bluetoothConnected: "Bluetooth device is connected"
        case .audioOutput: "Audio output device"
        case .externalDisplay: "External display is connected"
        case .schedule: "During time window"
        case .focusActive: "Focus is active"
        }
    }

    /// Whether this kind carries a battery percentage threshold.
    var usesPercentage: Bool {
        self == .batteryBelow || self == .batteryAtOrAbove
    }

    /// The editor UI this kind needs.
    var editor: TriggerConditionEditor {
        switch self {
        case .batteryBelow, .batteryAtOrAbove: .percentage
        case .frontmostApp, .appRunning: .appPicker
        case .wifiSSID: .text(prompt: "Network name")
        case .bluetoothConnected: .text(prompt: "Device name")
        case .audioOutput: .text(prompt: "Device name contains")
        case .schedule: .timeRange
        case .onACPower, .onBatteryPower, .charging, .networkConnected,
             .vpnActive, .externalDisplay, .focusActive:
            .none
        }
    }

    /// The feature flag that must be enabled for this kind to be available,
    /// or `nil` for always-available power conditions.
    var requiredFeature: TriggerFeature? {
        switch self {
        case .batteryBelow, .batteryAtOrAbove, .onACPower, .onBatteryPower, .charging:
            nil
        case .frontmostApp: .frontmostApp
        case .appRunning: .appRunning
        case .networkConnected: .network
        case .vpnActive: .vpn
        case .wifiSSID: .wifiSSID
        case .bluetoothConnected: .bluetooth
        case .audioOutput: .audioOutput
        case .externalDisplay: .display
        case .schedule: .schedule
        case .focusActive: .focusMode
        }
    }
}

/// The kind of inline editor a condition needs in the settings UI.
enum TriggerConditionEditor: Equatable {
    case none
    case percentage
    case appPicker
    case text(prompt: String)
    case timeRange
}

// MARK: - TriggerCondition <-> Kind

extension TriggerCondition {
    /// The kind of this condition.
    var kind: TriggerConditionKind {
        switch self {
        case .batteryBelow: .batteryBelow
        case .batteryAtOrAbove: .batteryAtOrAbove
        case .onACPower: .onACPower
        case .onBatteryPower: .onBatteryPower
        case .charging: .charging
        case .frontmostApp: .frontmostApp
        case .appRunning: .appRunning
        case .networkConnected: .networkConnected
        case .vpnActive: .vpnActive
        case .wifiSSID: .wifiSSID
        case .bluetoothConnected: .bluetoothConnected
        case .audioOutput: .audioOutput
        case .externalDisplayConnected: .externalDisplay
        case .schedule: .schedule
        case .focusActive: .focusActive
        }
    }

    /// The battery percentage threshold, when this condition carries one.
    var percentage: Double? {
        switch self {
        case let .batteryBelow(percentage), let .batteryAtOrAbove(percentage): percentage
        default: nil
        }
    }

    /// The bundle identifier, for application conditions.
    var bundleID: String? {
        switch self {
        case let .frontmostApp(bundleID), let .appRunning(bundleID): bundleID
        default: nil
        }
    }

    /// The free-text value, for text conditions.
    var text: String? {
        switch self {
        case let .wifiSSID(name), let .bluetoothConnected(name), let .audioOutput(name): name
        default: nil
        }
    }

    /// The schedule window in minutes-from-midnight, for schedule conditions.
    var scheduleWindow: (start: Int, end: Int)? {
        switch self {
        case let .schedule(start, end): (start, end)
        default: nil
        }
    }

    /// Builds the default condition for the given kind.
    static func defaultCondition(for kind: TriggerConditionKind) -> TriggerCondition {
        switch kind {
        case .batteryBelow: .batteryBelow(percentage: 20)
        case .batteryAtOrAbove: .batteryAtOrAbove(percentage: 80)
        case .onACPower: .onACPower
        case .onBatteryPower: .onBatteryPower
        case .charging: .charging
        case .frontmostApp: .frontmostApp(bundleID: "")
        case .appRunning: .appRunning(bundleID: "")
        case .networkConnected: .networkConnected
        case .vpnActive: .vpnActive
        case .wifiSSID: .wifiSSID(name: "")
        case .bluetoothConnected: .bluetoothConnected(name: "")
        case .audioOutput: .audioOutput(contains: "")
        case .externalDisplay: .externalDisplayConnected
        case .schedule: .schedule(startMinutes: 9 * 60, endMinutes: 17 * 60)
        case .focusActive: .focusActive
        }
    }

    /// Converts to the given kind, preserving a compatible carried value
    /// (percentage, bundle id, text, or schedule) where possible.
    static func make(kind: TriggerConditionKind, preserving old: TriggerCondition) -> TriggerCondition {
        switch kind {
        case .batteryBelow: .batteryBelow(percentage: old.percentage ?? 20)
        case .batteryAtOrAbove: .batteryAtOrAbove(percentage: old.percentage ?? 80)
        case .frontmostApp: .frontmostApp(bundleID: old.bundleID ?? "")
        case .appRunning: .appRunning(bundleID: old.bundleID ?? "")
        case .wifiSSID: .wifiSSID(name: old.text ?? "")
        case .bluetoothConnected: .bluetoothConnected(name: old.text ?? "")
        case .audioOutput: .audioOutput(contains: old.text ?? "")
        case .schedule:
            old.scheduleWindow.map { TriggerCondition.schedule(startMinutes: $0.start, endMinutes: $0.end) }
                ?? .schedule(startMinutes: 9 * 60, endMinutes: 17 * 60)
        case .onACPower, .onBatteryPower, .charging, .networkConnected,
             .vpnActive, .externalDisplay, .focusActive:
            defaultCondition(for: kind)
        }
    }

    /// Returns a copy with the battery percentage replaced.
    func withPercentage(_ value: Double) -> TriggerCondition {
        switch self {
        case .batteryBelow: .batteryBelow(percentage: value)
        case .batteryAtOrAbove: .batteryAtOrAbove(percentage: value)
        default: self
        }
    }

    /// Returns a copy with the bundle identifier replaced.
    func withBundleID(_ value: String) -> TriggerCondition {
        switch self {
        case .frontmostApp: .frontmostApp(bundleID: value)
        case .appRunning: .appRunning(bundleID: value)
        default: self
        }
    }

    /// Returns a copy with the free-text value replaced.
    func withText(_ value: String) -> TriggerCondition {
        switch self {
        case .wifiSSID: .wifiSSID(name: value)
        case .bluetoothConnected: .bluetoothConnected(name: value)
        case .audioOutput: .audioOutput(contains: value)
        default: self
        }
    }

    /// Returns a copy with the schedule window replaced.
    func withSchedule(start: Int, end: Int) -> TriggerCondition {
        switch self {
        case .schedule: .schedule(startMinutes: start, endMinutes: end)
        default: self
        }
    }
}

// MARK: - MenuBarItemTrigger

/// A user-defined rule that conditionally reveals or hides a single menu
/// bar item based on a ``TriggerCondition``.
///
/// When the condition becomes satisfied, the target item is moved into
/// ``revealSection``; when it is no longer satisfied, the item is returned
/// to ``hideSection``. When ``invert`` is `true`, the reveal/hide roles
/// swap, so the item is hidden while the condition is met.
struct MenuBarItemTrigger: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var itemIdentifier: String
    var itemDisplayName: String
    var revealSection: MenuBarSection.Name
    var hideSection: MenuBarSection.Name
    var condition: TriggerCondition

    /// When `true`, the item is hidden (not revealed) while the condition
    /// is satisfied. Gated by the `invertAction` feature flag in the UI.
    var invert: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        isEnabled: Bool = true,
        itemIdentifier: String = "",
        itemDisplayName: String = "",
        revealSection: MenuBarSection.Name = .visible,
        hideSection: MenuBarSection.Name = .hidden,
        condition: TriggerCondition = .batteryBelow(percentage: 20),
        invert: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.itemIdentifier = itemIdentifier
        self.itemDisplayName = itemDisplayName
        self.revealSection = revealSection
        self.hideSection = hideSection
        self.condition = condition
        self.invert = invert
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, itemIdentifier, itemDisplayName
        case revealSection, hideSection, condition, invert
    }

    /// Forward-compatible decoding: `invert` was added after the first
    /// release and is absent from triggers persisted before then.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        itemIdentifier = try container.decode(String.self, forKey: .itemIdentifier)
        itemDisplayName = try container.decode(String.self, forKey: .itemDisplayName)
        revealSection = try container.decode(MenuBarSection.Name.self, forKey: .revealSection)
        hideSection = try container.decode(MenuBarSection.Name.self, forKey: .hideSection)
        condition = try container.decode(TriggerCondition.self, forKey: .condition)
        invert = try container.decodeIfPresent(Bool.self, forKey: .invert) ?? false
    }

    /// Evaluates whether the target item should be revealed, accounting for
    /// the invert flag.
    func shouldReveal(state: SystemState, now: Date = Date()) -> Bool {
        let satisfied = condition.isSatisfied(state: state, now: now)
        return invert ? !satisfied : satisfied
    }

    /// A name suitable for display.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        if !itemDisplayName.isEmpty { return itemDisplayName }
        return "Untitled Trigger"
    }
}
