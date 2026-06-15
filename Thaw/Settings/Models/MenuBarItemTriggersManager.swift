//
//  MenuBarItemTriggersManager.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Combine
import Foundation

/// Owns the user's menu bar item triggers, persists them, and applies them
/// by revealing or hiding their target items as system conditions change.
///
/// Each enabled trigger is re-evaluated whenever the aggregated
/// ``SystemState`` changes (and periodically as a safety net, which also
/// covers time-of-day schedules). When a trigger's reveal decision flips,
/// its target item is moved into the configured reveal or hide section
/// after a short debounce, so brief fluctuations do not thrash the menu bar.
@MainActor
final class MenuBarItemTriggersManager: ObservableObject {
    /// The user's configured triggers.
    @Published var triggers: [MenuBarItemTrigger] {
        didSet {
            guard !suppressPersist else { return }
            persist()
            // A trigger may have been added, edited, or re-enabled; drop the
            // memoized state so the next evaluation re-applies. (The actual
            // move is still a no-op when the item is already in the right
            // section, so this does not warp the cursor on no-op edits.)
            lastAppliedReveal.removeAll()
            scheduleEvaluation()
        }
    }

    /// Per-source feature flags, also surfaced in the Developer pane.
    let featureFlags = TriggerFeatureFlagsManager()

    /// The shared app state.
    private weak var appState: AppState?

    /// Monitors the aggregated system state.
    let systemMonitor = SystemStateMonitor()

    /// The reveal decision currently reflected in each target item's
    /// placement, used to skip redundant moves.
    private var lastAppliedReveal = [UUID: Bool]()

    /// Per-trigger debounced apply tasks. A flipped decision only moves its
    /// item after the new state has held for ``flipDebounce``.
    private var pendingApplyTasks = [UUID: Task<Void, Never>]()

    /// How long a flipped decision must hold before the item is moved.
    private let flipDebounce: Duration = .seconds(6)

    /// True while loading from defaults; suppresses writeback.
    private var suppressPersist = false

    private var cancellables = Set<AnyCancellable>()

    /// Debounced forced-evaluation task, restarted on each edit.
    private var debouncedEvaluationTask: Task<Void, Never>?

    private let diagLog = DiagLog(category: "MenuBarItemTriggers")

    init() {
        suppressPersist = true
        triggers = Self.load()
        suppressPersist = false
    }

    /// Performs the initial setup of the manager.
    func performSetup(with appState: AppState) {
        self.appState = appState

        systemMonitor.start(flags: featureFlags)

        // Re-evaluate on every distinct system state change.
        systemMonitor.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.evaluate(for: state, force: false)
            }
            .store(in: &cancellables)

        // A periodic forced re-evaluation reconciles drift (manual user
        // moves, late-appearing items) and advances time-of-day schedules.
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.evaluate(for: self.systemMonitor.state, force: true)
            }
            .store(in: &cancellables)

        // Re-apply when feature flags change (a newly enabled source may
        // satisfy a trigger that was previously inert).
        featureFlags.objectWillChange
            .sink { [weak self] in
                self?.scheduleEvaluation()
            }
            .store(in: &cancellables)

        scheduleEvaluation()
    }

    // MARK: - Mutation

    /// Adds a trigger.
    func add(_ trigger: MenuBarItemTrigger) {
        triggers.append(trigger)
    }

    /// Removes the trigger with the given id.
    func remove(id: UUID) {
        triggers.removeAll { $0.id == id }
        lastAppliedReveal[id] = nil
        pendingApplyTasks[id]?.cancel()
        pendingApplyTasks[id] = nil
    }

    /// Removes the triggers at the given offsets.
    func remove(atOffsets offsets: IndexSet) {
        let removedIDs = offsets.compactMap { triggers.indices.contains($0) ? triggers[$0].id : nil }
        triggers.remove(atOffsets: offsets)
        for id in removedIDs {
            lastAppliedReveal[id] = nil
            pendingApplyTasks[id]?.cancel()
            pendingApplyTasks[id] = nil
        }
    }

    /// Replaces the trigger sharing the given id, if present.
    func update(_ trigger: MenuBarItemTrigger) {
        guard let index = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[index] = trigger
    }

    // MARK: - Evaluation

    /// Schedules a debounced forced evaluation against the current state.
    private func scheduleEvaluation() {
        debouncedEvaluationTask?.cancel()
        debouncedEvaluationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.evaluate(for: self.systemMonitor.state, force: true)
        }
    }

    /// Evaluates every enabled trigger against the given system state.
    ///
    /// A reveal decision that has flipped relative to the item's current
    /// placement is applied immediately when `force` is `true` (startup,
    /// edits, the safety timer) or after a debounce when `false` (live state
    /// changes).
    private func evaluate(for state: SystemState, force: Bool) {
        guard appState != nil else { return }

        let liveIDs = Set(triggers.map(\.id))
        lastAppliedReveal = lastAppliedReveal.filter { liveIDs.contains($0.key) }
        for (id, task) in pendingApplyTasks where !liveIDs.contains(id) {
            task.cancel()
            pendingApplyTasks[id] = nil
        }

        let now = Date()
        for trigger in triggers where trigger.isEnabled {
            guard !trigger.itemIdentifier.isEmpty else { continue }
            guard isAvailable(trigger) else { continue }

            let reveal = trigger.shouldReveal(state: state, now: now)

            if lastAppliedReveal[trigger.id] == reveal {
                pendingApplyTasks[trigger.id]?.cancel()
                pendingApplyTasks[trigger.id] = nil
                continue
            }

            if force {
                pendingApplyTasks[trigger.id]?.cancel()
                pendingApplyTasks[trigger.id] = nil
                apply(trigger, reveal: reveal)
            } else {
                scheduleDebouncedApply(for: trigger.id)
            }
        }
    }

    /// Whether the trigger's condition is currently available (its feature
    /// flag is enabled, or it is an always-available power condition).
    private func isAvailable(_ trigger: MenuBarItemTrigger) -> Bool {
        guard let feature = trigger.condition.kind.requiredFeature else { return true }
        return featureFlags.isEnabled(feature)
    }

    /// Schedules a debounced apply, re-checking the live state when the
    /// debounce elapses so a decision that flipped back is never acted on.
    /// The settle interval is per-condition (long for battery thresholds,
    /// short for discrete sources) so app/network/focus triggers stay
    /// responsive.
    private func scheduleDebouncedApply(for triggerID: UUID) {
        guard pendingApplyTasks[triggerID] == nil else { return }
        let settle = triggers.first(where: { $0.id == triggerID })?.condition.kind.settleInterval ?? flipDebounce
        pendingApplyTasks[triggerID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled, let self else { return }
            self.pendingApplyTasks[triggerID] = nil

            guard
                let trigger = self.triggers.first(where: { $0.id == triggerID }),
                trigger.isEnabled,
                !trigger.itemIdentifier.isEmpty,
                self.isAvailable(trigger)
            else {
                return
            }
            let reveal = trigger.shouldReveal(state: self.systemMonitor.state)
            guard self.lastAppliedReveal[triggerID] != reveal else { return }
            self.apply(trigger, reveal: reveal)
        }
    }

    /// Records the reveal decision as applied and moves the target item.
    private func apply(_ trigger: MenuBarItemTrigger, reveal: Bool) {
        guard let appState else { return }
        lastAppliedReveal[trigger.id] = reveal

        let section = reveal ? trigger.revealSection : trigger.hideSection
        let identifier = trigger.itemIdentifier
        diagLog.debug("Trigger \(trigger.displayName) reveal=\(reveal); moving \(identifier) to \(section.logString)")

        Task { @MainActor in
            await appState.itemManager.moveItem(withTagIdentifier: identifier, toSection: section)
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(triggers) else {
            diagLog.error("Failed to encode menu bar item triggers")
            return
        }
        Defaults.set(data, forKey: .menuBarItemTriggers)
    }

    private static func load() -> [MenuBarItemTrigger] {
        guard let data = Defaults.data(forKey: .menuBarItemTriggers) else {
            return []
        }
        do {
            return try JSONDecoder().decode([MenuBarItemTrigger].self, from: data)
        } catch {
            return []
        }
    }
}
