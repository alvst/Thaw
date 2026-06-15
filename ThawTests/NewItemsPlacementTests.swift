//
//  NewItemsPlacementTests.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

@testable import Thaw
import XCTest

// MARK: - NewItemsPlacement.Relation Tests

final class NewItemsPlacementRelationTests: XCTestCase {
    // MARK: - Raw Values

    func testLeftOfAnchorRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation.leftOfAnchor
        XCTAssertEqual(relation.rawValue, "leftOfAnchor")
    }

    func testRightOfAnchorRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation.rightOfAnchor
        XCTAssertEqual(relation.rawValue, "rightOfAnchor")
    }

    func testSectionDefaultRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation.sectionDefault
        XCTAssertEqual(relation.rawValue, "sectionDefault")
    }

    // MARK: - Init from Raw Value

    func testInitFromLeftOfAnchorRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation(rawValue: "leftOfAnchor")
        XCTAssertEqual(relation, .leftOfAnchor)
    }

    func testInitFromRightOfAnchorRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation(rawValue: "rightOfAnchor")
        XCTAssertEqual(relation, .rightOfAnchor)
    }

    func testInitFromSectionDefaultRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation(rawValue: "sectionDefault")
        XCTAssertEqual(relation, .sectionDefault)
    }

    func testInitFromInvalidRawValue() {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation(rawValue: "invalid")
        XCTAssertNil(relation)
    }

    // MARK: - Codable

    func testRelationEncode() throws {
        let relation = MenuBarItemManager.NewItemsPlacement.Relation.leftOfAnchor
        let encoder = JSONEncoder()
        let data = try encoder.encode(relation)
        let json = String(data: data, encoding: .utf8)

        XCTAssertEqual(json, "\"leftOfAnchor\"")
    }

    func testRelationDecode() throws {
        let json = "\"rightOfAnchor\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        let relation = try decoder.decode(MenuBarItemManager.NewItemsPlacement.Relation.self, from: data)

        XCTAssertEqual(relation, .rightOfAnchor)
    }

    func testRelationDecodeInvalid() throws {
        let json = "\"invalidValue\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(MenuBarItemManager.NewItemsPlacement.Relation.self, from: data))
    }

    // MARK: - Equality

    func testRelationEquality() {
        XCTAssertEqual(
            MenuBarItemManager.NewItemsPlacement.Relation.leftOfAnchor,
            MenuBarItemManager.NewItemsPlacement.Relation.leftOfAnchor
        )
        XCTAssertNotEqual(
            MenuBarItemManager.NewItemsPlacement.Relation.leftOfAnchor,
            MenuBarItemManager.NewItemsPlacement.Relation.rightOfAnchor
        )
    }
}

// MARK: - NewItemsPlacement Tests

final class NewItemsPlacementTests: XCTestCase {
    // MARK: - Initialization

    func testBasicInit() {
        let placement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )

        XCTAssertEqual(placement.sectionKey, "hidden")
        XCTAssertNil(placement.anchorIdentifier)
        XCTAssertEqual(placement.relation, .sectionDefault)
    }

    func testInitWithAnchor() {
        let placement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "visible",
            anchorIdentifier: "com.example.app:Item",
            relation: .leftOfAnchor
        )

        XCTAssertEqual(placement.sectionKey, "visible")
        XCTAssertEqual(placement.anchorIdentifier, "com.example.app:Item")
        XCTAssertEqual(placement.relation, .leftOfAnchor)
    }

    func testInitWithRightOfAnchor() {
        let placement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "alwaysHidden",
            anchorIdentifier: "com.other.app:OtherItem",
            relation: .rightOfAnchor
        )

        XCTAssertEqual(placement.sectionKey, "alwaysHidden")
        XCTAssertEqual(placement.anchorIdentifier, "com.other.app:OtherItem")
        XCTAssertEqual(placement.relation, .rightOfAnchor)
    }

    // MARK: - Default Value

    func testDefaultValueExists() {
        let defaultValue = MenuBarItemManager.NewItemsPlacement.defaultValue

        XCTAssertNotNil(defaultValue)
        XCTAssertNil(defaultValue.anchorIdentifier)
        XCTAssertEqual(defaultValue.relation, .sectionDefault)
    }

    func testDefaultValueSectionKey() {
        let defaultValue = MenuBarItemManager.NewItemsPlacement.defaultValue

        // Default section should be "hidden" per Defaults.DefaultValue.newItemsSection
        XCTAssertEqual(defaultValue.sectionKey, Defaults.DefaultValue.newItemsSection)
    }

    // MARK: - Equality

    func testEqualityIdentical() {
        let placement1 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "com.app:Item",
            relation: .leftOfAnchor
        )
        let placement2 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "com.app:Item",
            relation: .leftOfAnchor
        )

        XCTAssertEqual(placement1, placement2)
    }

    func testEqualityDifferentSection() {
        let placement1 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )
        let placement2 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "visible",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )

        XCTAssertNotEqual(placement1, placement2)
    }

    func testEqualityDifferentAnchor() {
        let placement1 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "anchor1",
            relation: .leftOfAnchor
        )
        let placement2 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "anchor2",
            relation: .leftOfAnchor
        )

        XCTAssertNotEqual(placement1, placement2)
    }

    func testEqualityDifferentRelation() {
        let placement1 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "anchor",
            relation: .leftOfAnchor
        )
        let placement2 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "anchor",
            relation: .rightOfAnchor
        )

        XCTAssertNotEqual(placement1, placement2)
    }

    func testEqualityNilVsNonNilAnchor() {
        let placement1 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )
        let placement2 = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "com.app:Item",
            relation: .sectionDefault
        )

        XCTAssertNotEqual(placement1, placement2)
    }

    // MARK: - Codable

    func testEncodeBasic() throws {
        let placement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(placement)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"sectionKey\":\"hidden\""))
        XCTAssertTrue(json.contains("\"relation\":\"sectionDefault\""))
    }

    func testEncodeWithAnchor() throws {
        let placement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "visible",
            anchorIdentifier: "com.example.app:StatusItem",
            relation: .leftOfAnchor
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(placement)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"anchorIdentifier\":\"com.example.app:StatusItem\""))
        XCTAssertTrue(json.contains("\"relation\":\"leftOfAnchor\""))
    }

    func testDecodeBasic() throws {
        let json = """
        {
            "sectionKey": "hidden",
            "anchorIdentifier": null,
            "relation": "sectionDefault"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        let placement = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(placement.sectionKey, "hidden")
        XCTAssertNil(placement.anchorIdentifier)
        XCTAssertEqual(placement.relation, .sectionDefault)
    }

    func testDecodeWithAnchor() throws {
        let json = """
        {
            "sectionKey": "alwaysHidden",
            "anchorIdentifier": "com.test.app:Item",
            "relation": "rightOfAnchor"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        let placement = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(placement.sectionKey, "alwaysHidden")
        XCTAssertEqual(placement.anchorIdentifier, "com.test.app:Item")
        XCTAssertEqual(placement.relation, .rightOfAnchor)
    }

    func testDecodeInvalidRelation() throws {
        let json = """
        {
            "sectionKey": "hidden",
            "anchorIdentifier": null,
            "relation": "invalidRelation"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data))
    }

    func testDecodeMissingOptionalField() throws {
        let json = """
        {
            "sectionKey": "hidden",
            "relation": "sectionDefault"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()

        // anchorIdentifier is Optional<String>, so missing key decodes as nil
        let placement = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(placement.sectionKey, "hidden")
        XCTAssertNil(placement.anchorIdentifier)
        XCTAssertEqual(placement.relation, .sectionDefault)
    }

    // MARK: - Round Trip

    func testRoundTripBasic() throws {
        let original = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "visible",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testRoundTripWithAnchor() throws {
        let original = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "hidden",
            anchorIdentifier: "com.complexapp.identifier:Very Long Item Name With Spaces",
            relation: .leftOfAnchor
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testRoundTripDefaultValue() throws {
        let original = MenuBarItemManager.NewItemsPlacement.defaultValue

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MenuBarItemManager.NewItemsPlacement.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - All Relations

    func testAllRelationsCovered() {
        // Ensure all three relations can be used in placements
        let leftPlacement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "test",
            anchorIdentifier: "anchor",
            relation: .leftOfAnchor
        )
        let rightPlacement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "test",
            anchorIdentifier: "anchor",
            relation: .rightOfAnchor
        )
        let defaultPlacement = MenuBarItemManager.NewItemsPlacement(
            sectionKey: "test",
            anchorIdentifier: nil,
            relation: .sectionDefault
        )

        XCTAssertEqual(leftPlacement.relation, .leftOfAnchor)
        XCTAssertEqual(rightPlacement.relation, .rightOfAnchor)
        XCTAssertEqual(defaultPlacement.relation, .sectionDefault)
    }
}
