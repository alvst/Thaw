//
//  MenuBarShapesTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - MenuBarEndCap Tests

final class MenuBarEndCapTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(MenuBarEndCap.square.rawValue, 0)
        XCTAssertEqual(MenuBarEndCap.round.rawValue, 1)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(MenuBarEndCap(rawValue: 0), .square)
        XCTAssertEqual(MenuBarEndCap(rawValue: 1), .round)
        XCTAssertNil(MenuBarEndCap(rawValue: 2))
    }

    func testAllCasesCount() {
        XCTAssertEqual(MenuBarEndCap.allCases.count, 2)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for endCap in MenuBarEndCap.allCases {
            let data = try encoder.encode(endCap)
            let decoded = try decoder.decode(MenuBarEndCap.self, from: data)
            XCTAssertEqual(decoded, endCap)
        }
    }
}

// MARK: - MenuBarShapeKind Tests

final class MenuBarShapeKindTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(MenuBarShapeKind.noShape.rawValue, 0)
        XCTAssertEqual(MenuBarShapeKind.full.rawValue, 1)
        XCTAssertEqual(MenuBarShapeKind.split.rawValue, 2)
        XCTAssertEqual(MenuBarShapeKind.notch.rawValue, 3)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(MenuBarShapeKind(rawValue: 0), .noShape)
        XCTAssertEqual(MenuBarShapeKind(rawValue: 1), .full)
        XCTAssertEqual(MenuBarShapeKind(rawValue: 2), .split)
        XCTAssertEqual(MenuBarShapeKind(rawValue: 3), .notch)
        XCTAssertNil(MenuBarShapeKind(rawValue: 4))
    }

    func testAllCasesCount() {
        XCTAssertEqual(MenuBarShapeKind.allCases.count, 4)
    }

    func testIdentifiableId() {
        for kind in MenuBarShapeKind.allCases {
            XCTAssertEqual(kind.id, kind.rawValue)
        }
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for kind in MenuBarShapeKind.allCases {
            let data = try encoder.encode(kind)
            let decoded = try decoder.decode(MenuBarShapeKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }
}

// MARK: - MenuBarFullShapeInfo Tests

final class MenuBarFullShapeInfoTests: XCTestCase {
    func testDefaultValue() {
        let defaultInfo = MenuBarFullShapeInfo.defaultValue
        XCTAssertEqual(defaultInfo.leadingEndCap, .round)
        XCTAssertEqual(defaultInfo.trailingEndCap, .round)
    }

    func testHasRoundedShapeBothRound() {
        let info = MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .round)
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeLeadingRound() {
        let info = MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .square)
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeTrailingRound() {
        let info = MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .round)
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeBothSquare() {
        let info = MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        XCTAssertFalse(info.hasRoundedShape)
    }

    func testCodable() throws {
        let original = MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .round)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarFullShapeInfo.self, from: data)

        XCTAssertEqual(decoded.leadingEndCap, original.leadingEndCap)
        XCTAssertEqual(decoded.trailingEndCap, original.trailingEndCap)
    }

    func testHashable() {
        let info1 = MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .round)
        let info2 = MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .round)
        let info3 = MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .round)

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
}

// MARK: - MenuBarSplitShapeInfo Tests

final class MenuBarSplitShapeInfoTests: XCTestCase {
    func testDefaultValue() {
        let defaultInfo = MenuBarSplitShapeInfo.defaultValue
        XCTAssertEqual(defaultInfo.leading, MenuBarFullShapeInfo.defaultValue)
        XCTAssertEqual(defaultInfo.trailing, MenuBarFullShapeInfo.defaultValue)
    }

    func testHasRoundedShapeLeadingRounded() {
        let info = MenuBarSplitShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        )
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeTrailingRounded() {
        let info = MenuBarSplitShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .round)
        )
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeNoneRounded() {
        let info = MenuBarSplitShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        )
        XCTAssertFalse(info.hasRoundedShape)
    }

    func testCodable() throws {
        let original = MenuBarSplitShapeInfo.defaultValue

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarSplitShapeInfo.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

// MARK: - MenuBarNotchShapeInfo Tests

final class MenuBarNotchShapeInfoTests: XCTestCase {
    func testDefaultValue() {
        let defaultInfo = MenuBarNotchShapeInfo.defaultValue
        XCTAssertEqual(defaultInfo.leading, MenuBarFullShapeInfo.defaultValue)
        XCTAssertEqual(defaultInfo.trailing, MenuBarFullShapeInfo.defaultValue)
    }

    func testHasRoundedShapeLeadingRounded() {
        let info = MenuBarNotchShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .round, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        )
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeTrailingRounded() {
        let info = MenuBarNotchShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .round)
        )
        XCTAssertTrue(info.hasRoundedShape)
    }

    func testHasRoundedShapeNoneRounded() {
        let info = MenuBarNotchShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        )
        XCTAssertFalse(info.hasRoundedShape)
    }

    func testCodable() throws {
        let original = MenuBarNotchShapeInfo.defaultValue

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarNotchShapeInfo.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testHashable() {
        let info1 = MenuBarNotchShapeInfo.defaultValue
        let info2 = MenuBarNotchShapeInfo.defaultValue
        let info3 = MenuBarNotchShapeInfo(
            leading: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square),
            trailing: MenuBarFullShapeInfo(leadingEndCap: .square, trailingEndCap: .square)
        )

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }

    func testShapeKindCodableNotch() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(MenuBarShapeKind.notch)
        let decoded = try decoder.decode(MenuBarShapeKind.self, from: data)
        XCTAssertEqual(decoded, .notch)
    }
}
