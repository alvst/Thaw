//
//  MenuBarItemTagTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import CoreGraphics
import XCTest

// MARK: - MenuBarItemTag.Namespace Tests

final class MenuBarItemTagNamespaceTests: XCTestCase {
    // MARK: - Initialization Tests

    func testNullNamespace() {
        let namespace = MenuBarItemTag.Namespace.null

        XCTAssertTrue(namespace.isNull)
        XCTAssertFalse(namespace.isString)
        XCTAssertFalse(namespace.isUUID)
        XCTAssertEqual(namespace.description, "null")
    }

    func testStringNamespace() {
        let namespace = MenuBarItemTag.Namespace.string("com.example.app")

        XCTAssertFalse(namespace.isNull)
        XCTAssertTrue(namespace.isString)
        XCTAssertFalse(namespace.isUUID)
        XCTAssertEqual(namespace.description, "com.example.app")
    }

    func testUUIDNamespace() {
        let uuid = UUID()
        let namespace = MenuBarItemTag.Namespace.uuid(uuid)

        XCTAssertFalse(namespace.isNull)
        XCTAssertFalse(namespace.isString)
        XCTAssertTrue(namespace.isUUID)
        XCTAssertEqual(namespace.description, uuid.uuidString)
    }

    func testOptionalWithValue() {
        let namespace = MenuBarItemTag.Namespace.optional("com.test.app")

        XCTAssertTrue(namespace.isString)
        XCTAssertEqual(namespace.description, "com.test.app")
    }

    func testOptionalWithNil() {
        let namespace = MenuBarItemTag.Namespace.optional(nil)

        XCTAssertTrue(namespace.isNull)
    }

    // MARK: - Equality Tests

    func testNamespaceEquality() {
        let ns1 = MenuBarItemTag.Namespace.string("com.example.app")
        let ns2 = MenuBarItemTag.Namespace.string("com.example.app")
        let ns3 = MenuBarItemTag.Namespace.string("com.other.app")

        XCTAssertEqual(ns1, ns2)
        XCTAssertNotEqual(ns1, ns3)
    }

    func testNullNamespaceEquality() {
        let ns1 = MenuBarItemTag.Namespace.null
        let ns2 = MenuBarItemTag.Namespace.null

        XCTAssertEqual(ns1, ns2)
    }

    func testUUIDNamespaceEquality() {
        let uuid = UUID()
        let ns1 = MenuBarItemTag.Namespace.uuid(uuid)
        let ns2 = MenuBarItemTag.Namespace.uuid(uuid)
        let ns3 = MenuBarItemTag.Namespace.uuid(UUID())

        XCTAssertEqual(ns1, ns2)
        XCTAssertNotEqual(ns1, ns3)
    }

    func testDifferentTypesNotEqual() {
        let stringNs = MenuBarItemTag.Namespace.string("test")
        let nullNs = MenuBarItemTag.Namespace.null

        XCTAssertNotEqual(stringNs, nullNs)
    }

    // MARK: - Hashable Tests

    func testNamespaceHashable() {
        let ns1 = MenuBarItemTag.Namespace.string("com.example.app")
        let ns2 = MenuBarItemTag.Namespace.string("com.example.app")

        XCTAssertEqual(ns1.hashValue, ns2.hashValue)
    }

    func testNamespaceInSet() {
        var set = Set<MenuBarItemTag.Namespace>()
        set.insert(.string("com.example.app"))
        set.insert(.string("com.example.app")) // duplicate
        set.insert(.null)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Static Constants Tests

    func testThawNamespace() {
        let thaw = MenuBarItemTag.Namespace.thaw
        XCTAssertTrue(thaw.isString)
        XCTAssertEqual(thaw.description, Constants.bundleIdentifier)
    }

    func testControlCenterNamespace() {
        let cc = MenuBarItemTag.Namespace.controlCenter
        XCTAssertTrue(cc.isString)
        XCTAssertEqual(cc.description, "com.apple.controlcenter")
    }

    func testSystemUIServerNamespace() {
        let sys = MenuBarItemTag.Namespace.systemUIServer
        XCTAssertTrue(sys.isString)
        XCTAssertEqual(sys.description, "com.apple.systemuiserver")
    }
}

// MARK: - MenuBarItemTag Tests

final class MenuBarItemTagTests: XCTestCase {
    // MARK: - Initialization Tests

    func testBasicInit() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem"
        )

        XCTAssertEqual(tag.namespace, .string("com.example.app"))
        XCTAssertEqual(tag.title, "TestItem")
        XCTAssertNil(tag.windowID)
        XCTAssertEqual(tag.instanceIndex, 0)
    }

    func testInitWithWindowID() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            windowID: 12345
        )

        XCTAssertEqual(tag.windowID, 12345)
    }

    func testInitWithInstanceIndex() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 3
        )

        XCTAssertEqual(tag.instanceIndex, 3)
    }

    // MARK: - Description Tests

    func testDescriptionBasic() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem"
        )

        XCTAssertEqual(tag.description, "com.example.app:TestItem")
    }

    func testDescriptionWithInstanceIndex() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 2
        )

        XCTAssertTrue(tag.description.contains(":2"))
    }

    func testDescriptionWithEmptyTitle() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: ""
        )

        XCTAssertEqual(tag.description, "com.example.app")
    }

    // MARK: - Tag Identifier Tests

    func testTagIdentifierBasic() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem"
        )

        XCTAssertEqual(tag.tagIdentifier, "com.example.app:TestItem")
    }

    func testTagIdentifierWithInstanceIndex() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 5
        )

        XCTAssertEqual(tag.tagIdentifier, "com.example.app:TestItem:5")
    }

    func testTagIdentifierZeroInstanceIndexOmitted() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 0
        )

        XCTAssertEqual(tag.tagIdentifier, "com.example.app:TestItem")
        XCTAssertFalse(tag.tagIdentifier.hasSuffix(":0"))
    }

    // MARK: - System Item Tests

    func testIsSystemItemForControlCenter() {
        let tag = MenuBarItemTag(
            namespace: .controlCenter,
            title: "SomeItem"
        )

        XCTAssertTrue(tag.isSystemItem)
    }

    func testIsSystemItemForSystemUIServer() {
        let tag = MenuBarItemTag(
            namespace: .systemUIServer,
            title: "SomeItem"
        )

        XCTAssertTrue(tag.isSystemItem)
    }

    func testIsSystemItemForThaw() {
        let tag = MenuBarItemTag(
            namespace: .thaw,
            title: "SomeItem"
        )

        XCTAssertTrue(tag.isSystemItem)
    }

    func testIsNotSystemItemForThirdPartyApp() {
        let tag = MenuBarItemTag(
            namespace: .string("com.thirdparty.app"),
            title: "SomeItem"
        )

        XCTAssertFalse(tag.isSystemItem)
    }

    func testIsNotSystemItemForUUID() {
        let tag = MenuBarItemTag(
            namespace: .uuid(UUID()),
            title: "SomeItem"
        )

        XCTAssertFalse(tag.isSystemItem)
    }

    // MARK: - Movable Tests

    func testClockIsNotMovable() {
        let clock = MenuBarItemTag.clock
        XCTAssertFalse(clock.isMovable)
    }

    func testControlCenterIsNotMovable() {
        let cc = MenuBarItemTag.controlCenter
        XCTAssertFalse(cc.isMovable)
    }

    func testRegularItemIsMovable() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "RegularItem"
        )

        XCTAssertTrue(tag.isMovable)
    }

    func testLegacyMovabilityIsIndependentFromMacOS27Anchoring() {
        let screenCapture = MenuBarItemTag.screenCaptureUI
        let legacyClock = MenuBarItemTag(namespace: .controlCenter, title: "Clock")

        XCTAssertTrue(screenCapture.isLayoutAnchoredSystemItem)
        XCTAssertFalse(screenCapture.isMovable)
        XCTAssertTrue(screenCapture.isMovableInLegacySectionLayout)
        XCTAssertFalse(legacyClock.isMovableInLegacySectionLayout)
    }

    func testMacOS27OnlyTrailingSystemItemsAreAnchored() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let anchoredTags = [
            MenuBarItemTag(namespace: .menuBarAgent, title: "Clock"),
            MenuBarItemTag(namespace: .menuBarAgent, title: "BentoBox-0"),
            MenuBarItemTag(namespace: .menuBarAgent, title: "com.apple.menuextra.clock"),
            MenuBarItemTag(namespace: .menuBarAgent, title: "com.apple.menuextra.controlcenter"),
            MenuBarItemTag(namespace: .systemUIServer, title: "Siri"),
        ]

        for tag in anchoredTags {
            XCTAssertTrue(tag.isLayoutAnchoredSystemItem, tag.description)
            XCTAssertFalse(tag.isMovable, tag.description)
            XCTAssertFalse(tag.canBeHidden, tag.description)
        }
    }

    func testMacOS27OtherMenuBarAgentModulesAreMovable() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let movableTitles = [
            "WiFi",
            "Sound",
            "Bluetooth",
            "NowPlaying",
            "FocusModes",
            "com.apple.menuextra.wifi",
            "com.apple.menuextra.sound",
            "com.apple.menuextra.bluetooth",
            "com.apple.menuextra.now-playing",
            "com.apple.menuextra.focusmode",
        ]

        for title in movableTitles {
            let tag = MenuBarItemTag(namespace: .menuBarAgent, title: title)

            XCTAssertFalse(tag.isLayoutAnchoredSystemItem, title)
            XCTAssertTrue(tag.isMovable, title)
        }
    }

    func testUnknownMenuBarAgentItemIsNotAnchored() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let tag = MenuBarItemTag(namespace: .menuBarAgent, title: "Item-0")

        XCTAssertFalse(tag.isLayoutAnchoredSystemItem)
        XCTAssertTrue(tag.isMovable)
    }

    // MARK: - Can Be Hidden Tests

    func testVisibleControlItemCannotBeHidden() {
        let visible = MenuBarItemTag.visibleControlItem
        XCTAssertFalse(visible.canBeHidden)
    }

    func testAudioVideoModuleCannotBeHidden() {
        let avm = MenuBarItemTag.audioVideoModule
        XCTAssertFalse(avm.canBeHidden)
    }

    func testRegularItemCanBeHidden() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "RegularItem"
        )

        XCTAssertTrue(tag.canBeHidden)
    }

    func testUUIDAudioVideoModuleCannotBeHidden() {
        let tag = MenuBarItemTag(
            namespace: .uuid(UUID()),
            title: "AudioVideoModule"
        )

        XCTAssertFalse(tag.canBeHidden)
    }

    // MARK: - Control Item Tests

    func testHiddenControlItemIsControlItem() {
        let hidden = MenuBarItemTag.hiddenControlItem
        XCTAssertTrue(hidden.isControlItem)
    }

    func testAlwaysHiddenControlItemIsControlItem() {
        let alwaysHidden = MenuBarItemTag.alwaysHiddenControlItem
        XCTAssertTrue(alwaysHidden.isControlItem)
    }

    func testVisibleControlItemIsControlItem() {
        let visible = MenuBarItemTag.visibleControlItem
        XCTAssertTrue(visible.isControlItem)
    }

    func testRegularItemIsNotControlItem() {
        let tag = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "RegularItem"
        )

        XCTAssertFalse(tag.isControlItem)
    }

    func testSpacerIsControlItem() {
        let tag = MenuBarItemTag(
            namespace: .thaw,
            title: "Something.Spacer.Item"
        )

        XCTAssertTrue(tag.isControlItem)
    }

    // MARK: - BentoBox Tests

    func testBentoBoxDetection() {
        // The BentoBox is owned by the menu bar hosting process: Control Center
        // on macOS 26, MenuBarAgent on macOS 27+.
        let hostingNamespace: MenuBarItemTag.Namespace
        if #available(macOS 27, *) {
            hostingNamespace = .menuBarAgent
        } else {
            hostingNamespace = .controlCenter
        }
        let tag = MenuBarItemTag(
            namespace: hostingNamespace,
            title: "BentoBox-0"
        )

        XCTAssertTrue(tag.isBentoBox)
    }

    func testBentoBoxWithoutPrefix() {
        let tag = MenuBarItemTag(
            namespace: .controlCenter,
            title: "NotBentoBox"
        )

        XCTAssertFalse(tag.isBentoBox)
    }

    func testBentoBoxWrongNamespace() {
        let tag = MenuBarItemTag(
            namespace: .string("com.other.app"),
            title: "BentoBox-0"
        )

        XCTAssertFalse(tag.isBentoBox)
    }

    // MARK: - System Clone Tests

    func testIsSystemClone() {
        let tag = MenuBarItemTag(
            namespace: .uuid(UUID()),
            title: "System Status Item Clone"
        )

        XCTAssertTrue(tag.isSystemClone)
    }

    func testIsSystemCloneWithStringNamespace() {
        // Field logs show clones carry a non-UUID namespace: the owning
        // process name (Window Server) when the source PID never resolves,
        // or a real bundle ID when the clone spatially mis-matches a nearby
        // app. The title is the reliable discriminator, so a string
        // namespace with the clone title must still count as a clone.
        let processNamespaceClone = MenuBarItemTag(
            namespace: .string("Window Server"),
            title: "System Status Item Clone"
        )
        let bundleNamespaceClone = MenuBarItemTag(
            namespace: .string("com.google.drivefs"),
            title: "System Status Item Clone"
        )

        XCTAssertTrue(processNamespaceClone.isSystemClone)
        XCTAssertTrue(bundleNamespaceClone.isSystemClone)
    }

    func testIsNotSystemCloneWithDifferentTitle() {
        let tag = MenuBarItemTag(
            namespace: .uuid(UUID()),
            title: "RegularItem"
        )

        XCTAssertFalse(tag.isSystemClone)
    }

    // MARK: - Equality Tests

    func testEqualityBasic() {
        let tag1 = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 0
        )
        let tag2 = MenuBarItemTag(
            namespace: .string("com.example.app"),
            title: "TestItem",
            instanceIndex: 0
        )

        XCTAssertEqual(tag1, tag2)
    }

    func testEqualityDifferentNamespace() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app1"), title: "Item")
        let tag2 = MenuBarItemTag(namespace: .string("com.app2"), title: "Item")

        XCTAssertNotEqual(tag1, tag2)
    }

    func testEqualityDifferentTitle() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item1")
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item2")

        XCTAssertNotEqual(tag1, tag2)
    }

    func testEqualityDifferentInstanceIndex() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", instanceIndex: 0)
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", instanceIndex: 1)

        XCTAssertNotEqual(tag1, tag2)
    }

    func testEqualitySystemItemIgnoresWindowID() {
        let tag1 = MenuBarItemTag(namespace: .controlCenter, title: "Item", windowID: 100)
        let tag2 = MenuBarItemTag(namespace: .controlCenter, title: "Item", windowID: 200)

        // System items ignore windowID in equality
        XCTAssertEqual(tag1, tag2)
    }

    func testEqualityNonSystemItemUsesWindowID() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", windowID: 100)
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", windowID: 200)

        // Non-system items consider windowID in equality
        XCTAssertNotEqual(tag1, tag2)
    }

    // MARK: - Matches Ignoring Window ID Tests

    func testMatchesIgnoringWindowID() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", windowID: 100)
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", windowID: 200)

        XCTAssertTrue(tag1.matchesIgnoringWindowID(tag2))
    }

    func testMatchesIgnoringWindowIDDifferentNamespace() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app1"), title: "Item", windowID: 100)
        let tag2 = MenuBarItemTag(namespace: .string("com.app2"), title: "Item", windowID: 100)

        XCTAssertFalse(tag1.matchesIgnoringWindowID(tag2))
    }

    func testMatchesIgnoringWindowIDDifferentInstanceIndex() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", instanceIndex: 0)
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item", instanceIndex: 1)

        XCTAssertFalse(tag1.matchesIgnoringWindowID(tag2))
    }

    // MARK: - Hashable Tests

    func testHashableConsistency() {
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item")
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item")

        XCTAssertEqual(tag1.hashValue, tag2.hashValue)
    }

    func testHashableInSet() {
        var set = Set<MenuBarItemTag>()
        let tag1 = MenuBarItemTag(namespace: .string("com.app"), title: "Item1")
        let tag2 = MenuBarItemTag(namespace: .string("com.app"), title: "Item2")
        let tag3 = MenuBarItemTag(namespace: .string("com.app"), title: "Item1") // duplicate

        set.insert(tag1)
        set.insert(tag2)
        set.insert(tag3)

        XCTAssertEqual(set.count, 2)
    }

    func testHashableAsDictionaryKey() {
        var dict = [MenuBarItemTag: String]()
        let tag = MenuBarItemTag(namespace: .string("com.app"), title: "Item")

        dict[tag] = "value"

        XCTAssertEqual(dict[tag], "value")
    }

    // MARK: - Static Constants Tests

    func testImmovableItemsContainsClock() {
        XCTAssertTrue(MenuBarItemTag.immovableItems.contains { $0.title == "Clock" })
    }

    func testNonHideableItemsContainsVisibleControlItem() {
        XCTAssertTrue(MenuBarItemTag.nonHideableItems.contains { $0 == .visibleControlItem })
    }

    func testControlItemsContainsHiddenControlItem() {
        XCTAssertTrue(MenuBarItemTag.controlItems.contains(.hiddenControlItem))
    }

    func testControlItemsContainsAlwaysHiddenControlItem() {
        XCTAssertTrue(MenuBarItemTag.controlItems.contains(.alwaysHiddenControlItem))
    }
}

// MARK: - macOS 27 Layout Anchor Tests

final class MacOS27LayoutAnchorOrderingTests: XCTestCase {
    @MainActor
    func testVisibleOrderingUsesLiveOrderForMenuBarAgentItems() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let alpha = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 0, windowID: 10)
        let wifi = systemItem(title: "WiFi", x: 24, windowID: 11)
        let beta = appItem(bundleID: "com.example.beta", title: "Beta", x: 48, windowID: 12)
        let gamma = appItem(bundleID: "com.example.gamma", title: "Gamma", x: 72, windowID: 13)

        let ordered = SimpleItemHider.orderedItems(
            [alpha, wifi, beta, gamma],
            in: .visible,
            using: [gamma.uniqueIdentifier, beta.uniqueIdentifier, alpha.uniqueIdentifier]
        )

        XCTAssertEqual(
            ordered.map(\.uniqueIdentifier),
            [alpha.uniqueIdentifier, wifi.uniqueIdentifier, beta.uniqueIdentifier, gamma.uniqueIdentifier]
        )
    }

    @MainActor
    func testVisibleOrderingKeepsMenuBarAgentItemsInLiveOrderWithoutSavedOrder() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let alpha = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 0, windowID: 110)
        let wifi = systemItem(title: "WiFi", x: 24, windowID: 111)
        let beta = appItem(bundleID: "com.example.beta", title: "Beta", x: 48, windowID: 112)

        let ordered = SimpleItemHider.orderedItems(
            [alpha, wifi, beta],
            in: .visible,
            using: []
        )

        XCTAssertEqual(
            ordered.map(\.uniqueIdentifier),
            [alpha.uniqueIdentifier, wifi.uniqueIdentifier, beta.uniqueIdentifier]
        )
    }

    @MainActor
    func testVisibleOrderingKeepsMixedAppleAndAppItemsInLiveOrder() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let alpha = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 0, windowID: 14)
        let beta = appItem(bundleID: "com.example.beta", title: "Beta", x: 24, windowID: 15)
        let wifi = systemItem(title: "WiFi", x: 48, windowID: 16)
        let gamma = appItem(bundleID: "com.example.gamma", title: "Gamma", x: 72, windowID: 17)
        let delta = appItem(bundleID: "com.example.delta", title: "Delta", x: 96, windowID: 18)
        let controlCenter = systemItem(title: "BentoBox-0", x: 120, windowID: 19)
        let unknownModule = systemItem(title: "Item-0", x: 144, windowID: 20)

        let ordered = SimpleItemHider.orderedItems(
            [alpha, beta, wifi, gamma, delta, controlCenter, unknownModule],
            in: .visible,
            using: [
                delta.uniqueIdentifier,
                gamma.uniqueIdentifier,
                unknownModule.uniqueIdentifier,
                controlCenter.uniqueIdentifier,
                wifi.uniqueIdentifier,
                beta.uniqueIdentifier,
                alpha.uniqueIdentifier,
            ]
        )

        XCTAssertEqual(
            ordered.map(\.uniqueIdentifier),
            [
                alpha.uniqueIdentifier,
                beta.uniqueIdentifier,
                wifi.uniqueIdentifier,
                gamma.uniqueIdentifier,
                delta.uniqueIdentifier,
                controlCenter.uniqueIdentifier,
                unknownModule.uniqueIdentifier,
            ]
        )
    }

    @MainActor
    func testVisibleOrderingIgnoresStaleSystemOrderEntries() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let alpha = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 0, windowID: 20)
        let clock = systemItem(title: "Clock", x: 24, windowID: 21)
        let beta = appItem(bundleID: "com.example.beta", title: "Beta", x: 48, windowID: 22)

        let ordered = SimpleItemHider.orderedItems(
            [alpha, clock, beta],
            in: .visible,
            using: [clock.uniqueIdentifier, beta.uniqueIdentifier, alpha.uniqueIdentifier]
        )

        XCTAssertEqual(
            ordered.map(\.uniqueIdentifier),
            [alpha.uniqueIdentifier, clock.uniqueIdentifier, beta.uniqueIdentifier]
        )
    }

    @MainActor
    func testPersistableVisibleOrderExcludesAnchoredSystemItems() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("MenuBarAgent anchoring is macOS 27-specific")
        }

        let alpha = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 0, windowID: 30)
        let clock = systemItem(title: "Clock", x: 24, windowID: 31)
        let unknownModule = systemItem(title: "Item-0", x: 36, windowID: 33)
        let beta = appItem(bundleID: "com.example.beta", title: "Beta", x: 48, windowID: 32)

        let identifiers = SimpleItemHider.persistableOrderIdentifiers(
            from: [alpha, clock, unknownModule, beta],
            in: .visible
        )

        XCTAssertEqual(identifiers, [alpha.uniqueIdentifier, unknownModule.uniqueIdentifier, beta.uniqueIdentifier])
    }

    @MainActor
    func testTemporaryHiddenRevealKeepsAlwaysHiddenConcealed() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider reveal is macOS 27-specific")
        }

        let assignment: [String: MenuBarSection.Name] = [
            "com.example.hidden:Hidden": .hidden,
            "com.example.always:Always": .alwaysHidden,
        ]

        let effective = SimpleItemHider.effectiveSectionAssignment(
            assignment,
            revealing: .hidden
        )

        XCTAssertEqual(effective, ["com.example.always:Always": .alwaysHidden])
    }

    @MainActor
    func testTemporaryAlwaysHiddenRevealAllowsAllAssignedItems() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider reveal is macOS 27-specific")
        }

        let assignment: [String: MenuBarSection.Name] = [
            "com.example.hidden:Hidden": .hidden,
            "com.example.always:Always": .alwaysHidden,
        ]

        let effective = SimpleItemHider.effectiveSectionAssignment(
            assignment,
            revealing: .alwaysHidden
        )

        XCTAssertTrue(effective.isEmpty)
    }

    @MainActor
    func testEffectiveAssignmentDropsThawOwnedEntries() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider reveal is macOS 27-specific")
        }

        let thawID = "\(Constants.bundleIdentifier):Thaw.ControlItem.Visible"
        let hostThawID = "\(Constants.bundleIdentifier).MenuBarHost:Thaw.ControlItem.Visible"
        let genericThawID = "\(Constants.bundleIdentifier):Item-0"
        let assignment: [String: MenuBarSection.Name] = [
            thawID: .alwaysHidden,
            hostThawID: .hidden,
            genericThawID: .hidden,
            "com.example.hidden:Hidden": .hidden,
        ]

        let effective = SimpleItemHider.effectiveSectionAssignment(
            assignment,
            revealing: nil
        )

        XCTAssertEqual(effective, ["com.example.hidden:Hidden": .hidden])
    }

    @MainActor
    func testPersistableVisibleOrderExcludesThawOwnedItems() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider reveal is macOS 27-specific")
        }

        let thaw = item(
            tag: MenuBarItemTag(namespace: .thaw, title: "Thaw.ControlItem.Visible", windowID: 90),
            x: 0,
            windowID: 90
        )
        let hostThaw = item(
            tag: MenuBarItemTag(namespace: .string("\(Constants.bundleIdentifier).MenuBarHost"), title: "Thaw.ControlItem.Visible", windowID: 91),
            x: 24,
            windowID: 91
        )
        let app = appItem(bundleID: "com.example.alpha", title: "Alpha", x: 48, windowID: 92)

        let identifiers = SimpleItemHider.persistableOrderIdentifiers(
            from: [thaw, hostThaw, app],
            in: .visible
        )

        XCTAssertEqual(identifiers, [app.uniqueIdentifier])
    }

    @MainActor
    func testGenericThawItemIsProtectedFromAssignmentHiding() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider protection is macOS 27-specific")
        }

        let genericThaw = item(
            tag: MenuBarItemTag(namespace: .thaw, title: "Item-0", windowID: 94),
            x: 0,
            windowID: 94
        )
        let hostThaw = item(
            tag: MenuBarItemTag(namespace: .string("\(Constants.bundleIdentifier).MenuBarHost"), title: "Thaw.ControlItem.Visible", windowID: 95),
            x: 24,
            windowID: 95
        )
        let app = appItem(bundleID: "com.example.alpha", title: "Item-0", x: 48, windowID: 96)

        XCTAssertTrue(SimpleItemHider.isProtectedAssignmentItem(genericThaw))
        XCTAssertTrue(SimpleItemHider.isProtectedAssignmentItem(hostThaw))
        XCTAssertFalse(SimpleItemHider.isProtectedAssignmentItem(app))
    }

    @MainActor
    func testAssessmentModeProtectedBundlesIncludeThawOwnedHosts() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("Assessment Mode hiding is macOS 27-specific")
        }

        XCTAssertTrue(AssessmentModeBackend.protectedBundleIDs.contains(Constants.bundleIdentifier))
        XCTAssertTrue(AssessmentModeBackend.protectedBundleIDs.contains("\(Constants.bundleIdentifier).MenuBarHost"))
    }

    @MainActor
    func testAssessmentModeAllowedSystemItemsAreCoreRange() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("Assessment Mode hiding is macOS 27-specific")
        }

        // MBSystemItemIdentifier has exactly 9 cases (raw values 0...8); the
        // restriction must allow exactly those to keep the core system controls.
        XCTAssertEqual(AssessmentModeBackend.allowedSystemItems.map(\.intValue), Array(0...8))
    }

    @MainActor
    func testAXProviderMapsThawOwnedHostsToThawNamespace() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("Menu bar AX provider is macOS 27-specific")
        }

        XCTAssertEqual(
            MenuBarItemAXProvider.namespace(forBundleIdentifier: Constants.bundleIdentifier),
            .thaw
        )
        XCTAssertEqual(
            MenuBarItemAXProvider.namespace(forBundleIdentifier: "\(Constants.bundleIdentifier).MenuBarHost"),
            .thaw
        )
    }

    @MainActor
    func testTemporaryRevealHiddenStateMatchesSectionControls() throws {
        guard #available(macOS 27, *) else {
            throw XCTSkip("SimpleItemHider reveal is macOS 27-specific")
        }

        XCTAssertTrue(SimpleItemHider.isSectionHidden(.visible, revealedSection: nil))
        XCTAssertTrue(SimpleItemHider.isSectionHidden(.hidden, revealedSection: nil))
        XCTAssertTrue(SimpleItemHider.isSectionHidden(.alwaysHidden, revealedSection: nil))

        XCTAssertFalse(SimpleItemHider.isSectionHidden(.visible, revealedSection: .hidden))
        XCTAssertFalse(SimpleItemHider.isSectionHidden(.hidden, revealedSection: .hidden))
        XCTAssertTrue(SimpleItemHider.isSectionHidden(.alwaysHidden, revealedSection: .hidden))

        XCTAssertFalse(SimpleItemHider.isSectionHidden(.visible, revealedSection: .alwaysHidden))
        XCTAssertFalse(SimpleItemHider.isSectionHidden(.hidden, revealedSection: .alwaysHidden))
        XCTAssertFalse(SimpleItemHider.isSectionHidden(.alwaysHidden, revealedSection: .alwaysHidden))
    }

    @MainActor
    func testSectionAssignmentSanitizerDropsThawControlItems() {
        let visibleControlID = "\(MenuBarItemTag.Namespace.thaw):\(ControlItem.Identifier.visible.rawValue)"
        let hiddenControlID = "\(MenuBarItemTag.Namespace.thaw):\(ControlItem.Identifier.hidden.rawValue)"
        let hostVisibleControlID = "\(Constants.bundleIdentifier).MenuBarHost:\(ControlItem.Identifier.visible.rawValue)"
        let genericThawID = "\(MenuBarItemTag.Namespace.thaw):Item-0"
        let hostGenericThawID = "\(Constants.bundleIdentifier).MenuBarHost:Item-0"
        let rawVisibleControlID = ControlItem.Identifier.visible.rawValue
        let appID = "com.example.alpha:Alpha"
        let visibleAppID = "com.example.beta:Beta"

        let sanitized = SimpleItemHider.sanitizedSectionAssignment([
            appID: .hidden,
            hiddenControlID: .alwaysHidden,
            genericThawID: .hidden,
            hostGenericThawID: .hidden,
            hostVisibleControlID: .hidden,
            rawVisibleControlID: .hidden,
            visibleAppID: .visible,
            visibleControlID: .hidden,
        ])

        XCTAssertEqual(sanitized, [appID: .hidden])
    }

    func testMacOS27LiveOrderRequiresFreshAXAdjacency() {
        let alphaTag = MenuBarItemTag.appItem(bundleID: "com.example.alpha", title: "Alpha", windowID: 40)
        let betaTag = MenuBarItemTag.appItem(bundleID: "com.example.beta", title: "Beta", windowID: 41)
        let gammaTag = MenuBarItemTag.appItem(bundleID: "com.example.gamma", title: "Gamma", windowID: 42)
        let alpha = item(tag: alphaTag, x: 0, windowID: 40)
        let beta = item(tag: betaTag, x: 24, windowID: 41)
        let gamma = item(tag: gammaTag, x: 48, windowID: 42)

        XCTAssertFalse(
            MenuBarItemManager.macOS27LiveOrderSatisfiesDestination(
                items: [alpha, beta, gamma],
                item: alpha,
                destination: .leftOfItem(gamma)
            )
        )

        let movedBeta = item(tag: betaTag, x: 0, windowID: 41)
        let movedAlpha = item(tag: alphaTag, x: 24, windowID: 40)
        let movedGamma = item(tag: gammaTag, x: 48, windowID: 42)
        XCTAssertTrue(
            MenuBarItemManager.macOS27LiveOrderSatisfiesDestination(
                items: [movedBeta, movedAlpha, movedGamma],
                item: alpha,
                destination: .leftOfItem(gamma)
            )
        )
    }

    func testMacOS27SectionBoundaryRequiresHiddenDividerBetweenSections() {
        let hidden = appItem(
            bundleID: "com.example.hidden",
            title: "Hidden",
            x: 0,
            windowID: 50
        )
        let divider = item(tag: .hiddenControlItem, x: 24, windowID: 51)
        let visible = appItem(
            bundleID: "com.example.visible",
            title: "Visible",
            x: 48,
            windowID: 52
        )
        let controls = MenuBarItemManager.ControlItemPair(
            hidden: divider,
            alwaysHidden: nil
        )
        let orderedItems = [hidden, divider, visible]

        XCTAssertEqual(
            MenuBarItemManager.macOS27SectionBoundaryDestination(
                for: .hidden,
                controlItems: controls
            ),
            .leftOfItem(divider)
        )
        XCTAssertEqual(
            MenuBarItemManager.macOS27SectionBoundaryDestination(
                for: .visible,
                controlItems: controls
            ),
            .rightOfItem(divider)
        )

        XCTAssertTrue(
            MenuBarItemManager.macOS27LiveOrderSatisfiesSectionBoundary(
                items: orderedItems,
                item: hidden,
                section: .hidden,
                controlItems: controls
            )
        )
        XCTAssertTrue(
            MenuBarItemManager.macOS27LiveOrderSatisfiesSectionBoundary(
                items: orderedItems,
                item: visible,
                section: .visible,
                controlItems: controls
            )
        )
        XCTAssertFalse(
            MenuBarItemManager.macOS27LiveOrderSatisfiesSectionBoundary(
                items: orderedItems,
                item: visible,
                section: .hidden,
                controlItems: controls
            )
        )
        XCTAssertFalse(
            MenuBarItemManager.macOS27LiveOrderSatisfiesSectionBoundary(
                items: orderedItems,
                item: hidden,
                section: .visible,
                controlItems: controls
            )
        )
    }

    func testMacOS27DividerMovesLeftOfLeftmostVisibleItem() {
        let thaw = item(tag: .visibleControlItem, x: 0, windowID: 60)
        let divider = item(tag: .hiddenControlItem, x: 24, windowID: 61)
        let hidden = appItem(
            bundleID: "com.example.hidden",
            title: "Hidden",
            x: 48,
            windowID: 62
        )
        let controls = MenuBarItemManager.ControlItemPair(
            hidden: divider,
            alwaysHidden: nil
        )

        XCTAssertEqual(
            MenuBarItemManager.macOS27DividerMoveDestination(
                items: [thaw, divider, hidden],
                sectionAssignment: [hidden.uniqueIdentifier: .hidden],
                controlItems: controls
            ),
            .leftOfItem(thaw)
        )

        let correctlyPlacedDivider = item(
            tag: .hiddenControlItem,
            x: -24,
            windowID: 63
        )
        XCTAssertNil(
            MenuBarItemManager.macOS27DividerMoveDestination(
                items: [correctlyPlacedDivider, thaw, hidden],
                sectionAssignment: [hidden.uniqueIdentifier: .hidden],
                controlItems: .init(
                    hidden: correctlyPlacedDivider,
                    alwaysHidden: nil
                )
            )
        )
    }

    private func appItem(
        bundleID: String,
        title: String,
        x: CGFloat,
        windowID: CGWindowID
    ) -> MenuBarItem {
        item(
            tag: .appItem(bundleID: bundleID, title: title, windowID: windowID),
            x: x,
            windowID: windowID
        )
    }

    private func systemItem(
        title: String,
        x: CGFloat,
        windowID: CGWindowID
    ) -> MenuBarItem {
        item(
            tag: MenuBarItemTag(namespace: .menuBarAgent, title: title, windowID: windowID),
            x: x,
            windowID: windowID
        )
    }

    private func item(
        tag: MenuBarItemTag,
        x: CGFloat,
        windowID: CGWindowID
    ) -> MenuBarItem {
        MenuBarItem.fixture(
            tag: tag,
            windowID: windowID,
            bounds: CGRect(x: x, y: 0, width: 20, height: 22)
        )
    }
}
