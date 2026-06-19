//
//  MenuBarTestFixturesTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

/// Sanity tests for the synthetic fixture builders in
/// MenuBarTestFixtures.swift. These pin down that the fixtures produce values
/// with the documented defaults so the planner tests built on top of them stay
/// stable.
final class MenuBarTestFixturesTests: XCTestCase {
    func testAppItemTagBuildsExpectedNamespaceAndTitle() {
        let tag = MenuBarItemTag.appItem(bundleID: "com.example.app", title: "Status")
        XCTAssertEqual(String(describing: tag.namespace), "com.example.app")
        XCTAssertEqual(tag.title, "Status")
        XCTAssertEqual(tag.instanceIndex, 0)
        XCTAssertNil(tag.windowID)
    }

    func testAppItemTagSupportsInstanceIndex() {
        let tag = MenuBarItemTag.appItem(bundleID: "com.example.app", title: "Status", instanceIndex: 2)
        XCTAssertEqual(tag.instanceIndex, 2)
    }

    func testMenuBarItemFixtureDefaultsToMovableHideableItem() {
        let tag = MenuBarItemTag.appItem(bundleID: "com.example.app", title: "Status")
        let item = MenuBarItem.fixture(tag: tag, windowID: 42)

        XCTAssertEqual(item.windowID, 42)
        XCTAssertEqual(item.tag, tag)
        XCTAssertEqual(item.sourcePID, 1234)
        XCTAssertEqual(item.ownerPID, 1234)
        XCTAssertEqual(item.bounds, CGRect(x: 0, y: 0, width: 24, height: 22))
        XCTAssertTrue(item.isMovable)
        XCTAssertTrue(item.canBeHidden)
        XCTAssertFalse(item.isControlItem)
        XCTAssertTrue(item.isOnScreen)
    }

    func testMenuBarItemFixtureRespectsExplicitBounds() {
        let bounds = CGRect(x: 100, y: 0, width: 30, height: 22)
        let item = MenuBarItem.fixture(
            tag: .appItem(bundleID: "com.example.app", title: "Status"),
            windowID: 1,
            bounds: bounds
        )
        XCTAssertEqual(item.bounds, bounds)
    }

    func testControlItemPairFixtureWithoutAlwaysHidden() {
        let pair = MenuBarItemManager.ControlItemPair.fixture(
            hiddenAt: CGRect(x: 500, y: 0, width: 24, height: 22)
        )

        XCTAssertEqual(pair.hidden.tag, .hiddenControlItem)
        XCTAssertEqual(pair.hidden.bounds.minX, 500)
        XCTAssertNil(pair.alwaysHidden)
    }

    func testControlItemPairFixtureWithAlwaysHidden() {
        let pair = MenuBarItemManager.ControlItemPair.fixture(
            hiddenAt: CGRect(x: 500, y: 0, width: 24, height: 22),
            alwaysHiddenAt: CGRect(x: 200, y: 0, width: 24, height: 22)
        )

        XCTAssertEqual(pair.hidden.tag, .hiddenControlItem)
        XCTAssertEqual(pair.alwaysHidden?.tag, .alwaysHiddenControlItem)
        XCTAssertEqual(pair.alwaysHidden?.bounds.minX, 200)
    }

    func testControlItemPairFixtureWindowIDsAreDistinct() {
        let pair = MenuBarItemManager.ControlItemPair.fixture(
            hiddenAt: CGRect(x: 500, y: 0, width: 24, height: 22),
            alwaysHiddenAt: CGRect(x: 200, y: 0, width: 24, height: 22)
        )
        XCTAssertNotEqual(pair.hidden.windowID, pair.alwaysHidden?.windowID)
    }
}

// MARK: - ControlItemDefaults Tests

final class ControlItemDefaultsTests: XCTestCase {
    private let visibleAutosaveName = ControlItem.Identifier.visible.rawValue

    override func tearDown() {
        ControlItemDefaults[.visible, visibleAutosaveName] = nil
        ControlItemDefaults[.visibleCC, visibleAutosaveName] = nil
        ControlItemDefaults[.preferredPosition, visibleAutosaveName] = nil
        super.tearDown()
    }

    func testRestoreVisibilityForVisibleControlItemRepairsPersistedHiddenStateOnMacOS27() {
        ControlItemDefaults[.visible, visibleAutosaveName] = false
        ControlItemDefaults[.visibleCC, visibleAutosaveName] = false

        ControlItemDefaults.restoreVisibilityIfNeeded(autosaveName: visibleAutosaveName)

        if #available(macOS 27, *) {
            XCTAssertEqual(ControlItemDefaults[.visible, visibleAutosaveName], true)
            XCTAssertEqual(ControlItemDefaults[.visibleCC, visibleAutosaveName], true)
        } else {
            XCTAssertEqual(ControlItemDefaults[.visible, visibleAutosaveName], false)
            XCTAssertEqual(ControlItemDefaults[.visibleCC, visibleAutosaveName], false)
        }
    }

    func testRestoreVisibilityRepairsHiddenSectionDividerOnMacOS27() {
        let hiddenAutosaveName = ControlItem.Identifier.hidden.rawValue
        ControlItemDefaults[.visible, hiddenAutosaveName] = false
        ControlItemDefaults[.visibleCC, hiddenAutosaveName] = false
        defer {
            ControlItemDefaults[.visible, hiddenAutosaveName] = nil
            ControlItemDefaults[.visibleCC, hiddenAutosaveName] = nil
        }

        ControlItemDefaults.restoreVisibilityIfNeeded(autosaveName: hiddenAutosaveName)

        if #available(macOS 27, *) {
            XCTAssertEqual(ControlItemDefaults[.visible, hiddenAutosaveName], true)
            XCTAssertEqual(ControlItemDefaults[.visibleCC, hiddenAutosaveName], true)
        } else {
            XCTAssertEqual(ControlItemDefaults[.visible, hiddenAutosaveName], false)
            XCTAssertEqual(ControlItemDefaults[.visibleCC, hiddenAutosaveName], false)
        }
    }

    func testMacOS27VisibleControlItemDoesNotRestoreCachedPreferredPositionAfterRemoval() {
        let shouldRestore = ControlItemDefaults.shouldRestorePreferredPositionAfterRemoval(
            autosaveName: visibleAutosaveName,
            isSectionDivider: false
        )

        if #available(macOS 27, *) {
            XCTAssertFalse(shouldRestore)
        } else {
            XCTAssertTrue(shouldRestore)
        }
    }

    func testSectionDividerDoesNotRestoreCachedPreferredPositionAfterRemoval() {
        let shouldRestore = ControlItemDefaults.shouldRestorePreferredPositionAfterRemoval(
            autosaveName: ControlItem.Identifier.hidden.rawValue,
            isSectionDivider: true
        )

        XCTAssertFalse(shouldRestore)
    }
}

// MARK: - ControlItem Section Divider Tests

final class ControlItemSectionDividerTests: XCTestCase {
    func testMacOS27ConcealedSectionCollapsesDividerUntilReveal() {
        let presentation = ControlItem.sectionDividerPresentation(
            state: .hideSection,
            style: .chevron,
            supportsSectionHiding: false
        )

        XCTAssertEqual(presentation, .hidden)
    }

    func testMacOS27NoDividerCollapsesConcealedSectionDivider() {
        let presentation = ControlItem.sectionDividerPresentation(
            state: .hideSection,
            style: .noDivider,
            supportsSectionHiding: false
        )

        XCTAssertEqual(presentation, .hidden)
    }

    func testLegacyConcealedSectionRetainsExpandedInvisibleDivider() {
        let presentation = ControlItem.sectionDividerPresentation(
            state: .hideSection,
            style: .chevron,
            supportsSectionHiding: true
        )

        XCTAssertEqual(presentation, .legacyConcealedSection)
    }

    func testRevealedSectionUsesConfiguredDividerStyle() {
        XCTAssertEqual(
            ControlItem.sectionDividerPresentation(
                state: .showSection,
                style: .chevron,
                supportsSectionHiding: true
            ),
            .chevron
        )
        XCTAssertEqual(
            ControlItem.sectionDividerPresentation(
                state: .showSection,
                style: .noDivider,
                supportsSectionHiding: false
            ),
            .hidden
        )
    }
}

// MARK: - ControlItem Primary Action Tests

final class ControlItemPrimaryActionTests: XCTestCase {
    func testPlainPrimaryActionTogglesSection() {
        XCTAssertEqual(primaryAction(), .toggleSection)
    }

    func testKeyboardPrimaryActionTogglesSection() {
        XCTAssertEqual(primaryAction(clickCount: 0), .toggleSection)
    }

    func testControlPrimaryActionDefersToContextMenu() {
        XCTAssertEqual(primaryAction(modifierFlags: .control), .contextMenu)
    }

    func testOptionPrimaryActionTogglesAlwaysHiddenSectionWhenEnabled() {
        XCTAssertEqual(
            primaryAction(modifierFlags: .option, usesOptionClick: true),
            .toggleAlwaysHidden
        )
    }

    func testOptionPrimaryActionDoesNothingWhenDisabled() {
        XCTAssertEqual(primaryAction(modifierFlags: .option), .none)
    }

    func testDoublePrimaryActionShowsAlwaysHiddenSectionWhenEnabled() {
        XCTAssertEqual(
            primaryAction(clickCount: 2, usesDoubleClick: true),
            .showAlwaysHidden
        )
    }

    func testDoublePrimaryActionUsesNormalBehaviorWhenDisabled() {
        XCTAssertEqual(primaryAction(clickCount: 2), .toggleSection)
    }

    private func primaryAction(
        modifierFlags: NSEvent.ModifierFlags = [],
        clickCount: Int = 1,
        usesDoubleClick: Bool = false,
        usesOptionClick: Bool = false
    ) -> ControlItem.PrimaryActionIntent {
        ControlItem.primaryActionIntent(
            identifier: .visible,
            modifierFlags: modifierFlags,
            clickCount: clickCount,
            usesDoubleClick: usesDoubleClick,
            usesOptionClick: usesOptionClick
        )
    }
}

// MARK: - Control Item Context Menu Routing Tests

final class ControlItemContextMenuRoutingTests: XCTestCase {
    private let iconFrame = CGRect(x: 100, y: 900, width: 24, height: 24)

    func testMacOS27RoutesClickInsideIconToControlItemMenu() {
        XCTAssertTrue(
            HIDEventManager.shouldShowControlItemContextMenu(
                usesMenuBarAgent: true,
                controlItemFrame: iconFrame,
                clickLocation: CGPoint(x: 112, y: 912)
            )
        )
    }

    func testMacOS27LeavesClickOutsideIconForMenuBarContextMenu() {
        XCTAssertFalse(
            HIDEventManager.shouldShowControlItemContextMenu(
                usesMenuBarAgent: true,
                controlItemFrame: iconFrame,
                clickLocation: CGPoint(x: 80, y: 912)
            )
        )
    }

    func testLegacySystemDoesNotUseGlobalControlItemMenuRoute() {
        XCTAssertFalse(
            HIDEventManager.shouldShowControlItemContextMenu(
                usesMenuBarAgent: false,
                controlItemFrame: iconFrame,
                clickLocation: CGPoint(x: 112, y: 912)
            )
        )
    }

    func testMissingControlItemFrameDoesNotConsumeClick() {
        XCTAssertFalse(
            HIDEventManager.shouldShowControlItemContextMenu(
                usesMenuBarAgent: true,
                controlItemFrame: nil,
                clickLocation: CGPoint(x: 112, y: 912)
            )
        )
    }
}

// MARK: - Menu Bar Item Capture Section Tests

final class MenuBarItemCaptureSectionTests: XCTestCase {
    private let allSections = MenuBarSection.Name.allCases

    func testLegacyCaptureKeepsEveryRequestedSection() {
        XCTAssertEqual(
            capturableSections(usesVisibilityRestrictions: false, revealedSection: nil),
            allSections
        )
    }

    func testMacOS27ConcealedCaptureUsesOnlyVisibleSection() {
        XCTAssertEqual(
            capturableSections(usesVisibilityRestrictions: true, revealedSection: nil),
            [.visible]
        )
    }

    func testMacOS27HiddenRevealCapturesVisibleAndHiddenSections() {
        XCTAssertEqual(
            capturableSections(usesVisibilityRestrictions: true, revealedSection: .hidden),
            [.visible, .hidden]
        )
    }

    func testMacOS27AlwaysHiddenRevealCapturesEverySection() {
        XCTAssertEqual(
            capturableSections(usesVisibilityRestrictions: true, revealedSection: .alwaysHidden),
            allSections
        )
    }

    private func capturableSections(
        usesVisibilityRestrictions: Bool,
        revealedSection: MenuBarSection.Name?
    ) -> [MenuBarSection.Name] {
        MenuBarItemImageCache.capturableSections(
            from: allSections,
            usesVisibilityRestrictions: usesVisibilityRestrictions,
            revealedSection: revealedSection
        )
    }
}
