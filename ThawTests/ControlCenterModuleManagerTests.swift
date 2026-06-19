//
//  ControlCenterModuleManagerTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - ControlCenterModuleManager Tests

/// Covers identifier mapping and state transitions through an in-memory
/// environment. Tests never mutate live Control Center preferences or restart
/// the Control Center process.
@MainActor
final class ControlCenterModuleManagerTests: XCTestCase {
    private static let airDropTitle = "com.apple.menuextra.airdrop"
    private static let airDropKey = "AirDrop"
    private static let bluetoothTitle = "com.apple.menuextra.bluetooth"
    private static let bluetoothKey = "Bluetooth"

    // MARK: governableMenuExtraTitle(forItemIdentifier:)

    func testGovernableTitleFromMenuBarAgentIdentifier() {
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.airdrop"
            ),
            "com.apple.menuextra.airdrop"
        )
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.now-playing"
            ),
            "com.apple.menuextra.now-playing"
        )
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.user"
            ),
            "com.apple.menuextra.user"
        )
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.focusmode"
            ),
            "com.apple.menuextra.focusmode"
        )
    }

    func testGovernableTitleFromBareTitle() {
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.menuextra.airdrop"
            ),
            "com.apple.menuextra.airdrop"
        )
    }

    func testWiFiAndBluetoothAreGovernable() {
        // Core modules with confirmed per-host keys: hideable via CC pref even
        // though Assessment Mode keeps them in its 0...8 allowlist.
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.wifi"
            ),
            "com.apple.menuextra.wifi"
        )
        XCTAssertEqual(
            ControlCenterModuleManager.governableMenuExtraTitle(
                forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.bluetooth"
            ),
            "com.apple.menuextra.bluetooth"
        )
    }

    func testNonGovernableIdentifiersReturnNil() {
        // Clock has no per-host key and is layout-anchored — not governed here.
        XCTAssertNil(ControlCenterModuleManager.governableMenuExtraTitle(
            forItemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.clock"
        ))
        // Third-party items.
        XCTAssertNil(ControlCenterModuleManager.governableMenuExtraTitle(
            forItemIdentifier: "app.cotypist.Cotypist:Item-0"
        ))
        // A substring match must not be mistaken for a suffix match.
        XCTAssertNil(ControlCenterModuleManager.governableMenuExtraTitle(
            forItemIdentifier: "com.apple.menuextra.airdrop.extra"
        ))
    }

    // MARK: isGovernable(itemIdentifier:)

    func testIsGovernable() {
        XCTAssertTrue(ControlCenterModuleManager.isGovernable(
            itemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.focusmode"
        ))
        XCTAssertTrue(ControlCenterModuleManager.isGovernable(
            itemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.bluetooth"
        ))
        XCTAssertFalse(ControlCenterModuleManager.isGovernable(
            itemIdentifier: "com.apple.MenuBarAgent:com.apple.menuextra.clock"
        ))
    }

    // MARK: Mapping & value constants

    func testEveryGovernedTitleMapsToAModuleKey() {
        for (title, key) in ControlCenterModuleManager.moduleKeysByMenuExtraTitle {
            XCTAssertTrue(
                title.hasPrefix("com.apple.menuextra."),
                "governed title should be a menuextra ID: \(title)"
            )
            XCTAssertFalse(key.isEmpty, "module key for \(title) must be non-empty")
        }
    }

    func testShownAndHiddenValuesAreDistinct() {
        XCTAssertEqual(ControlCenterModuleManager.shownValue, 2)
        XCTAssertEqual(ControlCenterModuleManager.hiddenValue, 8)
        XCTAssertNotEqual(
            ControlCenterModuleManager.shownValue,
            ControlCenterModuleManager.hiddenValue
        )
    }

    // MARK: Preference state transitions

    func testApplyHidesShownModuleAndRepeatedApplyIsNoOp() {
        let harness = makeHarness(values: [Self.airDropKey: ControlCenterModuleManager.shownValue])

        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertEqual(harness.store.values[Self.airDropKey], ControlCenterModuleManager.hiddenValue)
        XCTAssertEqual(
            harness.store.writes,
            [.init(key: Self.airDropKey, value: ControlCenterModuleManager.hiddenValue)]
        )
        XCTAssertEqual(harness.store.synchronizeCount, 1)
        XCTAssertEqual(harness.store.restartCount, 1)

        XCTAssertFalse(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertEqual(harness.store.writes.count, 1)
        XCTAssertEqual(harness.store.synchronizeCount, 1)
        XCTAssertEqual(harness.store.restartCount, 1)
    }

    func testRestoreReinstatesOriginalNonDefaultPreference() {
        let harness = makeHarness(values: [Self.airDropKey: 5])

        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: []))

        XCTAssertEqual(harness.store.values[Self.airDropKey], 5)
        XCTAssertEqual(
            harness.store.writes,
            [
                .init(key: Self.airDropKey, value: ControlCenterModuleManager.hiddenValue),
                .init(key: Self.airDropKey, value: 5),
            ]
        )
        XCTAssertEqual(harness.store.synchronizeCount, 2)
        XCTAssertEqual(harness.store.restartCount, 2)
    }

    func testInitiallyHiddenModuleRemainsHiddenAfterRestore() {
        let harness = makeHarness(values: [Self.airDropKey: ControlCenterModuleManager.hiddenValue])

        XCTAssertFalse(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertFalse(harness.manager.apply(hiddenMenuExtraTitles: []))

        XCTAssertEqual(harness.store.values[Self.airDropKey], ControlCenterModuleManager.hiddenValue)
        XCTAssertTrue(harness.store.writes.isEmpty)
        XCTAssertEqual(harness.store.synchronizeCount, 0)
        XCTAssertEqual(harness.store.restartCount, 0)
    }

    func testMissingPreferenceIsRemovedOnRestore() {
        let harness = makeHarness()

        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: []))

        XCTAssertNil(harness.store.values[Self.airDropKey])
        XCTAssertEqual(
            harness.store.writes,
            [
                .init(key: Self.airDropKey, value: ControlCenterModuleManager.hiddenValue),
                .init(key: Self.airDropKey, value: nil),
            ]
        )
    }

    func testUnknownModulesHaveNoSideEffects() {
        let harness = makeHarness()

        XCTAssertFalse(harness.manager.apply(hiddenMenuExtraTitles: ["com.apple.menuextra.unknown"]))

        XCTAssertTrue(harness.store.values.isEmpty)
        XCTAssertTrue(harness.store.writes.isEmpty)
        XCTAssertEqual(harness.store.synchronizeCount, 0)
        XCTAssertEqual(harness.store.restartCount, 0)
    }

    func testTransitionBetweenModulesRestoresAndHidesWithOneRestart() {
        let harness = makeHarness(values: [
            Self.airDropKey: ControlCenterModuleManager.shownValue,
            Self.bluetoothKey: 3,
        ])

        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))
        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.bluetoothTitle]))

        XCTAssertEqual(harness.store.values[Self.airDropKey], ControlCenterModuleManager.shownValue)
        XCTAssertEqual(harness.store.values[Self.bluetoothKey], ControlCenterModuleManager.hiddenValue)
        XCTAssertEqual(harness.store.synchronizeCount, 2)
        XCTAssertEqual(harness.store.restartCount, 2)

        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: []))
        XCTAssertEqual(harness.store.values[Self.bluetoothKey], 3)
        XCTAssertEqual(harness.store.synchronizeCount, 3)
        XCTAssertEqual(harness.store.restartCount, 3)
    }

    func testTerminationNotificationRestoresManagedModules() {
        let notificationCenter = NotificationCenter()
        let harness = makeHarness(
            values: [Self.airDropKey: ControlCenterModuleManager.shownValue],
            notificationCenter: notificationCenter
        )
        XCTAssertTrue(harness.manager.apply(hiddenMenuExtraTitles: [Self.airDropTitle]))

        notificationCenter.post(name: NSApplication.willTerminateNotification, object: nil)

        XCTAssertEqual(harness.store.values[Self.airDropKey], ControlCenterModuleManager.shownValue)
        XCTAssertEqual(harness.store.synchronizeCount, 2)
        XCTAssertEqual(harness.store.restartCount, 2)
    }

    private func makeHarness(
        values: [String: Int] = [:],
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> Harness {
        let store = InMemoryEnvironment(values: values)
        let environment = ControlCenterModuleManager.Environment(
            readValue: { store.values[$0] },
            writeValue: { value, key in store.writeValue(value, forKey: key) },
            synchronize: { store.synchronizeCount += 1 },
            restartControlCenter: { store.restartCount += 1 }
        )
        return Harness(
            manager: ControlCenterModuleManager(
                environment: environment,
                notificationCenter: notificationCenter
            ),
            store: store
        )
    }

    private struct Harness {
        let manager: ControlCenterModuleManager
        let store: InMemoryEnvironment
    }

    private final class InMemoryEnvironment {
        struct Write: Equatable {
            let key: String
            let value: Int?
        }

        var values: [String: Int]
        var writes: [Write] = []
        var synchronizeCount = 0
        var restartCount = 0

        init(values: [String: Int]) {
            self.values = values
        }

        func writeValue(_ value: Int?, forKey key: String) -> Bool {
            guard values[key] != value else {
                return false
            }
            writes.append(Write(key: key, value: value))
            values[key] = value
            return true
        }
    }
}
