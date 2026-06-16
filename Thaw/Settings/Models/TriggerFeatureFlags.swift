//
//  TriggerFeatureFlags.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine
import Foundation
import SwiftUI

// MARK: - TriggerFeature

/// An individually toggleable menu bar item trigger capability.
///
/// Each feature gates both (a) whether its condition kind appears in the
/// trigger editor and (b) whether its backing monitor runs. Features are
/// independent of one another, so they can be enabled and debugged one at a
/// time from the Developer settings pane. Battery/power conditions are
/// always available and are intentionally not represented here.
enum TriggerFeature: String, CaseIterable, Identifiable {
    case frontmostApp
    case appRunning
    case network
    case vpn
    case wifiSSID
    case bluetooth
    case audioOutput
    case display
    case schedule
    case focusMode
    case location
    case lowPowerMode
    case thermalPressure
    case invertAction

    var id: String { rawValue }

    /// A short title for the Developer pane.
    var title: String {
        switch self {
        case .frontmostApp: "Frontmost app"
        case .appRunning: "App running"
        case .network: "Network connectivity"
        case .vpn: "VPN active"
        case .wifiSSID: "Wi-Fi network (SSID)"
        case .bluetooth: "Bluetooth device"
        case .audioOutput: "Audio output device"
        case .display: "External display"
        case .schedule: "Time schedule"
        case .focusMode: "Focus / Do Not Disturb"
        case .location: "Location"
        case .lowPowerMode: "Low Power Mode"
        case .thermalPressure: "Thermal pressure"
        case .invertAction: "Invert action (hide when met)"
        }
    }

    /// A one-line description for the Developer pane.
    var detail: String {
        switch self {
        case .frontmostApp: "Reveal an item only while a chosen app is frontmost."
        case .appRunning: "Reveal an item while a chosen app is running."
        case .network: "Reveal an item based on network connectivity."
        case .vpn: "Reveal an item while a VPN tunnel is active."
        case .wifiSSID: "Reveal an item while connected to a specific Wi-Fi network."
        case .bluetooth: "Reveal an item while a Bluetooth device is connected."
        case .audioOutput: "Reveal an item based on the current audio output device."
        case .display: "Reveal an item while an external display is connected."
        case .schedule: "Reveal an item during a time-of-day window."
        case .focusMode: "Reveal an item while a macOS Focus is active."
        case .location: "Reveal an item while you're near a saved place (uses Location)."
        case .lowPowerMode: "Reveal an item while macOS Low Power Mode is on."
        case .thermalPressure: "Reveal an item when the system is under thermal pressure."
        case .invertAction: "Allow triggers to hide (instead of reveal) when the condition is met."
        }
    }

    /// Whether the feature relies on private/fragile APIs or permissions and
    /// may not work reliably on all systems.
    var isExperimental: Bool {
        switch self {
        case .wifiSSID, .focusMode, .location: true
        default: false
        }
    }
}

// MARK: - TriggerFeatureFlagsManager

/// Persists and publishes the set of enabled ``TriggerFeature`` values.
///
/// Stored as a list of raw values under a single Defaults key so new
/// features can be added without a migration. Everything defaults to off
/// except battery/power, which is not a flag.
@MainActor
final class TriggerFeatureFlagsManager: ObservableObject {
    @Published private var enabledRawValues: Set<String> {
        didSet {
            guard !suppressPersist else { return }
            persist()
        }
    }

    private var suppressPersist = false

    init() {
        suppressPersist = true
        enabledRawValues = Self.load()
        suppressPersist = false
    }

    /// Returns whether the given feature is enabled.
    func isEnabled(_ feature: TriggerFeature) -> Bool {
        enabledRawValues.contains(feature.rawValue)
    }

    /// Enables or disables the given feature.
    func setEnabled(_ feature: TriggerFeature, _ isOn: Bool) {
        if isOn {
            enabledRawValues.insert(feature.rawValue)
        } else {
            enabledRawValues.remove(feature.rawValue)
        }
    }

    /// A binding suitable for a SwiftUI toggle.
    func binding(for feature: TriggerFeature) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isEnabled(feature) ?? false },
            set: { [weak self] newValue in self?.setEnabled(feature, newValue) }
        )
    }

    private func persist() {
        Defaults.set(Array(enabledRawValues), forKey: .triggerFeatureFlags)
    }

    private static func load() -> Set<String> {
        let raw = Defaults.stringArray(forKey: .triggerFeatureFlags) ?? []
        return Set(raw)
    }
}
