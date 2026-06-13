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

    /// ფოტო-რეალისტური მოდულების პილოტი: კარადის რელსზე ხელით ხატული მოდულები
    /// (კვება + მთავარი) გვერდით ფოტო-MCB×2 + ფოტო-RCD — მასშტაბის/რეალიზმის შესაფასებლად.
    func testPhotoModulePilotScreenshot() {
        let app = launchApp()
        app.buttons["menu-panels"].tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 15))
        // ხელით ხატული მთავარი (შესადარებლად), მერე ფოტო RCD + ორი ფოტო MCB
        openPaletteCard(app, header: "palette-cat-supply", card: "palette-card-main_2p").tap()
        openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-rcd_30").tap()
        let mcb = openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10")
        mcb.tap(); mcb.tap()
        XCTAssertTrue(app.otherElements["face-mcb_b10_2"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "PhotoModulePilot"; shot.lifetime = .keepAlways; add(shot)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    /// ფოტო-კლემის ინტერაქცია: სადენი ფოტოს კლემაში „შედის" (ორმაგი ხრახნის გარეშე),
    /// მოუჭერელი → მოჭერილი, და ბერკეტი ON→OFF. + screenshot-ები შესაფასებლად.
    func testPhotoTerminalInteractionScreenshots() {
        let app = launchApp()
        app.buttons["menu-panels"].tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 15)); row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 15))
        let mcb = openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10")
        mcb.tap(); mcb.tap()
        XCTAssertTrue(app.otherElements["face-mcb_b10_2"].waitForExistence(timeout: 5))

        // 1) სადენი → ფოტო-კლემაში (cable-in) — კლემა მოუჭერელ-შეერთებული ხდება
        dragWire(app, "term-supply.L", "term-mcb_b10_1.in")
        let inTerm = app.otherElements["term-mcb_b10_1.in"]
        let looseExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'მოსაჭერია'"), object: inTerm)
        XCTAssertEqual(XCTWaiter().wait(for: [looseExp], timeout: 10), .completed,
                       "სადენი ფოტო-კლემაში — მოუჭერელი")
        shot(app, "PhotoTerminal-CableIn-Loose")

        // 2) მოჭერა — tighten-all ღილაკი (req #3). ღია აკორდეონი ჯერ ვკეცოთ, რომ ღილაკი ჩანდეს.
        app.buttons["palette-cat-protection"].tap()
        let tightenAll = app.buttons["tighten-all"]
        XCTAssertTrue(tightenAll.waitForExistence(timeout: 8), "მოუჭერელ სადენზე მოჭერის ღილაკი ჩანს")
        tightenAll.tap()
        // მოჭერის დადასტურება: მოჭერის ღილაკი ქრება (აღარაა მოუჭერელი სადენი)
        let goneExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: tightenAll)
        XCTAssertEqual(XCTWaiter().wait(for: [goneExp], timeout: 10), .completed,
                       "მოჭერის შემდეგ ღილაკი ქრება")
        shot(app, "PhotoTerminal-Tightened")

        // 3) ბერკეტი ON→OFF (მე-2 ავტომატი) — dim + ქვედა ბერკეტი
        let lever = app.otherElements["lever-mcb_b10_2"]
        XCTAssertTrue(lever.waitForExistence(timeout: 5), "ფოტო-ბერკეტი უნდა იყოს")
        XCTAssertEqual(lever.label, "ჩართული ბერკეტი")
        lever.tap()
        let offExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'გამორთული ბერკეტი'"), object: lever)
        XCTAssertEqual(XCTWaiter().wait(for: [offExp], timeout: 5), .completed, "ბერკეტი გამოირთო")
        shot(app, "PhotoLever-Off")
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

    /// პირველი ფარის-აწყობის დონეს აქვს კომპონენტების პალიტრა (main switch, MCB და ა.შ.).
    /// აკორდეონის გამო ჯერ კატეგორიის სათაურს ვხსნით, შემდეგ ვამოწმებთ ბარათებს.
    func testPanelFirstLevelHasComponentPalette() {
        let app = launchApp()
        let panels = app.buttons["menu-panels"]
        XCTAssertTrue(panels.waitForExistence(timeout: 20))
        panels.tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10), "ფარის ეკრანი უნდა გაიხსნას")
        // კვება-წყაროს კატეგორია → მთავარი ამომრთველის ბარათი
        let supply = app.buttons["palette-cat-supply"]
        XCTAssertTrue(supply.waitForExistence(timeout: 5), "პალიტრაში უნდა იყოს კვება-წყაროს სათაური")
        supply.tap()
        XCTAssertTrue(staticContaining(app, "მთავარი ამომრთველი 2P").waitForExistence(timeout: 5),
                      "გახსნილ კატეგორიაში უნდა იყოს მთავარი ამომრთველი")
        // დამცავების კატეგორია → MCB ბარათი
        let protection = app.buttons["palette-cat-protection"]
        XCTAssertTrue(protection.exists, "პალიტრაში უნდა იყოს დამცავების სათაური")
        protection.tap()
        XCTAssertTrue(staticContaining(app, "ავტომატი (MCB)").waitForExistence(timeout: 5),
                      "გახსნილ კატეგორიაში უნდა იყოს ავტომატი (MCB)")
        XCTAssertTrue(app.buttons["inspect"].isHittable, "ქვედა ღილაკები ეკრანზე უნდა დარჩეს")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Panel-basic-workbench"; shot.lifetime = .keepAlways; add(shot)
    }

    /// პალიტრის აკორდეონი: სათაურები ჩანს; საწყისად გახსნილია მიზნის კატეგორია
    /// (ნათურა → დატვირთვა); მეორის გახსნა წინას კეტავს; ხელახლა შეხება — კეტავს.
    func testPaletteAccordionOneCategoryAtATime() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let protection = app.buttons["palette-cat-protection"]
        let load = app.buttons["palette-cat-load"]
        XCTAssertTrue(protection.waitForExistence(timeout: 10), "უნდა იყოს დამცავების სათაური")
        XCTAssertTrue(load.exists, "უნდა იყოს დატვირთვის სათაური")
        XCTAssertTrue(app.buttons["palette-cat-supply"].exists, "უნდა იყოს კვება-წყაროს სათაური")
        // საწყისად გახსნილია მიზნის (ნათურა → დატვირთვა) კატეგორია; დამცავები დახურულია.
        XCTAssertTrue(staticContaining(app, "ნათურა 60W").waitForExistence(timeout: 5),
                      "საწყისად დატვირთვის კატეგორია უნდა იყოს გახსნილი")
        XCTAssertFalse(staticContaining(app, "ავტომატი (MCB)").exists,
                       "დამცავები საწყისად დახურული უნდა იყოს")
        // დამცავების გახსნა → MCB ჩანს, დატვირთვა (აკორდეონი) იკეტება.
        protection.tap()
        XCTAssertTrue(staticContaining(app, "ავტომატი (MCB)").waitForExistence(timeout: 5),
                      "გახსნისას MCB ბარათი უნდა გამოჩნდეს")
        waitGone(staticContaining(app, "ნათურა 60W"),
                 "აკორდეონი — ერთდროულად მხოლოდ ერთი კატეგორიაა გახსნილი")
        // ხელახლა შეხება კეტავს.
        protection.tap()
        waitGone(staticContaining(app, "ავტომატი (MCB)"),
                 "ხელახლა შეხებამ კატეგორია უნდა დაკეტოს")
    }

    /// ფარის-აწყობის დონეზე პალიტრიდან დამატებული DIN-მოდულები რელსზე ჯდება —
    /// კლემები (terminals) ჩანს და მისამართებადია.
    func testPanelModulesMountOnRail() {
        let app = launchApp()
        let panels = app.buttons["menu-panels"]
        XCTAssertTrue(panels.waitForExistence(timeout: 20))
        panels.tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        // მთავარი ამომრთველი + 2 ავტომატი + N/PE სალტეები პალიტრიდან
        app.buttons["palette-cat-supply"].tap()
        app.buttons["palette-card-main_2p"].tap()
        app.buttons["palette-cat-protection"].tap()
        let mcb = app.buttons["palette-card-mcb_b10"]
        mcb.tap(); mcb.tap()
        app.buttons["palette-cat-auxiliary"].tap()
        app.buttons["palette-card-busbar_n"].tap()
        app.buttons["palette-card-busbar_pe"].tap()
        // მოდულები რელსზეა — კლემები არსებობს
        XCTAssertTrue(app.otherElements["term-main_2p_1.Lin"].waitForExistence(timeout: 5),
                      "მთავარი ამომრთველის კლემა უნდა ჩანდეს რელსზე")
        XCTAssertTrue(app.otherElements["term-mcb_b10_2.in"].exists, "მეორე MCB-ის კლემა")
        XCTAssertTrue(app.otherElements["term-busbar_pe_1.0"].exists, "PE-სალტის კლემა")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Panel-DIN-modules"; shot.lifetime = .keepAlways; add(shot)
    }

    /// სადენის შეერთება → კლემა მოუჭერელია → ინსპექცია იძლევა მოჭერის შეცდომას;
    /// long-press კლემაზე ჭერს (screw-down) და შეცდომა ქრება.
    func testWireTightenInteractionAndInspection() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        // პალიტრიდან MCB (აკორდეონი: იდემპოტენტური გახსნა)
        openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10").tap()
        // სადენი: კვების L → MCB-ის შესასვლელი (drag; ნაგულისხმევი ხელსაწყო „სადენი")
        let to = app.otherElements["term-mcb_b10_1.in"]
        dragWire(app, "term-supply.L", "term-mcb_b10_1.in")
        // ახალი შეერთება მოუჭერელია
        let loose = NSPredicate(format: "value == 'მოსაჭერია'")
        let looseExp = XCTNSPredicateExpectation(predicate: loose, object: to)
        XCTAssertEqual(XCTWaiter().wait(for: [looseExp], timeout: 5), .completed,
                       "ახალი შეერთება მოუჭერელი უნდა იყოს")
        // ნაკლული ჭერა (0.2წმ < 0.45წმ) — ხრახნი უკან ბრუნდება, კვლავ მოსაჭერია
        to.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.2)
        XCTAssertEqual(to.value as? String, "მოსაჭერია",
                       "ადრე აშვებაზე კლემა მოუჭერელი უნდა დარჩეს (პროგრესული მოჭერა)")
        // ინსპექცია (კვება ჩართული) → მოჭერის შეცდომა ჩანს
        app.buttons["power-toggle"].tap()
        app.buttons["inspect"].tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10))
        XCTAssertTrue(staticContaining(app, "არ არის მოჭერილი").waitForExistence(timeout: 5),
                      "მოუჭერელ კლემაზე ინსპექციამ უნდა იჩივლოს")
        app.buttons["დახურვა"].tap()
        // long-press კლემაზე (~0.4წმ+) → მოჭერა
        to.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 0.8)
        let tight = NSPredicate(format: "value == 'მოჭერილია'")
        let tightExp = XCTNSPredicateExpectation(predicate: tight, object: to)
        XCTAssertEqual(XCTWaiter().wait(for: [tightExp], timeout: 5), .completed,
                       "long-press-მა კლემა უნდა მოჭიროს")
        // ხელახალი ინსპექცია → მოჭერის შეცდომა აღარ არის
        app.buttons["inspect"].tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10))
        XCTAssertFalse(staticContaining(app, "არ არის მოჭერილი").exists,
                       "მოჭერის შემდეგ ინსპექციაში მოჭერის შეცდომა აღარ უნდა იყოს")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Tighten-interaction"; shot.lifetime = .keepAlways; add(shot)
    }

    /// კლემიდან კლემამდე სადენის გავლება — ნელი, გამოკვეთილი drag-ით, რომ ძველ/ნელ
    /// CI-სიმულატორებზეც (iOS 17.x) საიმედოდ იცნოს ფარის ჟესტმა.
    private func dragWire(_ app: XCUIApplication, _ fromID: String, _ toID: String) {
        let from = app.otherElements[fromID]
        let to = app.otherElements[toID]
        XCTAssertTrue(from.waitForExistence(timeout: 10), "კლემა \(fromID) უნდა არსებობდეს")
        XCTAssertTrue(to.waitForExistence(timeout: 10), "კლემა \(toID) უნდა არსებობდეს")
        let start = from.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = to.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.15, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// პალიტრის ბარათის გახსნა იდემპოტენტურად: თუ ბარათი უკვე ჩანს, header-ს არ
    /// ვეხებით; თუ header-ის შეხებამ ღია კატეგორია დაკეტა (აკორდეონი) ან ანიმაცია
    /// ნელია — კიდევ ერთხელ ვცდილობთ, დიდი მოთმინებით (CI-ის ნელი სიმულატორები).
    @discardableResult
    private func openPaletteCard(_ app: XCUIApplication, header: String, card: String) -> XCUIElement {
        let cardEl = app.buttons[card]
        if cardEl.waitForExistence(timeout: 1.5), cardEl.isHittable { return cardEl }
        let headerEl = app.buttons[header]
        XCTAssertTrue(headerEl.waitForExistence(timeout: 10), "პალიტრის სათაური \(header)")
        headerEl.tap()
        if !cardEl.waitForExistence(timeout: 8) {
            // პირველმა შეხებამ უკვე ღია კატეგორია დაკეტა — ხელახლა გავხსნათ.
            headerEl.tap()
            XCTAssertTrue(cardEl.waitForExistence(timeout: 8),
                          "ბარათი \(card) ვერ გამოჩნდა (\(header))")
        }
        return cardEl
    }

    /// პირველი გაკვეთილის სრული აწყობა UI-დან: MCB + ნათურა + 4 სადენი + მოჭერა.
    /// აბრუნებს მზად ფარს ინსპექციისთვის (კვება ჯერ გამორთულია).
    private func buildTutorialCircuit(_ app: XCUIApplication) {
        // ჯერ ნათურა: load კატეგორია საწყისად გახსნილია (მიზნის კატეგორია) — header-ის
        // შეხება საერთოდ არ გვჭირდება; შემდეგ დამცავები (პირველი, ყოველთვის ხილული header).
        openPaletteCard(app, header: "palette-cat-load", card: "palette-card-lamp_60").tap()
        openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10").tap()
        dragWire(app, "term-supply.L", "term-mcb_b10_1.in")
        dragWire(app, "term-mcb_b10_1.out", "term-lamp_60_1.L")
        dragWire(app, "term-supply.N", "term-lamp_60_1.N")
        dragWire(app, "term-supply.PE", "term-lamp_60_1.PE")
        // „ყველას მოჭერა" მხოლოდ მოუჭერელ (ახალ) სადენებზე ჩანს — სადენების შექმნის დასტურიც.
        let tighten = app.buttons["tighten-all"]
        XCTAssertTrue(tighten.waitForExistence(timeout: 10),
                      "სადენების შემდეგ უნდა გამოჩნდეს მოჭერის ღილაკი (drag-ებმა იმუშავა?)")
        tighten.tap()
    }

    /// ფარი-პირველი განლაგება: ფარის ზონა ეკრანის ≥45%-ია (ბრიფი ჩაკეცილი).
    func testBoardGetsMajorityOfScreen() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        // პირველი ნახვისას ბრიფი გაშლილია — ჩავკეცოთ ნორმალურ მდგომარეობამდე.
        let toggle = app.buttons["brief-toggle"]
        if toggle.waitForExistence(timeout: 5), toggle.label.contains("ნაკლები") { toggle.tap() }
        let rail = app.otherElements["board-rail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5), "ფარის ზონა უნდა არსებობდეს")
        let ratio = rail.frame.height / app.frame.height
        XCTAssertGreaterThanOrEqual(ratio, 0.45,
                                    "ფარი ეკრანის ≥45%% უნდა იყოს (ახლა: \(ratio))")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Board-first-normal"; shot.lifetime = .keepAlways; add(shot)
    }

    /// ფოკუს-რეჟიმი: ⤢ შესვლა → მცურავი პალიტრიდან კომპონენტის დადება → გამოსვლა.
    func testFocusModePlaceComponentAndExit() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        let focus = app.buttons["focus-toggle"]
        XCTAssertTrue(focus.waitForExistence(timeout: 10), "ფარზე უნდა იყოს ⤢ ღილაკი")
        focus.tap()
        // კონტროლები დამალულია, მცურავი ზოლი ჩანს
        XCTAssertTrue(app.buttons["focus-palette"].waitForExistence(timeout: 5),
                      "ფოკუსში უნდა ჩანდეს მცურავი ზოლი")
        XCTAssertFalse(app.buttons["brief-toggle"].exists, "ფოკუსში ბრიფი დამალულია")
        // პალიტრის ფურცელი → კომპონენტი დაჯდა → ფურცელი დაიხურა
        app.buttons["focus-palette"].tap()
        let card = app.buttons["palette-card-mcb_b10"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "ფოკუს-პალიტრაში უნდა იყოს MCB")
        card.tap()
        XCTAssertTrue(app.otherElements["term-mcb_b10_1.in"].waitForExistence(timeout: 5),
                      "კომპონენტი ფარზე უნდა დაჯდეს")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Focus-mode"; shot.lifetime = .keepAlways; add(shot)
        // ახლო ხედი — მოდულის დეტალები (ბერკეტი, ხრახნები, იარლიყი) ფოკუს-რეჟიმში
        app.buttons["plus.magnifyingglass"].tap()
        app.buttons["plus.magnifyingglass"].tap()
        let closeup = XCTAttachment(screenshot: app.screenshot())
        closeup.name = "Focus-module-closeup"; closeup.lifetime = .keepAlways; add(closeup)
        // გამოსვლა — ჩვეულებრივი კონტროლები ბრუნდება
        app.buttons["focus-toggle"].tap()
        XCTAssertTrue(app.buttons["brief-toggle"].waitForExistence(timeout: 5),
                      "ფოკუსიდან გამოსვლის შემდეგ ბრიფი ბრუნდება")
    }

    /// კარადა ფიქსირებული რელსებით: ფარის-აწყობის დონეზე ორივე რელსი იხატება
    /// (ცარიელიც), დატვირთვები კი ქვედა ზოლში.
    func testCabinetRendersFixedRails() {
        let app = launchApp()
        app.buttons["menu-panels"].tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["rail-0"].waitForExistence(timeout: 5), "რელსი 1 უნდა ჩანდეს")
        XCTAssertTrue(app.otherElements["rail-1"].exists, "ცარიელი რელსი 2-იც ფიქსირებულია")
        // დატვირთვა → ქვედა ზოლი ჩნდება
        openPaletteCard(app, header: "palette-cat-load", card: "palette-card-lamp_60").tap()
        XCTAssertTrue(app.otherElements["load-strip"].waitForExistence(timeout: 5),
                      "დატვირთვების ზოლი კარადის ძირში")
    }

    /// რეგრესია (user-reported): მოდულის გადათრევა ქვედა (თუნდაც ცარიელ) რელსზე
    /// მართლა იქ სვამს მას.
    func testDragModuleToLowerRail() {
        let app = launchApp()
        app.buttons["menu-panels"].tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        // MCB რელს 1-ზე (ზემოდან ივსება)
        openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10").tap()
        let face = app.otherElements["face-mcb_b10_1"]
        XCTAssertTrue(face.waitForExistence(timeout: 5))
        let beforeY = face.frame.midY
        // გადათრევა მოძრაობის რეჟიმში (არა-სადენის ხელსაწყო) ცარიელ რელს 2-ზე
        app.buttons["მულტიმეტრი"].tap()
        let rail1 = app.otherElements["rail-1"]
        XCTAssertTrue(rail1.exists)
        face.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.15,
                   thenDragTo: rail1.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
        let landed = NSPredicate { _, _ in face.frame.midY > beforeY + 50 }
        let exp = XCTNSPredicateExpectation(predicate: landed, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 6), .completed,
                       "MCB ქვედა რელსზე უნდა ჩამოჯდეს (იყო y=\(beforeY), არის y=\(face.frame.midY))")
    }

    /// სავარცხელი სალტე ჯდება ორ მომიჯნავე ავტომატზე — ვიზუალი ჩნდება ფარზე.
    func testCombSeatsAcrossBreakers() {
        let app = launchApp()
        app.buttons["menu-panels"].tap()
        let row = app.buttons["panel-lvl_panel_basic"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        // ორი ავტომატი ერთ რელსზე
        let mcb = openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10")
        mcb.tap(); mcb.tap()
        XCTAssertTrue(app.otherElements["face-mcb_b10_2"].waitForExistence(timeout: 5))
        // სავარცხელი — დამხმარეების კატეგორიიდან
        openPaletteCard(app, header: "palette-cat-auxiliary", card: "palette-card-comb_1p").tap()
        XCTAssertTrue(app.otherElements["comb-comb_1p_1"].waitForExistence(timeout: 5),
                      "სავარცხელი უნდა ჩაჯდეს ავტომატებზე")
        // მომხმარებლის სადენების მთვლელი არ გაიზარდა (კბილები ავტო-კავშირებია)
        XCTAssertTrue(app.buttons["wires-list"].label.contains("0"),
                      "comb-ის კბილები მომხმარებლის სადენებში არ ითვლება")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Comb-seated"; shot.lifetime = .keepAlways; add(shot)
    }

    /// მრავალწვერა სადენი + ბუნიკი: sleeve ჩანს კლემის ჭდეზე (ვიზუალური დასტური).
    func testFerruleSleeveVisible() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        // მრავალწვერა კაბელი (სეგმენტი ჩანს, რადგან სადენის ხელსაწყო აქტიურია)
        let stranded = app.buttons["Stranded"]
        XCTAssertTrue(stranded.waitForExistence(timeout: 8), "კაბელის ტიპის სეგმენტი უნდა ჩანდეს")
        stranded.tap()
        // MCB + სადენი
        openPaletteCard(app, header: "palette-cat-protection", card: "palette-card-mcb_b10").tap()
        dragWire(app, "term-supply.L", "term-mcb_b10_1.in")
        // სინქრონიზაცია: სადენი მართლა შეიქმნა (კლემა მოუჭერელ-შეერთებულია)
        let inTerm = app.otherElements["term-mcb_b10_1.in"]
        let wiredExp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'მოსაჭერია'"), object: inTerm)
        XCTAssertEqual(XCTWaiter().wait(for: [wiredExp], timeout: 8), .completed,
                       "drag-მა სადენი უნდა შექმნას")
        // ბუნიკის დადება სადენების სიიდან — ტოგლის ტიპის ექსპოზიცია OS-ზეა
        // დამოკიდებული (switch/other), ამიტომ ნებისმიერი ტიპით ვეძებთ და
        // გადამრთველის (trailing) ზონაში ვეხებით.
        // კლასტერის შეკუმშვა: ღია კატეგორიის დაკეტვა (ზედა header ყოველთვის ხილულია),
        // რომ ქვედა wire-ხელსაწყოების რიგი ძველ მეტრიკებზეც ჩარჩოში მოექცეს.
        app.buttons["palette-cat-protection"].tap()
        let wiresBtn = app.buttons["wires-list"]
        XCTAssertTrue(wiresBtn.waitForExistence(timeout: 8))
        wiresBtn.tap()
        if !app.navigationBars["სადენები"].waitForExistence(timeout: 5) {
            wiresBtn.tap()   // ნელ რანერზე პირველი შეხება შეიძლება დაიკარგოს
            XCTAssertTrue(app.navigationBars["სადენები"].waitForExistence(timeout: 6),
                          "სადენების სია უნდა გაიხსნას")
        }
        // identifier-ის გავრცელება Toggle-ზე OS-ვერსიაზეა დამოკიდებული — ჯერ id-ით,
        // ვერადა ტიპით (ფურცელზე ერთადერთი ტოგლია).
        var ferrule = app.descendants(matching: .any)
            .matching(identifier: "ferrule-toggle").firstMatch
        if !ferrule.waitForExistence(timeout: 4) {
            ferrule = app.switches.firstMatch
        }
        XCTAssertTrue(ferrule.waitForExistence(timeout: 6), "მრავალწვერა სადენს უნდა ჰქონდეს ბუნიკის ტოგლი")
        ferrule.tap()
        app.buttons["დახურვა"].tap()
        // ახლო ხედი sleeve-ით
        XCTAssertTrue(app.buttons["plus.magnifyingglass"].waitForExistence(timeout: 8))
        app.buttons["plus.magnifyingglass"].tap()
        app.buttons["plus.magnifyingglass"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Ferrule-sleeve-closeup"; shot.lifetime = .keepAlways; add(shot)
        // მოჭერის შემდეგ — ჩასმული (flush) ხრახნის ახლო ხედი
        let tightenAll = app.buttons["tighten-all"]
        XCTAssertTrue(tightenAll.waitForExistence(timeout: 8), "მოუჭერელ სადენზე მოჭერის ღილაკი ჩანს")
        tightenAll.tap()
        let tightShot = XCTAttachment(screenshot: app.screenshot())
        tightShot.name = "Tightened-screw-closeup"; tightShot.lifetime = .keepAlways; add(tightShot)
    }

    /// კვების ჩართვაზე მუშა ნათურა ანათებს (ინსპექციის გარეშეც) — accessibility state.
    func testLampGlowsAfterPowerOn() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        buildTutorialCircuit(app)
        let face = app.otherElements["face-lamp_60_1"]
        XCTAssertTrue(face.waitForExistence(timeout: 8))
        XCTAssertEqual(face.value as? String, "გამორთულია", "კვებამდე ნათურა არ ანათებს")
        app.buttons["power-toggle"].tap()
        let lit = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == 'ანთია'"), object: face)
        XCTAssertEqual(XCTWaiter().wait(for: [lit], timeout: 8), .completed,
                       "კვების ჩართვაზე მუშა ნათურა უნდა აანთდეს")
    }

    /// რეგრესია: დონის დასრულების შემდეგ „შემდეგი დონე" რეალურად ხსნის შემდეგ დონეს.
    func testNextLevelNavigatesAfterCompletion() {
        let app = launchApp()
        openLearn(app)
        let tutorial = tutorialCell(app)
        XCTAssertTrue(tutorial.waitForExistence(timeout: 10))
        tutorial.tap()
        XCTAssertTrue(app.buttons["inspect"].waitForExistence(timeout: 10))
        buildTutorialCircuit(app)
        app.buttons["power-toggle"].tap()
        app.buttons["inspect"].tap()
        XCTAssertTrue(app.staticTexts["შედეგი"].waitForExistence(timeout: 10))
        XCTAssertTrue(staticContaining(app, "დონე დასრულდა").waitForExistence(timeout: 5),
                      "სწორი წრედით დონე უნდა ჩაითვალოს")
        let next = app.buttons["result-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "უნდა იყოს „შემდეგი დონე“ ღილაკი")
        next.tap()
        // შემდეგი დონის ფარი უნდა გაიხსნას (nav title: „გაკვეთილი 2 — როზეტი RCD-ით")
        let nextTitle = app.navigationBars.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "გაკვეთილი 2")).firstMatch
        XCTAssertTrue(nextTitle.waitForExistence(timeout: 10),
                      "„შემდეგი დონე“-მ უნდა გახსნას მე-2 გაკვეთილის ფარი")
    }

    /// ელოდება ელემენტის გაქრობას (ანიმაციის დასრულებას).
    private func waitGone(_ element: XCUIElement, _ message: String) {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                            object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 5), .completed, message)
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
