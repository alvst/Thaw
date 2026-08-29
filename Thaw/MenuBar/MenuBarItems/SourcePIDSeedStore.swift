//
//  SourcePIDSeedStore.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa

/// A remembered source-process attribution for one menu bar item window.
///
/// On macOS 26 every hosted status item window is owned by Control Center,
/// and the process that created it is resolved by an Accessibility scan in
/// the item service. That scan starts cold with the app: two seconds after
/// a launch it sees no AX frames at all, and on the next scans the AX frames
/// lag the window frames by one layout step, so the 1-pt spatial match fails
/// and the negative-cache ladder keeps the items provisional for up to a
/// minute (field log 2026-08-29, 13:44:22 to 13:44:47). Meanwhile the layout
/// editor drags items as `com.apple.controlcenter:Item-0:3` and the section
/// order cannot be saved.
///
/// Third-party item windows outlive Thaw: their Control Center window IDs
/// survived every Thaw relaunch in the field logs, and so did the processes
/// behind them. A seed remembers the last confirmed attribution so the next
/// launch can reuse it while the scan warms up. It is trusted only while the
/// process is still the same one — alive, and reporting the same bundle
/// identifier (or, for executables without one, the same name) — and it
/// never overrides a fresh resolution from the service.
nonisolated struct SourcePIDSeed: Codable, Equatable {
    /// The Control Center window the attribution belongs to.
    let windowID: CGWindowID

    /// The process the service last attributed the window to.
    let pid: pid_t

    /// The bundle identifier that process reported at the time, if any.
    let bundleIdentifier: String?

    /// The localized name that process reported at the time. This is the
    /// identity check for executables without a bundle identifier.
    let processName: String?
}

/// What a process reports about itself right now, compared against a seed.
nonisolated struct SourceProcessIdentity: Equatable {
    let bundleIdentifier: String?
    let processName: String?
}

/// Persists and applies ``SourcePIDSeed``s.
nonisolated enum SourcePIDSeedStore {
    /// The defaults key the seeds are stored under, as JSON.
    static let defaultsKey = "MenuBarItemManager.sourcePIDSeeds"

    /// Whether `seed` may stand in for a missing resolution of its window.
    ///
    /// `liveIdentity` is what the seed's PID reports now, or `nil` when no
    /// such process is running. A relaunched app has a new PID — its old
    /// PID is dead, or recycled by an unrelated process that fails the
    /// identity test — so a stale seed can never name the wrong app.
    ///
    /// Pure over its inputs.
    static func isTrustworthy(_ seed: SourcePIDSeed, liveIdentity: SourceProcessIdentity?) -> Bool {
        guard let liveIdentity else {
            return false
        }
        if let bundleIdentifier = seed.bundleIdentifier {
            return liveIdentity.bundleIdentifier == bundleIdentifier
        }
        guard let processName = seed.processName, !processName.isEmpty else {
            return false
        }
        return liveIdentity.bundleIdentifier == nil && liveIdentity.processName == processName
    }

    /// The seeds worth persisting from a resolved item list: one per window
    /// whose source process is known. Thaw's own control items are left out;
    /// their PID is known locally and never needs a seed.
    ///
    /// Pure over its inputs.
    static func seeds(
        from items: [MenuBarItem],
        identity: (pid_t) -> SourceProcessIdentity?
    ) -> [SourcePIDSeed] {
        var seen = Set<CGWindowID>()
        var result = [SourcePIDSeed]()
        for item in items where !item.isControlItem {
            guard let pid = item.sourcePID, seen.insert(item.windowID).inserted else {
                continue
            }
            let identity = identity(pid)
            result.append(
                SourcePIDSeed(
                    windowID: item.windowID,
                    pid: pid,
                    bundleIdentifier: identity?.bundleIdentifier,
                    processName: identity?.processName
                )
            )
        }
        return result.sorted { $0.windowID < $1.windowID }
    }

    /// Fills the unresolved slots of `pids` (indexed like `windowIDs`) from
    /// trustworthy seeds. Resolved slots are never touched: a fresh answer
    /// from the service always wins over a memory.
    ///
    /// - Returns: The window IDs that were seeded, in `windowIDs` order.
    ///
    /// Pure over its inputs.
    static func apply(
        seeds: [CGWindowID: SourcePIDSeed],
        to pids: inout [pid_t?],
        windowIDs: [CGWindowID],
        liveIdentity: (pid_t) -> SourceProcessIdentity?
    ) -> [CGWindowID] {
        var seeded = [CGWindowID]()
        for (index, windowID) in windowIDs.enumerated() where index < pids.count && pids[index] == nil {
            guard
                let seed = seeds[windowID],
                isTrustworthy(seed, liveIdentity: liveIdentity(seed.pid))
            else {
                continue
            }
            pids[index] = seed.pid
            seeded.append(windowID)
        }
        return seeded
    }

    /// What the process behind `pid` reports about itself, or `nil` when it
    /// is not running.
    static func liveIdentity(of pid: pid_t) -> SourceProcessIdentity? {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            return nil
        }
        return SourceProcessIdentity(bundleIdentifier: app.bundleIdentifier, processName: app.localizedName)
    }

    // MARK: Persistence

    /// The stored seeds, keyed by window ID.
    static func load(from defaults: UserDefaults) -> [CGWindowID: SourcePIDSeed] {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let seeds = try? JSONDecoder().decode([SourcePIDSeed].self, from: data)
        else {
            return [:]
        }
        return Dictionary(seeds.map { ($0.windowID, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// Stores `seeds`, replacing whatever was stored before.
    static func save(_ seeds: [SourcePIDSeed], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(seeds) else {
            return
        }
        defaults.set(data, forKey: defaultsKey)
    }
}
