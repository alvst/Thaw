//
//  AssessmentModeBackend.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Cocoa

/// Real macOS 27 menu bar item hiding, via the private MenuBarClientCore
/// "Assessment Mode" visibility-restriction assertion (see
/// ``ThawAssessmentModeHidingActivate``).
///
/// The assertion is an **allowlist**: every menu bar item whose owner is not
/// listed is hidden and the bar reflows. Thaw's model is a *deny* set (the
/// items the user chose to hide), so this backend inverts it — allow every
/// running app except the owners of hidden items, keep all Apple core system
/// items, and preserve MenuBarAgent extras by their logical bundle IDs.
///
/// Granularity for third-party items is per owning app: the assertion allowlist
/// keys on bundle identifiers, so hiding *any* item of an app hides *all* of
/// that app's items as a group. In practice almost every app vends a single
/// menu bar item, so this matches user expectations.
///
/// For the rare multi-item app, this backend errs on the side of *not* hiding:
/// a bundle is concealed only when none of its currently-enumerated items are
/// assigned `.visible` (see ``apply(sectionAssignment:allItems:)``).
/// That keeps the visible items — and the Visible layout bar — truthful, at the
/// cost of an item assigned Hidden staying visible while a sibling is Visible.
/// When the private API is unavailable this backend is simply inert; there is no
/// fallback.
@MainActor
final class AssessmentModeBackend {
    /// Whether the private assertion API is present on this system.
    static var isAvailable: Bool {
        ThawAssessmentModeHidingAvailable()
    }

    /// Diagnostic modes for the private Assessment Mode system-item allowlist.
    ///
    /// The default preserves Thaw's current macOS 27 behavior. The expanded and
    /// bundle-only modes are hidden expert probes for isolating whether Apple's
    /// system-item allowlist is involved in status-item scene loss.
    enum DiagnosticSystemItemsMode: String {
        case defaultRange = "default"
        case expandedRange = "expanded"
        case bundleOnly = "bundleOnly"

        var allowedSystemItems: [NSNumber] {
            switch self {
            case .defaultRange:
                // MBSystemItemIdentifier has exactly 9 cases, raw values 0...8:
                // battery, Bluetooth, clock, displays, keyboard, volume, Wi-Fi,
                // screen mirroring, and the primary BentoBox. Menu extras such
                // as AirDrop are not in this enum; Assessment Mode matches them
                // by logical com.apple.menuextra.* IDs instead.
                (0...8).map { NSNumber(value: $0) }
            case .expandedRange:
                (0...32).map { NSNumber(value: $0) }
            case .bundleOnly:
                []
            }
        }

        var logDescription: String {
            switch self {
            case .defaultRange:
                "default(0...8)"
            case .expandedRange:
                "expanded(0...32)"
            case .bundleOnly:
                "bundleOnly(empty)"
            }
        }
    }

    static func diagnosticSystemItemsMode(rawValue: String?) -> DiagnosticSystemItemsMode {
        // macOS 27: .defaultRange (0...8) is the proven optimum. The 2026-06-18
        // probe exhausted every systemItems setting: 0...8 keeps the 5 core CC
        // modules but always collateral-hides the 4 non-core extras
        // (user/now-playing/focusmode/airdrop); 0...32 is identical (raw values >8
        // map to nothing); [] (.bundleOnly) hides ALL 9. The 4 extras have no slot
        // in either allowlist axis, so the mechanism cannot preserve them — accept
        // collateral. See [[macos27-system-item-hiding-approach]].
        guard let rawValue, !rawValue.isEmpty else {
            return .defaultRange
        }
        return DiagnosticSystemItemsMode(rawValue: rawValue) ?? .defaultRange
    }

    private static var diagnosticSystemItemsMode: DiagnosticSystemItemsMode {
        diagnosticSystemItemsMode(rawValue: Defaults.string(forKey: .diagnosticAssessmentModeSystemItems))
    }

    private let diagLog = DiagLog(category: "AssessmentModeBackend")

    /// The live assertion handle, or `nil` when nothing is hidden.
    private var handle: UnsafeMutableRawPointer?

    /// The concealed-app bundle IDs baked into the currently-active assertion.
    private var appliedConcealed: Set<String> = []

    /// The allowed-app bundle IDs baked into the currently-active assertion.
    private var appliedAllowed: Set<String> = []

    /// The system-item allowlist mode baked into the currently-active assertion.
    private var appliedSystemItemsMode: DiagnosticSystemItemsMode?

    /// Learned `uniqueIdentifier → owning bundle ID` map. A concealed item drops
    /// out of AX enumeration entirely (the assertion removes it), so it would no
    /// longer appear in `allItems` and we'd lose its bundle ID — resetting the
    /// restriction and flickering it back on. Remembering the mapping from when
    /// the item *was* visible keeps it concealed across refreshes.
    private var knownBundleIDs: [String: String] = [:]

    /// Monotonic token identifying the most recent activation attempt. The
    /// assertion's failure callback fires asynchronously, by which point a newer
    /// activation may already be in effect; the callback compares against this to
    /// avoid tearing down a handle it didn't create.
    private var activationGeneration = 0

    /// The allowed set whose activation most recently failed asynchronously, or
    /// `nil`. Used to avoid re-activating the *identical* failed configuration on
    /// the next 1s tick (which would hot-loop); any genuine change to the desired
    /// set clears it and allows another attempt.
    private var lastFailedAllowed: Set<String>?

    static var protectedBundleIDs: Set<String> {
        Constants.thawOwnedBundleIdentifiers
    }

    private var protectedBundleIDs: Set<String> {
        Self.protectedBundleIDs
    }

    /// The identifiers currently concealed for a given assignment.
    private func concealedIdentifiers(
        sectionAssignment: [String: MenuBarSection.Name]
    ) -> Set<String> {
        var concealed = Set<String>()
        for (identifier, section) in sectionAssignment {
            switch section {
            case .visible:
                continue
            case .hidden, .alwaysHidden:
                concealed.insert(identifier)
            }
        }
        return concealed
    }

    private func isOwnAppBundleID(_ bundleID: String?) -> Bool {
        Constants.isThawOwnedBundleIdentifier(bundleID)
    }

    private func isOwnAppItem(_ item: MenuBarItem) -> Bool {
        item.tag.namespace == .thaw ||
            isOwnAppBundleID(item.sourceApplication?.bundleIdentifier) ||
            isOwnAppBundleID(item.owningApplication?.bundleIdentifier)
    }

    @discardableResult
    func apply(
        sectionAssignment: [String: MenuBarSection.Name],
        allItems: [MenuBarItem]
    ) -> Bool {
        // Learn/refresh the owner bundle ID of every currently-enumerated item.
        // owningApplication is Control Center on macOS 26+, so use
        // sourceApplication (the real app).
        for item in allItems {
            guard !isOwnAppItem(item) else {
                knownBundleIDs.removeValue(forKey: item.uniqueIdentifier)
                continue
            }
            if let bundleID = item.sourceApplication?.bundleIdentifier {
                knownBundleIDs[item.uniqueIdentifier] = bundleID
            }
        }

        // The identifiers concealed right now, based on persisted section
        // assignment.
        let concealed = concealedIdentifiers(
            sectionAssignment: sectionAssignment
        )

        // Bundles that still have at least one item that should be visible right
        // now (assigned `.visible`).
        // The assertion allowlist is per-bundle, so concealing such a bundle
        // would also hide those visible items — worse than leaving the
        // hidden-assigned sibling on screen. Exclude them below so the Visible
        // layout bar never disagrees with the real menu bar.
        var bundlesWithVisibleItem = Set<String>()
        for item in allItems where !concealed.contains(item.uniqueIdentifier) {
            guard !isOwnAppItem(item) else {
                bundlesWithVisibleItem.formUnion(protectedBundleIDs)
                continue
            }
            if let bundleID = item.sourceApplication?.bundleIdentifier {
                bundlesWithVisibleItem.insert(bundleID)
            }
        }

        // Owner bundle IDs of the concealed items, resolved from the learned map
        // so items that have already dropped out of enumeration stay concealed —
        // minus any bundle that still has a visible item (see above).
        var concealedBundleIDs = Set(concealed.compactMap { identifier in
            let bundleID = knownBundleIDs[identifier]
            return isOwnAppBundleID(bundleID) ? nil : bundleID
        })
            .subtracting(bundlesWithVisibleItem)

        // Never conceal Thaw itself. Thaw's own control items are *not* in
        // `allItems` (the cache exposes them separately, not as managed items),
        // so the visible-item guard above can't protect them; combined with the
        // sticky `knownBundleIDs` map, a hidden item that transiently mis-resolves
        // its owner to Thaw (PID reuse / AX hiccup) would conceal Thaw's control
        // item permanently and make the app unreachable. Self-protect
        // unconditionally — Thaw must always remain in the allowlist.
        for bundleID in protectedBundleIDs {
            concealedBundleIDs.remove(bundleID)
        }

        // Nothing concealed → tear down any active restriction.
        guard !concealedBundleIDs.isEmpty else {
            return reset()
        }

        // Allow every running app except those whose items are hidden. Listing
        // all running apps (not just ones currently in the cache) means apps
        // that appear later stay visible without a race. Thaw is force-included
        // so its own icon can never be hidden by the allowlist.
        var allowedSet = Set(
            NSWorkspace.shared.runningApplications
                .compactMap(\.bundleIdentifier)
                .filter { !concealedBundleIDs.contains($0) }
        )
        for bundleID in protectedBundleIDs {
            allowedSet.insert(bundleID)
        }

        // Ground-truth self-check: does the allowlist we're about to apply keep
        // every Thaw-owned icon host? If these log `allowed=true concealed=false`
        // and the icon is still hidden, the assertion is not honoring that
        // protected owner — a mechanism limitation, not an allowlist bug.
        for ownBundleID in protectedBundleIDs.sorted() {
            let running = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == ownBundleID
            }
            diagLog.info("self-check: \(ownBundleID) allowed=\(allowedSet.contains(ownBundleID)) concealed=\(concealedBundleIDs.contains(ownBundleID)) inRunningApps=\(running)")
        }

        // Re-activating tears down and rebuilds the restriction, which reflows
        // the whole menu bar — expensive, and a churn source when called on the
        // 1s timer while apps come and go (each Xcode/helper launch is a new
        // running app). So re-apply only when it actually matters:
        //   • nothing active yet, or
        //   • the concealed set changed (layout drag/reset), or
        //   • a *new* app appeared that must be kept visible (else it'd be
        //     hidden by the allowlist).
        // Apps merely quitting leave harmless stale entries in the allowlist, so
        // a pure shrink of the allowed set is ignored — no reflow needed.
        let systemItemsMode = Self.diagnosticSystemItemsMode
        let concealedChanged = concealedBundleIDs != appliedConcealed
        let systemItemsModeChanged = systemItemsMode != appliedSystemItemsMode
        let newlyAppeared = !allowedSet.subtracting(appliedAllowed).isEmpty
        guard handle == nil || concealedChanged || systemItemsModeChanged || newlyAppeared else { return false }

        // Don't re-activate the exact configuration that just failed
        // asynchronously — that would hot-loop on the 1s timer. Any change to the
        // desired set (an app launching/quitting, a drag/reset) makes this
        // unequal and clears the marker below, so a genuine retry still happens.
        if allowedSet == lastFailedAllowed {
            return false
        }
        lastFailedAllowed = nil

        // Re-activate with the new allowlist. The previous assertion is dropped
        // first so the server applies a single, current restriction.
        let allowedBundleIDs = allowedSet.sorted()
        let allowedSystemItems = systemItemsMode.allowedSystemItems
        activationGeneration += 1
        let generation = activationGeneration
        let attemptedAllowed = allowedSet
        diagLog.info(
            "applying restriction: systemItemsMode=\(systemItemsMode.logDescription), " +
            "systemItems=\(allowedSystemItems.map(\.stringValue)), " +
            "concealedBundles=\(concealedBundleIDs.sorted()), allowedBundles=\(allowedBundleIDs.count)"
        )
        let newHandle = ThawAssessmentModeHidingActivate(allowedBundleIDs, allowedSystemItems) { [weak self] in
            // Dispatched to the main queue by the ObjC wrapper, so MainActor
            // isolation holds at runtime even though the block type is not.
            MainActor.assumeIsolated {
                // Async activation failure. If a newer activation has since run,
                // this is stale — ignore it. Otherwise tear down the dud handle
                // so the next tick can retry once the desired set changes.
                guard let self, self.activationGeneration == generation else { return }
                self.diagLog.error("activation failed asynchronously; tearing down handle to allow retry")
                if let dud = self.handle {
                    ThawAssessmentModeHidingInvalidate(dud)
                }
                self.handle = nil
                self.appliedConcealed = []
                self.appliedAllowed = []
                self.appliedSystemItemsMode = nil
                self.lastFailedAllowed = attemptedAllowed
            }
        }
        if let old = handle {
            ThawAssessmentModeHidingInvalidate(old)
        }
        handle = newHandle
        appliedConcealed = concealedBundleIDs
        appliedAllowed = allowedSet
        appliedSystemItemsMode = systemItemsMode
        diagLog.info(
            "applied restriction: concealing \(concealedBundleIDs.count) app(s), " +
            "allowing \(allowedBundleIDs.count), systemItemsMode=\(systemItemsMode.logDescription)"
        )
        return true
    }

    private func reset() -> Bool {
        guard handle != nil else { return false }
        ThawAssessmentModeHidingInvalidate(handle)
        handle = nil
        appliedConcealed = []
        appliedAllowed = []
        appliedSystemItemsMode = nil
        diagLog.info("restriction reset; all items revealed")
        return true
    }
}
