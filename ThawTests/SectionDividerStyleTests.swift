//
//  SectionDividerStyleTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class SectionDividerStyleTests: XCTestCase {
    // MARK: - Raw Value Tests

    func testNoDividerRawValue() {
        XCTAssertEqual(SectionDividerStyle.noDivider.rawValue, 0)
    }

    func testChevronRawValue() {
        XCTAssertEqual(SectionDividerStyle.chevron.rawValue, 1)
    }

    // MARK: - Init from Raw Value Tests

    func testInitFromRawValueZero() {
        XCTAssertEqual(SectionDividerStyle(rawValue: 0), .noDivider)
    }

    func testInitFromRawValueOne() {
        XCTAssertEqual(SectionDividerStyle(rawValue: 1), .chevron)
    }

    func testInitFromInvalidRawValue() {
        XCTAssertNil(SectionDividerStyle(rawValue: 2))
        XCTAssertNil(SectionDividerStyle(rawValue: -1))
    }

    // MARK: - Identifiable Tests

    func testIdMatchesRawValue() {
        for style in SectionDividerStyle.allCases {
            XCTAssertEqual(style.id, style.rawValue)
        }
    }

    // MARK: - CaseIterable Tests

    func testAllCasesCount() {
        XCTAssertEqual(SectionDividerStyle.allCases.count, 2)
    }

    func testAllCasesContainsAllStyles() {
        XCTAssertTrue(SectionDividerStyle.allCases.contains(.noDivider))
        XCTAssertTrue(SectionDividerStyle.allCases.contains(.chevron))
    }
}
