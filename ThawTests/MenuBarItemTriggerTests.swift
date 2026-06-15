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
    // MARK: - Battery Level Conditions

    func testBatteryBelowSatisfiedWhenUnderThreshold() {
        let state = PowerState(batteryPercentage: 30, isOnACPower: false, isCharging: false)
        XCTAssertTrue(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(by: state))
    }

    func testBatteryBelowNotSatisfiedAtThreshold() {
        let state = PowerState(batteryPercentage: 50, isOnACPower: false, isCharging: false)
        XCTAssertFalse(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(by: state))
    }

    func testBatteryAtOrAboveSatisfiedAtThreshold() {
        let state = PowerState(batteryPercentage: 50, isOnACPower: false, isCharging: false)
        XCTAssertTrue(TriggerCondition.batteryAtOrAbove(percentage: 50).isSatisfied(by: state))
    }

    func testBatteryConditionsNeverSatisfiedWithoutBattery() {
        let state = PowerState(batteryPercentage: nil, isOnACPower: true, isCharging: false)
        XCTAssertFalse(TriggerCondition.batteryBelow(percentage: 50).isSatisfied(by: state))
        XCTAssertFalse(TriggerCondition.batteryAtOrAbove(percentage: 50).isSatisfied(by: state))
    }

    // MARK: - Power Source Conditions

    func testOnACPower() {
        let onAC = PowerState(batteryPercentage: 80, isOnACPower: true, isCharging: true)
        let onBattery = PowerState(batteryPercentage: 80, isOnACPower: false, isCharging: false)
        XCTAssertTrue(TriggerCondition.onACPower.isSatisfied(by: onAC))
        XCTAssertFalse(TriggerCondition.onACPower.isSatisfied(by: onBattery))
    }

    func testOnBatteryPower() {
        let onAC = PowerState(batteryPercentage: 80, isOnACPower: true, isCharging: true)
        let onBattery = PowerState(batteryPercentage: 80, isOnACPower: false, isCharging: false)
        XCTAssertFalse(TriggerCondition.onBatteryPower.isSatisfied(by: onAC))
        XCTAssertTrue(TriggerCondition.onBatteryPower.isSatisfied(by: onBattery))
    }

    func testCharging() {
        let charging = PowerState(batteryPercentage: 80, isOnACPower: true, isCharging: true)
        let notCharging = PowerState(batteryPercentage: 80, isOnACPower: true, isCharging: false)
        XCTAssertTrue(TriggerCondition.charging.isSatisfied(by: charging))
        XCTAssertFalse(TriggerCondition.charging.isSatisfied(by: notCharging))
    }

    // MARK: - Condition Kind Round-Trip

    func testMakePreservesPercentage() {
        let condition = TriggerCondition.make(kind: .batteryBelow, percentage: 15)
        XCTAssertEqual(condition.kind, .batteryBelow)
        XCTAssertEqual(condition.percentage, 15)
    }

    func testMakeSuppliesDefaultPercentage() {
        let condition = TriggerCondition.make(kind: .batteryAtOrAbove, percentage: nil)
        XCTAssertEqual(condition.percentage, 50)
    }

    func testMakeNonPercentageKindHasNoPercentage() {
        let condition = TriggerCondition.make(kind: .charging, percentage: 30)
        XCTAssertEqual(condition.kind, .charging)
        XCTAssertNil(condition.percentage)
    }

    func testUsesPercentageFlag() {
        XCTAssertTrue(TriggerConditionKind.batteryBelow.usesPercentage)
        XCTAssertTrue(TriggerConditionKind.batteryAtOrAbove.usesPercentage)
        XCTAssertFalse(TriggerConditionKind.onACPower.usesPercentage)
        XCTAssertFalse(TriggerConditionKind.onBatteryPower.usesPercentage)
        XCTAssertFalse(TriggerConditionKind.charging.usesPercentage)
    }

    // MARK: - Trigger Model

    func testDisplayNameFallsBackToItemName() {
        let trigger = MenuBarItemTrigger(
            name: "   ",
            itemIdentifier: "com.apple.controlcenter:Battery",
            itemDisplayName: "Battery"
        )
        XCTAssertEqual(trigger.displayName, "Battery")
    }

    func testDisplayNamePrefersCustomName() {
        let trigger = MenuBarItemTrigger(
            name: "Low Battery Alert",
            itemIdentifier: "com.apple.controlcenter:Battery",
            itemDisplayName: "Battery"
        )
        XCTAssertEqual(trigger.displayName, "Low Battery Alert")
    }

    func testTriggerCodableRoundTrip() throws {
        let trigger = MenuBarItemTrigger(
            name: "Show battery when low",
            isEnabled: true,
            itemIdentifier: "com.apple.controlcenter:Battery",
            itemDisplayName: "Battery",
            revealSection: .visible,
            hideSection: .alwaysHidden,
            condition: .batteryBelow(percentage: 20)
        )

        let data = try JSONEncoder().encode(trigger)
        let decoded = try JSONDecoder().decode(MenuBarItemTrigger.self, from: data)

        XCTAssertEqual(decoded, trigger)
    }

    func testTriggerArrayCodableRoundTrip() throws {
        let triggers = [
            MenuBarItemTrigger(name: "A", condition: .onBatteryPower),
            MenuBarItemTrigger(name: "B", condition: .charging),
        ]
        let data = try JSONEncoder().encode(triggers)
        let decoded = try JSONDecoder().decode([MenuBarItemTrigger].self, from: data)
        XCTAssertEqual(decoded, triggers)
    }
}
