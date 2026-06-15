//
//  TriggersSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI

// MARK: - Option value types

/// A stable, value-type representation of a menu bar item that can be
/// targeted by a trigger. Decoupling the picker's options from the live
/// item cache keeps the SwiftUI `Picker` from rebuilding (and dropping an
/// in-progress selection) on every cache publish.
struct TriggerItemOption: Hashable {
    let id: String
    let name: String
}

/// A running application offered in the app-condition picker.
struct TriggerAppOption: Hashable {
    let bundleID: String
    let name: String
}

// MARK: - TriggersSettingsPane

/// Settings pane for configuring conditional menu bar item triggers.
struct TriggersSettingsPane: View {
    @ObservedObject var manager: MenuBarItemTriggersManager
    @ObservedObject private var flags: TriggerFeatureFlagsManager

    // A plain reference, not an @ObservedObject: observing the item manager
    // would re-render the pane on every item cache publish, stealing focus.
    let itemManager: MenuBarItemManager

    @State private var itemOptions: [TriggerItemOption] = []
    @State private var appOptions: [TriggerAppOption] = []

    /// Composite key ("name-<id>" / "text-<id>") of the focused text field.
    @FocusState private var focusedField: String?

    init(manager: MenuBarItemTriggersManager, itemManager: MenuBarItemManager) {
        self.manager = manager
        self.itemManager = itemManager
        _flags = ObservedObject(wrappedValue: manager.featureFlags)
    }

    var body: some View {
        IceForm {
            introSection

            if manager.triggers.isEmpty {
                emptyState
            } else {
                ForEach($manager.triggers) { $trigger in
                    TriggerRow(
                        trigger: $trigger,
                        itemOptions: itemOptions,
                        appOptions: appOptions,
                        availableKinds: availableKinds(currentKind: trigger.condition.kind),
                        invertEnabled: flags.isEnabled(.invertAction),
                        focusedField: $focusedField,
                        onDelete: { manager.remove(id: trigger.id) }
                    )
                }
            }

            addButton
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onAppear {
            refreshItemOptions()
            refreshAppOptions()
        }
        .onReceive(itemManager.$itemCache) { _ in
            refreshItemOptions()
        }
    }

    // MARK: Available condition kinds

    /// The condition kinds offered in the picker: always-available power
    /// kinds, kinds whose feature flag is enabled, plus the trigger's own
    /// current kind (so a disabled flag never hides an existing selection).
    private func availableKinds(currentKind: TriggerConditionKind) -> [TriggerConditionKind] {
        TriggerConditionKind.allCases.filter { kind in
            if kind == currentKind { return true }
            guard let feature = kind.requiredFeature else { return true }
            return flags.isEnabled(feature)
        }
    }

    // MARK: Options refresh

    private func refreshItemOptions() {
        let items = itemManager.itemCache.managedItems
            .filter { $0.tag.isMovable && $0.tag.canBeHidden }

        var nameCounts = [String: Int]()
        for item in items {
            nameCounts[item.displayName, default: 0] += 1
        }

        var options = items.map { item -> TriggerItemOption in
            let base = item.displayName
            let name = (nameCounts[base] ?? 0) > 1 ? "\(base) — \(item.tag.tagIdentifier)" : base
            return TriggerItemOption(id: item.tag.tagIdentifier, name: name)
        }
        options.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if options != itemOptions {
            itemOptions = options
        }
    }

    private func refreshAppOptions() {
        var options = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> TriggerAppOption? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return TriggerAppOption(bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
        // Deduplicate by bundle id (multiple windows / instances).
        var seen = Set<String>()
        options = options.filter { seen.insert($0.bundleID).inserted }
        options.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        appOptions = options
    }

    // MARK: Sections

    private var introSection: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Conditional Triggers")
                    .font(.headline)
                Text("Automatically reveal a menu bar item while a condition is met, then hide it again when the condition no longer applies. Enable additional condition types in the Developer pane.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    private var emptyState: some View {
        IceSection(options: [.isBordered]) {
            VStack(spacing: 6) {
                Image(systemName: "bolt.badge.automatic")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No triggers yet")
                    .font(.headline)
                Text("Add a trigger to reveal a menu bar item when a condition is met.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }

    private var addButton: some View {
        Button {
            addTrigger()
        } label: {
            Label("Add Trigger", systemImage: "plus")
        }
        .controlSize(.large)
    }

    private func addTrigger() {
        let firstItem = itemOptions.first
        let trigger = MenuBarItemTrigger(
            itemIdentifier: firstItem?.id ?? "",
            itemDisplayName: firstItem?.name ?? "",
            revealSection: .visible,
            hideSection: .hidden,
            condition: .batteryBelow(percentage: 20)
        )
        manager.add(trigger)
    }
}

// MARK: - TriggerRow

/// An inline editor for a single ``MenuBarItemTrigger``.
private struct TriggerRow: View {
    @Binding var trigger: MenuBarItemTrigger
    let itemOptions: [TriggerItemOption]
    let appOptions: [TriggerAppOption]
    let availableKinds: [TriggerConditionKind]
    let invertEnabled: Bool
    var focusedField: FocusState<String?>.Binding
    let onDelete: () -> Void

    private var kindBinding: Binding<TriggerConditionKind> {
        Binding(
            get: { trigger.condition.kind },
            set: { trigger.condition = .make(kind: $0, preserving: trigger.condition) }
        )
    }

    private var selectedItemName: String {
        if let match = itemOptions.first(where: { $0.id == trigger.itemIdentifier }) {
            return match.name
        }
        if !trigger.itemDisplayName.isEmpty { return trigger.itemDisplayName }
        return trigger.itemIdentifier.isEmpty ? "No item selected" : trigger.itemIdentifier
    }

    private var isSelectedItemMissing: Bool {
        !trigger.itemIdentifier.isEmpty && !itemOptions.contains { $0.id == trigger.itemIdentifier }
    }

    var body: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                itemPicker
                conditionPicker
                conditionEditor
                sectionPickers
                if invertEnabled {
                    Toggle("Hide the item while the condition is met (invert)", isOn: $trigger.invert)
                        .toggleStyle(.switch)
                }
            }
            .padding(8)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            CommitTextField(
                title: "Trigger name",
                prompt: selectedItemName,
                value: $trigger.name,
                focusedField: focusedField,
                focusID: "name-\(trigger.id)"
            )

            Toggle("Enabled", isOn: $trigger.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this trigger")
        }
    }

    // MARK: Pickers

    private var itemPicker: some View {
        IcePicker("Menu bar item", selection: itemBinding) {
            if isSelectedItemMissing {
                Text("\(selectedItemName) (not present)").tag(trigger.itemIdentifier)
            }
            ForEach(itemOptions, id: \.id) { option in
                Text(option.name).tag(option.id)
            }
        }
    }

    private var conditionPicker: some View {
        IcePicker("Condition", selection: kindBinding) {
            ForEach(availableKinds) { kind in
                Text(kind.displayString).tag(kind)
            }
        }
    }

    @ViewBuilder
    private var conditionEditor: some View {
        switch trigger.condition.kind.editor {
        case .percentage:
            percentageEditor
        case .appPicker:
            appPicker
        case let .text(prompt):
            CommitTextField(
                title: prompt,
                prompt: prompt,
                value: textBinding,
                focusedField: focusedField,
                focusID: "text-\(trigger.id)"
            )
        case .timeRange:
            timeRangeEditor
        case .none:
            EmptyView()
        }
    }

    private var sectionPickers: some View {
        Group {
            IcePicker("Show in", selection: $trigger.revealSection) {
                ForEach(MenuBarSection.Name.allCases, id: \.self) { section in
                    Text(section.displayString).tag(section)
                }
            }
            IcePicker("Otherwise hide in", selection: $trigger.hideSection) {
                ForEach(MenuBarSection.Name.allCases, id: \.self) { section in
                    Text(section.displayString).tag(section)
                }
            }
        }
    }

    // MARK: Editors

    private var percentageEditor: some View {
        HStack(spacing: 12) {
            Slider(value: percentageBinding, in: 0 ... 100, step: 1) {
                Text("Battery level")
            }
            Text(verbatim: "\(Int(percentageBinding.wrappedValue.rounded()))%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var appPicker: some View {
        IcePicker("Application", selection: bundleIDBinding) {
            let current = trigger.condition.bundleID ?? ""
            if current.isEmpty {
                Text("Choose an app…").tag("")
            } else if !appOptions.contains(where: { $0.bundleID == current }) {
                Text("\(current) (not running)").tag(current)
            }
            ForEach(appOptions, id: \.bundleID) { option in
                Text(option.name).tag(option.bundleID)
            }
        }
    }

    private var timeRangeEditor: some View {
        let window = trigger.condition.scheduleWindow ?? (start: 540, end: 1020)
        return HStack(spacing: 12) {
            DatePicker(
                "From",
                selection: scheduleBinding(isStart: true, window: window),
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                "To",
                selection: scheduleBinding(isStart: false, window: window),
                displayedComponents: .hourAndMinute
            )
        }
    }

    // MARK: Bindings

    private var itemBinding: Binding<String> {
        Binding(
            get: { trigger.itemIdentifier },
            set: { newValue in
                trigger.itemIdentifier = newValue
                if let match = itemOptions.first(where: { $0.id == newValue }) {
                    trigger.itemDisplayName = match.name
                }
            }
        )
    }

    private var percentageBinding: Binding<Double> {
        Binding(
            get: { trigger.condition.percentage ?? 50 },
            set: { trigger.condition = trigger.condition.withPercentage($0) }
        )
    }

    private var bundleIDBinding: Binding<String> {
        Binding(
            get: { trigger.condition.bundleID ?? "" },
            set: { newValue in
                trigger.condition = trigger.condition.withBundleID(newValue)
                // Cache a display name for the trigger if none set yet.
                if trigger.name.trimmingCharacters(in: .whitespaces).isEmpty,
                   let app = appOptions.first(where: { $0.bundleID == newValue })
                {
                    trigger.itemDisplayName = trigger.itemDisplayName.isEmpty ? app.name : trigger.itemDisplayName
                }
            }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { trigger.condition.text ?? "" },
            set: { trigger.condition = trigger.condition.withText($0) }
        )
    }

    private func scheduleBinding(isStart: Bool, window: (start: Int, end: Int)) -> Binding<Date> {
        Binding(
            get: { Self.minutesToDate(isStart ? window.start : window.end) },
            set: { newDate in
                let minutes = Self.dateToMinutes(newDate)
                if isStart {
                    trigger.condition = trigger.condition.withSchedule(start: minutes, end: window.end)
                } else {
                    trigger.condition = trigger.condition.withSchedule(start: window.start, end: minutes)
                }
            }
        )
    }

    private static func minutesToDate(_ minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
        ) ?? Date()
    }

    private static func dateToMinutes(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - CommitTextField

/// A text field that edits a local draft and commits to the bound value
/// only on Enter or focus loss, so per-keystroke typing does not churn the
/// settings object graph (which re-renders the whole settings window and
/// steals focus). Focus is owned by the enclosing pane so clicking away
/// dismisses the field.
private struct CommitTextField: View {
    let title: String
    let prompt: String?
    @Binding var value: String
    var focusedField: FocusState<String?>.Binding
    let focusID: String

    @State private var draft: String = ""

    var body: some View {
        TextField(title, text: $draft, prompt: prompt.map { Text(verbatim: $0) })
            .textFieldStyle(.roundedBorder)
            .focused(focusedField, equals: focusID)
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in
                if focusedField.wrappedValue != focusID { draft = newValue }
            }
            .onChange(of: focusedField.wrappedValue) { _, newValue in
                if newValue != focusID { commit() }
            }
            .onSubmit {
                commit()
                focusedField.wrappedValue = nil
            }
    }

    private func commit() {
        if draft != value { value = draft }
    }
}
