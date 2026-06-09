//
//  ComponentCategoryTests.swift
//  ElectricSimTests
//
//  პალიტრის კატეგორიების ვალიდაცია.
//

import XCTest
@testable import ElectricSimCore

final class ComponentCategoryTests: XCTestCase {

    /// ყველა კომპონენტს აქვს ვალიდური კატეგორია.
    func testEveryComponentHasValidCategory() throws {
        let templates = try GameData.loadTemplates()
        XCTAssertFalse(templates.isEmpty)
        for (id, t) in templates {
            XCTAssertTrue(ComponentCategory.allCases.contains(t.resolvedCategory),
                          "\(id): არასწორი კატეგორია")
        }
    }

    /// ხუთივე კატეგორია წარმოდგენილია (ყველა სექცია დაირენდერება).
    func testAllCategoriesRepresented() throws {
        let templates = try GameData.loadTemplates()
        let present = Set(templates.values.map { $0.resolvedCategory })
        XCTAssertEqual(present, Set(ComponentCategory.allCases),
                       "ხუთივე კატეგორიას უნდა ჰქონდეს კომპონენტი")
    }

    /// კატეგორიის მეტამონაცემები + kind-მეპინგი.
    func testCategoryMetadataAndMapping() {
        XCTAssertEqual(ComponentCategory.allCases.count, 5)
        for c in ComponentCategory.allCases { XCTAssertFalse(c.georgian.isEmpty) }
        XCTAssertEqual(ComponentCategory.forKind(.mcb), .protection)
        XCTAssertEqual(ComponentCategory.forKind(.rcd), .protection)
        XCTAssertEqual(ComponentCategory.forKind(.lamp), .load)
        XCTAssertEqual(ComponentCategory.forKind(.motor), .load)
        XCTAssertEqual(ComponentCategory.forKind(.busbar), .auxiliary)
        XCTAssertEqual(ComponentCategory.forKind(.generator), .supply)
        XCTAssertEqual(ComponentCategory.forKind(.mainSwitch), .supply)
        XCTAssertEqual(ComponentCategory.forKind(.contactor), .control)
        XCTAssertEqual(ComponentCategory.forKind(.vfd), .control)
    }

    /// JSON-ში მითითებული category უნდა ემთხვეოდეს kind-ის ნაგულისხმევს.
    func testExplicitJSONCategoryMatchesKindDefault() throws {
        let templates = try GameData.loadTemplates()
        for (id, t) in templates {
            if let explicit = t.category {
                XCTAssertEqual(explicit, ComponentCategory.forKind(t.kind),
                               "\(id): JSON category ≠ kind-ის ნაგულისხმევი")
            }
        }
    }
}
