//
//  LocalizationTests.swift
//  ElectricSimTests
//
//  იცავს, რომ კომპონენტების სახელები ქართულია (არ იწყება ლათინურით; სტანდარტული
//  აბრევიატურები ფრჩხილებში დასაშვებია).
//

import XCTest
@testable import ElectricSimCore

final class LocalizationTests: XCTestCase {

    /// კომპონენტის template-სახელი არ უნდა იწყებოდეს ლათინური ასოთი (ქართული-პირველი).
    func testComponentTemplateNamesGeorgianFirst() throws {
        let templates = try GameData.loadTemplates()
        for (id, t) in templates {
            XCTAssertNil(t.name.range(of: "^[A-Za-z]", options: .regularExpression),
                         "\(id): სახელი იწყება ინგლისურით — „\(t.name)“")
        }
    }

    /// ComponentKind-ის ცალხაზოვანი-ნახაზის სათაური ქართული-პირველი უნდა იყოს.
    func testComponentKindTitlesGeorgianFirst() {
        for kind in ComponentKind.allCases {
            let title = kind.georgianTitle
            XCTAssertNil(title.range(of: "^[A-Za-z]", options: .regularExpression),
                         "\(kind): georgianTitle იწყება ინგლისურით — „\(title)“")
        }
    }

    /// საკვანძო თარგმანები (აბრევიატურები ფრჩხილებში შენარჩუნებულია).
    func testKeyComponentTranslations() {
        XCTAssertTrue(ComponentKind.mcb.georgianTitle.contains("ავტომატი"))
        XCTAssertTrue(ComponentKind.rcd.georgianTitle.contains("დიფ"))
        XCTAssertTrue(ComponentKind.rcd.georgianTitle.contains("RCD"))
        XCTAssertTrue(ComponentKind.busbar.georgianTitle.contains("შინა"))
        XCTAssertTrue(ComponentKind.motor.georgianTitle.contains("ძრავა"))
        XCTAssertTrue(ComponentKind.spd.georgianTitle.contains("ზეძაბვის"))
        XCTAssertTrue(ComponentKind.mainSwitch.georgianTitle.contains("მთავარი"))
    }
}
