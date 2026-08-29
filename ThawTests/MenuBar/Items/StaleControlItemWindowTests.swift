//
//  StaleControlItemWindowTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import Testing
@testable import Thaw

/// Characterizes the newest-window rule for same-titled control item windows.
///
/// On macOS 26 an `NSStatusItem`'s `window.windowNumber` is a synthetic AppKit
/// number, not the Control Center window ID, so the authoritative ghost filter
/// never sees its own window. After a relaunch the previous instance's dividers
/// stay hosted for tens of seconds (field log 2026-08-29 13:44:20: windows
/// 5786/5787/5788 next to the new instance's 5839/5842/5843) and the tag lookup
/// adopted the old ones. Window IDs are handed out monotonically, so the newest
/// window per title is the current instance's.
@MainActor
@Suite("StaleControlItemWindow")
struct StaleControlItemWindowTests {
    private let hiddenTitle = "Thaw.ControlItem.Hidden"
    private let alwaysHiddenTitle = "Thaw.ControlItem.AlwaysHidden"
    private let visibleTitle = "Thaw.ControlItem.Visible"

    private func item(tag: MenuBarItemTag, windowID: CGWindowID, title: String) -> MenuBarItem {
        MenuBarItem.fixture(tag: tag, windowID: windowID, title: title)
    }

    @Test("Older same-titled control windows are stale")
    func olderDuplicatesAreStale() {
        let items = [
            item(tag: .hiddenControlItem, windowID: 5786, title: hiddenTitle),
            item(tag: .alwaysHiddenControlItem, windowID: 5787, title: alwaysHiddenTitle),
            item(tag: .visibleControlItem, windowID: 5788, title: visibleTitle),
            item(tag: .visibleControlItem, windowID: 5839, title: visibleTitle),
            item(tag: .hiddenControlItem, windowID: 5842, title: hiddenTitle),
            item(tag: .alwaysHiddenControlItem, windowID: 5843, title: alwaysHiddenTitle),
            item(tag: .appItem(bundleID: "sh.gyorgy.keepresso", title: "Item-0"), windowID: 5784, title: "Item-0"),
        ]

        let stale = MenuBarItemManager.staleDuplicateControlItemWindowIDs(in: items)

        #expect(stale == [5786, 5787, 5788])
    }

    @Test("A single window per title is never stale")
    func singleWindowsAreNotStale() {
        let items = [
            item(tag: .hiddenControlItem, windowID: 5842, title: hiddenTitle),
            item(tag: .alwaysHiddenControlItem, windowID: 5843, title: alwaysHiddenTitle),
            item(tag: .appItem(bundleID: "sh.gyorgy.keepresso", title: "Item-0"), windowID: 2556, title: "Item-0"),
            item(tag: .appItem(bundleID: "sh.gyorgy.keepresso", title: "Item-0", instanceIndex: 1), windowID: 2557, title: "Item-0"),
        ]

        #expect(MenuBarItemManager.staleDuplicateControlItemWindowIDs(in: items).isEmpty)
    }

    @Test("Only the newest of several generations survives")
    func onlyNewestGenerationSurvives() {
        let items = [
            item(tag: .hiddenControlItem, windowID: 4530, title: hiddenTitle),
            item(tag: .hiddenControlItem, windowID: 5134, title: hiddenTitle),
            item(tag: .hiddenControlItem, windowID: 5718, title: hiddenTitle),
        ]

        #expect(MenuBarItemManager.staleDuplicateControlItemWindowIDs(in: items) == [4530, 5134])
    }

    @Test("Degraded namespaces do not hide a duplicate")
    func degradedNamespacesStillMatchByTitle() {
        // A previous instance's divider can enumerate under a localized or
        // owner namespace when identity is degraded; the CG title still says
        // what it is.
        let items = [
            item(tag: .appItem(bundleID: "Control Center", title: hiddenTitle), windowID: 5786, title: hiddenTitle),
            item(tag: .hiddenControlItem, windowID: 5842, title: hiddenTitle),
        ]

        #expect(MenuBarItemManager.staleDuplicateControlItemWindowIDs(in: items) == [5786])
    }

    @Test("Spacers are judged per title")
    func spacersAreJudgedPerTitle() {
        let spacer0 = "Thaw.ControlItem.Hidden.Spacer.0"
        let spacer1 = "Thaw.ControlItem.Hidden.Spacer.1"
        let items = [
            item(tag: .appItem(bundleID: "com.stonerl.Thaw", title: spacer0), windowID: 100, title: spacer0),
            item(tag: .appItem(bundleID: "com.stonerl.Thaw", title: spacer1), windowID: 101, title: spacer1),
            item(tag: .appItem(bundleID: "com.stonerl.Thaw", title: spacer0), windowID: 200, title: spacer0),
        ]

        #expect(MenuBarItemManager.staleDuplicateControlItemWindowIDs(in: items) == [100])
    }
}
