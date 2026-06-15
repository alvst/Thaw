//
//  WindowInfoTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

final class WindowInfoTests: XCTestCase {
    // MARK: - Test Helpers

    private func createWindowInfo(
        windowID: CGWindowID = 12345,
        ownerPID: pid_t = 1000,
        bounds: CGRect = CGRect(x: 0, y: 0, width: 100, height: 22),
        layer: Int = 25,
        title: String? = "TestItem",
        ownerName: String? = "TestApp",
        isOnScreen: Bool = true
    ) -> WindowInfo {
        // CGRect encodes as nested arrays: [[x,y],[width,height]]
        let titleJSON = title.map { "\"\($0)\"" } ?? "null"
        let ownerNameJSON = ownerName.map { "\"\($0)\"" } ?? "null"
        let json = """
        {
            "windowID": \(windowID),
            "ownerPID": \(ownerPID),
            "bounds": [[\(bounds.origin.x), \(bounds.origin.y)], [\(bounds.size.width), \(bounds.size.height)]],
            "layer": \(layer),
            "title": \(titleJSON),
            "ownerName": \(ownerNameJSON),
            "isOnScreen": \(isOnScreen)
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(WindowInfo.self, from: data)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = createWindowInfo()

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        XCTAssertEqual(decoded.windowID, original.windowID)
        XCTAssertEqual(decoded.ownerPID, original.ownerPID)
        XCTAssertEqual(decoded.bounds, original.bounds)
        XCTAssertEqual(decoded.layer, original.layer)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.ownerName, original.ownerName)
        XCTAssertEqual(decoded.isOnScreen, original.isOnScreen)
    }

    func testDecodeWithNilTitle() throws {
        let window = createWindowInfo(title: nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(window)
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        XCTAssertNil(decoded.title)
    }

    func testDecodeWithNilOwnerName() throws {
        let window = createWindowInfo(ownerName: nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(window)
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        XCTAssertNil(decoded.ownerName)
    }

    func testDecodePreservesAllFields() throws {
        let original = createWindowInfo(
            windowID: 99999,
            ownerPID: 5555,
            bounds: CGRect(x: 100, y: 200, width: 300, height: 400),
            layer: 42,
            title: "SpecificTitle",
            ownerName: "SpecificApp",
            isOnScreen: false
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        XCTAssertEqual(decoded.windowID, 99999)
        XCTAssertEqual(decoded.ownerPID, 5555)
        XCTAssertEqual(decoded.bounds.origin.x, 100)
        XCTAssertEqual(decoded.bounds.origin.y, 200)
        XCTAssertEqual(decoded.bounds.size.width, 300)
        XCTAssertEqual(decoded.bounds.size.height, 400)
        XCTAssertEqual(decoded.layer, 42)
        XCTAssertEqual(decoded.title, "SpecificTitle")
        XCTAssertEqual(decoded.ownerName, "SpecificApp")
        XCTAssertFalse(decoded.isOnScreen)
    }

    // MARK: - Equatable Tests

    func testEqualityIdentical() {
        let window1 = createWindowInfo()
        let window2 = createWindowInfo()

        XCTAssertEqual(window1, window2)
    }

    func testEqualityDifferentWindowID() {
        let window1 = createWindowInfo(windowID: 1)
        let window2 = createWindowInfo(windowID: 2)

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentOwnerPID() {
        let window1 = createWindowInfo(ownerPID: 100)
        let window2 = createWindowInfo(ownerPID: 200)

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentBounds() {
        let window1 = createWindowInfo(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        let window2 = createWindowInfo(bounds: CGRect(x: 10, y: 10, width: 100, height: 100))

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentLayer() {
        let window1 = createWindowInfo(layer: 10)
        let window2 = createWindowInfo(layer: 20)

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentTitle() {
        let window1 = createWindowInfo(title: "Title1")
        let window2 = createWindowInfo(title: "Title2")

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentOwnerName() {
        let window1 = createWindowInfo(ownerName: "App1")
        let window2 = createWindowInfo(ownerName: "App2")

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityDifferentIsOnScreen() {
        let window1 = createWindowInfo(isOnScreen: true)
        let window2 = createWindowInfo(isOnScreen: false)

        XCTAssertNotEqual(window1, window2)
    }

    func testEqualityNilVsNonNilTitle() {
        let window1 = createWindowInfo(title: nil)
        let window2 = createWindowInfo(title: "SomeTitle")

        XCTAssertNotEqual(window1, window2)
    }

    // MARK: - Hashable Tests

    func testHashableConsistency() {
        let window1 = createWindowInfo()
        let window2 = createWindowInfo()

        XCTAssertEqual(window1.hashValue, window2.hashValue)
    }

    func testHashableInSet() {
        let window1 = createWindowInfo(windowID: 1)
        let window2 = createWindowInfo(windowID: 2)
        let window3 = createWindowInfo(windowID: 1) // duplicate of window1

        var set = Set<WindowInfo>()
        set.insert(window1)
        set.insert(window2)
        set.insert(window3)

        XCTAssertEqual(set.count, 2)
    }

    func testHashableAsDictionaryKey() {
        let window = createWindowInfo()
        var dict = [WindowInfo: String]()

        dict[window] = "test"

        XCTAssertEqual(dict[window], "test")
    }

    // MARK: - Computed Property Tests

    func testIsWindowServerWindow() {
        let windowServerWindow = createWindowInfo(ownerName: "Window Server")
        let regularWindow = createWindowInfo(ownerName: "SomeApp")

        XCTAssertTrue(windowServerWindow.isWindowServerWindow)
        XCTAssertFalse(regularWindow.isWindowServerWindow)
    }

    func testIsWindowServerWindowWithNilOwnerName() {
        let window = createWindowInfo(ownerName: nil)

        XCTAssertFalse(window.isWindowServerWindow)
    }

    func testIsMenuRelatedForWindowServer() {
        let window = createWindowInfo(ownerName: "Window Server")

        XCTAssertTrue(window.isMenuRelated)
    }

    func testIsMenuRelatedForMainMenuLevel() {
        // kCGMainMenuWindowLevel is typically 24
        let window = createWindowInfo(layer: Int(CGWindowLevelForKey(.mainMenuWindow)), ownerName: "SomeApp")

        XCTAssertTrue(window.isMenuRelated)
    }

    func testIsMenuRelatedForStatusWindowLevel() {
        let window = createWindowInfo(layer: Int(CGWindowLevelForKey(.statusWindow)), ownerName: "SomeApp")

        XCTAssertTrue(window.isMenuRelated)
    }

    func testIsMenuRelatedForPopUpMenuLevel() {
        let window = createWindowInfo(layer: Int(CGWindowLevelForKey(.popUpMenuWindow)), ownerName: "SomeApp")

        XCTAssertTrue(window.isMenuRelated)
    }

    func testIsNotMenuRelatedForRegularWindow() {
        // Normal window level is 0
        let window = createWindowInfo(layer: 0, ownerName: "SomeApp")

        XCTAssertFalse(window.isMenuRelated)
    }
}
