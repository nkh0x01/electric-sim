//
//  ElectricSimUITests.swift
//  ElectricSimUITests
//
//  XCUITest — ნამდვილ აპს უშვებს სიმულატორზე და ამოწმებს ეკრანზე ქცევას:
//  მთავარი მენიუ (3 რეჟიმი), ნავიგაცია, solver UI-დან, შედეგი, ბრენდი.
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

    /// მთავარ მენიუში „სწავლება“-ს გახსნა.
    private func openLearn(_ app: XCUIApplication) {
        let learn = app.buttons["menu-learn"]
        XCTAssertTrue(learn.waitForExistence(timeout: 20), "მენიუში უნდა იყოს „სწავლება“")
        learn.tap()
    }

    private func tutorialCell(_ app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", "პირველი ნათურა")
        return app.staticTexts.matching(predicate).firstMatch
    }

    /// გაშვებისას ჩანს სამი რეჟიმი (Learn / Career / Sandbox).
    func testLaunchShowsThreeModes() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["menu-learn"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["menu-career"].exists, "უნდა იყოს კარიერა")
        XCTAssertTrue(app.buttons["menu-sandbox"].exists, "უნდა იყოს Sandbox")
    }

    /// Career რეჟიმი მისაწვდომია და სამუშაოს დაფა ჩანს.
    func testCareerBoardReachable() {
        let app = launchApp()
        let career = app.buttons["menu-career"]
        XCTAssertTrue(career.waitForExistence(timeout: 20))
        career.tap()
        let job = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ნათურის მონტაჟი")).firstMatch
        XCTAssertTrue(job.waitForExistence(timeout: 10), "კარიერის დაფაზე უნდა ჩანდეს სამუშაო")
    }

    /// Sandbox რეჟიმი მისაწვდომია.
    func testSandboxReachable() {
        let app = launchApp()
        let sandbox = app.buttons["menu-sandbox"]
        XCTAssertTrue(sandbox.waitForExistence(timeout: 20))
        sandbox.tap()
        XCTAssertTrue(app.navigationBars["Sandbox"].waitForExistence(timeout: 10),
                      "Sandbox ეკრანი უნდა გაიხსნას")
    }

    /// სწავლება → დონეების სია ჩანს.
    func testLearnShowsLevelList() {
        let app = launchApp()
        openLearn(app)
        XCTAssertTrue(tutorialCell(app).waitForExistence(timeout: 10),
                      "სწავლებაში უნდა გამოჩნდეს პირველი დონე")
    }

    /// დონეში შესვლა → ფარის ეკრანის მთავარი ღილაკები ჩანს.
    func testOpenLevelShowsWorkbench() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        XCTAssertTrue(app.buttons["power-on"].waitForExistence(timeout: 10),
                      "ფარის ეკრანზე უნდა იყოს „ჩართე ძაბვა“ ღილაკი")
        XCTAssertTrue(app.buttons["check"].exists, "უნდა იყოს „შემოწმება“ ღილაკი")
    }

    /// solver-ის გაშვება UI-დან → შედეგის ფურცელი იხსნება.
    func testRunSimulationShowsResult() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let check = app.buttons["check"]
        XCTAssertTrue(check.waitForExistence(timeout: 10))
        check.tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10),
                      "შემოწმების შემდეგ უნდა გამოჩნდეს შედეგის ფურცელი")
    }

    /// „შესახებ“ ეკრანი (სწავლების toolbar-ში) → ბრენდი gadget.ge.
    func testAboutScreenShowsBranding() {
        let app = launchApp()
        openLearn(app)
        let about = app.buttons["about"]
        XCTAssertTrue(about.waitForExistence(timeout: 10))
        about.tap()
        XCTAssertTrue(app.staticTexts["gadget.ge"].waitForExistence(timeout: 10),
                      "„შესახებ“ ეკრანზე უნდა ეწეროს gadget.ge")
    }
}
