//
//  TriggersSettingsPane.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

// MARK: - TriggerItemOption

/// A stable, value-type representation of a menu bar item that can be
/// targeted by a trigger.
///
/// Decoupling the picker's options from the live `MenuBarItem` cache keeps
/// the SwiftUI `Picker` from rebuilding (and dropping an in-progress
/// selection) every time the item cache republishes — which happens on
/// every cache cycle and every time a trigger moves an item between
/// sections.
struct TriggerItemOption: Hashable {
    /// The item's stable tag identifier.
    let id: String
    /// A disambiguated, human-readable name.
    let name: String
}

// MARK: - TriggersSettingsPane

/// Settings pane for configuring conditional menu bar item triggers.
///
/// A trigger reveals a chosen menu bar item when a power condition is met
/// (for example, "show the battery icon when the battery is below 20%") and
/// returns the item to a hidden section when the condition no longer holds.
struct TriggersSettingsPane: View {
    @ObservedObject var manager: MenuBarItemTriggersManager

    // A plain reference, not an @ObservedObject: observing the item
    // manager would re-render the whole pane on every item cache publish
    // (each cache cycle and every trigger move), which repeatedly steals
    // keyboard focus back to the trigger name field. Instead the item
    // options are refreshed through a targeted .onReceive below that only
    // updates local state when the set of items actually changes.
    let itemManager: MenuBarItemManager

    /// A snapshot of the menu bar items that can be targeted by a trigger.
    /// Only refreshed when the set of items (or their names) actually
    /// changes, so the picker stays stable during routine cache churn.
    @State private var itemOptions: [TriggerItemOption] = []

    /// The id of the trigger whose name field currently has keyboard focus,
    /// or `nil` when no name field is being edited.
    @FocusState private var focusedNameID: UUID?

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
                        focusedNameID: $focusedNameID,
                        onDelete: { manager.remove(id: trigger.id) }
                    )
                }
            }

            addButton
        }
        // Clicking anywhere outside a name field commits and dismisses it.
        .contentShape(Rectangle())
        .onTapGesture {
            focusedNameID = nil
        }
        .onAppear(perform: refreshItemOptions)
        .onReceive(itemManager.$itemCache) { _ in
            refreshItemOptions()
        }
    }

    // MARK: Item options

    /// Recomputes the targetable item options, assigning only when the
    /// result differs from the current snapshot.
    private func refreshItemOptions() {
        let items = itemManager.itemCache.managedItems
            .filter { $0.tag.isMovable && $0.tag.canBeHidden }

        // Count display names so duplicates can be disambiguated by tag.
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

    // MARK: Sections

    private var introSection: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Conditional Triggers")
                    .font(.headline)
                Text("Automatically reveal a menu bar item while a condition is met, then hide it again when the condition no longer applies.")
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
                Text("Add a trigger to reveal a menu bar item when a power condition is met.")
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
    var focusedNameID: FocusState<UUID?>.Binding
    let onDelete: () -> Void

    /// A local draft of the trigger name. The name field edits this rather
    /// than the published trigger, so per-keystroke typing does not churn
    /// the settings object graph (which re-renders the whole settings
    /// window and was stealing focus back to the field). The draft is
    /// committed to the trigger on Enter or when the field loses focus.
    @State private var draftName: String = ""

    /// The condition kind, derived from and written back to the condition.
    private var kindBinding: Binding<TriggerConditionKind> {
        Binding(
            get: { trigger.condition.kind },
            set: { trigger.condition = .make(kind: $0, percentage: trigger.condition.percentage) }
        )
    }

    /// The battery percentage threshold for percentage-based conditions.
    private var percentageBinding: Binding<Double> {
        Binding(
            get: { trigger.condition.percentage ?? 50 },
            set: { trigger.condition = .make(kind: trigger.condition.kind, percentage: $0) }
        )
    }

    /// The target item's display name, used when the selected item is not
    /// currently present in the menu bar.
    private var selectedItemName: String {
        if let match = itemOptions.first(where: { $0.id == trigger.itemIdentifier }) {
            return match.name
        }
        if !trigger.itemDisplayName.isEmpty {
            return trigger.itemDisplayName
        }
        return trigger.itemIdentifier.isEmpty ? "No item selected" : trigger.itemIdentifier
    }

    /// Whether the selected item is currently absent from the menu bar.
    private var isSelectedItemMissing: Bool {
        !trigger.itemIdentifier.isEmpty && !itemOptions.contains { $0.id == trigger.itemIdentifier }
    }

    var body: some View {
        IceSection(options: [.isBordered]) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()

                IcePicker("Menu bar item", selection: itemBinding) {
                    // Keep the selected item selectable even while it is
                    // temporarily absent from the live cache, so the
                    // picker never silently snaps to a different item.
                    if isSelectedItemMissing {
                        Text("\(selectedItemName) (not present)").tag(trigger.itemIdentifier)
                    }
                    ForEach(itemOptions, id: \.id) { option in
                        Text(option.name).tag(option.id)
                    }
                }

                IcePicker("Condition", selection: kindBinding) {
                    ForEach(TriggerConditionKind.allCases) { kind in
                        Text(kind.displayString).tag(kind)
                    }
                }

                if trigger.condition.kind.usesPercentage {
                    percentageEditor
                }

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
            .padding(8)
        }
        .onAppear {
            draftName = trigger.name
        }
        .onChange(of: trigger.name) { _, newValue in
            // Keep the draft in sync if the name changes externally while
            // this field is not being edited.
            if focusedNameID.wrappedValue != trigger.id {
                draftName = newValue
            }
        }
        .onChange(of: focusedNameID.wrappedValue) { _, newValue in
            // Commit when focus leaves this row's name field.
            if newValue != trigger.id {
                commitName()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            TextField("Trigger name", text: $draftName, prompt: Text(verbatim: selectedItemName))
                .textFieldStyle(.roundedBorder)
                .focused(focusedNameID, equals: trigger.id)
                .onSubmit {
                    commitName()
                    focusedNameID.wrappedValue = nil
                }

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

    /// Writes the draft name back to the trigger if it changed.
    private func commitName() {
        let trimmed = draftName
        if trimmed != trigger.name {
            trigger.name = trimmed
        }
    }

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
}
