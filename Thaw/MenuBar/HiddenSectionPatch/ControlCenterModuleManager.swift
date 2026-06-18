//
//  ControlCenterModuleManager.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Cocoa

/// Governs the visibility of the Apple Control Center menu-bar extras that the
/// macOS 27 Assessment Mode allowlist *cannot* control individually.
///
/// The 2026-06-18 investigation proved that AirDrop, Focus, User (Fast User
/// Switching), and Now Playing are not addressable by either Assessment Mode
/// axis: they have no `MBSystemItemIdentifier` raw value (only the 9 core
/// modules, 0...8, do) and their `com.apple.menuextra.*` IDs in the bundle
/// allowlist are ignored. Whenever a restriction is active they are collaterally
/// hidden, and nothing in the allowlist can keep them.
///
/// These four are, however, ordinary Control Center modules whose menu-bar
/// visibility lives in Control Center's own **per-host** preference domain:
///
///     defaults -currentHost write com.apple.controlcenter <Key> -int <2|8>
///
/// where `2` shows the module in the menu bar and `8` hides it (empirically
/// confirmed via a reversible AirDrop flip-test). The change only takes effect
/// after Control Center is relaunched (it reads the preference at launch), so
/// this manager restarts it whenever it mutates a value.
///
/// This is a *separate subsystem* from ``AssessmentModeBackend``: those modules
/// are stripped from the assessment allowlist input and handled here instead.
/// Note the inherent limitation — while any assessment restriction is active the
/// four modules are collaterally hidden regardless of their preference, so this
/// manager's visible effect is the per-item show/hide when no restriction (or no
/// *other* hidden item) forces them off.
@MainActor
final class ControlCenterModuleManager {
    /// Maps a MenuBarAgent extra's AX title to its Control Center per-host
    /// preference key.
    ///
    /// AirDrop / NowPlaying / UserSwitcher are confirmed keys present in the
    /// live `com.apple.controlcenter` per-host domain. Focus has no key until
    /// the module is customized; `FocusModes` is the conventional name and is
    /// written speculatively (a wrong key is an inert no-op, never harmful).
    nonisolated static let moduleKeysByMenuExtraTitle: [String: String] = [
        "com.apple.menuextra.airdrop": "AirDrop",
        "com.apple.menuextra.now-playing": "NowPlaying",
        "com.apple.menuextra.user": "UserSwitcher",
        "com.apple.menuextra.focusmode": "FocusModes",
    ]

    /// The per-host preference value that shows a module in the menu bar.
    nonisolated static let shownValue = 2

    /// The per-host preference value that hides a module from the menu bar.
    nonisolated static let hiddenValue = 8

    private static let domain = "com.apple.controlcenter" as CFString
    private static let controlCenterBundleID = "com.apple.controlcenter"

    private let diagLog = DiagLog(category: "ControlCenterModuleManager")

    /// The menu-extra titles currently hidden by this manager.
    private var appliedHidden: Set<String> = []

    /// The pre-hide preference value to restore for each hidden module, captured
    /// while it was still shown so a non-default user preference survives.
    private var originalValues: [String: Int] = [:]

    /// Retains the block-based termination observer for the app's lifetime (this
    /// manager is owned by `SimpleItemHider`, which lives the whole session).
    private var terminationObserver: NSObjectProtocol?

    init() {
        // Restore the user's modules if Thaw quits while it has any hidden, so a
        // CC-pref hide never outlives the app that applied it.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restoreAll() }
        }
    }

    // MARK: Identifier helpers

    /// The governable menu-extra title embedded in an item `uniqueIdentifier`
    /// such as `com.apple.MenuBarAgent:com.apple.menuextra.airdrop`, or `nil` if
    /// the identifier is not one of the Control Center modules this manager owns.
    nonisolated static func governableMenuExtraTitle(forItemIdentifier identifier: String) -> String? {
        for title in moduleKeysByMenuExtraTitle.keys
            where identifier == title || identifier.hasSuffix(":\(title)")
        {
            return title
        }
        return nil
    }

    /// Whether the given item `uniqueIdentifier` is a Control Center module this
    /// manager governs (and therefore should be kept out of the assessment-mode
    /// allowlist input).
    nonisolated static func isGovernable(itemIdentifier identifier: String) -> Bool {
        governableMenuExtraTitle(forItemIdentifier: identifier) != nil
    }

    // MARK: Apply

    /// Hides exactly the given set of governable menu-extra titles via their
    /// Control Center preference, restoring any module no longer in the set.
    ///
    /// Restarts Control Center only when a preference value actually changes, so
    /// the steady-state 1s refresh is a no-op once the desired set is applied.
    ///
    /// - Returns: `true` if any preference changed (and Control Center was
    ///   restarted), `false` otherwise.
    @discardableResult
    func apply(hiddenMenuExtraTitles titles: Set<String>) -> Bool {
        let desired = titles.filter { Self.moduleKeysByMenuExtraTitle[$0] != nil }
        guard desired != appliedHidden else {
            return false
        }

        var changed = false

        for title in desired.subtracting(appliedHidden) {
            guard let key = Self.moduleKeysByMenuExtraTitle[title] else { continue }
            let current = Self.readValue(forKey: key) ?? Self.shownValue
            if current != Self.hiddenValue {
                originalValues[title] = current
            }
            if Self.writeValue(Self.hiddenValue, forKey: key) {
                changed = true
            }
        }

        for title in appliedHidden.subtracting(desired) {
            guard let key = Self.moduleKeysByMenuExtraTitle[title] else { continue }
            let restore = originalValues.removeValue(forKey: title) ?? Self.shownValue
            if Self.writeValue(restore, forKey: key) {
                changed = true
            }
        }

        appliedHidden = desired

        if changed {
            Self.synchronize()
            Self.restartControlCenter()
            diagLog.info("applied CC module visibility; hidden=\(desired.sorted())")
        }
        return changed
    }

    /// Restores every module this manager has hidden to its pre-hide value. Used
    /// on teardown / app termination so a CC-pref hide never persists past Thaw.
    func restoreAll() {
        apply(hiddenMenuExtraTitles: [])
    }

    // MARK: Preference I/O

    private static func readValue(forKey key: String) -> Int? {
        let value = CFPreferencesCopyValue(
            key as CFString,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        return (value as? NSNumber)?.intValue
    }

    @discardableResult
    private static func writeValue(_ value: Int, forKey key: String) -> Bool {
        if readValue(forKey: key) == value {
            return false
        }
        CFPreferencesSetValue(
            key as CFString,
            value as CFNumber,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        return true
    }

    private static func synchronize() {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Sends SIGTERM to the running Control Center so it relaunches and re-reads
    /// the preference. Control Center is a managed launch agent and restarts
    /// itself automatically within ~1-2s.
    private static func restartControlCenter() {
        for app in NSWorkspace.shared.runningApplications
            where app.bundleIdentifier == controlCenterBundleID
        {
            kill(app.processIdentifier, SIGTERM)
        }
    }
}
