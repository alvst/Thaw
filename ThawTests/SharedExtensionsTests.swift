//
//  SharedExtensionsTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - CGError Extension Tests

final class CGErrorExtensionTests: XCTestCase {
    // MARK: - LogString Tests

    func testSuccessLogString() {
        let error = CGError.success
        XCTAssertEqual(error.logString, "\(error.rawValue): success")
    }

    func testFailureLogString() {
        let error = CGError.failure
        XCTAssertEqual(error.logString, "\(error.rawValue): failure")
    }

    func testIllegalArgumentLogString() {
        let error = CGError.illegalArgument
        XCTAssertEqual(error.logString, "\(error.rawValue): illegalArgument")
    }

    func testInvalidConnectionLogString() {
        let error = CGError.invalidConnection
        XCTAssertEqual(error.logString, "\(error.rawValue): invalidConnection")
    }

    func testInvalidContextLogString() {
        let error = CGError.invalidContext
        XCTAssertEqual(error.logString, "\(error.rawValue): invalidContext")
    }

    func testCannotCompleteLogString() {
        let error = CGError.cannotComplete
        XCTAssertEqual(error.logString, "\(error.rawValue): cannotComplete")
    }

    func testNotImplementedLogString() {
        let error = CGError.notImplemented
        XCTAssertEqual(error.logString, "\(error.rawValue): notImplemented")
    }

    func testRangeCheckLogString() {
        let error = CGError.rangeCheck
        XCTAssertEqual(error.logString, "\(error.rawValue): rangeCheck")
    }

    func testTypeCheckLogString() {
        let error = CGError.typeCheck
        XCTAssertEqual(error.logString, "\(error.rawValue): typeCheck")
    }

    func testInvalidOperationLogString() {
        let error = CGError.invalidOperation
        XCTAssertEqual(error.logString, "\(error.rawValue): invalidOperation")
    }

    func testNoneAvailableLogString() {
        let error = CGError.noneAvailable
        XCTAssertEqual(error.logString, "\(error.rawValue): noneAvailable")
    }

    func testLogStringContainsRawValue() {
        let error = CGError.failure
        XCTAssertTrue(error.logString.contains("\(error.rawValue)"))
    }
}

// MARK: - CGPoint Extension Tests

final class CGPointExtensionTests: XCTestCase {
    // MARK: - Distance Tests

    func testDistanceToSamePoint() {
        let point = CGPoint(x: 10, y: 20)
        XCTAssertEqual(point.distance(to: point), 0)
    }

    func testDistanceHorizontal() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 10, y: 0)
        XCTAssertEqual(point1.distance(to: point2), 10)
    }

    func testDistanceVertical() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 0, y: 15)
        XCTAssertEqual(point1.distance(to: point2), 15)
    }

    func testDistanceDiagonal345() {
        // 3-4-5 right triangle
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 3, y: 4)
        XCTAssertEqual(point1.distance(to: point2), 5)
    }

    func testDistanceNegativeCoordinates() {
        let point1 = CGPoint(x: -5, y: -5)
        let point2 = CGPoint(x: -5, y: 5)
        XCTAssertEqual(point1.distance(to: point2), 10)
    }

    func testDistanceIsSymmetric() {
        let point1 = CGPoint(x: 10, y: 20)
        let point2 = CGPoint(x: 30, y: 40)
        XCTAssertEqual(point1.distance(to: point2), point2.distance(to: point1))
    }

    func testDistanceFractional() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 1, y: 1)
        let expected = sqrt(2.0)
        XCTAssertEqual(point1.distance(to: point2), expected, accuracy: 0.0001)
    }

    func testDistanceLargeValues() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 1000, y: 1000)
        let expected = sqrt(2_000_000.0)
        XCTAssertEqual(point1.distance(to: point2), expected, accuracy: 0.0001)
    }
}

// MARK: - CGRect Extension Tests

final class CGRectExtensionTests: XCTestCase {
    // MARK: - Center Tests

    func testCenterOfOriginRect() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(rect.center, CGPoint(x: 50, y: 50))
    }

    func testCenterOfOffsetRect() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 200)
        XCTAssertEqual(rect.center, CGPoint(x: 60, y: 120))
    }

    func testCenterOfNegativeOriginRect() {
        let rect = CGRect(x: -50, y: -50, width: 100, height: 100)
        XCTAssertEqual(rect.center, CGPoint(x: 0, y: 0))
    }

    func testCenterOfZeroSizeRect() {
        let rect = CGRect(x: 10, y: 20, width: 0, height: 0)
        XCTAssertEqual(rect.center, CGPoint(x: 10, y: 20))
    }

    func testCenterOfUnitRect() {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        XCTAssertEqual(rect.center, CGPoint(x: 0.5, y: 0.5))
    }

    func testCenterOfAsymmetricRect() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 50)
        XCTAssertEqual(rect.center, CGPoint(x: 100, y: 25))
    }

    func testCenterUsesMidXMidY() {
        let rect = CGRect(x: 5, y: 10, width: 30, height: 40)
        XCTAssertEqual(rect.center.x, rect.midX)
        XCTAssertEqual(rect.center.y, rect.midY)
    }
}
