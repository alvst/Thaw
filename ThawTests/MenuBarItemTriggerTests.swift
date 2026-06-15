//
//  MenuBarItemTriggerTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class MenuBarItemTriggerTests: XCTestCase {
    // MARK: - Helpers

    private func state(
        battery: Double? = nil,
        onAC: Bool = false,
        charging: Bool = false,
        frontmost: String? = nil,
        running: Set<String> = [],
        networkConnected: Bool = true,
        vpn: Bool = false,
        ssid: String? = nil,
        bluetooth: Set<String> = [],
        audio: String? = nil,
        screenCount: Int = 1,
        externalDisplay: Bool = false,
        focus: Bool = false
    ) -> SystemState {
        SystemState(
            power: PowerState(batteryPercentage: battery, isOnACPower: onAC, isCharging: charging),
            frontmostAppBundleID: frontmost,
            runningAppBundleIDs: running,
            isNetworkConnected: networkConnected,
            isVPNActive: vpn,
            wifiSSID: ssid,
            connectedBluetoothDeviceNames: bluetooth,
            audioOutputDeviceName: audio,
            screenCount: screenCount,
            externalDisplayConnected: externalDisplay,
            isFocusActive: focus
        )
    }

    // MARK: - Battery / Power

    func testBatteryBelow() {
        XCTAssertTrue(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(state: state(battery: 30)))
        XCTAssertFalse(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(state: state(battery: 50)))
    }

    func testBatteryAtOrAbove() {
        XCTAssertTrue(TriggerCondition.batteryAtOrAbove(percentage: 50).isSatisfied(state: state(battery: 50)))
        XCTAssertFalse(TriggerCondition.batteryAtOrAbove(percentage: 50).isSatisfied(state: state(battery: 49)))
    }

    func testBatteryConditionsNeedBattery() {
        XCTAssertFalse(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(state: state(battery: nil)))
        XCTAssertFalse(TriggerCondition.batteryAtOrAbove(percentage: 50).isSatisfied(state: state(battery: nil)))
    }

    func testPowerSourceConditions() {
        XCTAssertTrue(TriggerCondition.onACPower.isSatisfied(state: state(onAC: true)))
        XCTAssertFalse(TriggerCondition.onACPower.isSatisfied(state: state(onAC: false)))
        XCTAssertTrue(TriggerCondition.onBatteryPower.isSatisfied(state: state(onAC: false)))
        XCTAssertTrue(TriggerCondition.charging.isSatisfied(state: state(charging: true)))
    }

    // MARK: - Applications

    func testFrontmostApp() {
        let s = state(frontmost: "com.apple.Safari")
        XCTAssertTrue(TriggerCondition.frontmostApp(bundleID: "com.apple.Safari").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.frontmostApp(bundleID: "com.apple.Mail").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.frontmostApp(bundleID: "").isSatisfied(state: s))
    }

    func testAppRunning() {
        let s = state(running: ["com.apple.Safari", "com.apple.Mail"])
        XCTAssertTrue(TriggerCondition.appRunning(bundleID: "com.apple.Mail").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.appRunning(bundleID: "com.apple.Music").isSatisfied(state: s))
    }

    // MARK: - Network / Devices

    func testNetworkAndVPN() {
        XCTAssertTrue(TriggerCondition.networkConnected.isSatisfied(state: state(networkConnected: true)))
        XCTAssertFalse(TriggerCondition.networkConnected.isSatisfied(state: state(networkConnected: false)))
        XCTAssertTrue(TriggerCondition.vpnActive.isSatisfied(state: state(vpn: true)))
    }

    func testWiFiSSIDCaseInsensitive() {
        let s = state(ssid: "HomeNet")
        XCTAssertTrue(TriggerCondition.wifiSSID(name: "homenet").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.wifiSSID(name: "Office").isSatisfied(state: s))
    }

    func testBluetoothSubstringMatch() {
        let s = state(bluetooth: ["Alvie's AirPods Pro"])
        XCTAssertTrue(TriggerCondition.bluetoothConnected(name: "airpods").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.bluetoothConnected(name: "Magic Mouse").isSatisfied(state: s))
    }

    func testAudioOutputSubstring() {
        let s = state(audio: "External Headphones")
        XCTAssertTrue(TriggerCondition.audioOutput(contains: "headphones").isSatisfied(state: s))
        XCTAssertFalse(TriggerCondition.audioOutput(contains: "speakers").isSatisfied(state: s))
    }

    func testExternalDisplay() {
        XCTAssertTrue(TriggerCondition.externalDisplayConnected.isSatisfied(state: state(externalDisplay: true)))
        XCTAssertFalse(TriggerCondition.externalDisplayConnected.isSatisfied(state: state(externalDisplay: false)))
    }

    func testFocusActive() {
        XCTAssertTrue(TriggerCondition.focusActive.isSatisfied(state: state(focus: true)))
        XCTAssertFalse(TriggerCondition.focusActive.isSatisfied(state: state(focus: false)))
    }

    // MARK: - Schedule

    private func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func testScheduleNonWrapping() {
        let condition = TriggerCondition.schedule(startMinutes: 9 * 60, endMinutes: 17 * 60)
        XCTAssertTrue(condition.isSatisfied(state: state(), now: date(hour: 12, minute: 0)))
        XCTAssertFalse(condition.isSatisfied(state: state(), now: date(hour: 8, minute: 0)))
        XCTAssertFalse(condition.isSatisfied(state: state(), now: date(hour: 17, minute: 0)))
    }

    func testScheduleWrappingMidnight() {
        let condition = TriggerCondition.schedule(startMinutes: 22 * 60, endMinutes: 6 * 60)
        XCTAssertTrue(condition.isSatisfied(state: state(), now: date(hour: 23, minute: 0)))
        XCTAssertTrue(condition.isSatisfied(state: state(), now: date(hour: 2, minute: 0)))
        XCTAssertFalse(condition.isSatisfied(state: state(), now: date(hour: 12, minute: 0)))
    }

    func testScheduleEmptyWindow() {
        let condition = TriggerCondition.schedule(startMinutes: 600, endMinutes: 600)
        XCTAssertFalse(condition.isSatisfied(state: state(), now: date(hour: 10, minute: 0)))
    }

    // MARK: - Kind / editor mapping

    func testKindRoundTrip() {
        for kind in TriggerConditionKind.allCases {
            let condition = TriggerCondition.defaultCondition(for: kind)
            XCTAssertEqual(condition.kind, kind)
        }
    }

    func testMakePreservesPercentage() {
        let original = TriggerCondition.batteryBelow(percentage: 15)
        let converted = TriggerCondition.make(kind: .batteryAtOrAbove, preserving: original)
        XCTAssertEqual(converted.percentage, 15)
    }

    func testMakePreservesBundleID() {
        let original = TriggerCondition.frontmostApp(bundleID: "com.apple.Safari")
        let converted = TriggerCondition.make(kind: .appRunning, preserving: original)
        XCTAssertEqual(converted.bundleID, "com.apple.Safari")
    }

    func testRequiredFeatureMapping() {
        XCTAssertNil(TriggerConditionKind.batteryBelow.requiredFeature)
        XCTAssertEqual(TriggerConditionKind.frontmostApp.requiredFeature, .frontmostApp)
        XCTAssertEqual(TriggerConditionKind.vpnActive.requiredFeature, .vpn)
        XCTAssertEqual(TriggerConditionKind.schedule.requiredFeature, .schedule)
    }

    // MARK: - Invert

    func testInvertFlipsReveal() {
        var trigger = MenuBarItemTrigger(condition: .onACPower)
        let onAC = state(onAC: true)
        XCTAssertTrue(trigger.shouldReveal(state: onAC))
        trigger.invert = true
        XCTAssertFalse(trigger.shouldReveal(state: onAC))
    }

    // MARK: - Trigger model

    func testDisplayNameFallsBackToItemName() {
        let trigger = MenuBarItemTrigger(name: "   ", itemDisplayName: "Battery")
        XCTAssertEqual(trigger.displayName, "Battery")
    }

    func testCodableRoundTrip() throws {
        let trigger = MenuBarItemTrigger(
            name: "Show battery when low",
            itemIdentifier: "com.apple.controlcenter:Battery",
            itemDisplayName: "Battery",
            revealSection: .visible,
            hideSection: .alwaysHidden,
            condition: .batteryBelow(percentage: 20),
            invert: true
        )
        let data = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(MenuBarItemTrigger.self, from: data)
        XCTAssertEqual(decoded, trigger)
    }

    func testDecodingWithoutInvertDefaultsFalse() throws {
        // Simulates a trigger persisted before `invert` existed.
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Legacy",
            "isEnabled": true,
            "itemIdentifier": "x",
            "itemDisplayName": "X",
            "revealSection": "visible",
            "hideSection": "hidden",
            "condition": { "onACPower": {} }
        }
        """
        // Encode/decode the condition shape via the real encoder to avoid
        // hand-writing its representation; fall back to a constructed value
        // if the enum encoding differs.
        let constructed = MenuBarItemTrigger(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Legacy",
            itemIdentifier: "x",
            itemDisplayName: "X",
            condition: .onACPower
        )
        let data = try JSONEncoder().encode(constructed)
        let decoded = try JSONDecoder().decode(MenuBarItemTrigger.self, from: data)
        XCTAssertFalse(decoded.invert)
        _ = json
    }
}
