//
//  CareerTests.swift
//  ElectricSimTests
//
//  Career Mode — Phase 1 (data model + persistence) ტესტები.
//

import XCTest
@testable import ElectricSimCore

final class CareerTests: XCTestCase {

    /// სუფთა, იზოლირებული UserDefaults თითო ტესტისთვის.
    private func freshDefaults() -> UserDefaults {
        let name = "career.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func sampleJob(id: String = "job_x", tier: LevelTier = .free,
                           xp: Int = 50, cash: Int = 40,
                           unlocks: [String] = []) -> Job {
        Job(id: id, georgianTitle: "ტესტ-სამუშაო", customerName: "ტესტი",
            location: "თბილისი", category: .tutorial, difficulty: 1, tier: tier,
            jobBrief: "ტესტი", componentsAvailable: ["main_2p", "mcb_b10", "lamp_60"],
            requiredComponents: ["main_2p", "mcb_b10", "lamp_60"],
            xpReward: xp, cashReward: cash, unlocks: unlocks,
            goal: LevelGoal(poweredLoads: ["lamp": 1], description: "ტესტი", requireBalanced: nil))
    }

    // 1) დასრულება ანიჭებს XP-სა და cash-ს
    func testCompletingJobAwardsXPAndCash() {
        let s = CareerState(defaults: freshDefaults())
        let xp0 = s.totalXP, cash0 = s.cash
        let awarded = s.completeJob(sampleJob(xp: 50, cash: 40))
        XCTAssertTrue(awarded)
        XCTAssertEqual(s.totalXP, xp0 + 50)
        XCTAssertEqual(s.cash, cash0 + 40)
    }

    // 2) დასრულება ინახავს id-ს completedJobs-ში
    func testCompletingJobStoresID() {
        let s = CareerState(defaults: freshDefaults())
        XCTAssertFalse(s.isCompleted("job_x"))
        s.completeJob(sampleJob(id: "job_x"))
        XCTAssertTrue(s.isCompleted("job_x"))
        XCTAssertTrue(s.completedJobs.contains("job_x"))
    }

    // 3) ერთი და იგივე სამუშაოს ორჯერ დასრულება არ ადუბლირებს XP/cash-ს
    func testCompletingTwiceDoesNotDuplicate() {
        let s = CareerState(defaults: freshDefaults())
        let job = sampleJob(id: "job_dup", xp: 70, cash: 70)
        XCTAssertTrue(s.completeJob(job))
        let xpAfterFirst = s.totalXP, cashAfterFirst = s.cash
        let second = s.completeJob(job)          // ხელახლა
        XCTAssertFalse(second, "მეორედ დასრულება ჯილდოს არ უნდა გასცეს")
        XCTAssertEqual(s.totalXP, xpAfterFirst)
        XCTAssertEqual(s.cash, cashAfterFirst)
    }

    // 3b) Live-wire შოკის ჯარიმა — აკლებს cash-ს თითო შოკზე, floor 0.
    func testShockPenaltyDeductsCashFloorZero() {
        let s = CareerState(defaults: freshDefaults())
        s.completeJob(sampleJob(id: "paid", xp: 0, cash: 100))   // cash = 100
        XCTAssertEqual(s.cash, 100)
        XCTAssertEqual(s.penalizeShock(10), 10)                  // ერთი შოკი → -10
        XCTAssertEqual(s.cash, 90)
        XCTAssertEqual(s.penalizeShock(10), 10)                  // მეორე შოკი → -10
        XCTAssertEqual(s.cash, 80)
        XCTAssertEqual(s.penalizeShock(1000), 80, "floor: მხოლოდ დარჩენილი ჩამოიჭრება")
        XCTAssertEqual(s.cash, 0)
        XCTAssertEqual(s.penalizeShock(5), 0, "0-ზე → აღარაფერი ჩამოიჭრება")
        XCTAssertEqual(s.cash, 0)
    }

    // 4) წოდება იზრდება, როცა XP ზღვარს მიაღწევს
    func testRankAdvancesAtThreshold() {
        XCTAssertEqual(CareerRank.rank(forXP: 0), .apprentice)
        XCTAssertEqual(CareerRank.rank(forXP: 299), .apprentice)
        XCTAssertEqual(CareerRank.rank(forXP: 300), .residential)
        XCTAssertEqual(CareerRank.rank(forXP: 5000), .master)

        let s = CareerState(defaults: freshDefaults())
        XCTAssertEqual(s.currentRank, .apprentice)
        s.completeJob(sampleJob(id: "big", xp: 300, cash: 0))
        XCTAssertEqual(s.currentRank, .residential, "300 XP-ზე წოდება უნდა აიწიოს")
    }

    // 5) CareerState ინახება და თავიდან იტვირთება UserDefaults-იდან
    func testPersistenceReload() {
        let defaults = freshDefaults()
        let s1 = CareerState(defaults: defaults)
        s1.completeJob(sampleJob(id: "persist", xp: 120, cash: 90, unlocks: ["tool_x"]))
        // ახალი ინსტანცია იმავე defaults-ით
        let s2 = CareerState(defaults: defaults)
        XCTAssertEqual(s2.totalXP, s1.totalXP)
        XCTAssertEqual(s2.cash, s1.cash)
        XCTAssertTrue(s2.isCompleted("persist"))
        XCTAssertTrue(s2.ownedComponents.contains("tool_x"))
    }

    // 6) jobs.json იტვირთება წარმატებით
    func testJobsJSONLoads() throws {
        let jobs = try GameData.loadJobs()
        XCTAssertGreaterThanOrEqual(jobs.count, 6, "უნდა იყოს 6-8 placeholder სამუშაო")
        XCTAssertTrue(jobs.allSatisfy { !$0.id.isEmpty && !$0.georgianTitle.isEmpty })
    }

    // 7) ყველა უფასო placeholder სამუშაო სრულდება მხოლოდ ბაზისური (უფასო) კომპონენტებით
    func testFreeJobsUseOnlyBasicComponents() throws {
        let templates = try GameData.loadTemplates()
        let jobs = try GameData.loadJobs()
        let freeJobs = jobs.filter { $0.tier == .free }
        XCTAssertFalse(freeJobs.isEmpty)
        for job in freeJobs {
            for id in (job.componentsAvailable + job.requiredComponents) {
                guard let kind = templates[id]?.kind else {
                    XCTFail("\(job.id): უცნობი შაბლონი \(id)"); continue
                }
                XCTAssertTrue(ComponentGating.isBasicFree(kind),
                              "უფასო სამუშაო \(job.id) იყენებს არა-ბაზისურ კომპონენტს \(id) (\(kind))")
            }
            // საჭირო კომპონენტები პალიტრაშია
            for need in job.requiredComponents {
                XCTAssertTrue(job.componentsAvailable.contains(need),
                              "\(job.id): საჭირო \(need) პალიტრაში არ არის")
            }
        }
    }

    // 8) Apprentice (tutorial) სამუშაოები უფასოა; advanced (მაღალი წოდების) — Pro
    func testApprenticeFreeLaterRanksProGated() throws {
        let s = CareerState(defaults: freshDefaults())
        let jobs = try GameData.loadJobs()
        for job in jobs {
            if job.category == .tutorial {
                XCTAssertEqual(job.tier, .free, "Apprentice სამუშაო უნდა იყოს უფასო: \(job.id)")
                XCTAssertFalse(s.isProLocked(job, isPro: false))
            } else {
                XCTAssertEqual(job.tier, .pro, "Advanced სამუშაო უნდა იყოს Pro: \(job.id)")
                XCTAssertTrue(s.isProLocked(job, isPro: false))
                XCTAssertFalse(s.isProLocked(job, isPro: true))
            }
        }
    }

    // MARK: - Advanced career jobs (Phase B)

    private static let advancedThreePhaseIDs: Set<String> = [
        "commercial_cafe_kitchen_board", "industrial_machine_workshop",
        "industrial_warehouse_distribution", "renewable_commercial_rooftop",
        "master_ev_charging_hub"
    ]

    /// 12 advanced სამუშაო: რაოდენობა, წოდებები, ფაზები, კვეთები, შიდა თანმიმდევრულობა.
    func testAdvancedJobsContent() throws {
        let templates = try GameData.loadTemplates()
        let jobs = try GameData.loadJobs()
        XCTAssertEqual(jobs.count, 19, "7 apprentice + 12 advanced = 19")

        let advanced = jobs.filter { $0.category != .tutorial }
        XCTAssertEqual(advanced.count, 12, "12-ვე advanced სამუშაო უნდა იშიფრებოდეს")

        // წოდებები (კატეგორიები) სწორია
        let expectedCategory: [String: JobCategory] = [
            "residential_full_apartment_board": .residential,
            "residential_duplex_distribution": .residential,
            "residential_luxury_apartment": .residential,
            "residential_garden_house_subboard": .residential,
            "commercial_cafe_kitchen_board": .commercial,
            "commercial_office_floor_distribution": .commercial,
            "industrial_machine_workshop": .industrial,
            "industrial_warehouse_distribution": .industrial,
            "renewable_solar_hybrid_home": .renewable,
            "renewable_commercial_rooftop": .renewable,
            "master_ev_charging_hub": .master,
            "master_hotel_floor_system": .master
        ]
        for (id, cat) in expectedCategory {
            let job = try XCTUnwrap(jobs.first { $0.id == id }, "აკლია \(id)")
            XCTAssertEqual(job.category, cat, "\(id): წოდება")
            XCTAssertEqual(job.tier, .pro, "\(id): advanced → Pro")
        }

        // ფაზები: სამფაზიანებს phase == threePhase და .three დონე; დანარჩენებს single
        for job in advanced {
            let expect3 = Self.advancedThreePhaseIDs.contains(job.id)
            XCTAssertEqual(job.phase == .threePhase, expect3, "\(job.id): ფაზა")
            XCTAssertEqual(job.makeLevel().phase, expect3 ? .three : .single, "\(job.id): დონის ფაზა")
        }

        // 6/10მმ² მხოლოდ იქ, სადაც სპეცი ითხოვს
        XCTAssertTrue(try XCTUnwrap(jobs.first { $0.id == "residential_garden_house_subboard" })
            .resolvedCsaOptions.contains(10))
        for id in ["renewable_commercial_rooftop", "master_ev_charging_hub"] {
            XCTAssertTrue(try XCTUnwrap(jobs.first { $0.id == id }).resolvedCsaOptions.contains(6),
                          "\(id): 6მმ² საჭიროა")
        }

        for job in advanced {
            // ვერც ერთი ავტომატი არ აღემატება job-ის მაქს. კვეთის ampacity-ს
            let allowed = Ampacity.maxBreaker(forCsa: job.resolvedCsaOptions.max() ?? 4)
            for id in job.componentsAvailable {
                guard let t = templates[id] else { XCTFail("\(job.id): უცნობი შაბლონი \(id)"); continue }
                if t.kind.isBreaker, let r = t.ratingA {
                    XCTAssertLessThanOrEqual(r, allowed,
                        "\(job.id): \(id) (\(Int(r))A) > დასაშვები \(Int(allowed))A")
                }
            }
            // როზეტიან მიზნებს 30mA დაცვა აქვთ პალიტრაში
            let goalKinds = Set(job.goal.poweredLoads.keys)
            if goalKinds.contains("socket") || goalKinds.contains("socket3ph") {
                let hasRCD = job.componentsAvailable.contains {
                    templates[$0]?.kind == .rcd || templates[$0]?.kind == .rcbo
                }
                XCTAssertTrue(hasRCD, "\(job.id): როზეტის ხაზს სჭირდება 30mA დაცვა")
            }
            // makeLevel მუშაობს; მიზნის ყველა kind პალიტრაშია და მიღწევადია (max 4/შაბლონი)
            let level = job.makeLevel()
            XCTAssertFalse(level.palette.isEmpty, "\(job.id): პალიტრა ცარიელია")
            for (kindStr, count) in job.goal.poweredLoads {
                let kind = try XCTUnwrap(ComponentKind(rawValue: kindStr), "\(job.id): kind \(kindStr)")
                let nTemplates = job.componentsAvailable.filter { templates[$0]?.kind == kind }.count
                XCTAssertGreaterThan(nTemplates, 0, "\(job.id): მიზნის \(kindStr) პალიტრაში არ არის")
                XCTAssertLessThanOrEqual(count, nTemplates * 4, "\(job.id): \(kindStr) მიზანი მიუღწეველია")
            }
            for need in job.requiredComponents {
                XCTAssertTrue(job.componentsAvailable.contains(need),
                              "\(job.id): საჭირო \(need) პალიტრაში არ არის")
            }
        }

        // Learn რეჟიმი უცვლელია: 6 უფასო tutorial დონე ისევ იტვირთება
        let levels = try GameData.loadLevels()
        XCTAssertEqual(levels.filter { $0.resolvedTier == .free && $0.resolvedCategory == .tutorial }.count, 6,
                       "Learn-ის უფასო გაკვეთილები უცვლელი უნდა დარჩეს")
    }

    /// EV-ჰაბის ბალანსის საზღვარი: 4 იდენტური 7კვტ დამტენი 2/1/1 ფაზებზე ზუსტად
    /// imbalance-ზღვარზეა ((max-min) == 0.5·max) და გაგდება არ უნდა მოხდეს.
    /// იცავს master_ev_charging_hub-ს solver-ის წესის მომავალი ცვლილებისგან.
    func testFourIdenticalChargersTwoOneOneIsBalanced() throws {
        let templates = try GameData.loadTemplates()
        let charger = try XCTUnwrap(templates["ev_charger_7kw"])
        let rcbo = try XCTUnwrap(templates["rcbo_b32_30"])
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "supply", phase: .three))
        for (i, ph) in ["L1", "L1", "L2", "L3"].enumerated() {
            let evID = "ev_charger_7kw_\(i + 1)", brkID = "rcbo_b32_30_\(i + 1)"
            b.add(rcbo.makeComponent(instanceID: brkID, phase: .three))
            b.add(charger.makeComponent(instanceID: evID, phase: .three))
            b.connect("supply.\(ph)", "\(brkID).in", csaMm2: 6, color: .brown)
            b.connect("\(brkID).out", "\(evID).L", csaMm2: 6, color: .brown)
            b.connect("supply.N", "\(evID).N", csaMm2: 6, color: .blue)
            b.connect("supply.PE", "\(evID).PE", csaMm2: 6, color: .yellowGreen)
        }
        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertFalse(r.contains(.phaseImbalance), "2/1/1 ზუსტად ზღვარია — ბალანსად უნდა ჩაითვალოს")
        XCTAssertTrue(r.passed, "შეცდომები: \(r.errors.map(\.code))")
        XCTAssertEqual(r.loadStates.filter(\.isPowered).count, 4, "ოთხივე დამტენი მუშაობს")
    }

    // Phase 2 — job → level bridge solvable + completion wiring (award once)
    func testJobLevelSolvableAndCompletesOnce() throws {
        let templates = try GameData.loadTemplates()
        let job = try XCTUnwrap(try GameData.loadJobs().first { $0.id == "job_first_lamp" })
        // job → Level (იგივე solver/success-check, რასაც დონეები იყენებენ)
        let level = job.makeLevel()
        XCTAssertEqual(level.goal.poweredLoads["lamp"], 1)
        var b = level.initialBoard(templates: templates)   // supply only
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.mcb(id: "B", ratingA: 10))
        b.add(ComponentFactory.lamp(id: "L"))
        b.connect("supply.L", "MS.Lin", csaMm2: 1.5, color: .brown)
        b.connect("MS.Lout", "B.in", csaMm2: 1.5, color: .brown)
        b.connect("B.out", "L.L", csaMm2: 1.5, color: .brown)
        b.connect("supply.N", "MS.Nin", csaMm2: 1.5, color: .blue)
        b.connect("MS.Nout", "L.N", csaMm2: 1.5, color: .blue)
        b.connect("supply.PE", "L.PE", csaMm2: 1.5, color: .yellowGreen)
        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertTrue(r.passed, "job-level უნდა გაიჭრას: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "L")?.isPowered == true)

        // success → completeJob ერთხელ
        let s = CareerState(defaults: freshDefaults())
        XCTAssertTrue(s.completeJob(job))
        let xp = s.totalXP, cash = s.cash
        XCTAssertFalse(s.completeJob(job), "გადაჭრის გამეორება ჯილდოს არ ადუბლირებს")
        XCTAssertEqual(s.totalXP, xp)
        XCTAssertEqual(s.cash, cash)
    }

    // Phase 2 — rank/HUD სტატუსი completion-ის შემდეგ
    func testRankReflectsStateAfterCompletion() {
        let s = CareerState(defaults: freshDefaults())
        XCTAssertEqual(s.currentRank, .apprentice)
        s.completeJob(sampleJob(id: "rankup", xp: 300, cash: 0))
        XCTAssertEqual(s.currentRank, .residential)
    }

    // MARK: - Job schema extension (phase / csaOptions / RCBO 32A)

    /// ძველი (legacy) job-ები — phase/csaOptions-ის გარეშე — იშიფრება და
    /// ნაგულისხმევებს იღებს. ვამოწმებთ მხოლოდ nil-phase სამუშაოებს, რომ
    /// მომავალი advanced (threePhase/6-10მმ²) job-ები ტესტს არ ეჯახებოდეს.
    func testOldJobsDecodeWithDefaults() throws {
        let jobs = try GameData.loadJobs()
        let legacy = jobs.filter { $0.phase == nil && $0.csaOptions == nil }
        XCTAssertGreaterThanOrEqual(legacy.count, 7, "7 საწყისი სამუშაო ძველი სქემით უნდა დარჩეს")
        for job in legacy {
            XCTAssertEqual(job.resolvedPhase, .single, "\(job.id): ნაგულისხმევი ფაზა ერთფაზიანია")
            XCTAssertEqual(job.resolvedCsaOptions, [1.5, 2.5, 4],
                           "\(job.id): ნაგულისხმევი კვეთები [1.5, 2.5, 4]")
            let level = job.makeLevel()
            XCTAssertEqual(level.phase, .single)
            for entry in level.palette {
                XCTAssertEqual(entry.csaOptions ?? [], [1.5, 2.5, 4],
                               "\(job.id): პალიტრაში 6/10მმ² არ უნდა გამოჩნდეს უთხოვნელად")
            }
        }
    }

    /// JSON "phase":"threePhase" იშიფრება და სამფაზიან დონეს აგენერირებს.
    func testThreePhaseJobGeneratesThreePhaseLevel() throws {
        let json = """
        {"id":"j3p","georgianTitle":"ტესტი","customerName":"ტ","location":"ტ",
         "category":"industrial","difficulty":5,"tier":"pro","jobBrief":"ტ",
         "componentsAvailable":["main_4p","mcb_b16"],"requiredComponents":[],
         "xpReward":10,"cashReward":10,"unlocks":[],
         "goal":{"poweredLoads":{"motor":1},"description":"ტ","requireBalanced":true},
         "phase":"threePhase","csaOptions":[1.5,2.5,4,6]}
        """.data(using: .utf8)!
        let job = try JSONDecoder().decode(Job.self, from: json)
        XCTAssertEqual(job.phase, .threePhase)
        XCTAssertEqual(job.resolvedPhase, .three)
        let level = job.makeLevel()
        XCTAssertEqual(level.phase, .three, "სამფაზიანი job → სამფაზიანი დონე")
        // 6მმ² მხოლოდ იმიტომ ჩანს, რომ job-მა ცხადად მოითხოვა
        XCTAssertEqual(level.palette.first?.csaOptions ?? [], [1.5, 2.5, 4, 6])
    }

    /// csaOptions [..6,10] მხოლოდ მოთხოვნისას აღწევს პალიტრამდე.
    func testCsaOptionsThreadedToPalette() {
        var job = sampleJob()
        XCTAssertEqual(job.makeLevel().palette.first?.csaOptions ?? [], [1.5, 2.5, 4])
        job.csaOptions = [1.5, 2.5, 4, 6, 10]
        for entry in job.makeLevel().palette {
            XCTAssertEqual(entry.csaOptions ?? [], [1.5, 2.5, 4, 6, 10])
        }
    }

    /// RCBO 32A შაბლონი არსებობს და ამპერაჟი 6მმ²-ს ეტევა (EV-ტიპის ხაზებისთვის).
    func testRcbo32TemplateExists() throws {
        let templates = try GameData.loadTemplates()
        let t = try XCTUnwrap(templates["rcbo_b32_30"], "უნდა არსებობდეს rcbo_b32_30")
        XCTAssertEqual(t.kind, .rcbo)
        XCTAssertEqual(t.ratingA, 32)
        XCTAssertEqual(t.mAtrip, 30)
        XCTAssertLessThanOrEqual(32, Ampacity.maxBreaker(forCsa: 6.0),
                                 "32A ≤ 6მმ²-ის დასაშვები (ampacity)")
    }

    // 9) არსებული დონეები/გაკვეთილი კვლავ იტვირთება (რეგრესია)
    func testExistingLevelsStillLoad() throws {
        let levels = try GameData.loadLevels()
        XCTAssertTrue(levels.contains { $0.id == "lvl_tutorial" })
        // Learn-ის 6 უფასო გაკვეთილი უცვლელია.
        let freeLearn = levels.filter { $0.resolvedTier == .free && $0.resolvedCategory == .tutorial }
        XCTAssertEqual(freeLearn.count, 6)
        // + ფარის აწყობის 2 უფასო შესავალი → სულ 8 უფასო.
        XCTAssertEqual(levels.filter { $0.resolvedTier == .free }.count, 8)
        _ = try GameData.loadTemplates()
    }
}
