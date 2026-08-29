//
//  SourcePIDSeedStoreTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite("SourcePIDSeedStore")
struct SourcePIDSeedStoreTests {
    private let bundled = SourcePIDSeed(
        windowID: 2314,
        pid: 54484,
        bundleIdentifier: "com.example.IconSwitcher",
        processName: "Icon Switcher"
    )

    private let bare = SourcePIDSeed(
        windowID: 5467,
        pid: 12460,
        bundleIdentifier: nil,
        processName: "IconSwitcher"
    )

    @Test("A seed is trusted only while the same bundle is still behind its PID")
    func bundledSeedRequiresMatchingBundle() {
        #expect(SourcePIDSeedStore.isTrustworthy(
            bundled,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: "com.example.IconSwitcher", processName: "Icon Switcher")
        ))
        // A renamed process with the same bundle is still the same app.
        #expect(SourcePIDSeedStore.isTrustworthy(
            bundled,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: "com.example.IconSwitcher", processName: "Other")
        ))
        // The PID was recycled by another app.
        #expect(!SourcePIDSeedStore.isTrustworthy(
            bundled,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: "sh.gyorgy.keepresso", processName: "Keepresso")
        ))
        // The process is gone.
        #expect(!SourcePIDSeedStore.isTrustworthy(bundled, liveIdentity: nil))
    }

    @Test("A bundle-less seed falls back to the process name")
    func bareSeedRequiresMatchingName() {
        #expect(SourcePIDSeedStore.isTrustworthy(
            bare,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: nil, processName: "IconSwitcher")
        ))
        #expect(!SourcePIDSeedStore.isTrustworthy(
            bare,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: nil, processName: "swift-build")
        ))
        // A bundled app that happens to share the name is not the same process.
        #expect(!SourcePIDSeedStore.isTrustworthy(
            bare,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: "com.example.IconSwitcher", processName: "IconSwitcher")
        ))
        let nameless = SourcePIDSeed(windowID: 1, pid: 2, bundleIdentifier: nil, processName: nil)
        #expect(!SourcePIDSeedStore.isTrustworthy(
            nameless,
            liveIdentity: SourceProcessIdentity(bundleIdentifier: nil, processName: nil)
        ))
    }

    @Test("Applying seeds fills only unresolved slots with trustworthy seeds")
    func applyFillsOnlyUnresolvedSlots() {
        var pids: [pid_t?] = [nil, 8086, nil, nil]
        let windowIDs: [CGWindowID] = [2314, 2556, 5467, 71]
        let seeds: [CGWindowID: SourcePIDSeed] = [
            2314: bundled,
            2556: SourcePIDSeed(windowID: 2556, pid: 999, bundleIdentifier: "x.y.z", processName: nil),
            5467: bare,
        ]
        let identities: [pid_t: SourceProcessIdentity] = [
            54484: SourceProcessIdentity(bundleIdentifier: "com.example.IconSwitcher", processName: "Icon Switcher"),
            // The bare binary relaunched: its old PID now belongs to something else.
            12460: SourceProcessIdentity(bundleIdentifier: "com.apple.Terminal", processName: "Terminal"),
        ]

        let seeded = SourcePIDSeedStore.apply(
            seeds: seeds,
            to: &pids,
            windowIDs: windowIDs,
            liveIdentity: { identities[$0] }
        )

        #expect(seeded == [2314])
        #expect(pids == [54484, 8086, nil, nil])
    }

    @Test("Seeds are taken from resolved, non-control items only, once per window")
    func seedsFromItems() {
        let items = [
            MenuBarItem.fixture(
                tag: .appItem(bundleID: "com.example.IconSwitcher", title: "Item-0", windowID: 2314),
                windowID: 2314,
                sourcePID: 54484
            ),
            MenuBarItem.fixture(
                tag: .appItem(bundleID: "com.example.IconSwitcher", title: "Item-0", windowID: 2314),
                windowID: 2314,
                sourcePID: 54484
            ),
            MenuBarItem.fixture(
                tag: .appItem(bundleID: "com.apple.controlcenter", title: "Item-11", windowID: 4926),
                windowID: 4926,
                sourcePID: nil
            ),
            MenuBarItem.fixture(tag: .hiddenControlItem, windowID: 5718, sourcePID: 17950),
            MenuBarItem.fixture(
                tag: .appItem(bundleID: "sh.gyorgy.keepresso", title: "Item-0", windowID: 2556),
                windowID: 2556,
                sourcePID: 8086
            ),
        ]
        let identities: [pid_t: SourceProcessIdentity] = [
            54484: SourceProcessIdentity(bundleIdentifier: "com.example.IconSwitcher", processName: "Icon Switcher"),
            8086: SourceProcessIdentity(bundleIdentifier: "sh.gyorgy.keepresso", processName: "Keepresso"),
        ]

        let seeds = SourcePIDSeedStore.seeds(from: items) { identities[$0] }

        #expect(seeds == [
            SourcePIDSeed(windowID: 2314, pid: 54484, bundleIdentifier: "com.example.IconSwitcher", processName: "Icon Switcher"),
            SourcePIDSeed(windowID: 2556, pid: 8086, bundleIdentifier: "sh.gyorgy.keepresso", processName: "Keepresso"),
        ])
    }

    @Test("Seeds round-trip through defaults")
    func seedsRoundTrip() throws {
        let suiteName = "com.stonerl.Thaw.tests.SourcePIDSeedStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(SourcePIDSeedStore.load(from: defaults).isEmpty)

        SourcePIDSeedStore.save([bundled, bare], to: defaults)
        let loaded = SourcePIDSeedStore.load(from: defaults)

        #expect(loaded == [2314: bundled, 5467: bare])

        SourcePIDSeedStore.save([], to: defaults)
        #expect(SourcePIDSeedStore.load(from: defaults).isEmpty)
    }

    @Test("Corrupt stored data reads as no seeds")
    func corruptDataReadsAsEmpty() throws {
        let suiteName = "com.stonerl.Thaw.tests.SourcePIDSeedStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not json".utf8), forKey: SourcePIDSeedStore.defaultsKey)

        #expect(SourcePIDSeedStore.load(from: defaults).isEmpty)
    }
}
