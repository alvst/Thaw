//
//  SimpleItemHider.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Cocoa

/// macOS 27 section-based hiding, the authority behind the restored
/// drag-between-sections layout UI.
///
/// macOS 27 removed every legacy mechanism for moving a status item off-screen, so
/// the classic Visible / Hidden / Always-Hidden model is reconstructed here on
/// top of a single source of truth that this object owns:
///
/// - **Section assignment** (``sectionAssignment``): which section each item
///   belongs to, keyed by ``MenuBarItem/uniqueIdentifier`` and persisted. This
///   is what the layout bars render and what drags mutate.
/// - **Temporary reveal** (``revealedSection``): the Hidden / Always-Hidden
///   section currently shown from the Thaw icon or hotkeys. This only changes
///   the live assertion allowlist; persisted assignments stay untouched.
///
/// The actual hiding is delegated to ``AssessmentModeBackend``: the private
/// visibility-restriction assertion that genuinely removes the icons and reflows
/// the bar. Its allowlist is recomputed from the assignment map. When the private
/// API is unavailable the backend is inert (nothing is hidden) and there is no
/// cosmetic overlay fallback.
///
/// Created only on macOS 27+ (see `MenuBarManager`), so everything it owns is
/// implicitly gated to that OS — macOS 26 keeps its native section machinery.
@MainActor
final class SimpleItemHider: ObservableObject {
    /// UserDefaults key for the persisted per-item section assignment
    /// (`[uniqueIdentifier: sectionRawValue]`, `.visible` entries omitted).
    private static let assignmentKey = "Thaw.simpleSectionAssignment"

    /// Legacy UserDefaults key from the binary switch-list era. Read once at
    /// first launch to migrate hidden items into the new assignment map.
    private static let legacyHiddenKey = "Thaw.simpleHiddenItemIdentifiers"

    /// UserDefaults key for the persisted per-section item order
    /// (`[sectionRawValue: [uniqueIdentifier]]`).
    private static let orderKey = "Thaw.simpleSectionOrder"

    private weak var appState: AppState?
    private let diagLog = DiagLog(category: "SimpleItemHider")

    /// Section each item is assigned to, keyed by ``MenuBarItem/uniqueIdentifier``.
    /// Entries equal to `.visible` are omitted (the default), so the map only
    /// holds the hidden / always-hidden items. Published so the settings UI and
    /// layout bars reflect changes.
    @Published private(set) var sectionAssignment: [String: MenuBarSection.Name]

    /// User-chosen left-to-right order of items within each section, set by
    /// layout-bar drags and persisted. For the Visible section, MenuBarAgent
    /// identifiers stay out of the saved order on macOS 27 and render as a
    /// trailing live-order block.
    @Published private(set) var sectionItemOrder: [MenuBarSection.Name: [String]]

    /// The currently revealed hidden section, if any. `.hidden` reveals only
    /// Hidden items; `.alwaysHidden` reveals both Hidden and Always-Hidden items.
    @Published private(set) var revealedSection: MenuBarSection.Name?

    /// The backend that performs the hiding (the private visibility-restriction
    /// assertion).
    private let backend: AssessmentModeBackend

    private var timer: Timer?

    init(appState: AppState) {
        self.appState = appState
        self.sectionAssignment = Self.loadAssignment()
        self.sectionItemOrder = Self.loadOrder()
        self.backend = AssessmentModeBackend()
        let assessmentModeAvailable = AssessmentModeBackend.isAvailable
        diagLog.info("hiding backend: AssessmentMode (\(assessmentModeAvailable ? "available" : "unavailable")); \(sectionAssignment.count) assigned item(s)")
    }

    /// Loads the persisted section assignment, migrating from the old binary
    /// hidden set on first launch.
    private static func loadAssignment() -> [String: MenuBarSection.Name] {
        let defaults = UserDefaults.standard
        if let stored = defaults.dictionary(forKey: assignmentKey) as? [String: String] {
            var map = [String: MenuBarSection.Name]()
            for (identifier, raw) in stored {
                if let section = MenuBarSection.Name(rawValue: raw), section != .visible {
                    map[identifier] = section
                }
            }
            return sanitizedSectionAssignment(map)
        }
        // One-time migration: every item the user had hidden in the switch-list
        // era becomes a member of the Hidden section.
        if let legacy = defaults.stringArray(forKey: legacyHiddenKey), !legacy.isEmpty {
            return sanitizedSectionAssignment(legacy.reduce(into: [:]) { $0[$1] = .hidden })
        }
        return [:]
    }

    /// Drops assignments that can never be valid hidden-section entries.
    static func sanitizedSectionAssignment(
        _ assignment: [String: MenuBarSection.Name]
    ) -> [String: MenuBarSection.Name] {
        assignment.filter { identifier, section in
            section != .visible &&
                !isControlItemAssignmentIdentifier(identifier) &&
                !isOwnAppAssignmentIdentifier(identifier)
        }
    }

    private static func isOwnAppAssignmentIdentifier(_ identifier: String) -> Bool {
        identifier == Constants.bundleIdentifier ||
            identifier.hasPrefix("\(Constants.bundleIdentifier):")
    }

    private static func isControlItemAssignmentIdentifier(_ identifier: String) -> Bool {
        if identifier.contains(".Spacer.") {
            return true
        }

        let controlTitles = Set(ControlItem.Identifier.allCases.map(\.rawValue))
        if controlTitles.contains(identifier) {
            return true
        }

        let thawControlIdentifiers = Set(
            ControlItem.Identifier.allCases.map { "\(MenuBarItemTag.Namespace.thaw):\($0.rawValue)" }
        )
        return thawControlIdentifiers.contains(identifier)
    }

    private func persistAssignment() {
        let raw = sectionAssignment.mapValues(\.rawValue)
        UserDefaults.standard.set(raw, forKey: Self.assignmentKey)
    }

    /// Loads the persisted per-section item order.
    private static func loadOrder() -> [MenuBarSection.Name: [String]] {
        guard let stored = UserDefaults.standard.dictionary(forKey: orderKey) as? [String: [String]] else {
            return [:]
        }
        var map = [MenuBarSection.Name: [String]]()
        for (raw, ids) in stored {
            if let section = MenuBarSection.Name(rawValue: raw) {
                map[section] = ids
            }
        }
        return map
    }

    private func persistOrder() {
        let raw = Dictionary(uniqueKeysWithValues: sectionItemOrder.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(raw, forKey: Self.orderKey)
    }

    /// Returns the temporary reveal target for a section control.
    ///
    /// The Visible control item is the user-facing Thaw icon; like Ice on macOS
    /// 26, clicking it reveals the Hidden section.
    static func revealTarget(for section: MenuBarSection.Name) -> MenuBarSection.Name? {
        switch section {
        case .visible, .hidden:
            return .hidden
        case .alwaysHidden:
            return .alwaysHidden
        }
    }

    /// Whether the section should currently be considered hidden by the UI.
    static func isSectionHidden(
        _ section: MenuBarSection.Name,
        revealedSection: MenuBarSection.Name?
    ) -> Bool {
        switch section {
        case .visible, .hidden:
            return revealedSection != .hidden && revealedSection != .alwaysHidden
        case .alwaysHidden:
            return revealedSection != .alwaysHidden
        }
    }

    /// Assignment map to use for the live assertion while a section is revealed.
    static func effectiveSectionAssignment(
        _ assignment: [String: MenuBarSection.Name],
        revealing revealedSection: MenuBarSection.Name?
    ) -> [String: MenuBarSection.Name] {
        let sanitized = sanitizedSectionAssignment(assignment)
        guard let revealedSection else {
            return sanitized
        }

        return sanitized.filter { _, section in
            switch revealedSection {
            case .visible, .hidden:
                return section == .alwaysHidden
            case .alwaysHidden:
                return false
            }
        }
    }

    /// Temporarily reveals a hidden section in the real menu bar.
    func show(_ section: MenuBarSection.Name) {
        guard let target = Self.revealTarget(for: section), revealedSection != target else {
            return
        }
        revealedSection = target
        diagLog.info("show(\(target.rawValue)); temporarily revealing assigned item(s)")
        refresh()
    }

    /// Re-applies the persisted assignment, concealing temporary reveals.
    func hideRevealedSections() {
        guard revealedSection != nil else {
            return
        }
        let previous = revealedSection
        revealedSection = nil
        diagLog.info("hideRevealedSections(previous=\(previous?.rawValue ?? "none"))")
        refresh()
    }

    /// Toggles the temporary reveal state for a section.
    func toggle(_ section: MenuBarSection.Name) {
        if Self.isSectionHidden(section, revealedSection: revealedSection) {
            show(section)
        } else {
            hideRevealedSections()
        }
    }

    /// Whether the section is currently concealed by the live assertion.
    func isSectionHidden(_ section: MenuBarSection.Name) -> Bool {
        Self.isSectionHidden(section, revealedSection: revealedSection)
    }

    /// Records the user's left-to-right order for a section (from a layout-bar
    /// drag) and persists it. The caller is expected to trigger a recache so the
    /// layout bars re-render in the new order.
    func setSectionOrder(_ identifiers: [String], for section: MenuBarSection.Name) {
        sectionItemOrder[section] = identifiers
        persistOrder()
        diagLog.info("setSectionOrder(\(section.rawValue)); \(identifiers.count) item(s)")
    }

    /// Records a section order from live layout items, dropping control items
    /// and macOS 27 MenuBarAgent entries before persistence.
    func setSectionOrder(from items: [MenuBarItem], for section: MenuBarSection.Name) {
        setSectionOrder(Self.persistableOrderIdentifiers(from: items, in: section), for: section)
    }

    /// Returns the identifiers Thaw is allowed to persist for a section order.
    static func persistableOrderIdentifiers(
        from items: [MenuBarItem],
        in _: MenuBarSection.Name
    ) -> [String] {
        items.compactMap { item in
            guard !item.isControlItem,
                  !item.tag.isLayoutAnchoredSystemItem,
                  !isOwnAppItem(item),
                  !isMacOS27MenuBarAgentItem(item)
            else {
                return nil
            }
            return item.uniqueIdentifier
        }
    }

    /// Reorders `items` to match the user's recorded order for `section`.
    /// On macOS 27, visible MenuBarAgent items are kept as a trailing live-order
    /// block so Apple-hosted modules do not get mixed into Thaw's saved order.
    func ordered(_ items: [MenuBarItem], in section: MenuBarSection.Name) -> [MenuBarItem] {
        let order = sectionItemOrder[section] ?? []
        return Self.orderedItems(items, in: section, using: order)
    }

    static func orderedItems(
        _ items: [MenuBarItem],
        in section: MenuBarSection.Name,
        using order: [String]
    ) -> [MenuBarItem] {
        if section == .visible {
            return visibleItemsWithTrailingMenuBarAgentBlock(items, using: order)
        }

        guard !order.isEmpty else {
            return items
        }

        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.enumerated().sorted { lhs, rhs in
            let lr = rank[lhs.element.uniqueIdentifier] ?? (order.count + lhs.offset)
            let rr = rank[rhs.element.uniqueIdentifier] ?? (order.count + rhs.offset)
            return lr < rr
        }.map(\.element)
    }

    private static func visibleItemsWithTrailingMenuBarAgentBlock(
        _ items: [MenuBarItem],
        using order: [String]
    ) -> [MenuBarItem] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let partition = partitionMenuBarAgentItems(items)
        let orderedNonMenuBarAgentItems = partition.nonMenuBarAgent.enumerated().sorted { lhs, rhs in
            let lr = rank[lhs.element.uniqueIdentifier] ?? (order.count + lhs.offset)
            let rr = rank[rhs.element.uniqueIdentifier] ?? (order.count + rhs.offset)
            return lr < rr
        }.map(\.element)
        return orderedNonMenuBarAgentItems + partition.menuBarAgent
    }

    private static func isMacOS27MenuBarAgentItem(_ item: MenuBarItem) -> Bool {
        if #available(macOS 27, *) {
            return item.tag.namespace == .menuBarAgent
        }
        return false
    }

    static func isProtectedAssignmentItem(_ item: MenuBarItem) -> Bool {
        item.isControlItem ||
            item.tag.isLayoutAnchoredSystemItem ||
            isOwnAppItem(item) ||
            isMacOS27MenuBarAgentItem(item)
    }

    private static func isOwnAppItem(_ item: MenuBarItem) -> Bool {
        item.tag.namespace == .thaw ||
            item.sourceApplication?.bundleIdentifier == Constants.bundleIdentifier ||
            item.owningApplication?.bundleIdentifier == Constants.bundleIdentifier ||
            isOwnAppAssignmentIdentifier(item.uniqueIdentifier)
    }

    private static func partitionMenuBarAgentItems(
        _ items: [MenuBarItem]
    ) -> (nonMenuBarAgent: [MenuBarItem], menuBarAgent: [MenuBarItem]) {
        var nonMenuBarAgent = [MenuBarItem]()
        var menuBarAgent = [MenuBarItem]()
        for item in items {
            if isMacOS27MenuBarAgentItem(item) {
                menuBarAgent.append(item)
            } else {
                nonMenuBarAgent.append(item)
            }
        }
        return (nonMenuBarAgent, menuBarAgent)
    }

    /// Starts the periodic refresh that keeps the backend in sync with the live
    /// item set (e.g. re-applying the allowlist when apps appear or quit).
    func start() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    /// The section the item with the given identifier is assigned to.
    func section(for identifier: String) -> MenuBarSection.Name {
        sectionAssignment[identifier] ?? .visible
    }

    /// The section for a live item. System anchors and macOS 27 MenuBarAgent
    /// items are always visible even if stale defaults say otherwise.
    func section(for item: MenuBarItem) -> MenuBarSection.Name {
        if item.tag.isLayoutAnchoredSystemItem ||
            Self.isOwnAppItem(item) ||
            Self.isMacOS27MenuBarAgentItem(item)
        {
            return .visible
        }
        return section(for: item.uniqueIdentifier)
    }

    /// Assigns the item to a section. Dropping it back into `.visible` removes
    /// the entry (the default). Persists and re-applies the restriction.
    func setSection(_ section: MenuBarSection.Name, identifier: String) {
        guard !Self.isControlItemAssignmentIdentifier(identifier),
              !Self.isOwnAppAssignmentIdentifier(identifier)
        else {
            if sectionAssignment.removeValue(forKey: identifier) != nil {
                persistAssignment()
                refresh()
            }
            diagLog.warning("ignored protected section assignment for \(identifier)")
            return
        }

        if section == .visible {
            sectionAssignment.removeValue(forKey: identifier)
        } else {
            sectionAssignment[identifier] = section
        }
        persistAssignment()
        diagLog.info("setSection(\(section.rawValue)) \(identifier); \(sectionAssignment.count) assigned item(s)")
        refresh()
    }

    /// Assigns a live item to a section, rejecting items that can never be
    /// safely concealed on macOS 27. Use this overload when a caller has the
    /// `MenuBarItem`; it can identify Thaw-owned generic `Item-0` entries even
    /// when their persisted identifier is not the stable control-item title.
    func setSection(_ section: MenuBarSection.Name, item: MenuBarItem) {
        guard !Self.isProtectedAssignmentItem(item) else {
            if sectionAssignment.removeValue(forKey: item.uniqueIdentifier) != nil {
                persistAssignment()
                refresh()
            }
            diagLog.warning("ignored protected section assignment for \(item.uniqueIdentifier)")
            return
        }
        setSection(section, identifier: item.uniqueIdentifier)
    }

    /// Replaces the entire section assignment wholesale (used by Reset Layout).
    /// `.visible` entries are dropped (the default), then the restriction is
    /// persisted and re-applied.
    func resetAssignment(to assignment: [String: MenuBarSection.Name]) {
        sectionAssignment = Self.sanitizedSectionAssignment(assignment)
        persistAssignment()
        diagLog.info("resetAssignment; \(sectionAssignment.count) assigned item(s)")
        refresh()
    }

    /// Last-known snapshots of assigned items, captured while they were still
    /// enumerable. A concealed item has no window and drops out of the AX
    /// enumeration, so the layout bars resurrect it from its snapshot (see the
    /// macOS 27 re-bucketing in `MenuBarItemManager`). Keyed by
    /// ``MenuBarItem/uniqueIdentifier``.
    private var snapshots: [String: MenuBarItem] = [:]

    /// The retained snapshot for an assigned item, if one was captured this
    /// session (while the item was still visible).
    func snapshot(for identifier: String) -> MenuBarItem? {
        snapshots[identifier]
    }

    /// Re-applies the current assignment against the live item cache, and
    /// refreshes the retained snapshots.
    func refresh() {
        guard let appState else { return }
        let allItems = appState.itemManager.itemCache.managedItems
        let assignedControlItemIDs = Set(sectionAssignment.keys.filter(Self.isControlItemAssignmentIdentifier))
        let protectedAssignedIDs = Set(
            allItems
                .filter {
                    ($0.tag.isLayoutAnchoredSystemItem ||
                        Self.isOwnAppItem($0) ||
                        Self.isMacOS27MenuBarAgentItem($0)) &&
                        sectionAssignment[$0.uniqueIdentifier] != nil
                }
                .map(\.uniqueIdentifier)
        )
        let assignedOwnAppIDs = Set(sectionAssignment.keys.filter(Self.isOwnAppAssignmentIdentifier))
        let invalidAssignmentIDs = assignedControlItemIDs
            .union(assignedOwnAppIDs)
            .union(protectedAssignedIDs)
        if !invalidAssignmentIDs.isEmpty {
            for identifier in invalidAssignmentIDs {
                sectionAssignment.removeValue(forKey: identifier)
            }
            persistAssignment()
            diagLog.info("removed \(invalidAssignmentIDs.count) control/system assignment(s)")
        }
        // Snapshot every assigned item while it's still live, so it can keep
        // appearing in the layout bars after it's concealed. Drop snapshots for
        // items that are no longer assigned.
        for item in allItems where sectionAssignment[item.uniqueIdentifier] != nil {
            snapshots[item.uniqueIdentifier] = item
        }
        snapshots = snapshots.filter { sectionAssignment[$0.key] != nil }
        let effectiveAssignment = Self.effectiveSectionAssignment(
            sectionAssignment,
            revealing: revealedSection
        )
        let didChangeRestriction = backend.apply(
            sectionAssignment: effectiveAssignment,
            allItems: allItems
        )
        if didChangeRestriction {
            diagLog.info("restriction changed; visible control item left registered")
        }
    }
}
