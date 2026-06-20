//
//  PlanTests.swift
//  ElectricSimTests
//
//  მონტაჟის დიზაინერი — Phase 1. PlanSizing (წინ-დაზომვა), InstallationGeometry
//  (ტრასის სიგრძე) და ProjectCompiler (გეგმა → Board, solver-ის ვერდიქტი).
//

import XCTest
@testable import ElectricSimCore

final class PlanTests: XCTestCase {

    // MARK: PlanSizing — დატვირთვა → ავტომატი

    func testRequiredBreakerForLightingLoad() {
        // 240W ერთფაზაზე → I ≈ 1.04A → უმცირესი სტანდარტული = 6A.
        XCTAssertEqual(PlanSizing.requiredBreaker(forLoadSumW: 240, phase: .single), 6)
    }

    func testRequiredBreakerForSocketLoad() {
        // 3680W (16A როზეტი) → I = 16A → ავტომატი 16A.
        XCTAssertEqual(PlanSizing.requiredBreaker(forLoadSumW: 3680, phase: .single), 16)
    }

    func testRequiredBreakerRoundsUp() {
        // 4000W → I ≈ 17.4A → შემდეგი სტანდარტი = 20A.
        XCTAssertEqual(PlanSizing.requiredBreaker(forLoadSumW: 4000, phase: .single), 20)
    }

    func testRequiredBreakerThreePhase() {
        // 4000W სამფაზაზე → I = 4000 / (√3·400) ≈ 5.77A → 6A.
        XCTAssertEqual(PlanSizing.requiredBreaker(forLoadSumW: 4000, phase: .three), 6)
    }

    // MARK: PlanSizing — ავტომატი → კვეთა

    func testMinCSAForBreaker() {
        XCTAssertEqual(PlanSizing.minCSA(forBreaker: 16, cable: .copper), 1.5)   // 1.5→16A
        XCTAssertEqual(PlanSizing.minCSA(forBreaker: 20, cable: .copper), 2.5)   // 2.5→20A
        XCTAssertEqual(PlanSizing.minCSA(forBreaker: 25, cable: .copper), 4)     // 4→25A
        XCTAssertEqual(PlanSizing.minCSA(forBreaker: 32, cable: .copper), 6)     // 6→32A
    }

    func testMinCSAAluminumDerate() {
        // ალუმინი 1.5mm² = 16×0.78 ≈ 12.5A < 16 → საჭიროა 2.5mm² (20×0.78 ≈ 15.6) …
        // …არც ის ჰყოფნის 16-ს; 4mm² = 25×0.78 = 19.5 ≥ 16 → 4mm².
        XCTAssertEqual(PlanSizing.minCSA(forBreaker: 16, cable: .aluminum), 4)
    }

    // MARK: გეომეტრია — ტრასის სიგრძე

    func testPolylineLengthMeters() {
        // (0,0)→(3,0)→(3,4): 3 + 4 = 7 უჯრედი; cellMeters 0.5 → 3.5 მ.
        let run = [GridPoint(0, 0), GridPoint(3, 0), GridPoint(3, 4)]
        XCTAssertEqual(InstallationGeometry.polylineLengthCells(run), 7, accuracy: 0.0001)
        let proj = demoProject(run: run, cellMeters: 0.5)
        XCTAssertEqual(proj.runLengthM(), 3.5, accuracy: 0.0001)
    }

    func testPolylineDiagonal() {
        // (0,0)→(3,4): hypot = 5 უჯრედი.
        XCTAssertEqual(InstallationGeometry.polylineLengthCells([GridPoint(0, 0), GridPoint(3, 4)]),
                       5, accuracy: 0.0001)
    }

    // MARK: ProjectCompiler — გეგმა → Board → solver

    func testCompileProducesExpectedBoard() {
        let proj = demoProject()
        let board = ProjectCompiler.board(from: proj, templates: templates())
        // supply + main + 1 ავტომატი + 3 ნათურა
        XCTAssertEqual(board.components.filter { $0.kind == .supply }.count, 1)
        XCTAssertEqual(board.components.filter { $0.kind == .mainSwitch }.count, 1)
        XCTAssertEqual(board.components.filter { $0.kind == .mcb }.count, 1)
        XCTAssertEqual(board.components.filter { $0.kind == .lamp }.count, 3)
        // ავტომატის ნომინალი = წრედის არჩევანი
        XCTAssertEqual(board.components.first { $0.kind == .mcb }?.ratingA, 10)
        // ცხელი სადენი დატვირთვამდე ატარებს ტრასის სიგრძეს
        let runM = proj.runLengthM()
        XCTAssertTrue(board.wires.contains { abs($0.lengthM - runM) < 0.0001 },
                      "ცხელ/ნულ/PE სადენებს ტრასის სიგრძე უნდა ჰქონდეთ")
    }

    func testCompiledLightingCircuitPasses() {
        let proj = demoProject()
        let board = ProjectCompiler.board(from: proj, templates: templates())
        let result = CircuitSolver().solve(board, energize: true)
        XCTAssertTrue(result.passed, "სწორი განათების წრედი უნდა გაიაროს: \(result.errors.map(\.message))")
        // PanelAssembly.validate-საც არ უნდა ჰქონდეს კრიტიკული საჩივარი ამ მინიმალურ ფარზე
        XCTAssertNil(PanelAssembly.validate(board).first { $0.severity == .error },
                     "მინიმალური ფარი (main → ავტომატი → დატვირთვა) ვალიდურია")
    }

    func testUndersizedCableFailsViaExistingSolver() {
        // ავტომატი 32A 1.5mm²-ზე → arსებული solver-ი .breakerExceedsCable-ს უნდა აგდებდეს.
        var proj = demoProject()
        proj.circuit.breakerRatingA = 32
        proj.circuit.csaMm2 = 1.5
        let board = ProjectCompiler.board(from: proj, templates: templates())
        let result = CircuitSolver().solve(board, energize: false)
        XCTAssertTrue(result.issues.contains { $0.code == .breakerExceedsCable },
                      "ნაკლები კვეთა — solver-მა უნდა დაიჭიროს")
    }

    // MARK: ფიქსტურები

    private func templates() -> [String: ComponentTemplate] {
        ["lamp_60": ComponentTemplate(id: "lamp_60", kind: .lamp, name: "ნათურა 60W",
                                      powerW: 60, requiresPE: true)]
    }

    private func demoProject(run: [GridPoint] = [GridPoint(1, 5), GridPoint(5, 5), GridPoint(5, 2)],
                             cellMeters: Double = 0.5) -> InstallationProject {
        let loads = [
            LoadPoint(id: "L1", templateId: "lamp_60", kind: .lamp, at: GridPoint(5, 2)),
            LoadPoint(id: "L2", templateId: "lamp_60", kind: .lamp, at: GridPoint(7, 2)),
            LoadPoint(id: "L3", templateId: "lamp_60", kind: .lamp, at: GridPoint(9, 2))
        ]
        let circuit = PlanCircuit(id: "c1", name: "განათება", kind: .lighting,
                                  loadIDs: ["L1", "L2", "L3"], run: run,
                                  csaMm2: 1.5, breakerRatingA: 10, breakerCurve: .B)
        let room = PlanRoom(id: "r1", name: "ოთახი", origin: GridPoint(0, 0), width: 14, height: 8)
        return InstallationProject(id: "demo", title: "დემო ბინა",
                                   grid: GridSpec(cols: 16, rows: 10, cellMeters: cellMeters),
                                   room: room, panelAt: GridPoint(1, 5),
                                   loads: loads, circuit: circuit)
    }
}
