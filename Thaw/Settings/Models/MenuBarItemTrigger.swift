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
/// satisfied, evaluated against a ``PowerState`` snapshot.
///
/// The enum is deliberately open to extension: additional condition kinds
/// (script result, image comparison, schedule, …) can be added as new
/// cases without changing the surrounding trigger plumbing.
enum TriggerCondition: Codable, Hashable {
    /// Satisfied while the battery charge is below the given percentage
    /// (`0...100`).
    case batteryBelow(percentage: Double)

    /// Satisfied while the battery charge is at or above the given
    /// percentage (`0...100`).
    case batteryAtOrAbove(percentage: Double)

    /// Satisfied while the machine is drawing from AC power.
    case onACPower

    /// Satisfied while the machine is running on battery power.
    case onBatteryPower

    /// Satisfied while the battery is charging.
    case charging

    /// Returns whether the condition is satisfied by the given power state.
    ///
    /// Machines without a battery report `batteryPercentage == nil`; for
    /// those, battery-level conditions are never satisfied while
    /// power-source conditions still evaluate normally.
    func isSatisfied(by state: PowerState) -> Bool {
        switch self {
        case let .batteryBelow(percentage):
            guard let level = state.batteryPercentage else { return false }
            return level < percentage
        case let .batteryAtOrAbove(percentage):
            guard let level = state.batteryPercentage else { return false }
            return level >= percentage
        case .onACPower:
            return state.isOnACPower
        case .onBatteryPower:
            return !state.isOnACPower
        case .charging:
            return state.isCharging
        }
    }
}

// MARK: - TriggerConditionKind

/// The user-selectable kind of a ``TriggerCondition``, used to drive the
/// settings UI independently of the threshold value carried by some kinds.
enum TriggerConditionKind: String, CaseIterable, Identifiable {
    case batteryBelow
    case batteryAtOrAbove
    case onACPower
    case onBatteryPower
    case charging

    var id: String { rawValue }

    /// A human-readable description for the settings interface.
    var displayString: String {
        switch self {
        case .batteryBelow: "Battery is below"
        case .batteryAtOrAbove: "Battery is at or above"
        case .onACPower: "Connected to power"
        case .onBatteryPower: "Running on battery"
        case .charging: "Battery is charging"
        }
    }

    /// Whether this kind carries a battery percentage threshold.
    var usesPercentage: Bool {
        switch self {
        case .batteryBelow, .batteryAtOrAbove: true
        case .onACPower, .onBatteryPower, .charging: false
        }
    }
}

extension TriggerCondition {
    /// The kind of this condition.
    var kind: TriggerConditionKind {
        switch self {
        case .batteryBelow: .batteryBelow
        case .batteryAtOrAbove: .batteryAtOrAbove
        case .onACPower: .onACPower
        case .onBatteryPower: .onBatteryPower
        case .charging: .charging
        }
    }

    /// The battery percentage threshold, when this condition carries one.
    var percentage: Double? {
        switch self {
        case let .batteryBelow(percentage), let .batteryAtOrAbove(percentage):
            return percentage
        case .onACPower, .onBatteryPower, .charging:
            return nil
        }
    }

    /// Builds a condition from a kind and an optional percentage threshold,
    /// supplying a sensible default percentage when one is required.
    static func make(kind: TriggerConditionKind, percentage: Double?) -> TriggerCondition {
        let value = percentage ?? 50
        switch kind {
        case .batteryBelow: return .batteryBelow(percentage: value)
        case .batteryAtOrAbove: return .batteryAtOrAbove(percentage: value)
        case .onACPower: return .onACPower
        case .onBatteryPower: return .onBatteryPower
        case .charging: return .charging
        }
    }
}

// MARK: - MenuBarItemTrigger

/// A user-defined rule that conditionally reveals or hides a single menu
/// bar item based on a ``TriggerCondition``.
///
/// When the condition becomes satisfied, the target item is moved into
/// ``revealSection``; when it is no longer satisfied, the item is returned
/// to ``hideSection``.
struct MenuBarItemTrigger: Codable, Hashable, Identifiable {
    /// A stable identifier for the trigger.
    var id: UUID

    /// A user-facing name for the trigger.
    var name: String

    /// Whether the trigger is active. Disabled triggers are never
    /// evaluated and leave their target item where it is.
    var isEnabled: Bool

    /// The stable tag identifier (``MenuBarItemTag/tagIdentifier``) of the
    /// menu bar item this trigger controls.
    var itemIdentifier: String

    /// A display name for the target item, cached so the settings UI can
    /// label the trigger even when the item is not currently present.
    var itemDisplayName: String

    /// The section the target item moves to when the condition is met.
    var revealSection: MenuBarSection.Name

    /// The section the target item returns to when the condition is not met.
    var hideSection: MenuBarSection.Name

    /// The condition that governs the trigger.
    var condition: TriggerCondition

    init(
        id: UUID = UUID(),
        name: String = "",
        isEnabled: Bool = true,
        itemIdentifier: String = "",
        itemDisplayName: String = "",
        revealSection: MenuBarSection.Name = .visible,
        hideSection: MenuBarSection.Name = .hidden,
        condition: TriggerCondition = .batteryBelow(percentage: 50)
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.itemIdentifier = itemIdentifier
        self.itemDisplayName = itemDisplayName
        self.revealSection = revealSection
        self.hideSection = hideSection
        self.condition = condition
    }

    /// A name suitable for display, falling back to the target item's
    /// display name when the user has not provided a custom name.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !itemDisplayName.isEmpty {
            return itemDisplayName
        }
        return "Untitled Trigger"
    }
}
