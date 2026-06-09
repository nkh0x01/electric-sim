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

    // ექვსი free მისია, ცხრა pro (batch-1: 15 მისია, gating tier-ით).
    func testFaultTierSplit() throws {
        let missions = try GameData.loadFaults()
        XCTAssertEqual(missions.filter { $0.tier == .free }.count, 6)
        XCTAssertEqual(missions.filter { $0.tier == .pro }.count, 9)
    }

    // faults.json იტვირთება
    func testFaultsJSONLoads() throws {
        let missions = try GameData.loadFaults()
        XCTAssertEqual(missions.count, 15)
        XCTAssertEqual(missions.filter { $0.tier == .free }.count, 6)
        XCTAssertEqual(missions.filter { $0.tier == .pro }.count, 9)
        XCTAssertEqual(Set(missions.map { $0.id }).count, missions.count, "id-ები უნიკალურია")
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
        let m = try XCTUnwrap(try GameData.loadFaults().first { $0.id == "fault_bedroom_wrong_breaker" })
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

    // MARK: - Batch-1 fault types (Part A)

    private func healthyLampBoard(breakerA: Double = 10, csa: Double = 1.5) -> Board {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.mcb(id: "brk", ratingA: breakerA))
        b.add(ComponentFactory.lamp(id: "L"))
        b.connect("S.L", "MS.Lin", csaMm2: csa, color: .brown)
        b.connect("MS.Lout", "brk.in", csaMm2: csa, color: .brown)
        b.connect("brk.out", "L.L", csaMm2: csa, color: .brown)
        b.connect("S.N", "MS.Nin", csaMm2: csa, color: .blue)
        b.connect("MS.Nout", "L.N", csaMm2: csa, color: .blue)
        b.connect("S.PE", "L.PE", csaMm2: csa, color: .yellowGreen)
        return b
    }

    // explicit-მარკერით წარმოდგენილი (solver-ით აღმოუჩენადი) ტიპები: inject → diagnose → fix.
    func testFlagFaultTypesEndToEnd() {
        let flagTypes: [FaultType] = [.sharedNeutral, .nuisanceRCDTrip, .failedSPD,
                                      .wrongPhaseSequence, .looseNeutral]
        for ft in flagTypes {
            var faulted = healthyLampBoard()
            BoardEdit(setFaultFlag: ["MS": ft]).apply(to: &faulted)
            XCTAssertFalse(FaultEngine.boardPasses(faulted), "\(ft): დეფექტიანი უნდა ჩავარდეს")
            XCTAssertEqual(FaultEngine.diagnose(faulted), ft, "\(ft): დიაგნოზი")
            XCTAssertTrue(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit(clearFaultFlag: ["MS"])),
                          "\(ft): სწორმა fix-მა უნდა გადაჭრას")
            XCTAssertFalse(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit()),
                           "\(ft): ცარიელი fix არ უნდა ჭრიდეს")
        }
    }

    // wrongCableSize: ნამდვილი breakerExceedsCable + მარკერი; fix = კაბელის გასქელება.
    func testWrongCableSizeEndToEnd() {
        var faulted = healthyLampBoard(breakerA: 20, csa: 1.5)   // B20 1.5mm²-ზე → გადახურდება
        BoardEdit(setFaultFlag: ["L": .wrongCableSize]).apply(to: &faulted)
        XCTAssertFalse(FaultEngine.boardPasses(faulted))
        XCTAssertEqual(FaultEngine.diagnose(faulted), .wrongCableSize)
        // სწორი: სქელი კაბელი + მარკერის გაწმენდა
        XCTAssertTrue(FaultEngine.fixResolves(faulted: faulted,
                       fix: BoardEdit(setAllCsaMm2: 2.5, clearFaultFlag: ["L"])))
        // არასწორი: ავტომატის შემცირება — ampacity ვარდება, მაგრამ მარკერი რჩება
        XCTAssertFalse(FaultEngine.fixResolves(faulted: faulted, fix: BoardEdit(setRatingA: ["brk": 10])))
    }
}
