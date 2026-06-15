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
/// by revealing or hiding their target items as power conditions change.
///
/// Each enabled trigger is re-evaluated whenever the system power state
/// changes (and periodically as a safety net). When a trigger's condition
/// flips, its target item is moved into the configured reveal or hide
/// section. The move is a no-op when the item is already in the target
/// section, so re-evaluation is self-correcting and cheap.
@MainActor
final class MenuBarItemTriggersManager: ObservableObject {
    /// The user's configured triggers.
    @Published var triggers: [MenuBarItemTrigger] {
        didSet {
            guard !suppressPersist else { return }
            persist()
            // A trigger may have been added, edited, or re-enabled; drop the
            // memoized satisfaction state so the next evaluation re-applies.
            // (The actual move is still a no-op when the item is already in
            // the right section, so this does not warp the cursor on edits
            // that change nothing about placement.)
            lastAppliedSatisfied.removeAll()
            scheduleEvaluation()
        }
    }

    /// The shared app state.
    private weak var appState: AppState?

    /// Monitors the system power source.
    private let powerMonitor = PowerSourceMonitor()

    /// The satisfaction value currently reflected in each target item's
    /// placement, used to skip redundant moves when nothing changed.
    private var lastAppliedSatisfied = [UUID: Bool]()

    /// Per-trigger debounced apply tasks. A condition change only moves its
    /// item after the new state has held continuously for ``flipDebounce``,
    /// which prevents cursor-warping moves from battery readings that jitter
    /// around a threshold.
    private var pendingApplyTasks = [UUID: Task<Void, Never>]()

    /// How long a flipped condition must hold before the item is moved.
    private let flipDebounce: Duration = .seconds(6)

    /// True while loading from defaults; suppresses writeback in the
    /// `triggers` didSet so the initial load is not echoed to disk.
    private var suppressPersist = false

    private var cancellables = Set<AnyCancellable>()

    /// A debounced forced-evaluation task, restarted on each edit so a
    /// burst of UI changes results in a single re-evaluation.
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

        powerMonitor.start()

        // Re-evaluate on every distinct power state change. removeDuplicates
        // keeps the safety-timer republishes from causing redundant work.
        powerMonitor.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.evaluate(for: state, force: false)
            }
            .store(in: &cancellables)

        // A periodic forced re-evaluation reconciles any drift (manual user
        // moves, items that appear after launch) without waiting for a
        // power change.
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.evaluate(for: self.powerMonitor.state, force: true)
            }
            .store(in: &cancellables)

        // Apply the current state once at startup. Force so freshly resolved
        // items are placed even if the satisfaction value matches the
        // default.
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
        lastAppliedSatisfied[id] = nil
        pendingApplyTasks[id]?.cancel()
        pendingApplyTasks[id] = nil
    }

    /// Removes the triggers at the given offsets.
    func remove(atOffsets offsets: IndexSet) {
        let removedIDs = offsets.compactMap { triggers.indices.contains($0) ? triggers[$0].id : nil }
        triggers.remove(atOffsets: offsets)
        for id in removedIDs {
            lastAppliedSatisfied[id] = nil
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

    /// Schedules a debounced forced evaluation against the current power
    /// state, so a burst of edits coalesces into a single re-evaluation.
    private func scheduleEvaluation() {
        debouncedEvaluationTask?.cancel()
        debouncedEvaluationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.evaluate(for: self.powerMonitor.state, force: true)
        }
    }

    /// Evaluates every enabled trigger against the given power state.
    ///
    /// A condition that has flipped relative to the item's current placement
    /// is applied immediately when `force` is `true` (startup, edits, and the
    /// safety timer) or after a debounce when `false` (live power changes),
    /// so brief threshold jitter does not thrash the menu bar.
    ///
    /// - Parameter force: When `true`, applies flipped conditions without
    ///   waiting for the debounce. The move itself remains a no-op when the
    ///   item is already in the target section.
    private func evaluate(for state: PowerState, force: Bool) {
        guard appState != nil else { return }

        // Prune memoized state and pending work for triggers that are gone.
        let liveIDs = Set(triggers.map(\.id))
        lastAppliedSatisfied = lastAppliedSatisfied.filter { liveIDs.contains($0.key) }
        for (id, task) in pendingApplyTasks where !liveIDs.contains(id) {
            task.cancel()
            pendingApplyTasks[id] = nil
        }

        for trigger in triggers where trigger.isEnabled {
            guard !trigger.itemIdentifier.isEmpty else { continue }

            let satisfied = trigger.condition.isSatisfied(by: state)

            // Desired placement already matches what we last applied: cancel
            // any pending flip (the state returned before the debounce
            // elapsed) and move on without touching the menu bar.
            if lastAppliedSatisfied[trigger.id] == satisfied {
                pendingApplyTasks[trigger.id]?.cancel()
                pendingApplyTasks[trigger.id] = nil
                continue
            }

            if force {
                pendingApplyTasks[trigger.id]?.cancel()
                pendingApplyTasks[trigger.id] = nil
                apply(trigger, satisfied: satisfied)
            } else {
                scheduleDebouncedApply(for: trigger.id)
            }
        }
    }

    /// Schedules a debounced apply for the trigger, re-checking the live
    /// state when the debounce elapses so a condition that flipped back is
    /// never acted on.
    private func scheduleDebouncedApply(for triggerID: UUID) {
        guard pendingApplyTasks[triggerID] == nil else { return }
        pendingApplyTasks[triggerID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.flipDebounce ?? .seconds(6))
            guard !Task.isCancelled, let self else { return }
            self.pendingApplyTasks[triggerID] = nil

            guard
                let trigger = self.triggers.first(where: { $0.id == triggerID }),
                trigger.isEnabled,
                !trigger.itemIdentifier.isEmpty
            else {
                return
            }
            let satisfied = trigger.condition.isSatisfied(by: self.powerMonitor.state)
            guard self.lastAppliedSatisfied[triggerID] != satisfied else { return }
            self.apply(trigger, satisfied: satisfied)
        }
    }

    /// Records the satisfaction value as applied and moves the target item
    /// into the corresponding section.
    private func apply(_ trigger: MenuBarItemTrigger, satisfied: Bool) {
        guard let appState else { return }
        lastAppliedSatisfied[trigger.id] = satisfied

        let section = satisfied ? trigger.revealSection : trigger.hideSection
        let identifier = trigger.itemIdentifier
        diagLog.debug("Trigger \(trigger.displayName) satisfied=\(satisfied); moving \(identifier) to \(section.logString)")

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
