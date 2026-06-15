//
//  MenuBarItemServiceTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - MenuBarItemService Tests

final class MenuBarItemServiceTests: XCTestCase {
    // MARK: - Service Name

    func testServiceName() {
        XCTAssertEqual(MenuBarItemService.name, "com.stonerl.Thaw.MenuBarItemService")
    }
}

// MARK: - Request Tests

final class MenuBarItemServiceRequestTests: XCTestCase {
    // MARK: - Start Request

    func testStartRequestEncode() throws {
        let request = MenuBarItemService.Request.start
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("start"))
    }

    func testStartRequestDecode() throws {
        let json = #"{"start":{}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        let request = try decoder.decode(MenuBarItemService.Request.self, from: data)

        if case .start = request {
            // Success
        } else {
            XCTFail("Expected .start request")
        }
    }

    func testStartRequestRoundTrip() throws {
        let original = MenuBarItemService.Request.start
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemService.Request.self, from: data)

        if case .start = decoded {
            // Success
        } else {
            XCTFail("Expected .start request after round trip")
        }
    }

    // MARK: - SourcePID Request

    func testSourcePIDRequestRoundTrip() throws {
        // Create a WindowInfo manually for testing
        let windowInfo = createTestWindowInfo()
        let original = MenuBarItemService.Request.sourcePID(windowInfo)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemService.Request.self, from: data)

        if case let .sourcePID(decodedWindow) = decoded {
            XCTAssertEqual(decodedWindow.windowID, windowInfo.windowID)
            XCTAssertEqual(decodedWindow.ownerPID, windowInfo.ownerPID)
        } else {
            XCTFail("Expected .sourcePID request after round trip")
        }
    }

    // MARK: - Helper

    private func createTestWindowInfo() -> WindowInfo {
        // CGRect encodes as nested arrays: [[x,y],[width,height]]
        let json = """
        {
            "windowID": 12345,
            "ownerPID": 1000,
            "bounds": [[0, 0], [100, 22]],
            "layer": 25,
            "title": "TestItem",
            "ownerName": "TestApp",
            "isOnScreen": true
        }
        """
        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(WindowInfo.self, from: data)
    }
}

// MARK: - Response Tests

final class MenuBarItemServiceResponseTests: XCTestCase {
    // MARK: - Start Response

    func testStartResponseEncode() throws {
        let response = MenuBarItemService.Response.start
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("start"))
    }

    func testStartResponseRoundTrip() throws {
        let original = MenuBarItemService.Response.start
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemService.Response.self, from: data)

        if case .start = decoded {
            // Success
        } else {
            XCTFail("Expected .start response after round trip")
        }
    }

    // MARK: - SourcePID Response

    func testSourcePIDResponseWithPID() throws {
        let original = MenuBarItemService.Response.sourcePID(1234)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemService.Response.self, from: data)

        if case let .sourcePID(pid) = decoded {
            XCTAssertEqual(pid, 1234)
        } else {
            XCTFail("Expected .sourcePID response")
        }
    }

    func testSourcePIDResponseWithNil() throws {
        let original = MenuBarItemService.Response.sourcePID(nil)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemService.Response.self, from: data)

        if case let .sourcePID(pid) = decoded {
            XCTAssertNil(pid)
        } else {
            XCTFail("Expected .sourcePID response with nil")
        }
    }

    func testSourcePIDResponseEncodesCorrectly() throws {
        let response = MenuBarItemService.Response.sourcePID(5678)
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("sourcePID"))
        XCTAssertTrue(json.contains("5678"))
    }
}
