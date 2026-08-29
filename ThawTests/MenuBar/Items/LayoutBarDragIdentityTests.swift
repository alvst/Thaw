//
//  LayoutBarDragIdentityTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Testing
@testable import Thaw

/// How the layout editor recognizes the item it dragged in the cache that
/// is refreshed after the move.
///
/// The dragged item's tag is a snapshot; the refreshed cache can name the
/// same window differently once its source process resolves. In the 13:28
/// field log the dragged `com.apple.controlcenter:Item-0` came back as
/// `IconSwitcher:Item-0`, the tag comparison missed it, and the editor
/// re-dragged an item that had already landed.
@Suite("Layout bar drag identity")
struct LayoutBarDragIdentityTests {
    private let provisional = MenuBarItem.fixture(
        tag: MenuBarItemTag(namespace: .controlCenter, title: "Item-0", windowID: 5467, instanceIndex: 0),
        windowID: 5467,
        sourcePID: nil,
        ownerPID: 645
    )

    private let resolved = MenuBarItem.fixture(
        tag: .appItem(bundleID: "IconSwitcher", title: "Item-0", windowID: 5467),
        windowID: 5467,
        sourcePID: 12460,
        ownerPID: 645
    )

    private let keepresso = MenuBarItem.fixture(
        tag: .appItem(bundleID: "sh.gyorgy.keepresso", title: "Item-0", windowID: 2556),
        windowID: 2556
    )

    @Test("The same window is the same item whatever the cache calls it")
    func sameWindowIsSameItem() {
        #expect(LayoutBarPaddingView.isSameItem(resolved, provisional))
        #expect(!LayoutBarPaddingView.isSameItem(keepresso, provisional))
    }

    @Test("A recreated window still matches by tag")
    func recreatedWindowMatchesByTag() {
        let recreated = MenuBarItem.fixture(
            tag: .appItem(bundleID: "IconSwitcher", title: "Item-0", windowID: 5744),
            windowID: 5744,
            sourcePID: 12460,
            ownerPID: 645
        )
        #expect(LayoutBarPaddingView.isSameItem(recreated, resolved))
    }

    @Test("The dragged item is found beside its target under its resolved name")
    func reachedPositionUnderResolvedName() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(keepresso),
            sectionItems: [resolved, keepresso]
        )
        #expect(reached)
    }

    @Test("The wrong side of the target is not the intended position")
    func wrongSideIsNotReached() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .rightOfItem(keepresso),
            sectionItems: [resolved, keepresso]
        )
        #expect(!reached)
    }

    @Test("Containment is enough when the target is a section divider")
    func dividerTargetNeedsOnlyContainment() {
        let divider = MenuBarItem.fixture(tag: .hiddenControlItem, windowID: 5134, sourcePID: nil)
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(divider),
            sectionItems: [keepresso, resolved]
        )
        #expect(reached)
    }

    @Test("An item missing from the section has not reached its position")
    func missingItemIsNotReached() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(keepresso),
            sectionItems: [keepresso]
        )
        #expect(!reached)
    }
}
