//
//  ControlCenterRelaunchGraceTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Testing
@testable import Thaw

/// Characterizes the grace period that keeps a control item lookup failure
/// during a Control Center restart from counting toward a status item
/// rebuild. Control Center re-hosts every status item after it restarts; one
/// second after the 2026-08-29 13:40:54 restart the enumeration held three
/// windows and no divider, and the next cycle resolved normally.
@Suite("Control Center relaunch grace")
struct ControlCenterRelaunchGraceTests {
    @Test("A failure right after Control Center launched is not counted")
    func failureInsideGraceIsNotCounted() {
        #expect(!MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: .seconds(1)))
        #expect(!MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: .zero))
        #expect(!MenuBarItemManager.shouldCountControlItemLookupFailure(
            hostUptime: MenuBarItemManager.controlCenterRelaunchGrace - .milliseconds(1)
        ))
    }

    @Test("A failure after the grace period is counted")
    func failureAfterGraceIsCounted() {
        #expect(MenuBarItemManager.shouldCountControlItemLookupFailure(
            hostUptime: MenuBarItemManager.controlCenterRelaunchGrace
        ))
        #expect(MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: .seconds(3600)))
    }

    @Test("An unknown host uptime does not suppress counting")
    func unknownUptimeIsCounted() {
        #expect(MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: nil))
    }

    @Test("A custom grace period is respected")
    func customGraceIsRespected() {
        #expect(!MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: .seconds(4), grace: .seconds(5)))
        #expect(MenuBarItemManager.shouldCountControlItemLookupFailure(hostUptime: .seconds(5), grace: .seconds(5)))
    }
}
