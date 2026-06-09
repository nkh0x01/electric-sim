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
            jobBrief: "ტესტი", componentsAvailable: ["main_2p", "lamp_60"],
            requiredComponents: ["main_2p", "lamp_60"],
            xpReward: xp, cashReward: cash, unlocks: unlocks)
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

    // 8) Apprentice (placeholder) სამუშაოები უფასოა; მაღალი წოდების — Pro-ჩაკეტილი
    func testApprenticeFreeLaterRanksProGated() throws {
        let s = CareerState(defaults: freshDefaults())
        let jobs = try GameData.loadJobs()
        // placeholder სამუშაოები ყველა უფასოა → არ-ჩაკეტილი უფასო მომხმარებლისთვის
        for job in jobs {
            XCTAssertEqual(job.tier, .free, "Phase 1 placeholder სამუშაო უნდა იყოს უფასო: \(job.id)")
            XCTAssertFalse(s.isProLocked(job, isPro: false))
        }
        // Pro სამუშაო — ჩაკეტილია უფასოსთვის, ღიაა Pro-სთვის (gating არ იფორკება)
        let proJob = sampleJob(id: "job_pro", tier: .pro)
        XCTAssertTrue(s.isProLocked(proJob, isPro: false))
        XCTAssertFalse(s.isProLocked(proJob, isPro: true))
    }

    // 9) არსებული დონეები/გაკვეთილი კვლავ იტვირთება (რეგრესია)
    func testExistingLevelsStillLoad() throws {
        let levels = try GameData.loadLevels()
        XCTAssertTrue(levels.contains { $0.id == "lvl_tutorial" })
        // 6-დონიანი უფასო ტიერი უცვლელია
        XCTAssertEqual(levels.filter { $0.resolvedTier == .free }.count, 6)
        _ = try GameData.loadTemplates()
    }
}
