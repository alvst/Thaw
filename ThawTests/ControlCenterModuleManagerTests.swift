//
//  ControlCenterModuleManagerTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

@testable import Thaw
import XCTest

// MARK: - ControlCenterModuleManager Tests

/// Covers the pure identifier/mapping logic only. ``ControlCenterModuleManager``
/// `apply(_:)` mutates the live `com.apple.controlcenter` per-host domain and
/// restarts Control Center, so it is intentionally not exercised here.
final class ControlCenterModuleManagerTests: XCTestCase {
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
}
