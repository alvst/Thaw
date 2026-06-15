//
//  IceBarLocationTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class IceBarLocationTests: XCTestCase {
    // MARK: - Raw Value Tests

    func testDynamicRawValue() {
        XCTAssertEqual(IceBarLocation.dynamic.rawValue, 0)
    }

    func testMousePointerRawValue() {
        XCTAssertEqual(IceBarLocation.mousePointer.rawValue, 1)
    }

    func testIceIconRawValue() {
        XCTAssertEqual(IceBarLocation.iceIcon.rawValue, 2)
    }

    func testLeftAlignedRawValue() {
        XCTAssertEqual(IceBarLocation.leftAligned.rawValue, 3)
    }

    func testRightAlignedRawValue() {
        XCTAssertEqual(IceBarLocation.rightAligned.rawValue, 4)
    }

    // MARK: - Init from Raw Value Tests

    func testInitFromRawValueZero() {
        XCTAssertEqual(IceBarLocation(rawValue: 0), .dynamic)
    }

    func testInitFromRawValueOne() {
        XCTAssertEqual(IceBarLocation(rawValue: 1), .mousePointer)
    }

    func testInitFromRawValueTwo() {
        XCTAssertEqual(IceBarLocation(rawValue: 2), .iceIcon)
    }

    func testInitFromRawValueThree() {
        XCTAssertEqual(IceBarLocation(rawValue: 3), .leftAligned)
    }

    func testInitFromRawValueFour() {
        XCTAssertEqual(IceBarLocation(rawValue: 4), .rightAligned)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(IceBarLocation(rawValue: -1))
        XCTAssertNil(IceBarLocation(rawValue: 100))
    }

    // MARK: - Identifiable Tests

    func testIdMatchesRawValue() {
        for location in IceBarLocation.allCases {
            XCTAssertEqual(location.id, location.rawValue)
        }
    }

    // MARK: - CaseIterable Tests

    func testAllCasesCount() {
        XCTAssertEqual(IceBarLocation.allCases.count, 5)
    }

    func testAllCasesContainsAllLocations() {
        XCTAssertTrue(IceBarLocation.allCases.contains(.dynamic))
        XCTAssertTrue(IceBarLocation.allCases.contains(.mousePointer))
        XCTAssertTrue(IceBarLocation.allCases.contains(.iceIcon))
        XCTAssertTrue(IceBarLocation.allCases.contains(.leftAligned))
        XCTAssertTrue(IceBarLocation.allCases.contains(.rightAligned))
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for location in IceBarLocation.allCases {
            let data = try encoder.encode(location)
            let decoded = try decoder.decode(IceBarLocation.self, from: data)
            XCTAssertEqual(decoded, location)
        }
    }

    func testDecodeFromRawValueJSON() throws {
        let decoder = JSONDecoder()

        // JSON integers should decode to locations
        XCTAssertEqual(try decoder.decode(IceBarLocation.self, from: XCTUnwrap("0".data(using: .utf8))), .dynamic)
        XCTAssertEqual(try decoder.decode(IceBarLocation.self, from: XCTUnwrap("1".data(using: .utf8))), .mousePointer)
        XCTAssertEqual(try decoder.decode(IceBarLocation.self, from: XCTUnwrap("2".data(using: .utf8))), .iceIcon)
        XCTAssertEqual(try decoder.decode(IceBarLocation.self, from: XCTUnwrap("3".data(using: .utf8))), .leftAligned)
        XCTAssertEqual(try decoder.decode(IceBarLocation.self, from: XCTUnwrap("4".data(using: .utf8))), .rightAligned)
    }

    // MARK: - fromString() Tests

    func testFromStringDynamic() {
        XCTAssertEqual(IceBarLocation.fromString("dynamic"), .dynamic)
    }

    func testFromStringMousePointer() {
        XCTAssertEqual(IceBarLocation.fromString("mousePointer"), .mousePointer)
    }

    func testFromStringIceIcon() {
        XCTAssertEqual(IceBarLocation.fromString("iceIcon"), .iceIcon)
    }

    func testFromStringLeftAligned() {
        XCTAssertEqual(IceBarLocation.fromString("leftAligned"), .leftAligned)
    }

    func testFromStringRightAligned() {
        XCTAssertEqual(IceBarLocation.fromString("rightAligned"), .rightAligned)
    }

    func testFromStringNumericZero() {
        XCTAssertEqual(IceBarLocation.fromString("0"), .dynamic)
    }

    func testFromStringNumericOne() {
        XCTAssertEqual(IceBarLocation.fromString("1"), .mousePointer)
    }

    func testFromStringNumericTwo() {
        XCTAssertEqual(IceBarLocation.fromString("2"), .iceIcon)
    }

    func testFromStringNumericThree() {
        XCTAssertEqual(IceBarLocation.fromString("3"), .leftAligned)
    }

    func testFromStringNumericFour() {
        XCTAssertEqual(IceBarLocation.fromString("4"), .rightAligned)
    }

    func testFromStringInvalid() {
        XCTAssertNil(IceBarLocation.fromString("invalid"))
        XCTAssertNil(IceBarLocation.fromString("5"))
        XCTAssertNil(IceBarLocation.fromString(""))
        XCTAssertNil(IceBarLocation.fromString("Dynamic")) // case sensitive
        XCTAssertNil(IceBarLocation.fromString("mouse_pointer")) // snake_case not supported
        XCTAssertNil(IceBarLocation.fromString("ice_icon"))
        XCTAssertNil(IceBarLocation.fromString("left_aligned"))
        XCTAssertNil(IceBarLocation.fromString("right_aligned"))
    }
}
