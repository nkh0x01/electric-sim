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

    /// დიაგნოსტიკა (fault-finding) მისაწვდომია და მისიის ბრიფინგი იხსნება.
    func testFaultFindingReachable() {
        let app = launchApp()
        let faults = app.buttons["menu-faults"]
        XCTAssertTrue(faults.waitForExistence(timeout: 20), "მენიუში უნდა იყოს დიაგნოსტიკა")
        faults.tap()
        // free მისიის გახსნა → ბრიფინგის „დაიწყე დიაგნოსტიკა“ ღილაკი.
        let mission = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "გადამეტებული ავტომატი")).firstMatch
        XCTAssertTrue(mission.waitForExistence(timeout: 10), "დიაგნოსტიკის სიაში უნდა ჩანდეს მისია")
        mission.tap()
        XCTAssertTrue(app.buttons["fault-start"].waitForExistence(timeout: 10),
                      "მისიის ბრიფინგზე უნდა იყოს „დაიწყე დიაგნოსტიკა“")
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
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10),
                      "ფარის ეკრანზე უნდა იყოს „შემოწმებაზე გაგზავნა“ ღილაკი")
        XCTAssertTrue(app.buttons["power-toggle"].exists, "უნდა იყოს კვების გადამრთველი")
    }

    /// solver-ის გაშვება UI-დან → შედეგის ფურცელი იხსნება.
    func testRunSimulationShowsResult() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        // ახალი ნაკადი: ჯერ ჩართე კვება, მერე გააგზავნე შემოწმებაზე.
        let power = app.buttons["power-toggle"]
        XCTAssertTrue(power.waitForExistence(timeout: 10))
        power.tap()
        let inspect = app.buttons["inspect"]
        XCTAssertTrue(inspect.waitForExistence(timeout: 10))
        inspect.tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10),
                      "ჩართულ ფარზე შემოწმება უნდა აჩვენებდეს შედეგის ფურცელს")
    }

    /// დონის ფარზე მოქმედების ღილაკები ეკრანზე ხილული/დაჭერადია — პალიტრამ არ
    /// უნდა გადასწიოს ისინი ეკრანს გარეთ (პალიტრის განლაგების რეგრესიის დაცვა).
    func testWorkbenchControlsStayOnScreen() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let inspect = app.buttons["inspect"]
        let power = app.buttons["power-toggle"]
        XCTAssertTrue(inspect.waitForExistence(timeout: 10))
        XCTAssertTrue(inspect.isHittable, "„შემოწმებაზე გაგზავნა“ ღილაკი ეკრანზე უნდა იყოს (პალიტრამ არ უნდა გადასწიოს)")
        XCTAssertTrue(power.isHittable, "კვების გადამრთველი ეკრანზე უნდა იყოს")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Workbench-palette-controls"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// მთავარი მენიუს „ფარის აწყობა" რეჟიმი მისაწვდომია და დონეები ჩანს.
    func testPanelAssemblyModeReachable() {
        let app = launchApp()
        let panels = app.buttons["menu-panels"]
        XCTAssertTrue(panels.waitForExistence(timeout: 20), "მთავარ მენიუში უნდა იყოს „ფარის აწყობა“")
        panels.tap()
        XCTAssertTrue(staticContaining(app, "მარტივი ერთფაზა ფარი").waitForExistence(timeout: 10),
                      "ფარის აწყობის სიაში უნდა ჩანდეს პირველი დონე")
    }

    /// ფარის-აწყობის დონეები Learn-ში აღარ დუბლირდება (ცალკე რეჟიმში გადავიდა).
    func testPanelLevelsNotDuplicatedInLearn() {
        let app = launchApp()
        openLearn(app)
        XCTAssertTrue(tutorialCell(app).waitForExistence(timeout: 10), "Learn-ში ჩანს გაკვეთილი")
        XCTAssertFalse(staticContaining(app, "მარტივი ერთფაზა ფარი").waitForExistence(timeout: 3),
                       "ფარის აწყობის დონე Learn-ში აღარ უნდა ჩანდეს")
    }

    /// ფარზე ჩანს არჩეული კაბელის ქართული სახელი (ხისტი/მრავალწვერა + კვეთა + აღნიშვნა).
    func testWorkbenchShowsGeorgianCableName() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let cable = app.staticTexts["cable-name"]
        XCTAssertTrue(cable.waitForExistence(timeout: 10), "ფარზე უნდა ჩანდეს ქართული კაბელის სახელი")
        XCTAssertTrue(cable.label.contains("კაბელი"), "სახელი ქართულ-პირველი უნდა იყოს („კაბელი“)")
    }

    /// staticText, რომელიც შეიცავს მოცემულ ქვესტრიქონს.
    private func staticContaining(_ app: XCUIApplication, _ substr: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", substr)).firstMatch
    }

    /// კვების გადამრთველი ცვლის მდგომარეობას (გამორთულია ↔ ცოცხალია). ნაგულისხმევი OFF.
    func testPowerToggleChangesState() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let power = app.buttons["power-toggle"]
        XCTAssertTrue(power.waitForExistence(timeout: 10))
        XCTAssertTrue(staticContaining(app, "უსაფრთხო").waitForExistence(timeout: 5),
                      "ნაგულისხმევად ფარი გამორთულია (უსაფრთხო რედაქტირება)")
        power.tap()
        XCTAssertTrue(staticContaining(app, "ცოცხალია").waitForExistence(timeout: 5),
                      "ჩართვის შემდეგ ფარი ცოცხალია")
    }

    /// შემოწმება ჯერ კვების ჩართვას მოითხოვს: გამორთულზე → შეტყობინება (არა შედეგი);
    /// ჩართვის შემდეგ → შედეგის ფურცელი.
    func testInspectionRequiresPowerOn() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let inspect = app.buttons["inspect"]
        XCTAssertTrue(inspect.waitForExistence(timeout: 10))
        // გამორთული კვება → ინსპექცია არ უნდა გაეშვას, ჩანს შეტყობინება
        inspect.tap()
        XCTAssertTrue(app.staticTexts["ჩართე კვება შემოწმებამდე"].waitForExistence(timeout: 5),
                      "გამორთულ ფარზე უნდა გამოჩნდეს „ჩართე კვება შემოწმებამდე“")
        XCTAssertFalse(app.staticTexts["შედეგი"].exists, "გამორთულზე შედეგი არ უნდა გამოჩნდეს")
        app.buttons["გასაგებია"].tap()
        // ჩართე კვება და გააგზავნე — ახლა შედეგი ჩანს
        app.buttons["power-toggle"].tap()
        inspect.tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10),
                      "ჩართულ ფარზე შემოწმება უნდა აჩვენებდეს შედეგს")
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

    /// მთავარი მენიუს ⚙️ → პარამეტრები → „შესახებ“ → ბრენდი gadget.ge.
    func testSettingsFromMainMenuOpensAbout() {
        let app = launchApp()
        let settings = app.buttons["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "მთავარ მენიუში უნდა იყოს პარამეტრები")
        settings.tap()
        let about = app.buttons["settings-about"]
        XCTAssertTrue(about.waitForExistence(timeout: 10), "პარამეტრებში უნდა იყოს „შესახებ“")
        about.tap()
        XCTAssertTrue(app.staticTexts["gadget.ge"].waitForExistence(timeout: 10),
                      "„შესახებ“ ეკრანზე უნდა ეწეროს gadget.ge")
    }

    /// მთავარი მენიუს „პარამეტრები“ რიგი (პირდაპირ სიაში) → SettingsView იხსნება.
    func testMainMenuSettingsRowOpensSettings() {
        let app = launchApp()
        let row = app.buttons["menu-settings"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "მთავარ მენიუში უნდა იყოს „პარამეტრები“ რიგი")
        row.tap()
        XCTAssertTrue(app.buttons["settings-about"].waitForExistence(timeout: 10),
                      "„პარამეტრები“ რიგმა უნდა გახსნას SettingsView")
    }

    /// მთავარი მენიუს „ჩვენ შესახებ“ რიგი (პირდაპირ სიაში) → About ეკრანი ბრენდითა
    /// და რეალური ლოგოებით (SF-სიმბოლო placeholder აღარ).
    func testMainMenuAboutRowShowsRealLogos() {
        let app = launchApp()
        let row = app.buttons["menu-about"]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "მთავარ მენიუში უნდა იყოს „ჩვენ შესახებ“ რიგი")
        row.tap()
        XCTAssertTrue(app.staticTexts["gadget.ge"].waitForExistence(timeout: 10),
                      "About ეკრანზე უნდა ეწეროს gadget.ge")
        // რეალური asset-ლოგოები უნდა დაიხატოს (Image("GadgetLogo")/Image("TsiliLogo")).
        XCTAssertTrue(app.images["about-logo-GadgetLogo"].waitForExistence(timeout: 5),
                      "Gadget-ის რეალური ლოგო უნდა დაიხატოს")
        XCTAssertTrue(app.images["about-logo-TsiliLogo"].exists,
                      "Tsili-ის რეალური ლოგო უნდა დაიხატოს")
        // ვიზუალური მტკიცებულება — ეკრანის სქრინშოტი დანართად.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "About-with-real-logos"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
