//
//  SettingsView.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    let appState: AppState
    @ObservedObject var navigationState: AppNavigationState

    private var allSections: [SettingsNavigationIdentifier] {
        SettingsNavigationIdentifier.allCases
    }

    private var currentSectionIndex: Int? {
        allSections.firstIndex(of: navigationState.settingsNavigationIdentifier)
    }

    private var isFirstSection: Bool {
        currentSectionIndex == 0
    }

    private var isLastSection: Bool {
        currentSectionIndex == allSections.count - 1
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            settingsPane
                .id(navigationState.settingsNavigationIdentifier)
        }
        .navigationTitle(navigationState.settingsNavigationIdentifier.localized)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ControlGroup {
                    Button(action: navigateBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .disabled(isFirstSection)

                    Button(action: navigateForward) {
                        Label("Forward", systemImage: "chevron.right")
                    }
                    .disabled(isLastSection)
                }
                .controlGroupStyle(.navigation)
            }
            if #available(macOS 27, *) {
                ToolbarItem(placement: .automatic) {
                    experimentalMacOS27Pill
                }
                // Suppress the toolbar item's default Liquid Glass background so
                // only our yellow pill shows (not a glass capsule around it).
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    /// A yellow warning pill shown in the toolbar on macOS 27, where menu bar
    /// item support is experimental (hiding works through a private system API
    /// and some features may be unreliable).
    private var experimentalMacOS27Pill: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Experimental support for macOS 27 beta - some features may be unreliable")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(.yellow.opacity(0.15)))
        .help("Menu bar support on macOS 27 is experimental: hiding works through a private system API and some features may be unreliable.")
    }

    private var sidebar: some View {
        // Use a Binding that wraps the navigation state to ensure updates happen
        // on the main thread and avoid view update warnings.
        let selection = Binding<SettingsNavigationIdentifier>(
            get: { navigationState.settingsNavigationIdentifier },
            set: { newValue in
                if navigationState.settingsNavigationIdentifier != newValue {
                    Task { @MainActor in
                        navigationState.settingsNavigationIdentifier = newValue
                    }
                }
            }
        )

        return List(selection: selection) {
            Section {
                ForEach(SettingsNavigationIdentifier.allCases) { identifier in
                    Label {
                        Text(identifier.localized)
                    } icon: {
                        identifier.iconResource.view
                    }
                    .tag(identifier)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(ideal: 180, max: 220)
    }

    @ViewBuilder
    private var settingsPane: some View {
        switch navigationState.settingsNavigationIdentifier {
        case .general:
            GeneralSettingsPane(settings: appState.settings.general)
        case .displays:
            DisplaySettingsPane(displaySettings: appState.settings.displaySettings)
        case .menuBarLayout:
            MenuBarLayoutSettingsPane(itemManager: appState.itemManager)
        case .menuBarAppearance:
            MenuBarAppearanceSettingsPane(appearanceManager: appState.appearanceManager)
        case .hotkeys:
            HotkeysSettingsPane(settings: appState.settings.hotkeys)
        case .profiles:
            ProfileSettingsPane(profileManager: appState.profileManager)
        case .advanced:
            AdvancedSettingsPane(settings: appState.settings.advanced)
        case .automation:
            AutomationSettingsPane()
        case .about:
            AboutSettingsPane(updatesManager: appState.updatesManager)
        }
    }

    private func navigateBack() {
        guard let index = currentSectionIndex, index > 0 else { return }
        navigationState.settingsNavigationIdentifier = allSections[index - 1]
    }

    private func navigateForward() {
        guard let index = currentSectionIndex, index < allSections.count - 1 else { return }
        navigationState.settingsNavigationIdentifier = allSections[index + 1]
    }
}
