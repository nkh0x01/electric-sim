//
//  CircuitSolverTests.swift
//  ElectricSimTests
//
//  Circuit solver-ის ერთეულ-ტესტები: ვალიდაცია + დეფექტების სცენარები
//  (short / overload / leakage / polarity / PE / ampacity).
//

import XCTest
@testable import ElectricSimCore

final class CircuitSolverTests: XCTestCase {

    let solver = CircuitSolver()

    // MARK: - Builders

    /// აშენებს ერთფაზიან ხაზს: კვება → მთავარი → [rcd?] → ავტომატი → დატვირთვა.
    /// აბრუნებს Board-ს. პარამეტრებით ვმართავთ დეფექტებს ტესტებში.
    private func makeLineBoard(load: Component,
                              breakerRating: Double = 10,
                              breakerCurve: BreakerCurve = .B,
                              csa: Double = 1.5,
                              includeRCD: Bool = false,
                              wireNeutral: Bool = true,
                              wirePE: Bool = true,
                              swapPolarity: Bool = false,
                              shortLN: Bool = false) -> Board {
        var board = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "S")
        let main = ComponentFactory.mainSwitch(id: "MS")
        let mcb = ComponentFactory.mcb(id: "B", ratingA: breakerRating, curve: breakerCurve)
        board.add(supply); board.add(main); board.add(mcb); board.add(load)

        let rcd = ComponentFactory.rcd(id: "RCD")
        if includeRCD { board.add(rcd) }

        func p(_ comp: String, _ s: String) -> String { "\(comp).\(s)" }

        // --- ფაზა L ---
        board.connect(p("S", "L"), p("MS", "Lin"), csaMm2: csa, color: .brown)
        if includeRCD {
            board.connect(p("MS", "Lout"), p("RCD", "Lin"), csaMm2: csa, color: .brown)
            board.connect(p("RCD", "Lout"), p("B", "in"), csaMm2: csa, color: .brown)
        } else {
            board.connect(p("MS", "Lout"), p("B", "in"), csaMm2: csa, color: .brown)
        }
        let loadLineTerm = swapPolarity ? p(load.id, "N") : p(load.id, "L")
        board.connect(p("B", "out"), loadLineTerm, csaMm2: csa, color: .brown)

        // --- ნული N ---
        if wireNeutral {
            board.connect(p("S", "N"), p("MS", "Nin"), csaMm2: csa, color: .blue)
            let loadNeutralTerm = swapPolarity ? p(load.id, "L") : p(load.id, "N")
            if includeRCD {
                board.connect(p("MS", "Nout"), p("RCD", "Nin"), csaMm2: csa, color: .blue)
                board.connect(p("RCD", "Nout"), loadNeutralTerm, csaMm2: csa, color: .blue)
            } else {
                board.connect(p("MS", "Nout"), loadNeutralTerm, csaMm2: csa, color: .blue)
            }
        }

        // --- მიწა PE ---
        if wirePE {
            board.connect(p("S", "PE"), p(load.id, "PE"), csaMm2: csa, color: .yellowGreen)
        }

        // --- L–N მოკლე ჩართვა (განზრახ დეფექტი) ---
        if shortLN {
            board.connect(p(load.id, "L"), p(load.id, "N"), csaMm2: csa, color: .brown)
        }

        return board
    }

    // MARK: - 1. სწორი წრედი

    func testValidLampCircuit() {
        let lamp = ComponentFactory.lamp(id: "LAMP", powerW: 60)
        let board = makeLineBoard(load: lamp, breakerRating: 10, csa: 1.5)
        let result = solver.solve(board, energize: true)

        XCTAssertTrue(result.passed, "სწორი ხაზი უნდა გავიდეს ვალიდაცია: \(result.errors.map(\.code))")
        XCTAssertTrue(result.errors.isEmpty)
        let st = result.state(for: "LAMP")
        XCTAssertNotNil(st)
        XCTAssertTrue(st!.isPowered, "ნათურა უნდა აანთდეს")
        XCTAssertNil(st!.trip)
        XCTAssertEqual(st!.currentA, 60.0 / 230.0, accuracy: 0.001)
    }

    // MARK: - 2. როზეტი RCD-ის გარეშე

    func testSocketWithoutRCDFails() {
        let socket = ComponentFactory.socket(id: "SOC", powerW: 2300)
        let board = makeLineBoard(load: socket, breakerRating: 16, csa: 2.5, includeRCD: false)
        let result = solver.solve(board)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.errors.contains { $0.code == .socketWithoutRCD })
    }

    // MARK: - 3. როზეტი RCD-ით

    func testSocketWithRCDPasses() {
        let socket = ComponentFactory.socket(id: "SOC", powerW: 2300)
        let board = makeLineBoard(load: socket, breakerRating: 16, csa: 2.5, includeRCD: true)
        let result = solver.solve(board, energize: true)
        XCTAssertTrue(result.passed, "RCD-ით როზეტი უნდა გავიდეს: \(result.errors.map(\.code))")
        XCTAssertFalse(result.errors.contains { $0.code == .socketWithoutRCD })
        XCTAssertTrue(result.state(for: "SOC")!.isPowered)
    }

    // MARK: - 4. მოკლე ჩართვა L–N

    func testShortCircuitLN() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        let board = makeLineBoard(load: lamp, shortLN: true)
        let result = solver.solve(board, energize: true)
        XCTAssertTrue(result.issues.contains { $0.code == .shortLN }, "უნდა აღმოაჩინოს L–N short")
        let st = result.state(for: "LAMP")!
        XCTAssertEqual(st.trip, .magnetic, "short → მაგნიტური გაგდება")
        XCTAssertFalse(st.isPowered)
    }

    // MARK: - 5. ავტომატი > კაბელის დასაშვები დენი

    func testBreakerExceedsCable() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        // B20 ავტომატი 1.5mm² კაბელზე (max 16A) → შეცდომა
        let board = makeLineBoard(load: lamp, breakerRating: 20, csa: 1.5)
        let result = solver.solve(board)
        XCTAssertTrue(result.errors.contains { $0.code == .breakerExceedsCable })
    }

    func testBreakerMatchesCablePasses() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        // B16 ავტომატი 2.5mm² კაბელზე (max 20A) → ოკ
        let board = makeLineBoard(load: lamp, breakerRating: 16, csa: 2.5)
        let result = solver.solve(board)
        XCTAssertFalse(result.errors.contains { $0.code == .breakerExceedsCable })
    }

    // MARK: - 6. გადატვირთვა (თერმული)

    func testOverloadThermalTrip() {
        // 3000W / 230V ≈ 13A, ავტომატი B10 → გადატვირთვა
        let lamp = ComponentFactory.lamp(id: "HEAT", powerW: 3000)
        let board = makeLineBoard(load: lamp, breakerRating: 10, csa: 2.5)
        let result = solver.solve(board, energize: true)
        let st = result.state(for: "HEAT")!
        XCTAssertEqual(st.trip, .thermal, "გადატვირთვა → თერმული გაგდება")
        XCTAssertTrue(result.issues.contains { $0.code == .overload })
        XCTAssertFalse(st.isPowered)
    }

    // MARK: - 7. დენის გაჟონვა (RCD)

    func testLeakageRCDTrip() {
        // 100mA გაჟონვა, RCD 30mA → RCD გაგდება
        let socket = ComponentFactory.socket(id: "SOC", powerW: 2300, leakageMa: 100)
        let board = makeLineBoard(load: socket, breakerRating: 16, csa: 2.5, includeRCD: true)
        let result = solver.solve(board, energize: true)
        let st = result.state(for: "SOC")!
        XCTAssertEqual(st.trip, .rcd, "გაჟონვა → RCD გაგდება")
        XCTAssertTrue(result.issues.contains { $0.code == .leakageTrip })
    }

    func testLeakageNoRCDShockRisk() {
        // 100mA გაჟონვა, RCD არ არის, PE არ არის → შოკის რისკი
        let lamp = ComponentFactory.lamp(id: "L1", powerW: 60, requiresPE: true, leakageMa: 100)
        let board = makeLineBoard(load: lamp, breakerRating: 10, csa: 1.5,
                                  includeRCD: false, wirePE: false)
        let result = solver.solve(board, energize: true)
        let st = result.state(for: "L1")!
        XCTAssertTrue(st.shockRisk, "მიწის გარეშე გაჟონვა → შოკის რისკი")
        XCTAssertTrue(result.issues.contains { $0.code == .shockRisk })
    }

    // MARK: - 8. მიწის (PE) გარეშე

    func testMissingPE() {
        let lamp = ComponentFactory.lamp(id: "LAMP", requiresPE: true)
        let board = makeLineBoard(load: lamp, wirePE: false)
        let result = solver.solve(board)
        XCTAssertTrue(result.errors.contains { $0.code == .missingPE })
    }

    // MARK: - 9. პოლარობის არევა

    func testPolarityReversed() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        let board = makeLineBoard(load: lamp, swapPolarity: true)
        let result = solver.solve(board)
        XCTAssertTrue(result.errors.contains { $0.code == .polarityReversed })
    }

    // MARK: - 10. ღია წრედი (ნული არ არის)

    func testOpenCircuitNoNeutral() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        let board = makeLineBoard(load: lamp, wireNeutral: false)
        let result = solver.solve(board, energize: true)
        XCTAssertTrue(result.errors.contains { $0.code == .openCircuit })
        XCTAssertFalse(result.state(for: "LAMP")!.isPowered, "ღია წრედზე ნათურა არ ანთდება")
    }

    // MARK: - 11. კვების გარეშე

    func testNoSupply() {
        var board = Board(phase: .single)
        board.add(ComponentFactory.lamp(id: "LAMP"))
        let result = solver.solve(board)
        XCTAssertTrue(result.issues.contains { $0.code == .noSupply })
    }

    // MARK: - 12. Ampacity ცხრილი

    func testAmpacityTable() {
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 1.5), 16)
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 2.5), 20)
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 4), 25)
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 6), 32)
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 10), 40)
        // 3.0mm² → უახლოესი ქვედა სტანდარტი (2.5) → 20A
        XCTAssertEqual(Ampacity.maxBreaker(forCsa: 3.0), 20)
    }

    // MARK: - Phase 2: fault-finding დონეები (prebuilt + fix)

    func testPhase2LevelsLoad() throws {
        let levels = try GameData.loadLevels()
        XCTAssertGreaterThanOrEqual(levels.count, 6)
        XCTAssertEqual(levels.first { $0.id == "lvl_fault_short" }?.resolvedMode, .faultFind)
        XCTAssertEqual(levels.first { $0.id == "lvl_tutorial" }?.resolvedMode, .build)
    }

    func testFaultOpenCircuitLevel() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        let level = try XCTUnwrap(levels.first { $0.id == "lvl_fault_open" })
        var board = level.initialBoard(templates: templates)

        // დეფექტი: ნათურა არ ანათებს (ნული აკლია)
        var r = solver.solve(board, energize: true)
        XCTAssertTrue(r.errors.contains { $0.code == .openCircuit })
        XCTAssertFalse(r.state(for: "lamp")!.isPowered)

        // შესწორება: დააკავშირე გამოტოვებული ნული
        board.connect("main.Nout", "lamp.N", csaMm2: 1.5, color: .blue)
        r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed, "გასწორების შემდეგ უნდა გაიაროს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "lamp")!.isPowered)
    }

    func testFaultShortLevel() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        let level = try XCTUnwrap(levels.first { $0.id == "lvl_fault_short" })
        var board = level.initialBoard(templates: templates)

        // დეფექტი: მოკლე ჩართვა → მაგნიტური გაგდება
        var r = solver.solve(board, energize: true)
        XCTAssertTrue(r.issues.contains { $0.code == .shortLN })
        XCTAssertEqual(r.state(for: "lamp")!.trip, .magnetic)

        // შესწორება: წაშალე ზედმეტი L–N სადენი
        board.wires.removeAll {
            ($0.fromPortID == "lamp.L" && $0.toPortID == "lamp.N") ||
            ($0.fromPortID == "lamp.N" && $0.toPortID == "lamp.L")
        }
        r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed)
        XCTAssertTrue(r.state(for: "lamp")!.isPowered)
    }

    func testFaultLeakageLevel() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        let level = try XCTUnwrap(levels.first { $0.id == "lvl_fault_leakage" })
        var board = level.initialBoard(templates: templates)

        // დეფექტი: გაუმართავი როზეტი აჟონავს → RCD იგდება
        var r = solver.solve(board, energize: true)
        XCTAssertEqual(r.state(for: "soc")!.trip, .rcd)

        // შესწორება: შეცვალე გაუმართავი როზეტი ახლით
        board.components.removeAll { $0.id == "soc" }
        board.wires.removeAll { $0.fromPortID.hasPrefix("soc.") || $0.toPortID.hasPrefix("soc.") }
        board.add(ComponentFactory.socket(id: "good", powerW: 2300))
        board.connect("brk.out", "good.L", csaMm2: 2.5, color: .brown)
        board.connect("rcd.Nout", "good.N", csaMm2: 2.5, color: .blue)
        board.connect("supply.PE", "good.PE", csaMm2: 2.5, color: .yellowGreen)

        r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed, "გასწორების შემდეგ უნდა გაიაროს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "good")!.isPowered)
    }

    // MARK: - Phase 3: სამფაზა + ბალანსი + მოტორი

    /// აშენებს სამფაზიან დაფას N ნათურით, თითო ფაზაზე `phaseFor(i)`.
    private func makeThreePhaseLamps(phaseFor: (Int) -> String, count: Int = 3) -> Board {
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "S", phase: .three))
        let m = ComponentFactory.mainSwitch(id: "M", phase: .three)
        b.add(m)
        b.connect("S.N", "M.Nin", csaMm2: 2.5, color: .blue)
        for c in ["L1", "L2", "L3"] {
            b.connect("S.\(c)", "M.\(c)in", csaMm2: 2.5, color: .brown)
        }
        for i in 0..<count {
            let suf = phaseFor(i)
            let brk = ComponentFactory.mcb(id: "B\(i)", ratingA: 16)
            let lamp = ComponentFactory.lamp(id: "L\(i)", powerW: 60)
            b.add(brk); b.add(lamp)
            b.connect("M.\(suf)out", "B\(i).in", csaMm2: 2.5, color: .brown)
            b.connect("B\(i).out", "L\(i).L", csaMm2: 2.5, color: .brown)
            b.connect("M.Nout", "L\(i).N", csaMm2: 2.5, color: .blue)
            b.connect("S.PE", "L\(i).PE", csaMm2: 2.5, color: .yellowGreen)
        }
        return b
    }

    func testThreePhaseBalanced() {
        let board = makeThreePhaseLamps { ["L1", "L2", "L3"][$0] }
        let r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed, "დაბალანსებული დატვირთვა: \(r.errors.map(\.code))")
        XCTAssertFalse(r.issues.contains { $0.code == .phaseImbalance })
        XCTAssertTrue(r.loadStates.allSatisfy { $0.isPowered })
    }

    func testThreePhaseImbalance() {
        // სამივე ნათურა L1-ზე → დისბალანსი
        let board = makeThreePhaseLamps { _ in "L1" }
        let r = solver.solve(board, energize: true)
        XCTAssertTrue(r.warnings.contains { $0.code == .phaseImbalance })
    }

    func testMotorRuns() {
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "S", phase: .three))
        b.add(ComponentFactory.mainSwitch(id: "M", phase: .three))
        b.add(ComponentFactory.mcb(id: "B", ratingA: 16, curve: .C))
        b.add(ComponentFactory.motor(id: "MOT", powerW: 4000))
        for c in ["L1", "L2", "L3"] { b.connect("S.\(c)", "M.\(c)in", csaMm2: 2.5, color: .brown) }
        b.connect("M.L1out", "B.in", csaMm2: 2.5, color: .brown)
        b.connect("B.out", "MOT.L1", csaMm2: 2.5, color: .brown)
        b.connect("M.L2out", "MOT.L2", csaMm2: 2.5, color: .black)
        b.connect("M.L3out", "MOT.L3", csaMm2: 2.5, color: .grey)
        b.connect("S.PE", "MOT.PE", csaMm2: 2.5, color: .yellowGreen)

        let r = solver.solve(b, energize: true)
        XCTAssertTrue(r.passed, "მოტორი უნდა ამუშავდეს: \(r.errors.map(\.code))")
        let st = r.state(for: "MOT")!
        XCTAssertTrue(st.isPowered)
        XCTAssertEqual(st.currentA, 4000.0 / (Double(3).squareRoot() * 400.0), accuracy: 0.05)
    }

    func testMotorMissingPhaseFails() {
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "S", phase: .three))
        b.add(ComponentFactory.mainSwitch(id: "M", phase: .three))
        b.add(ComponentFactory.mcb(id: "B", ratingA: 16, curve: .C))
        b.add(ComponentFactory.motor(id: "MOT", powerW: 4000))
        for c in ["L1", "L2", "L3"] { b.connect("S.\(c)", "M.\(c)in", csaMm2: 2.5, color: .brown) }
        b.connect("M.L1out", "B.in", csaMm2: 2.5, color: .brown)
        b.connect("B.out", "MOT.L1", csaMm2: 2.5, color: .brown)
        b.connect("M.L2out", "MOT.L2", csaMm2: 2.5, color: .black)
        // L3 განზრახ არ არის
        b.connect("S.PE", "MOT.PE", csaMm2: 2.5, color: .yellowGreen)

        let r = solver.solve(b, energize: true)
        XCTAssertTrue(r.errors.contains { $0.code == .openCircuit })
        XCTAssertFalse(r.state(for: "MOT")!.isPowered)
    }

    func testPhase3LevelsLoad() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        let motorLevel = try XCTUnwrap(levels.first { $0.id == "lvl_motor" })
        XCTAssertEqual(motorLevel.phase, .three)
        XCTAssertEqual(levels.first { $0.id == "lvl_three_phase" }?.goal.requireBalanced, true)
        // მოტორის შაბლონი იქმნება სამი ფაზის ფეხებით
        let motor = templates["motor_3ph"]!.makeComponent(instanceID: "x")
        XCTAssertNotNil(motor.port(conductor: .L3))
    }

    // MARK: - Phase 4: sandbox + custom level (Codable persistence)

    func testPhase4SandboxAndCodable() throws {
        let levels = try GameData.loadLevels()
        let sandboxes = levels.filter { $0.resolvedMode == .sandbox }
        XCTAssertEqual(sandboxes.count, 2, "უნდა იყოს 2 sandbox დონე (1ph + 3ph)")
        XCTAssertTrue(sandboxes.allSatisfy { $0.goal.poweredLoads.isEmpty })

        // Level Codable round-trip — ამაზეა დაფუძნებული custom დონეების შენახვა.
        let data = try JSONEncoder().encode(levels)
        let decoded = try JSONDecoder().decode([Level].self, from: data)
        XCTAssertEqual(decoded.count, levels.count)
        XCTAssertEqual(decoded.map(\.id), levels.map(\.id))
    }

    // MARK: - კომპონენტების ბიბლიოთეკის გაფართოება

    /// ალუმინის კაბელი დერეიტდება: B16 2.5mm² ალუმინზე (20×0.78≈15.6A) → შეცდომა.
    func testAluminumCableDerating() {
        let lamp = ComponentFactory.lamp(id: "LAMP")
        var board = makeLineBoard(load: lamp, breakerRating: 16, csa: 2.5)
        // ფაზის სეგმენტის კაბელი ალუმინად ვაქციოთ
        for i in board.wires.indices where board.wires[i].toPortID == "LAMP.L" {
            board.wires[i].cableType = .aluminum
        }
        let result = solver.solve(board)
        XCTAssertTrue(result.errors.contains { $0.code == .breakerExceedsCable },
                      "ალუმინზე B16/2.5mm² უნდა იყოს გადაჭარბება")
    }

    /// კონტაქტორი დენს ატარებს — მის უკან ნათურა ანათებს.
    func testContactorPassesCurrent() {
        var board = Board(phase: .single)
        board.add(ComponentFactory.supply(id: "S"))
        board.add(ComponentFactory.mainSwitch(id: "MS"))
        board.add(ComponentFactory.mcb(id: "B", ratingA: 10))
        let contactor = ComponentFactory.seriesDevice(id: "K", kind: .contactor,
                                                      name: "კონტაქტორი", conductors: [.L])
        board.add(contactor)
        board.add(ComponentFactory.lamp(id: "LAMP"))
        board.connect("S.L", "MS.Lin", csaMm2: 1.5, color: .brown)
        board.connect("MS.Lout", "B.in", csaMm2: 1.5, color: .brown)
        board.connect("B.out", "K.Lin", csaMm2: 1.5, color: .brown)
        board.connect("K.Lout", "LAMP.L", csaMm2: 1.5, color: .brown)
        board.connect("S.N", "MS.Nin", csaMm2: 1.5, color: .blue)
        board.connect("MS.Nout", "LAMP.N", csaMm2: 1.5, color: .blue)
        board.connect("S.PE", "LAMP.PE", csaMm2: 1.5, color: .yellowGreen)

        let r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed, "კონტაქტორის უკან წრედი უნდა მუშაობდეს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "LAMP")!.isPowered)
    }

    /// ბოილერი (2kW≈8.7A) C16-ზე 2.5mm² → მუშაობს გაგდების გარეშე.
    func testBoilerOnProperBreaker() {
        let boiler = ComponentFactory.appliance(id: "BLR", kind: .boiler, name: "ბოილერი", powerW: 2000)
        let board = makeLineBoard(load: boiler, breakerRating: 16, breakerCurve: .C, csa: 2.5)
        let r = solver.solve(board, energize: true)
        XCTAssertTrue(r.passed, "ბოილერი უნდა მუშაობდეს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "BLR")!.isPowered)
    }

    /// 3-ფაზიანი როზეტი RCD-ის გარეშე → შეცდომა.
    func testThreePhaseSocketRequiresRCD() {
        var board = Board(phase: .three)
        board.add(ComponentFactory.supply(id: "S", phase: .three))
        board.add(ComponentFactory.mainSwitch(id: "M", phase: .three))
        board.add(ComponentFactory.mcb(id: "B", ratingA: 16))
        board.add(ComponentFactory.appliance(id: "SO3", kind: .socket3ph, name: "3-ფაზ. როზეტი",
                                             powerW: 6000, threePhase: true))
        for c in ["L1", "L2", "L3"] { board.connect("S.\(c)", "M.\(c)in", csaMm2: 4, color: .brown) }
        board.connect("M.L1out", "B.in", csaMm2: 4, color: .brown)
        board.connect("B.out", "SO3.L1", csaMm2: 4, color: .brown)
        board.connect("M.L2out", "SO3.L2", csaMm2: 4, color: .black)
        board.connect("M.L3out", "SO3.L3", csaMm2: 4, color: .grey)
        board.connect("S.PE", "SO3.PE", csaMm2: 4, color: .yellowGreen)

        let r = solver.solve(board, energize: true)
        XCTAssertTrue(r.errors.contains { $0.code == .socketWithoutRCD },
                      "3-ფაზიანი როზეტი RCD-ის გარეშე უნდა იძლეოდეს შეცდომას")
    }

    /// გაფართოებული ბიბლიოთეკა იტვირთება და ახალი kind-ები იქმნება.
    func testExpandedLibraryLoads() throws {
        let templates = try GameData.loadTemplates()
        for id in ["mpcb_16", "contactor_3p", "wago_5", "boiler_2000", "socket3ph_16", "smart_relay", "mcb_d20"] {
            XCTAssertNotNil(templates[id], "უნდა არსებობდეს შაბლონი: \(id)")
        }
        let wago = templates["wago_5"]!.makeComponent(instanceID: "w")
        XCTAssertTrue(wago.kind.isConnector)
        let mpcb = templates["mpcb_16"]!.makeComponent(instanceID: "m")
        XCTAssertTrue(mpcb.kind.isBreaker && mpcb.kind.isSeriesDevice)
    }

    // MARK: - დატვირთვის გრაფი + ცალხაზოვანი ნახაზი

    func testLoadReportAndSLD() {
        let lamp = ComponentFactory.lamp(id: "LAMP", powerW: 60)
        let board = makeLineBoard(load: lamp, breakerRating: 10, csa: 1.5)

        let rep = solver.loadReport(board)
        XCTAssertEqual(rep.lines.count, 1)
        XCTAssertEqual(rep.totalPowerW, 60, accuracy: 0.1)
        XCTAssertTrue(rep.lines.first!.powered)
        XCTAssertEqual(rep.lines.first!.phase, .L)
        XCTAssertEqual(rep.totalCurrentA, 60.0 / 230.0, accuracy: 0.01)

        let csv = rep.csv()
        XCTAssertTrue(csv.contains("current_A"))
        XCTAssertTrue(csv.contains("LAMP"))
        XCTAssertTrue(csv.contains("TOTAL"))

        let sld = solver.singleLineDiagram(board)
        XCTAssertEqual(sld.phase, .single)
        XCTAssertTrue(sld.incomer.contains { $0.kind == .supply })
        XCTAssertTrue(sld.incomer.contains { $0.kind == .mainSwitch })
        XCTAssertEqual(sld.circuits.count, 1)
        XCTAssertEqual(sld.circuits.first?.breaker?.kind, .mcb)
        XCTAssertEqual(sld.circuits.first?.csaMm2, 1.5)
    }

    // MARK: - მრჩეველი (Recommender)

    func testRecommenderLamp() {
        let a = Recommender.advise(kind: .lamp, powerW: 60)
        XCTAssertEqual(a.breakerRatingA, 6)       // 0.26A → უმცირესი ნომინალი
        XCTAssertEqual(a.curve, .B)
        XCTAssertEqual(a.csaMm2, 1.5)
        XCTAssertFalse(a.needsRCD)
    }

    func testRecommenderSocketNeedsRCD() {
        let a = Recommender.advise(kind: .socket, powerW: 2300) // 10A ×1.25=12.5 → 16A
        XCTAssertEqual(a.breakerRatingA, 16)
        XCTAssertEqual(a.curve, .B)
        XCTAssertTrue(a.needsRCD)
    }

    func testRecommenderMotorCurveC() {
        let a = Recommender.advise(kind: .motor, powerW: 4000, phase: .three) // ≈5.77A×1.25 → 10A
        XCTAssertEqual(a.curve, .C)
        XCTAssertEqual(a.breakerRatingA, 10)
        XCTAssertFalse(a.needsRCD)
    }

    func testRecommenderAluminumNeedsThickerCable() {
        let cu = Recommender.advise(kind: .boiler, powerW: 5000, cable: .copper)
        let al = Recommender.advise(kind: .boiler, powerW: 5000, cable: .aluminum)
        XCTAssertGreaterThanOrEqual(al.csaMm2, cu.csaMm2, "ალუმინს უფრო მსხვილი კვეთა სჭირდება")
    }

    func testBoardAdviceFlagsMissingProtection() {
        var board = Board(phase: .single)
        board.add(ComponentFactory.supply(id: "S"))
        board.add(ComponentFactory.socket(id: "SO"))
        let recs = Recommender.boardAdvice(board)
        XCTAssertTrue(recs.contains { $0.message.contains("მთავარი") })
        XCTAssertTrue(recs.contains { $0.message.contains("RCD") })
    }

    // MARK: - ძაბვის ვარდნა + სელექტიურობა

    func testVoltageDropFormula() {
        // I=10A, L=20m, 2.5mm² Cu, 1-ფაზა → ΔU ≈ 1.22%
        let p = VoltageDrop.percent(currentA: 10, lengthM: 20, csaMm2: 2.5,
                                    cable: .copper, threePhase: false)
        XCTAssertEqual(p, 1.217, accuracy: 0.02)
        // ალუმინი იგივე პირობებში — მეტი ვარდნა
        let al = VoltageDrop.percent(currentA: 10, lengthM: 20, csaMm2: 2.5,
                                     cable: .aluminum, threePhase: false)
        XCTAssertGreaterThan(al, p)
        XCTAssertEqual(VoltageDrop.limitPct(for: .lamp), 3)
        XCTAssertEqual(VoltageDrop.limitPct(for: .socket), 5)
    }

    func testLoadReportVoltageDrop() {
        let lamp = ComponentFactory.lamp(id: "LAMP", powerW: 2000) // ~8.7A
        var board = makeLineBoard(load: lamp, breakerRating: 16, csa: 1.5)
        for i in board.wires.indices { board.wires[i].lengthM = 30 }
        let rep = solver.loadReport(board)
        XCTAssertGreaterThan(rep.lines.first!.voltageDropPct, 0)
        XCTAssertEqual(rep.lines.first!.csaMm2, 1.5)
        XCTAssertEqual(rep.lines.first!.lengthM, 30, accuracy: 0.1)
    }

    func testSelectivity() {
        XCTAssertTrue(Selectivity.isSelective(upstream: 40, downstream: 16))
        XCTAssertFalse(Selectivity.isSelective(upstream: 16, downstream: 16))
        XCTAssertFalse(Selectivity.isSelective(upstream: 25, downstream: 20))
    }

    func testProtectiveChainAndSelectivityIssues() {
        // supply → main → MCB(A) → MCB(B) → lamp  (ორი ავტომატი მიმდევრობით)
        func build(aRating: Double, bRating: Double) -> Board {
            var b = Board(phase: .single)
            b.add(ComponentFactory.supply(id: "S"))
            b.add(ComponentFactory.mainSwitch(id: "MS"))
            b.add(ComponentFactory.mcb(id: "A", ratingA: aRating))
            b.add(ComponentFactory.mcb(id: "B", ratingA: bRating))
            b.add(ComponentFactory.lamp(id: "LAMP"))
            b.connect("S.L", "MS.Lin", csaMm2: 4, color: .brown)
            b.connect("MS.Lout", "A.in", csaMm2: 4, color: .brown)
            b.connect("A.out", "B.in", csaMm2: 2.5, color: .brown)
            b.connect("B.out", "LAMP.L", csaMm2: 1.5, color: .brown)
            b.connect("S.N", "MS.Nin", csaMm2: 4, color: .blue)
            b.connect("MS.Nout", "LAMP.N", csaMm2: 1.5, color: .blue)
            b.connect("S.PE", "LAMP.PE", csaMm2: 1.5, color: .yellowGreen)
            return b
        }
        let chain = solver.protectiveChain(build(aRating: 40, bRating: 16), loadID: "LAMP")
        XCTAssertEqual(chain.map { $0.ratingA }, [16, 40], "branch→main რიგით")

        XCTAssertTrue(solver.selectivityIssues(build(aRating: 40, bRating: 16)).isEmpty)
        XCTAssertFalse(solver.selectivityIssues(build(aRating: 20, bRating: 16)).isEmpty)
    }

    // MARK: - ხარჯთაღრიცხვა (BOM)

    func testBillOfMaterials() throws {
        let templates = try GameData.loadTemplates()
        var board = Board(phase: .single)
        board.add(ComponentFactory.supply(id: "S"))
        board.add(templates["main_2p"]!.makeComponent(instanceID: "main_2p_1"))
        board.add(templates["mcb_b10"]!.makeComponent(instanceID: "mcb_b10_1"))
        board.add(templates["mcb_b10"]!.makeComponent(instanceID: "mcb_b10_2"))
        board.connect("S.L", "main_2p_1.Lin", csaMm2: 1.5, color: .brown, lengthM: 10)

        let bom = BOMBuilder.build(board)
        // 2× B10 დაჯგუფებული ერთ ხაზში, რაოდენობა 2
        let mcbItem = bom.items.first { $0.name.contains("B10") }
        XCTAssertEqual(mcbItem?.quantity, 2)
        XCTAssertEqual(mcbItem?.unitPriceGEL, 12)
        XCTAssertEqual(mcbItem?.totalGEL, 24)
        XCTAssertGreaterThan(bom.cablePriceGEL, 0)   // 10მ კაბელი
        XCTAssertGreaterThan(bom.totalGEL, bom.componentsGEL - 0.001)
        // supply არ ითვლება
        XCTAssertFalse(bom.items.contains { $0.name.contains("კვება") })
    }

    // MARK: - მრავალი წყარო + ახალი კომპონენტები

    func testBatterySourcePowersLamp() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.source(id: "BAT", kind: .battery, name: "battery", phase: .single))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.mcb(id: "B", ratingA: 10))
        b.add(ComponentFactory.lamp(id: "LAMP"))
        b.connect("BAT.L", "MS.Lin", csaMm2: 1.5, color: .brown)
        b.connect("MS.Lout", "B.in", csaMm2: 1.5, color: .brown)
        b.connect("B.out", "LAMP.L", csaMm2: 1.5, color: .brown)
        b.connect("BAT.N", "MS.Nin", csaMm2: 1.5, color: .blue)
        b.connect("MS.Nout", "LAMP.N", csaMm2: 1.5, color: .blue)
        b.connect("BAT.PE", "LAMP.PE", csaMm2: 1.5, color: .yellowGreen)
        let r = solver.solve(b, energize: true)
        XCTAssertTrue(r.passed, "ბატარეა (წყარო) უნდა კვებავდეს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "LAMP")!.isPowered)
    }

    func testGeneratorPowersMotor() {
        var b = Board(phase: .three)
        b.add(ComponentFactory.source(id: "GEN", kind: .generator, name: "gen", phase: .three))
        b.add(ComponentFactory.mainSwitch(id: "M", phase: .three))
        b.add(ComponentFactory.mcb(id: "B", ratingA: 16, curve: .C))
        b.add(ComponentFactory.motor(id: "MOT", powerW: 4000))
        for c in ["L1", "L2", "L3"] { b.connect("GEN.\(c)", "M.\(c)in", csaMm2: 2.5, color: .brown) }
        b.connect("M.L1out", "B.in", csaMm2: 2.5, color: .brown)
        b.connect("B.out", "MOT.L1", csaMm2: 2.5, color: .brown)
        b.connect("M.L2out", "MOT.L2", csaMm2: 2.5, color: .black)
        b.connect("M.L3out", "MOT.L3", csaMm2: 2.5, color: .grey)
        b.connect("GEN.PE", "MOT.PE", csaMm2: 2.5, color: .yellowGreen)
        let r = solver.solve(b, energize: true)
        XCTAssertTrue(r.state(for: "MOT")!.isPowered, "გენერატორი უნდა ამუშავებდეს მოტორს")
    }

    func testFuseActsAsBreaker() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.seriesDevice(id: "F", kind: .fuse, name: "fuse",
                                            conductors: [.L], ratingA: 20))
        b.add(ComponentFactory.lamp(id: "LAMP"))
        b.connect("S.L", "MS.Lin", csaMm2: 1.5, color: .brown)
        b.connect("MS.Lout", "F.Lin", csaMm2: 1.5, color: .brown)
        b.connect("F.Lout", "LAMP.L", csaMm2: 1.5, color: .brown)
        b.connect("S.N", "MS.Nin", csaMm2: 1.5, color: .blue)
        b.connect("MS.Nout", "LAMP.N", csaMm2: 1.5, color: .blue)
        b.connect("S.PE", "LAMP.PE", csaMm2: 1.5, color: .yellowGreen)
        // 20A დამცველი 1.5mm²-ზე (max 16A) → ampacity შეცდომა (fuse=isBreaker)
        let r = solver.solve(b)
        XCTAssertTrue(r.errors.contains { $0.code == .breakerExceedsCable })
    }

    func testNewKindsLoad() throws {
        let t = try GameData.loadTemplates()
        for id in ["fuse_16", "terminal_block", "estop", "vfd", "generator", "battery", "inverter"] {
            XCTAssertNotNil(t[id], "უნდა არსებობდეს: \(id)")
        }
        XCTAssertTrue(t["terminal_block"]!.makeComponent(instanceID: "x").kind.isConnector)
        XCTAssertTrue(t["generator"]!.makeComponent(instanceID: "g").kind.isSource)
        XCTAssertTrue(t["fuse_16"]!.makeComponent(instanceID: "f").kind.isBreaker)
    }

    // MARK: - 13. სადენის ფერები (IEC)

    func testWireColors() {
        XCTAssertEqual(WireColor.standard(for: .PE), .yellowGreen)
        XCTAssertEqual(WireColor.standard(for: .N), .blue)
        XCTAssertEqual(WireColor.standard(for: .L), .brown)
        XCTAssertEqual(WireColor.standard(for: .L1), .brown)
        XCTAssertEqual(WireColor.standard(for: .L2), .black)
        XCTAssertEqual(WireColor.standard(for: .L3), .grey)
    }

    // MARK: - 14. უფასო დონეების სისრულე (Pro-ჩაკეტვის safeguard)

    /// ყველა უფასო (non-Pro) დონის ყველა საჭირო კომპონენტი ხელმისაწვდომი უნდა იყოს
    /// უფასო მომხმარებლისთვის — წინააღმდეგ შემთხვევაში დონე გაუვალია.
    func testFreeLevelsAreCompletableByFreeUser() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        let freeLevels = levels.filter { $0.resolvedTier == .free }
        XCTAssertGreaterThanOrEqual(freeLevels.count, 5, "უფასო (Learn) ტიერი საკმარისად დიდი უნდა იყოს")
        for level in freeLevels {
            for entry in level.palette {
                XCTAssertNotNil(templates[entry.templateId],
                                "უფასო დონე \(level.id): უცნობი შაბლონი \(entry.templateId)")
                XCTAssertTrue(ComponentGating.isPaletteEntryAvailableForFree(entry, templates: templates),
                              "უფასო დონე \(level.id): \(entry.templateId) Pro-ჩაკეტილია — დონე ვერ გაივლება")
            }
            var availableKinds = Set(level.palette.compactMap { templates[$0.templateId]?.kind })
            availableKinds.formUnion((level.prebuilt?.components ?? []).compactMap { templates[$0.templateId]?.kind })
            for (kindStr, _) in level.goal.poweredLoads {
                guard let kind = ComponentKind(rawValue: kindStr) else {
                    XCTFail("უფასო დონე \(level.id): უცნობი kind \(kindStr)"); continue
                }
                XCTAssertTrue(availableKinds.contains(kind),
                              "უფასო დონე \(level.id): საჭიროა \(kindStr), მაგრამ პალიტრაში/prebuilt-ში არ არის")
            }
        }
    }

    /// დონეები იტვირთება ახალი ველებით (category/tier/difficulty); უფასო ნაკრები ფიქსირებულია.
    func testLevelCategoriesAndTiers() throws {
        let levels = try GameData.loadLevels()
        // უფასოა მხოლოდ Learn (tutorial) დონეები.
        let freeIDs = Set(levels.filter { $0.resolvedTier == .free }.map { $0.id })
        // Learn-ის 6 საწყისი დონე + ფარის აწყობის პირველი 2 (უფასო შესავალი).
        XCTAssertEqual(freeIDs, ["lvl_tutorial", "lvl_socket_rcd", "lvl_two_lamps",
                                 "lvl_lamp_socket", "lvl_two_sockets", "lvl_lamp_two_sockets",
                                 "lvl_panel_basic", "lvl_panel_rcd"])
        XCTAssertTrue(levels.contains { $0.resolvedCategory == .panelAssembly })
        for l in levels { XCTAssertTrue((1...5).contains(l.resolvedDifficulty)) }
        // გაფართოებული კონტენტი — Pro.
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_intro" }?.resolvedTier, .pro)
    }

    /// ტარიფის მოდელი: Learn=უფასო (მხოლოდ ბაზისური კომპონენტებით), დანარჩენი=Pro.
    func testTierModelLearnFreeRestPro() throws {
        let templates = try GameData.loadTemplates()
        let levels = try GameData.loadLevels()
        var freeCount = 0
        for level in levels {
            if level.resolvedTier == .free {
                freeCount += 1
                // 1. უფასო დონე = Learn/tutorial ან ფარის-აწყობის უფასო შესავალი
                XCTAssertTrue([.tutorial, .panelAssembly].contains(level.resolvedCategory),
                              "უფასო დონე \(level.id) უნდა იყოს Learn ან ფარის აწყობა")
                // 2. სრულდება მხოლოდ ბაზისური (უფასო) კომპონენტებით
                for entry in level.palette {
                    guard let kind = templates[entry.templateId]?.kind else {
                        XCTFail("\(level.id): უცნობი შაბლონი \(entry.templateId)"); continue
                    }
                    XCTAssertTrue(ComponentGating.isBasicFree(kind),
                                  "უფასო დონე \(level.id) იყენებს არა-ბაზისურ კომპონენტს \(entry.templateId) (\(kind))")
                }
                // 3. მიზნის ყველა დატვირთვა პალიტრაშია
                let avail = Set(level.palette.compactMap { templates[$0.templateId]?.kind })
                for (k, _) in level.goal.poweredLoads {
                    XCTAssertTrue(ComponentKind(rawValue: k).map(avail.contains) ?? false,
                                  "უფასო დონე \(level.id): მიზანი \(k) პალიტრაში არ არის")
                }
            } else {
                // 4. დანარჩენი (panel/3ph/fault/advanced/sandbox) — Pro
                XCTAssertEqual(level.resolvedTier, .pro, "\(level.id) უნდა იყოს Pro")
            }
        }
        XCTAssertGreaterThanOrEqual(freeCount, 1, "უნდა არსებობდეს მინიმუმ ერთი უფასო Learn დონე")
        // sandbox ყოველთვის Pro
        for s in levels where s.resolvedMode == .sandbox {
            XCTAssertEqual(s.resolvedTier, .pro, "sandbox უნდა იყოს Pro")
        }
        // three-phase / fault-finding — ყველა Pro
        for l in levels where [.threePhase, .faultFinding].contains(l.resolvedCategory) {
            XCTAssertEqual(l.resolvedTier, .pro, "\(l.id) (\(l.resolvedCategory)) უნდა იყოს Pro")
        }
        // ფარის აწყობა — Pro, გარდა პირველი ორი უფასო შესავლისა.
        let freePanelIDs: Set<String> = ["lvl_panel_basic", "lvl_panel_rcd"]
        for l in levels where l.resolvedCategory == .panelAssembly && !freePanelIDs.contains(l.id) {
            XCTAssertEqual(l.resolvedTier, .pro, "\(l.id) — ფარის აწყობა უნდა იყოს Pro")
        }
    }

    /// ფარის აწყობა ცალკე რეჟიმად: 6–8 დონე, პირველი 2 უფასო (ბაზისური კომპონენტებით),
    /// დანარჩენი Pro; თითო დონის goal-დატვირთვა პალიტრაშია.
    func testPanelAssemblyModeProgression() throws {
        let levels = try GameData.loadLevels()
        let templates = try GameData.loadTemplates()
        let panels = levels.filter { $0.resolvedCategory == .panelAssembly }
            .sorted { $0.index < $1.index }
        XCTAssertTrue((6...8).contains(panels.count), "ფარის აწყობა — 6–8 დონე (\(panels.count))")
        // პირველი ორი უფასო, დანარჩენი Pro.
        XCTAssertEqual(Array(panels.prefix(2).map { $0.resolvedTier }), [.free, .free])
        for p in panels.dropFirst(2) { XCTAssertEqual(p.resolvedTier, .pro, "\(p.id) უნდა იყოს Pro") }
        // უფასო ფარები — მხოლოდ ბაზისური კომპონენტებით.
        for p in panels.prefix(2) {
            for e in p.palette {
                guard let kind = templates[e.templateId]?.kind else { XCTFail("\(p.id): \(e.templateId)"); continue }
                XCTAssertTrue(ComponentGating.isBasicFree(kind),
                              "უფასო ფარი \(p.id) იყენებს არა-ბაზისურ კომპონენტს \(e.templateId)")
            }
        }
        // goal-დატვირთვა პალიტრაშია; ფარები იქმნება Board-ად პრობლემის გარეშე.
        for p in panels {
            let avail = Set(p.palette.compactMap { templates[$0.templateId]?.kind })
            for (k, _) in p.goal.poweredLoads {
                XCTAssertTrue(ComponentKind(rawValue: k).map(avail.contains) ?? false,
                              "\(p.id): goal \(k) პალიტრაში არ არის")
            }
            XCTAssertTrue(p.isPanelAssembly, "\(p.id) isPanelAssembly უნდა იყოს true")
        }
    }

    // MARK: - 15. ფარის აწყობის ვალიდაცია (panel assembly)

    /// სწორად აწყობილი ფარი: მთავარი → SPD → RCD → ავტომატები (ზოლით) → ხაზები.
    private func makeCorrectPanel() -> Board {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.spd(id: "SPD"))
        b.add(ComponentFactory.rcd(id: "RCD"))
        b.add(ComponentFactory.busbar(id: "BB", conductor: .L, slots: 4))
        b.add(ComponentFactory.mcb(id: "B1", ratingA: 10))
        b.add(ComponentFactory.mcb(id: "B2", ratingA: 16))
        b.add(ComponentFactory.lamp(id: "LAMP"))
        b.add(ComponentFactory.socket(id: "SOC"))
        b.connect("S.L", "MS.Lin", csaMm2: 4, color: .brown)
        b.connect("MS.Lout", "RCD.Lin", csaMm2: 4, color: .brown)
        b.connect("RCD.Lout", "BB.0", csaMm2: 4, color: .brown)
        b.connect("BB.1", "B1.in", csaMm2: 2.5, color: .brown)
        b.connect("BB.2", "B2.in", csaMm2: 2.5, color: .brown)
        b.connect("B1.out", "LAMP.L", csaMm2: 1.5, color: .brown)
        b.connect("B2.out", "SOC.L", csaMm2: 2.5, color: .brown)
        b.connect("SPD.L", "BB.3", csaMm2: 2.5, color: .brown)
        b.connect("SPD.PE", "S.PE", csaMm2: 2.5, color: .yellowGreen)
        b.connect("S.N", "MS.Nin", csaMm2: 4, color: .blue)
        b.connect("MS.Nout", "RCD.Nin", csaMm2: 4, color: .blue)
        b.connect("RCD.Nout", "LAMP.N", csaMm2: 1.5, color: .blue)
        b.connect("RCD.Nout", "SOC.N", csaMm2: 2.5, color: .blue)
        b.connect("S.PE", "LAMP.PE", csaMm2: 1.5, color: .yellowGreen)
        b.connect("S.PE", "SOC.PE", csaMm2: 2.5, color: .yellowGreen)
        return b
    }

    func testPanelAssemblyCorrectOrderPasses() {
        let b = makeCorrectPanel()
        XCTAssertTrue(PanelAssembly.validate(b).isEmpty,
                      "სწორი ფარი ვერ უნდა აგენერირებდეს შეცდომას: \(PanelAssembly.validate(b).map(\.code))")
        let r = solver.solve(b, energize: true)
        XCTAssertTrue(r.passed, "სწორი ფარი უნდა გაიაროს: \(r.errors.map(\.code))")
        XCTAssertTrue(r.state(for: "LAMP")?.isPowered == true)
        XCTAssertTrue(r.state(for: "SOC")?.isPowered == true)
    }

    func testPanelRcdAfterMcbFails() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.mcb(id: "B1", ratingA: 10))   // ავტომატი RCD-მდე — შეცდომა
        b.add(ComponentFactory.rcd(id: "RCD"))
        b.add(ComponentFactory.busbar(id: "BB", conductor: .L, slots: 4))
        XCTAssertTrue(PanelAssembly.validate(b).contains { $0.code == .panelRcdAfterMcb })
    }

    func testPanelMainNotFirstFails() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mcb(id: "B1", ratingA: 10))   // ავტომატი მთავარამდე — შეცდომა
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.rcd(id: "RCD"))
        XCTAssertTrue(PanelAssembly.validate(b).contains { $0.code == .panelMainNotFirst })
    }

    func testPanelBusbarFeedMissing() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "S"))
        b.add(ComponentFactory.mainSwitch(id: "MS"))
        b.add(ComponentFactory.rcd(id: "RCD"))
        b.add(ComponentFactory.mcb(id: "B1", ratingA: 10))
        b.add(ComponentFactory.mcb(id: "B2", ratingA: 16))   // ორი ავტომატი ზოლის გარეშე
        XCTAssertTrue(PanelAssembly.validate(b).contains { $0.code == .panelBusbarFeed })
    }
}
