//
//  FaultTests.swift
//  ElectricSimTests
//
//  Fault-finding — Phase 1: ინჟექცია + დიაგნოსტიკა + შესწორების ვერიფიკაცია.
//

import XCTest
@testable import ElectricSimCore

final class FaultTests: XCTestCase {

    private func templates() throws -> [String: ComponentTemplate] {
        try GameData.loadTemplates()
    }

    private func freshDefaults() -> UserDefaults {
        let name = "fault.test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    // მისიის დასრულება — XP/cash ერთხელ (replay არ ადუბლირებს).
    func testCompleteFaultAwardsOnce() throws {
        let m = try XCTUnwrap(try GameData.loadFaults().first)
        let s = CareerState(defaults: freshDefaults())
        let xp0 = s.totalXP, cash0 = s.cash
        XCTAssertTrue(s.completeFault(m))
        XCTAssertEqual(s.totalXP, xp0 + m.xpReward)
        XCTAssertEqual(s.cash, cash0 + m.cashReward)
        XCTAssertTrue(s.isCompleted(m.id))
        XCTAssertFalse(s.completeFault(m), "ხელახლა დასრულება ჯილდოს არ ადუბლირებს")
        XCTAssertEqual(s.totalXP, xp0 + m.xpReward)
        XCTAssertEqual(s.cash, cash0 + m.cashReward)
    }

    // ერთი free მისია, ორი pro (gating არსებული tier-ით).
    func testFaultTierSplit() throws {
        let missions = try GameData.loadFaults()
        XCTAssertEqual(missions.filter { $0.tier == .free }.count, 1)
        XCTAssertEqual(missions.filter { $0.tier == .pro }.count, 2)
    }

    // faults.json იტვირთება
    func testFaultsJSONLoads() throws {
        let missions = try GameData.loadFaults()
        XCTAssertEqual(missions.count, 3)
        XCTAssertEqual(missions.filter { $0.tier == .free }.count, 1)
        XCTAssertEqual(missions.filter { $0.tier == .pro }.count, 2)
        XCTAssertTrue(missions.allSatisfy { !$0.georgianTitle.isEmpty && !$0.symptoms.isEmpty })
    }

    // საბაზისო (ჯანსაღი) ფარი გადის; დეფექტიანი — ვერა.
    func testBaseHealthyFaultedBroken() throws {
        let t = try templates()
        for m in try GameData.loadFaults() {
            XCTAssertTrue(FaultEngine.boardPasses(m.baseBoard(templates: t)),
                          "\(m.id): საბაზისო ფარი უნდა იყოს ჯანსაღი")
            XCTAssertFalse(FaultEngine.boardPasses(m.faultedBoard(templates: t)),
                           "\(m.id): დეფექტიანი ფარი არ უნდა გავიდეს")
        }
    }

    // დეფექტი სწორად დიაგნოზირდება.
    func testEachFaultDiagnosed() throws {
        let t = try templates()
        for m in try GameData.loadFaults() {
            let dx = FaultEngine.diagnose(m.faultedBoard(templates: t))
            XCTAssertEqual(dx, m.faultType, "\(m.id): არასწორი დიაგნოზი (\(String(describing: dx)))")
        }
    }

    // სწორი fix აგვარებს; ცარიელი/არასწორი fix — არა.
    func testCorrectFixResolvesWrongDoesNot() throws {
        let t = try templates()
        for m in try GameData.loadFaults() {
            let faulted = m.faultedBoard(templates: t)
            XCTAssertTrue(FaultEngine.fixResolves(faulted: faulted, fix: m.fix),
                          "\(m.id): სწორმა შესწორებამ უნდა გადაჭრას")
            XCTAssertFalse(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit()),
                           "\(m.id): ცარიელი შესწორება არ უნდა ჭრიდეს")
        }
    }

    // არასწორი ნომინალი — ნაწილობრივი (ჯერ კიდევ დიდი) ავტომატი არ აგვარებს.
    func testWrongBreakerPartialFixFails() throws {
        let t = try templates()
        let m = try XCTUnwrap(try GameData.loadFaults().first { $0.id == "fault_wrong_breaker" })
        let faulted = m.faultedBoard(templates: t)
        // 25A კვლავ > 16A (1.5mm²) → არ ჭრის; 16A → ჭრის
        XCTAssertFalse(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit(setRatingA: ["brk": 25])))
        XCTAssertTrue(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit(setRatingA: ["brk": 16])))
    }

    // repairedBoard (faulted + mission.fix) გადის.
    func testRepairedBoardPasses() throws {
        let t = try templates()
        for m in try GameData.loadFaults() {
            XCTAssertTrue(FaultEngine.boardPasses(m.repairedBoard(templates: t)),
                          "\(m.id): შესწორებული ფარი უნდა გავიდეს")
        }
    }

    // BoardEdit ინჟექცია/გაწმენდა მუშაობს კომპონენტებზე.
    func testBoardEditMutatesComponents() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.mcb(id: "brk", ratingA: 16))
        BoardEdit(setRatingA: ["brk": 32]).apply(to: &b)
        XCTAssertEqual(b.components.first { $0.id == "brk" }?.ratingA, 32)
        b.add(ComponentFactory.socket(id: "soc", powerW: 2300, leakageMa: 80))
        BoardEdit(setLeakageMa: ["soc": 0]).apply(to: &b)
        XCTAssertNil(b.components.first { $0.id == "soc" }?.leakageMa)
    }
}
