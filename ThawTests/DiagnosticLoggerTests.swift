//
//  DiagnosticLoggerTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - DiagnosticLogger.Level Tests

final class DiagnosticLoggerLevelTests: XCTestCase {
    // MARK: - Raw Values

    func testDebugRawValue() {
        XCTAssertEqual(DiagnosticLogger.Level.debug.rawValue, "DEBUG")
    }

    func testInfoRawValue() {
        XCTAssertEqual(DiagnosticLogger.Level.info.rawValue, "INFO")
    }

    func testNoticeRawValue() {
        XCTAssertEqual(DiagnosticLogger.Level.notice.rawValue, "NOTICE")
    }

    func testWarningRawValue() {
        XCTAssertEqual(DiagnosticLogger.Level.warning.rawValue, "WARNING")
    }

    func testErrorRawValue() {
        XCTAssertEqual(DiagnosticLogger.Level.error.rawValue, "ERROR")
    }

    // MARK: - Init From Raw Value

    func testInitFromDebugRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "DEBUG")
        XCTAssertEqual(level, .debug)
    }

    func testInitFromInfoRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "INFO")
        XCTAssertEqual(level, .info)
    }

    func testInitFromNoticeRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "NOTICE")
        XCTAssertEqual(level, .notice)
    }

    func testInitFromWarningRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "WARNING")
        XCTAssertEqual(level, .warning)
    }

    func testInitFromErrorRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "ERROR")
        XCTAssertEqual(level, .error)
    }

    func testInitFromInvalidRawValue() {
        let level = DiagnosticLogger.Level(rawValue: "INVALID")
        XCTAssertNil(level)
    }

    func testInitFromLowercaseRawValue() {
        // Raw values are case-sensitive
        let level = DiagnosticLogger.Level(rawValue: "debug")
        XCTAssertNil(level)
    }

    // MARK: - All Levels

    func testAllLevelsHaveUppercaseRawValues() {
        let levels: [DiagnosticLogger.Level] = [.debug, .info, .notice, .warning, .error]

        for level in levels {
            XCTAssertEqual(level.rawValue, level.rawValue.uppercased(),
                           "Level \(level) should have uppercase raw value")
        }
    }

    func testAllLevelsAreDistinct() {
        let levels: [DiagnosticLogger.Level] = [.debug, .info, .notice, .warning, .error]
        let rawValues = Set(levels.map(\.rawValue))

        XCTAssertEqual(rawValues.count, levels.count,
                       "All levels should have distinct raw values")
    }
}
