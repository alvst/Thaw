//
//  DeveloperSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

// MARK: - DeveloperSettingsPane

/// Developer settings: per-source feature flags for menu bar item triggers
/// and a live readout of the aggregated system state, so each trigger
/// source can be enabled and debugged in isolation.
struct DeveloperSettingsPane: View {
    @ObservedObject private var flags: TriggerFeatureFlagsManager

    /// A direct, flag-independent snapshot of the system, refreshed on a
    /// timer while the pane is visible so the readout always shows ground
    /// truth (the trigger monitors themselves remain gated by the flags).
    @State private var liveState = SystemState()

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    init(manager: MenuBarItemTriggersManager) {
        flags = manager.featureFlags
    }

    var body: some View {
        IceForm {
            introSection
            flagsSection
            liveStateSection
        }
        .onAppear { liveState = SystemStateMonitor.fullSnapshot(flags: flags) }
        .onReceive(refreshTimer) { _ in
            liveState = SystemStateMonitor.fullSnapshot(flags: flags)
        }
    }

    // MARK: Intro

    private var introSection: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Trigger Feature Flags")
                    .font(.headline)
                Text("Enable experimental trigger sources one at a time. Each flag turns on its condition in the Triggers pane and starts its background monitor. Battery and power conditions are always available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    // MARK: Flags

    private var flagsSection: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(TriggerFeature.allCases.enumerated()), id: \.element.id) { index, feature in
                    if index > 0 {
                        Divider()
                    }
                    flagRow(feature)
                        .padding(.vertical, 8)
                }
            }
            .padding(8)
        }
    }

    private func flagRow(_ feature: TriggerFeature) -> some View {
        Toggle(isOn: flags.binding(for: feature)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.title)
                    if feature.isExperimental {
                        Text("Experimental")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.25), in: Capsule())
                    }
                }
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Live state

    private var liveStateSection: some View {
        IceSection("Live System State", options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 6) {
                let state = liveState
                stateRow("Battery", batteryString(state.power))
                stateRow("Power source", state.power.isOnACPower ? "AC power" : "Battery")
                stateRow("Charging", state.power.isCharging ? "Yes" : "No")
                stateRow("Frontmost app", state.frontmostAppBundleID ?? "—")
                stateRow("Running apps", "\(state.runningAppBundleIDs.count)")
                stateRow("Network", state.isNetworkConnected ? "Connected" : "Offline")
                stateRow("VPN", state.isVPNActive ? "Active" : "Inactive")
                stateRow("Wi-Fi SSID", flags.isEnabled(.wifiSSID) ? (state.wifiSSID ?? "—") : "Enable flag to read")
                stateRow("Bluetooth", flags.isEnabled(.bluetooth) ? state.connectedBluetoothDeviceNames.sorted().joined(separator: ", ").orDash : "Enable flag to read")
                stateRow("Audio output", state.audioOutputDeviceName ?? "—")
                stateRow("Displays", "\(state.screenCount)\(state.externalDisplayConnected ? " (external connected)" : "")")
                stateRow("Focus active", state.isFocusActive ? "Yes" : "No")
                stateRow("Focus mode", state.activeFocusModeName ?? "—")
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stateRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private func batteryString(_ power: PowerState) -> String {
        guard let percentage = power.batteryPercentage else { return "No battery" }
        return "\(Int(percentage.rounded()))%"
    }
}

private extension String {
    /// Returns an em dash when the string is empty.
    var orDash: String {
        isEmpty ? "—" : self
    }
}
