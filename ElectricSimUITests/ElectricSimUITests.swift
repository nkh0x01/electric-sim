//
//  ElectricSimUITests.swift
//  ElectricSimUITests
//
//  XCUITest — ნამდვილ აპს უშვებს სიმულატორზე და ამოწმებს ეკრანზე ქცევას:
//  ნავიგაცია, solver-ის გაშვება UI-დან, შედეგის ფურცელი, ბრენდი.
//

import XCTest

final class ElectricSimUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    /// პირველი დონის უჯრა (ზუსტი ტირეს მაგივრად — ქვესტრიქონით).
    private func tutorialCell(_ app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", "პირველი ნათურა")
        return app.staticTexts.matching(predicate).firstMatch
    }

    /// აპი ეშვება და დონეების სია ჩანს.
    func testLaunchShowsLevelList() {
        let app = launchApp()
        XCTAssertTrue(tutorialCell(app).waitForExistence(timeout: 20),
                      "გაშვებისას უნდა გამოჩნდეს პირველი დონე")
    }

    /// დონეში შესვლა → ფარის ეკრანის მთავარი ღილაკები ჩანს.
    func testOpenLevelShowsWorkbench() {
        let app = launchApp()
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 20))
        tutorial.tap()

        XCTAssertTrue(app.buttons["power-on"].waitForExistence(timeout: 10),
                      "ფარის ეკრანზე უნდა იყოს „ჩართე ძაბვა“ ღილაკი")
        XCTAssertTrue(app.buttons["check"].exists, "უნდა იყოს „შემოწმება“ ღილაკი")
    }

    /// solver-ის გაშვება UI-დან → შედეგის ფურცელი იხსნება.
    func testRunSimulationShowsResult() {
        let app = launchApp()
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 20))
        tutorial.tap()

        let check = app.buttons["check"]
        XCTAssertTrue(check.waitForExistence(timeout: 10))
        check.tap()

        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10),
                      "შემოწმების შემდეგ უნდა გამოჩნდეს შედეგის ფურცელი")
    }

    /// „შესახებ“ ეკრანი იხსნება და ბრენდი (gadget.ge) ჩანს.
    func testAboutScreenShowsBranding() {
        let app = launchApp()
        let about = app.buttons["about"]
        XCTAssertTrue(about.waitForExistence(timeout: 20))
        about.tap()

        XCTAssertTrue(app.staticTexts["gadget.ge"].waitForExistence(timeout: 10),
                      "„შესახებ“ ეკრანზე უნდა ეწეროს gadget.ge")
    }
}
